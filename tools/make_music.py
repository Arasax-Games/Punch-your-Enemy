#!/usr/bin/env python3
"""Erzeugt die Spielmusik (5 entspannte Titel) aus tools/music/tracks.py.

    python3 tools/make_music.py               # alle Titel
    python3 tools/make_music.py --only tortenstrand --preview

Ergebnis:
  assets/audio/music/tracks/<id>_<schicht>.ogg   Schichten fürs Spiel (nahtlose Schleifen, gleich lang)
  build/music/<nr> <Titel>.mp3                   Hörfassung (zwei Durchläufe mit Ausblendung) – nicht im Repo
  build/music/preview_<id>.png                   Spektrogramm zur Kontrolle (mit --preview)

Braucht numpy, scipy und ffmpeg (mit libvorbis und libmp3lame); matplotlib nur für --preview.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import zlib

import numpy as np
from scipy.io import wavfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "music"))

from synth import SR, Mix, circular, highpass, lowpass, make_ir, peaking, wow_flutter  # noqa: E402
from tracks import TRACKS  # noqa: E402

GAME_DIR = os.path.join(ROOT, "assets", "audio", "music", "tracks")
LISTEN_DIR = os.path.join(ROOT, "build", "music")
TARGET_DB = -19.0     # Lautheit der vollen Mischung (gegatetes RMS)
PEAK = 0.89           # -1 dBFS
OGG_QUALITY = "3"


def gated_db(x: np.ndarray, win: float = 0.4) -> float:
    mono = x.mean(axis=1) if x.ndim > 1 else x
    n = int(win * SR)
    k = len(mono) // n
    if k == 0:
        return -120.0
    r = np.sqrt((mono[: k * n].reshape(k, n) ** 2).mean(axis=1) + 1e-14)
    db = 20 * np.log10(r)
    active = db[db > max(db.max() - 30, -90)]
    return float(10 * np.log10(np.mean(10 ** (active / 10)))) if len(active) else -120.0


def tone(x: np.ndarray, cutoff: float, circular_loop: bool, eq: list | None = None) -> np.ndarray:
    def fn(y):
        y = highpass(y, 32)
        for f0, gain, q in eq or []:
            y = peaking(y, f0, gain, q)
        return lowpass(y, cutoff) if cutoff < 16000 else y
    return circular(x, fn) if circular_loop else fn(x)


def encode(samples: np.ndarray, path: str, codec_args: list[str]) -> None:
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wavfile.write(tmp.name, SR, samples.astype(np.float32))
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, *codec_args, path], check=True)
    finally:
        os.unlink(tmp.name)


def preview(track_id: str, title: str, full: np.ndarray, layers: dict) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(2, 1, figsize=(14, 7), gridspec_kw={"height_ratios": [3, 2]})
    mono = full.mean(axis=1)
    axes[0].specgram(mono, NFFT=2048, Fs=SR, noverlap=1024, cmap="magma", vmin=-120)
    axes[0].set_ylim(0, 12000)
    axes[0].set_title(f"{title} – Spektrogramm")
    t = np.arange(len(mono)) / SR
    step = int(0.1 * SR)
    for name, x in layers.items():
        env = np.sqrt(np.convolve(x.mean(axis=1) ** 2, np.ones(step) / step, mode="same"))[::step]
        axes[1].plot(t[::step][: len(env)], 20 * np.log10(env + 1e-6), label=name, lw=0.8)
    axes[1].set_ylim(-70, 0)
    axes[1].legend(loc="lower right", ncol=5)
    axes[1].set_xlabel("Sekunden")
    fig.tight_layout()
    fig.savefig(os.path.join(LISTEN_DIR, f"preview_{track_id}.png"), dpi=70)
    plt.close(fig)


def build(number: int, track_id: str, title: str, fn, want_preview: bool) -> dict:
    song, mix, cfg = fn()
    ir = make_ir(cfg["rt60"], seed=zlib.crc32(track_id.encode()) & 0xFFFF, predelay=cfg.get("predelay", 0.018))
    raw = mix.render(ir)
    L = song.loop_n

    # Schichten untereinander ausbalancieren (gegatetes RMS, relativ in dB)
    gains = {}
    for name in Mix.LAYERS:
        level = gated_db(raw[name][:L])
        target = cfg["targets"][name]
        gains[name] = 10 ** ((target - level) / 20) if level > -100 else 0.0

    # Spielfassung: nahtlose Schleife
    loop = [tone(mix.wrap(raw[name] * gains[name]), cfg["tone"], True, cfg.get("eq")) for name in Mix.LAYERS]
    if cfg["wow"] or cfg["flutter"]:
        loop = wow_flutter(loop, song.loop_seconds, cfg["wow"], cfg["flutter"], seed=number)
    full = sum(loop)
    master = 10 ** ((TARGET_DB - gated_db(full)) / 20)
    master = min(master, PEAK / (np.max(np.abs(full)) + 1e-9))
    loop = [x * master for x in loop]
    full = full * master

    os.makedirs(GAME_DIR, exist_ok=True)
    for name, x in zip(Mix.LAYERS, loop):
        encode(x, os.path.join(GAME_DIR, f"{track_id}_{name}.ogg"), ["-c:a", "libvorbis", "-q:a", OGG_QUALITY])

    # Hörfassung: zwei Durchläufe hintereinander (Nachklang fließt natürlich weiter), am Ende ausgeblendet
    unwrapped = sum(raw[name] * gains[name] for name in Mix.LAYERS)
    total = 2 * L + (len(unwrapped) - L)
    listen = np.zeros((total, 2))
    listen[: len(unwrapped)] += unwrapped
    listen[L: L + len(unwrapped)] += unwrapped
    listen = tone(listen, cfg["tone"], False, cfg.get("eq"))
    if cfg["wow"] or cfg["flutter"]:
        listen = wow_flutter([listen], song.loop_seconds, cfg["wow"], cfg["flutter"], seed=number)[0]
    bar = int(song.beats(song.bpb) * SR)
    fade_start = 2 * L - 3 * bar
    fade = np.ones(total)
    fade[fade_start:] = np.clip(1 - (np.arange(total - fade_start) / (total - fade_start)) * 1.4, 0, 1) ** 2
    listen *= fade[:, None] * master
    listen *= min(1.0, PEAK / (np.max(np.abs(listen)) + 1e-9))
    os.makedirs(LISTEN_DIR, exist_ok=True)
    mp3 = os.path.join(LISTEN_DIR, f"{number:02d} {title}.mp3")
    encode(listen, mp3, ["-c:a", "libmp3lame", "-q:a", "2", "-metadata", f"title={title}",
                         "-metadata", "artist=Punch your Enemy", "-metadata", "album=Punch your Enemy – Soundtrack",
                         "-metadata", f"track={number}/{len(TRACKS)}"])
    if want_preview:
        preview(track_id, title, full, dict(zip(Mix.LAYERS, loop)))

    # Naht: Sprung am Schleifenpunkt im Verhältnis zu typischen Sprüngen zwischen zwei Samples
    typical = float(np.percentile(np.abs(np.diff(full[:, 0])), 99)) + 1e-9
    seam = float(np.max(np.abs(full[0] - full[-1]))) / typical
    stats = {name: (round(gated_db(x), 1), round(float(np.max(np.abs(x))), 2)) for name, x in zip(Mix.LAYERS, loop)}
    print(f"{number}. {title}: {song.loop_seconds:.1f} s Schleife, {song.bpm:g} BPM, "
          f"Mischung {gated_db(full):.1f} dB / Spitze {np.max(np.abs(full)):.2f}, Naht {seam:.2f}× (≤ 1 = unhörbar)")
    for name, (db, peak) in stats.items():
        print(f"     {name:6s} {db:6.1f} dB  Spitze {peak:.2f}")
    return {"id": track_id, "seconds": song.loop_seconds}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", help="nur diesen Titel (id)")
    parser.add_argument("--preview", action="store_true", help="Spektrogramme nach build/music/ schreiben")
    args = parser.parse_args()
    for i, (track_id, title, fn) in enumerate(TRACKS, start=1):
        if args.only and args.only != track_id:
            continue
        build(i, track_id, title, fn, args.preview)


if __name__ == "__main__":
    main()
