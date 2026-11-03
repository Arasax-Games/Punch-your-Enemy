"""Die fünf Titel der Spielmusik. Jede Funktion bekommt einen `Song` (Zeitraster) und einen `Mix`
(Busse/Schichten) und schreibt Noten hinein. Schichten: keys → bass → beat → lead → extra
(in dieser Reihenfolge kommen sie im Spiel mit dem Fortschritt dazu).

Melodien sind von Hand geschrieben: pro Takt eine Liste (Schlag, Ton, Länge in Schlägen[, Stärke]).
"""
from __future__ import annotations

import numpy as np

from synth import (Chord, Mix, Song, SR, autopan, bandpass, bongo, brush_swish, brush_tap, celesta, clap_soft,
                   epiano, flute, glass, hat, highpass, kalimba, kick, lowpass, marimba, note, nylon, pad,
                   pingpong, rim, ride, saturate, shaker, snap, snare_lofi, sub_bass, upright, vibraphone,
                   vinyl, voicing, wind)


# ---------------------------------------------------------------------------
# Hilfen
# ---------------------------------------------------------------------------

def segments(progression: list, first_bar: int = 0, bpb: int = 4) -> list[tuple[int, float, Chord, float]]:
    """['Gm9', ('Am7', 'D7b9'), ...] → [(Takt, Startschlag, Akkord, Länge in Schlägen)]"""
    out = []
    for i, item in enumerate(progression):
        bar = first_bar + i
        if isinstance(item, tuple):
            half = bpb / len(item)
            for k, sym in enumerate(item):
                out.append((bar, k * half, Chord(sym), half))
        else:
            out.append((bar, 0.0, Chord(item), float(bpb)))
    return out


def play_line(song: Song, mix: Mix, bus: str, inst, first_bar: int, line: list, gain: float = 1.0,
              pan: float = 0.0, legato: float = 0.92, human: float = 0.006, vel: float = 0.8,
              transpose: int = 0) -> None:
    rng = song.rng
    for i, bar_notes in enumerate(line):
        for item in bar_notes:
            beat, name, length = item[:3]
            v = item[3] if len(item) > 3 else vel
            v *= rng.uniform(0.92, 1.05)
            t = song.time(first_bar + i, beat, human)
            sig = inst(note(name) + transpose, song.beats(length) * legato, min(1.0, v), rng)
            mix.add(bus, sig, t, gain, pan)


def drums(song: Song, mix: Mix, bus: str, bar: int, pattern: str, make, gain: float = 1.0, pan: float = 0.0,
          human: float = 0.003) -> None:
    """16er-Raster: X laut, x mittel, o leise, , ganz leise, . Pause."""
    levels = {"X": 1.0, "x": 0.75, "o": 0.45, ",": 0.25}
    rng = song.rng
    for step, ch in enumerate(pattern):
        if ch in levels:
            v = levels[ch] * rng.uniform(0.9, 1.05)
            mix.add(bus, make(v, rng), song.time(bar, step * 0.25, human), gain, pan)


def strum(song: Song, mix: Mix, bus: str, inst, notes: list[int], t0: float, length: float, vel: float,
          spread: float = 0.012, gain: float = 1.0, up: bool = False, pans: tuple[float, float] = (-0.3, 0.3)) -> None:
    rng = song.rng
    order = list(reversed(notes)) if up else notes
    for k, m in enumerate(order):
        p = pans[0] + (pans[1] - pans[0]) * (notes.index(m) / max(1, len(notes) - 1))
        v = vel * rng.uniform(0.85, 1.05) * (0.9 if k else 1.0)
        mix.add(bus, inst(m, length, v, rng), t0 + k * spread + rng.normal(0, 0.002), gain, p)


# ---------------------------------------------------------------------------
# 1) Pflaster-Pause – Lo-Fi-Hip-Hop, 78 BPM
# ---------------------------------------------------------------------------

def pflaster_pause() -> tuple[Song, Mix, dict]:
    song = Song(bpm=78, bars=32, swing=0.6, swing_unit=0.25, seed=11)
    mix = Mix(song)
    pan_rate = song.periodic(0.22)
    mix.bus("ep", "keys", send=0.22, post=lambda x: autopan(saturate(lowpass(x, 4200), 1.15), pan_rate, 0.22))
    mix.bus("bass", "bass", send=0.02, post=lambda x: lowpass(x, 700))
    mix.bus("kick", "beat", send=0.04, post=lambda x: lowpass(x, 6000))
    mix.bus("snare", "beat", send=0.28, post=lambda x: lowpass(x, 5200))
    mix.bus("hat", "beat", send=0.06, post=lambda x: lowpass(x, 8000))
    mix.bus("vib", "lead", send=0.28, post=lambda x: pingpong(lowpass(x, 6500), song.beats(0.75), 0.35, 0.2))
    mix.bus("flute", "lead", send=0.3, post=lambda x: lowpass(x, 6000))
    mix.bus("crackle", "extra", send=0.0)
    mix.bus("pad", "extra", send=0.35, post=lambda x: lowpass(x, 1200, 4))

    intro = ["Gm9", "C13", "Fmaj9", "Dm9"]
    a = ["Gm9", "C13", "Fmaj9", "Dm9", "Gm9", "C13", "Am7", "D7b9"]
    b = ["Bbmaj9", "Am9", "Gm9", "Fmaj9", "Bbmaj9", "Am9", "Gm9", ("Am7", "D7b9")]
    outro = ["Gm9", "C13", "Fmaj9", "D7b9"]
    prog = intro + a + b + a + outro
    segs = segments(prog)
    rng = song.rng

    # Tasten: weiche Akkorde, leicht verschleppt
    prev = None
    for bar, b0, ch, length in segs:
        v = voicing(ch, 53, 74, 5 if len(ch.intervals) > 4 else 4, prev, rootless=True)
        prev = v
        if length >= 4:
            hits = [(0.0, 1.45, 0.62), (2.5, 1.35, 0.5)]
            if bar % 4 == 3:
                hits.append((1.75, 0.6, 0.32))
        else:
            hits = [(0.0, length * 0.9, 0.58)]
        for hb, hl, hv in hits:
            strum(song, mix, "ep", epiano, v, song.time(bar, b0 + hb, 0.005), song.beats(hl), hv, spread=0.016)

    # Bass ab Takt 4
    last = None
    for idx, (bar, b0, ch, length) in enumerate(segs):
        if bar < 4:
            continue
        root = ch.bass_note(29, 45, near=last or 31)
        nxt = segs[(idx + 1) % len(segs)][2].bass_note(29, 45, near=root)
        if length >= 4:
            line = [(0.0, root, 1.3, 0.85), (2.5, root + 12 if root + 12 <= 48 else root, 0.6, 0.55),
                    (3.5, nxt + (1 if nxt < root else -1), 0.4, 0.5)]
        else:
            line = [(0.0, root, length * 0.85, 0.8)]
        for beat, m, dur, v in line:
            mix.add("bass", sub_bass(m, song.beats(dur), v, rng, drive=1.5), song.time(bar, b0 + beat, 0.004), 0.9)
        last = root

    # Beat ab Takt 4
    for bar in range(4, 32):
        sec_b = 12 <= bar < 20
        k = "X.....x.x.....x." if sec_b else "X.....x...X....."
        if bar % 8 == 3:
            k = "X.....x...X..x.."
        drums(song, mix, "kick", bar, k, kick, 0.9)
        s = "....X.......X..o" if bar % 8 == 7 else "....X.......X..."
        drums(song, mix, "snare", bar, s, snare_lofi, 0.7)
        drums(song, mix, "hat", bar, "x.o.x.o,x.o.x.o," if bar % 2 else "x.o.x.o.x.o.x.oo",
              lambda v, r: hat(v, r, 0.035), 0.35, 0.25)

    # Melodie: Vibraphon im A-Teil, Flöte im B-Teil
    mel_a = [
        [(1.0, "A4", .5), (1.5, "Bb4", .5), (2.0, "D5", 1.5)],
        [(0.0, "C5", .75), (0.75, "A4", .75), (1.5, "G4", 1.5)],
        [(0.5, "E5", .5), (1.0, "F5", .5), (1.5, "E5", .5), (2.0, "C5", 2.0)],
        [(1.0, "D5", .5), (1.5, "C5", .5), (2.0, "A4", 2.0)],
        [(1.0, "A4", .5), (1.5, "Bb4", .5), (2.0, "D5", 1.0), (3.0, "F5", 1.0)],
        [(0.0, "E5", 1.5), (1.5, "D5", .5), (2.0, "C5", 1.5)],
        [(0.5, "C5", .5), (1.0, "E5", 1.0), (2.0, "G5", .5), (2.5, "E5", 1.5)],
        [(0.0, "F#5", 1.0), (1.0, "Eb5", .5), (1.5, "D5", .5), (2.0, "C5", 1.0), (3.0, "A4", 1.0)],
    ]
    mel_b = [
        [(0.0, "F5", 1.5), (1.5, "D5", .5), (2.0, "C5", 2.0)],
        [(0.0, "E5", 1.5), (1.5, "C5", .5), (2.0, "A4", 2.0)],
        [(0.0, "D5", 1.0), (1.0, "Bb4", 1.0), (2.0, "A4", 1.0), (3.0, "F4", 1.0)],
        [(0.0, "G4", 3.0)],
        [(0.0, "F5", 1.5), (1.5, "G5", .5), (2.0, "F5", .5), (2.5, "D5", 1.5)],
        [(0.0, "E5", 2.0), (2.0, "G5", 1.0), (3.0, "E5", 1.0)],
        [(0.0, "F5", 1.0), (1.0, "D5", 1.0), (2.0, "Bb4", 1.0), (3.0, "A4", 1.0)],
        [(0.0, "C5", 1.5), (2.0, "F#4", 1.0), (3.0, "A4", 1.0)],
    ]
    play_line(song, mix, "vib", vibraphone, 4, mel_a, 0.75, 0.15, vel=0.7)
    play_line(song, mix, "flute", flute, 12, mel_b, 0.55, -0.1, legato=0.95, vel=0.7)
    play_line(song, mix, "vib", vibraphone, 20, mel_a, 0.75, 0.15, vel=0.72)

    # Extras: Knistern über die ganze Schleife, Fläche im B-Teil und am Ende
    mix.add_stereo("crackle", vinyl(song.loop_n, np.random.default_rng(5), rate=6.0), 0.0, 3.0)
    for bar, b0, ch, length in segs:
        if 12 <= bar < 20 or bar >= 28:
            v = voicing(ch, 50, 70, 4, None)
            for m in v:
                mix.add("pad", pad(m, song.beats(length) * 1.02, 0.35, rng, attack=0.8, rel=1.6),
                        song.time(bar, b0), 0.4, rng.uniform(-0.5, 0.5))
    return song, mix, {"rt60": 1.5, "tone": 8500, "wow": 0.0028, "flutter": 0.0007, "eq": [(450, -2.5, 0.8)],
                       "targets": {"keys": 0, "bass": -1, "beat": -1.5, "lead": -1.5, "extra": -9}}


# ---------------------------------------------------------------------------
# 2) Hängematten-Bossa – Bossa nova, 128 BPM
# ---------------------------------------------------------------------------

def haengematten_bossa() -> tuple[Song, Mix, dict]:
    song = Song(bpm=128, bars=48, swing=0.52, swing_unit=0.5, seed=22)
    mix = Mix(song)
    mix.bus("guitar", "keys", send=0.18, post=lambda x: highpass(x, 90))
    mix.bus("bass", "bass", send=0.05, post=lambda x: lowpass(x, 900))
    mix.bus("perc", "beat", send=0.12, post=lambda x: lowpass(x, 11000))
    mix.bus("kick", "beat", send=0.05, post=lambda x: lowpass(x, 3000))
    mix.bus("flute", "lead", send=0.3, post=lambda x: lowpass(x, 7000))
    mix.bus("pad", "extra", send=0.4, post=lambda x: lowpass(x, 1500, 4))
    mix.bus("sparkle", "extra", send=0.45, post=lambda x: pingpong(x, song.beats(1.5), 0.4, 0.3))

    intro = ["Dmaj7", "Dmaj7", "Em7", "A7"]
    a = ["Dmaj7", "Dmaj7", "Em7", "A7", "F#m7", "B7b9", "Em9", "A13"]
    b = ["Gmaj7", "Gm6", "F#m7", "B7", "Em7", "A7", "Dmaj9", ("Em7", "A7")]
    inter = ["Em9", "A13", "Em9", "A13"]
    prog = intro + a + b + a + b + inter + a
    segs = segments(prog)
    rng = song.rng
    a_starts, b_starts = [4, 20, 40], [12, 28]

    # Gitarre: Bossa-Rhythmus über zwei Takte
    prev = None
    for bar, b0, ch, length in segs:
        v = voicing(ch, 52, 72, 4, prev, rootless=False, max_span=12)
        prev = v
        if length >= 4:
            hits = [0.0, 1.5, 3.0] if bar % 2 == 0 else [0.5, 2.0, 3.5]
        else:
            hits = [b0 % 4 + h for h in ([0.0, 1.5] if b0 == 0 else [0.0, 1.0])]
            hits = [h for h in hits if h < 4]
        for k, h in enumerate(hits):
            nxt = hits[k + 1] if k + 1 < len(hits) else b0 + length
            vel = 0.5 if h % 1 == 0 else 0.42
            strum(song, mix, "guitar", nylon, v, song.time(bar, h, 0.004), song.beats(nxt - h) * 0.85, vel,
                  spread=0.009, up=(k % 2 == 1), gain=0.8)
    # Daumen-Bass der Gitarre (leise, hält das Intro zusammen)
    for bar, b0, ch, length in segs:
        for beat in ([0.0, 2.0] if length >= 4 else [b0]):
            m = ch.bass_note(40, 52, near=45, fifth=(length >= 4 and beat == 2.0))
            mix.add("guitar", nylon(m, song.beats(1.6), 0.42, rng), song.time(bar, beat, 0.003), 0.7, -0.1)

    # Kontrabass ab Takt 4
    for idx, (bar, b0, ch, length) in enumerate(segs):
        if bar < 4:
            continue
        root = ch.bass_note(33, 47, near=38)
        fifth = ch.bass_note(33, 47, near=root + 7, fifth=True)
        if length >= 4:
            line = [(0.0, root, 1.4), (1.5, fifth, 0.45), (2.0, fifth, 1.4), (3.5, root, 0.45)]
        else:
            line = [(b0, root, 1.4), (b0 + 1.5, fifth, 0.45)]
        for beat, m, dur in line:
            mix.add("bass", upright(m, song.beats(dur), 0.8 if dur > 1 else 0.6, rng), song.time(bar, beat, 0.004), 1.0)

    # Percussion ab Takt 4: Shaker, Rim-Clave, weiche Bass-Trommel
    for bar in range(4, 48):
        drums(song, mix, "perc", bar, "xoxoxoxoxoxoxoxo", shaker, 0.2, 0.35)
        clave = [0, 3, 6] if bar % 2 == 0 else [2, 5]
        for slot in clave:
            mix.add("perc", rim(0.55 * rng.uniform(0.9, 1.05), rng), song.time(bar, slot * 0.5, 0.003), 0.5, -0.2)
        drums(song, mix, "kick", bar, "x.....o.x.......", lambda v, r: kick(v, r, tone=0.9, length=0.3), 0.55)

    # Flöte
    mel_a = [
        [(0.0, "F#5", 1.5), (1.5, "E5", .5), (2.0, "F#5", 1.0), (3.0, "A5", 1.0)],
        [(0.5, "E5", .5), (1.0, "D5", 1.5), (2.5, "C#5", 1.5)],
        [(0.0, "B4", 1.5), (1.5, "D5", .5), (2.0, "G5", 1.0), (3.0, "F#5", 1.0)],
        [(0.0, "E5", 2.0), (2.0, "C#5", .5), (2.5, "E5", .5), (3.0, "G5", 1.0)],
        [(0.0, "A5", 1.5), (1.5, "E5", .5), (2.0, "C#5", 2.0)],
        [(0.0, "D#5", 1.0), (1.0, "C5", .5), (1.5, "D#5", .5), (2.0, "F#5", 2.0)],
        [(0.0, "G5", 1.0), (1.0, "F#5", 1.0), (2.0, "E5", 1.0), (3.0, "D5", 1.0)],
        [(0.0, "C#5", 2.5), (2.5, "B4", .5), (3.0, "A4", 1.0)],
    ]
    mel_b = [
        [(0.0, "B4", 1.0), (1.0, "D5", 1.0), (2.0, "F#5", 2.0)],
        [(0.0, "E5", 1.5), (1.5, "D5", .5), (2.0, "Bb4", 2.0)],
        [(0.0, "A4", 1.0), (1.0, "C#5", 1.0), (2.0, "E5", 2.0)],
        [(0.0, "D#5", 1.5), (1.5, "F#5", .5), (2.0, "A5", 2.0)],
        [(0.0, "G5", 1.5), (1.5, "F#5", .5), (2.0, "E5", 1.0), (3.0, "D5", 1.0)],
        [(0.0, "C#5", 1.0), (1.0, "E5", 1.0), (2.0, "G5", 1.5), (3.5, "F#5", .5)],
        [(0.0, "E5", 3.0)],
        [(1.0, "B4", .5), (1.5, "C#5", .5), (2.0, "E5", 1.0), (3.0, "G5", 1.0)],
    ]
    for s in a_starts:
        play_line(song, mix, "flute", flute, s, mel_a, 0.6, 0.1, legato=0.95, vel=0.72)
    for s in b_starts:
        play_line(song, mix, "flute", flute, s, mel_b, 0.6, 0.1, legato=0.95, vel=0.72)

    # Extras: Streicherfläche im B-Teil und im Zwischenspiel, Funkeln an Abschnittsanfängen
    for bar, b0, ch, length in segs:
        if any(s <= bar < s + 8 for s in b_starts) or 36 <= bar < 40:
            v = voicing(ch, 55, 76, 4, None)
            for m in v:
                mix.add("pad", pad(m, song.beats(length), 0.3, rng, attack=0.7, rel=1.4, spread=8),
                        song.time(bar, b0), 0.35, rng.uniform(-0.6, 0.6))
    for s in [4, 12, 20, 28, 36, 40]:
        ch = Chord(prog[s] if isinstance(prog[s], str) else prog[s][0])
        tones = ch.tones(79, 93)
        for k, m in enumerate(tones[:4]):
            mix.add("sparkle", glass(m, 0.3, 0.32, rng), song.time(s, k * 0.5), 0.5, 0.4 - 0.25 * k)
    return song, mix, {"rt60": 1.6, "tone": 11000, "wow": 0.0008, "flutter": 0.0003,
                       "targets": {"keys": 0, "bass": -2, "beat": -4, "lead": -1, "extra": -8}}


# ---------------------------------------------------------------------------
# 3) Eisbeutel-Lounge – Jazz-Lounge mit Swing, 96 BPM
# ---------------------------------------------------------------------------

def walking_bass(song: Song, mix: Mix, bus: str, segs, lo: int = 28, hi: int = 50) -> None:
    rng = song.rng
    prev = 41
    for idx, (bar, b0, ch, length) in enumerate(segs):
        nxt = segs[(idx + 1) % len(segs)][2]
        beats = int(length)
        notes = [ch.bass_note(lo, hi, near=prev)]
        target = nxt.bass_note(lo, hi, near=notes[0])
        for k in range(1, beats):
            cur = notes[-1]
            if k == beats - 1:
                n = target + (1 if rng.random() < 0.5 else -1) if rng.random() < 0.75 else target + 7
                if not lo <= n <= hi:
                    n = target - 1
            else:
                tones = [m for m in ch.tones(lo, hi) if 1 <= abs(m - cur) <= 5]
                direction = 1 if target > cur else -1
                tones.sort(key=lambda m: (0 if (m - cur) * direction > 0 else 1, abs(m - cur)))
                n = tones[0] if tones else cur
            notes.append(n)
        for k, m in enumerate(notes):
            v = (0.85 if k == 0 else 0.7) * rng.uniform(0.9, 1.05)
            mix.add(bus, upright(m, song.beat * 0.95, v, rng), song.time(bar, b0 + k, 0.004))
        prev = notes[-1]


def improvise(song: Song, mix: Mix, bus: str, inst, segs, lo: int, hi: int, scale_pcs: set[int],
              gain: float = 1.0, pan: float = 0.0) -> None:
    """Kleine Swing-Phrasen aus Akkord- und Skalentönen (für den Solo-Teil)."""
    rng = song.rng
    cur = (lo + hi) // 2
    seg_at = {}
    for bar, b0, ch, length in segs:
        for k in range(int(length * 2)):
            seg_at[(bar, b0 + k * 0.5)] = ch
    positions = sorted(seg_at)
    i = 0
    while i < len(positions):
        start = i + rng.integers(1, 3)
        length = int(rng.integers(5, 10))
        for j in range(start, min(start + length, len(positions))):
            bar, beat = positions[j]
            ch = seg_at[(bar, beat)]
            if beat % 1 == 0:
                pool = [m for m in ch.tones(lo, hi) if 0 < abs(m - cur) <= 4] or ch.tones(lo, hi)
            else:
                pool = [m for m in range(lo, hi + 1) if m % 12 in scale_pcs and 0 < abs(m - cur) <= 2] or [cur]
            cur = int(rng.choice(pool))
            last = j == min(start + length, len(positions)) - 1
            dur = song.beats(1.5 if last else 0.45)
            v = (0.62 if beat % 1 == 0 else 0.5) * rng.uniform(0.9, 1.08)
            mix.add(bus, inst(cur, dur, v, rng), song.time(bar, beat, 0.006), gain, pan)
        i = start + length + int(rng.integers(2, 5))


def eisbeutel_lounge() -> tuple[Song, Mix, dict]:
    song = Song(bpm=96, bars=40, swing=0.64, swing_unit=0.5, seed=33)
    mix = Mix(song)
    pan_rate = song.periodic(0.3)
    mix.bus("ep", "keys", send=0.2, post=lambda x: autopan(lowpass(x, 4500), pan_rate, 0.18))
    mix.bus("bass", "bass", send=0.06, post=lambda x: lowpass(x, 1200))
    mix.bus("ride", "beat", send=0.12, post=lambda x: lowpass(x, 7000))
    mix.bus("brush", "beat", send=0.15, post=lambda x: lowpass(x, 5000))
    mix.bus("kick", "beat", send=0.03, post=lambda x: lowpass(x, 2000))
    mix.bus("vib", "lead", send=0.28, post=lambda x: lowpass(x, 8000))
    mix.bus("snap", "extra", send=0.35)
    mix.bus("pad", "extra", send=0.4, post=lambda x: lowpass(x, 1400, 4))

    a = ["Fmaj7", "D7b9", "Gm7", "C7", "Am7", "D7", "Gm7", "C7"]
    b = ["Cm7", "F7", "Bbmaj7", "Bbmaj7", "Am7", "D7", "Gm7", "C7b9"]
    vamp = [("Fmaj7", "Dm7"), ("Gm7", "C7")] * 4
    prog = a + a + b + a + vamp
    segs = segments(prog)
    rng = song.rng

    # E-Piano: Charleston-Rhythmus mit Lagen ohne Grundton
    prev = None
    for bar, b0, ch, length in segs:
        v = voicing(ch, 53, 71, 4, prev, rootless=True, max_span=12)
        prev = v
        hits = [(0.0, 0.8, 0.5), (1.5, 1.6, 0.42)] if length >= 4 else [(0.0, 1.4, 0.46)]
        if length >= 4 and bar % 4 == 2:
            hits.append((3.5, 0.4, 0.35))
        for hb, hl, hv in hits:
            strum(song, mix, "ep", epiano, v, song.time(bar, b0 + hb, 0.006), song.beats(hl), hv, spread=0.01,
                  gain=0.9)

    walking_bass(song, mix, "bass", segs)

    # Schlagzeug mit Besen: Ride-Muster, Hi-Hat mit dem Fuß auf 2 und 4, Besen-Wischen
    for bar in range(40):
        for beat, v in [(0, .5), (1, .58), (1.5, .32), (2, .5), (3, .58), (3.5, .32)]:
            mix.add("ride", ride(v * rng.uniform(0.9, 1.05), rng, 1.3), song.time(bar, beat, 0.003), 0.2, 0.35)
        for beat in (1, 3):
            mix.add("brush", hat(0.5, rng, 0.02, tone=0.8), song.time(bar, beat, 0.003), 0.3, 0.1)
            mix.add("brush", brush_tap(0.45 * rng.uniform(0.9, 1.1), rng), song.time(bar, beat, 0.004), 0.4, -0.15)
        mix.add("brush", brush_swish(0.22, rng, song.beats(3.6)), song.time(bar, 0.2), 0.18, -0.3)
        for beat in range(4):
            mix.add("kick", kick(0.25, rng, tone=0.85, length=0.25), song.time(bar, beat, 0.003), 0.4)

    # Vibraphon: Thema (AABA), danach freie Phrasen
    mel_a = [
        [(0.0, "A4", .5), (0.5, "C5", .5), (1.0, "E5", 1.5), (2.5, "D5", .5), (3.0, "C5", 1.0)],
        [(0.0, "Eb5", 1.0), (1.0, "D5", .5), (1.5, "C5", .5), (2.0, "A4", 2.0)],
        [(0.0, "Bb4", 1.5), (1.5, "D5", .5), (2.0, "F5", 1.5), (3.5, "E5", .5)],
        [(0.0, "E5", 1.0), (1.0, "D5", .5), (1.5, "C5", .5), (2.0, "Bb4", 2.0)],
        [(0.0, "C5", .5), (0.5, "E5", .5), (1.0, "G5", 1.5), (2.5, "E5", .5), (3.0, "C5", 1.0)],
        [(0.0, "F#5", 1.5), (1.5, "E5", .5), (2.0, "D5", 1.0), (3.0, "C5", 1.0)],
        [(0.0, "Bb4", 1.0), (1.0, "D5", 1.0), (2.0, "F5", .5), (2.5, "E5", .5), (3.0, "D5", 1.0)],
        [(0.0, "E5", 2.0)],
    ]
    mel_a2 = mel_a[:7] + [[(0.0, "C5", 1.0), (1.5, "A4", .5), (2.0, "C5", 1.0)]]
    mel_b = [
        [(0.0, "Eb5", 1.5), (1.5, "D5", .5), (2.0, "C5", 1.0), (3.0, "Bb4", 1.0)],
        [(0.0, "A4", 1.5), (1.5, "C5", .5), (2.0, "Eb5", 2.0)],
        [(0.0, "D5", 3.0), (3.0, "F5", 1.0)],
        [(0.0, "A5", 2.0), (2.0, "F5", 1.0), (3.0, "D5", 1.0)],
        [(0.0, "E5", 1.5), (1.5, "G5", .5), (2.0, "C5", 2.0)],
        [(0.0, "F#5", 1.5), (1.5, "A5", .5), (2.0, "D5", 1.0), (3.0, "C5", 1.0)],
        [(0.0, "Bb4", 1.0), (1.0, "D5", 1.0), (2.0, "F5", 1.0), (3.0, "A5", 1.0)],
        [(0.0, "G5", 1.5), (1.5, "Db5", .5), (2.0, "E5", 2.0)],
    ]
    play_line(song, mix, "vib", vibraphone, 0, mel_a, 0.7, 0.2, vel=0.72, human=0.008)
    play_line(song, mix, "vib", vibraphone, 8, mel_a2, 0.7, 0.2, vel=0.72, human=0.008)
    play_line(song, mix, "vib", vibraphone, 16, mel_b, 0.7, 0.2, vel=0.72, human=0.008)
    play_line(song, mix, "vib", vibraphone, 24, mel_a, 0.7, 0.2, vel=0.72, human=0.008)
    f_major = {0, 2, 4, 5, 7, 9, 10, 11}
    improvise(song, mix, "vib", vibraphone, segments(vamp, 32), 64, 81, f_major, 0.65, 0.2)

    # Extras: Fingerschnipsen auf 2 und 4 (B-Teil und Solo), Streicher im B-Teil
    for bar in list(range(16, 24)) + list(range(32, 40)):
        for beat in (1, 3):
            mix.add("snap", snap(0.6 * rng.uniform(0.9, 1.1), rng), song.time(bar, beat, 0.006), 0.5,
                    0.5 if beat == 1 else -0.5)
    for bar, b0, ch, length in segs:
        if 16 <= bar < 24:
            for m in voicing(ch, 55, 74, 4, None):
                mix.add("pad", pad(m, song.beats(length), 0.3, rng, attack=0.9, rel=1.5, spread=7),
                        song.time(bar, b0), 0.35, rng.uniform(-0.6, 0.6))
    return song, mix, {"rt60": 1.8, "tone": 10000, "wow": 0.001, "flutter": 0.0004,
                       "targets": {"keys": 0, "bass": -1, "beat": -5, "lead": -1, "extra": -8}}


# ---------------------------------------------------------------------------
# 4) Tortenstrand – tropischer Chill, 104 BPM
# ---------------------------------------------------------------------------

def tortenstrand() -> tuple[Song, Mix, dict]:
    song = Song(bpm=104, bars=40, swing=0.54, swing_unit=0.25, seed=44)
    mix = Mix(song)
    mix.bus("marimba", "keys", send=0.2, post=lambda x: pingpong(lowpass(x, 7000), song.beats(0.75), 0.3, 0.14))
    mix.bus("bass", "bass", send=0.02, post=lambda x: lowpass(x, 800))
    mix.bus("kick", "beat", send=0.04, post=lambda x: lowpass(x, 5000))
    mix.bus("clap", "beat", send=0.45)
    mix.bus("perc", "beat", send=0.15, post=lambda x: lowpass(x, 10000))
    mix.bus("whistle", "lead", send=0.32, post=lambda x: pingpong(lowpass(x, 7000), song.beats(0.75), 0.3, 0.16))
    mix.bus("kalimba", "extra", send=0.3, post=lambda x: pingpong(x, song.beats(0.5), 0.35, 0.2))
    mix.bus("waves", "extra", send=0.1)
    mix.bus("pad", "extra", send=0.4, post=lambda x: lowpass(x, 1600, 4))

    a = ["Gmaj7", "Em7", "Cmaj7", "D6"] * 2
    b = ["Am7", "Bm7", "Cmaj7", ("D7sus4", "D7")] * 2
    prog = a[:4] + a + b + a + a[:4] + b
    segs = segments(prog)
    rng = song.rng
    beat_bars = [bar for bar in range(4, 40) if not 28 <= bar < 32]

    # Marimba: Arpeggio im 16tel-Raster plus tiefer Grundton
    rhythm = "x.xx.x.xx.x.x.xx"
    order = [0, 2, 1, 3, 2, 4, 3, 1, 2, 0, 3, 2, 4, 1, 3, 2]
    prev = None
    for bar, b0, ch, length in segs:
        v = voicing(ch, 62, 79, 4, prev, max_span=12)
        prev = v
        notes = v + [v[0] + 12]
        for step, c in enumerate(rhythm):
            beat = step * 0.25
            if c != "x" or not (b0 <= beat < b0 + length):
                continue
            accent = 0.62 if step % 4 == 0 else 0.46
            mix.add("marimba", marimba(notes[order[step]], 0.2, accent * rng.uniform(0.9, 1.05), rng),
                    song.time(bar, beat, 0.003), 0.75, rng.uniform(-0.35, 0.35))
        mix.add("marimba", marimba(ch.bass_note(43, 55, near=48), 0.4, 0.55, rng), song.time(bar, b0, 0.003), 0.7, -0.1)

    # Bass
    for bar, b0, ch, length in segs:
        if bar < 4 or 28 <= bar < 32:
            continue
        root = ch.bass_note(31, 45, near=38)
        fifth = ch.bass_note(31, 50, near=root + 7, fifth=True)
        pattern = [(0.0, root, .7), (0.75, root, .35), (1.5, root + 12 if root + 12 <= 50 else root, .4),
                   (2.0, root, .7), (2.75, fifth, .5)]
        for beat, m, dur in pattern:
            if b0 <= beat < b0 + length:
                mix.add("bass", sub_bass(m, song.beats(dur), 0.8, rng, drive=1.3, punch=0.5),
                        song.time(bar, beat, 0.003), 0.9)

    # Beat (Pause im Break)
    for bar in beat_bars:
        drums(song, mix, "kick", bar, "x.......x.......", lambda v, r: kick(v, r, tone=1.0, length=0.35), 0.7)
        drums(song, mix, "clap", bar, "....x.......x...", clap_soft, 0.42)
        drums(song, mix, "perc", bar, "xoxoxoxoxoxoxoxo", shaker, 0.16, 0.35)
        for step, f0 in [(3, 360), (7, 260), (11, 360), (14, 260)]:
            mix.add("perc", bongo(0.5 * rng.uniform(0.85, 1.05), rng, f0), song.time(bar, step * 0.25, 0.004),
                    0.45, -0.4 if f0 > 300 else -0.2)

    # Pfeif-Melodie
    mel_a = [
        [(0.0, "D6", .75), (0.75, "B5", .75), (1.5, "G5", .5), (2.0, "A5", 1.5), (3.5, "B5", .5)],
        [(0.0, "G5", 1.5), (1.5, "E5", .5), (2.0, "D5", 2.0)],
        [(0.0, "E5", .75), (0.75, "G5", .75), (1.5, "B5", 1.0), (2.5, "A5", .5), (3.0, "G5", 1.0)],
        [(0.0, "F#5", 2.0), (2.0, "E5", .5), (2.5, "D5", 1.5)],
        [(0.0, "D6", .75), (0.75, "B5", .75), (1.5, "G5", .5), (2.0, "E6", 1.5), (3.5, "D6", .5)],
        [(0.0, "B5", 1.5), (1.5, "G5", .5), (2.0, "E5", 2.0)],
        [(0.0, "G5", .75), (0.75, "A5", .75), (1.5, "B5", .5), (2.0, "C6", 1.0), (3.0, "B5", 1.0)],
        [(0.0, "A5", 3.0)],
    ]
    mel_b = [
        [(0.0, "C6", 1.5), (1.5, "B5", .5), (2.0, "A5", 1.0), (3.0, "G5", 1.0)],
        [(0.0, "F#5", 1.5), (1.5, "A5", .5), (2.0, "D6", 2.0)],
        [(0.0, "E6", 1.0), (1.0, "D6", 1.0), (2.0, "B5", 1.0), (3.0, "G5", 1.0)],
        [(0.0, "A5", 2.0), (2.0, "C6", 1.0), (3.0, "F#5", 1.0)],
        [(0.0, "E5", 1.0), (1.0, "A5", 1.0), (2.0, "C6", 1.5), (3.5, "B5", .5)],
        [(0.0, "A5", 1.5), (1.5, "F#5", .5), (2.0, "D5", 2.0)],
        [(0.0, "G5", 1.0), (1.0, "B5", 1.0), (2.0, "E6", 2.0)],
        [(0.0, "D6", 2.0), (2.0, "C6", 1.0), (3.0, "A5", 1.0)],
    ]
    whistle = lambda m, d, v, r: flute(m, d, v, r, vib_depth=0.006, breath=0.015, pure=True)
    play_line(song, mix, "whistle", whistle, 4, mel_a, 0.42, 0.15, legato=0.9, vel=0.7)
    play_line(song, mix, "whistle", whistle, 12, mel_b, 0.42, 0.15, legato=0.9, vel=0.7)
    play_line(song, mix, "whistle", whistle, 20, mel_a, 0.42, 0.15, legato=0.9, vel=0.7)
    play_line(song, mix, "whistle", whistle, 32, mel_b, 0.42, 0.15, legato=0.9, vel=0.7)

    # Extras: Meeresrauschen, Kalimba-Gegenstimme im B-Teil und Break, Fläche im Break
    mix.add_stereo("waves", wind(song.loop_n, np.random.default_rng(9)), 0.0, 0.4)
    for bar, b0, ch, length in segs:
        if 12 <= bar < 20 or bar >= 28:
            tones = ch.tones(67, 86)
            for k, beat in enumerate([0.5, 1.25, 2.5, 3.0, 3.5]):
                if b0 <= beat < b0 + length and tones:
                    m = tones[(k * 2 + bar) % len(tones)]
                    mix.add("kalimba", kalimba(m, 0.4, 0.5 * rng.uniform(0.85, 1.05), rng),
                            song.time(bar, beat, 0.004), 0.55, 0.45)
        if 28 <= bar < 32:
            for m in voicing(ch, 52, 72, 4, None):
                mix.add("pad", pad(m, song.beats(length), 0.3, rng, attack=0.6, rel=1.2), song.time(bar, b0),
                        0.4, rng.uniform(-0.6, 0.6))
    return song, mix, {"rt60": 1.4, "tone": 12000, "wow": 0.0, "flutter": 0.0,
                       "targets": {"keys": 0, "bass": -1, "beat": -2.5, "lead": -2, "extra": -8}}


# ---------------------------------------------------------------------------
# 5) Sternchen kreisen – Ambient, 64 BPM
# ---------------------------------------------------------------------------

def sternchen_kreisen() -> tuple[Song, Mix, dict]:
    song = Song(bpm=64, bars=28, swing=0.5, swing_unit=0.5, seed=55, tail=8.0)
    mix = Mix(song)
    mix.bus("pad", "keys", send=0.45, post=lambda x: lowpass(x, 1800, 4))
    mix.bus("ep", "keys", send=0.4, post=lambda x: lowpass(x, 3500))
    mix.bus("bass", "bass", send=0.08, post=lambda x: lowpass(x, 400))
    mix.bus("beat", "beat", send=0.35, post=lambda x: lowpass(x, 6000))
    mix.bus("celesta", "lead", send=0.45, post=lambda x: pingpong(x, song.beats(0.75), 0.4, 0.22, tone=5000))
    mix.bus("glass", "extra", send=0.55, post=lambda x: pingpong(x, song.beats(0.5), 0.45, 0.3, tone=6000))
    mix.bus("air", "extra", send=0.2)

    a = ["Dmaj9", "Bm11", "Gmaj9", "A6sus4"] * 2
    b = ["Em9", "F#m7", "Gmaj9", ("Asus4", "A")] * 2
    coda = ["Dmaj9", "Bm11", "Gmaj9", "A6sus4"]
    prog = a + b + a + coda
    segs = segments(prog)
    rng = song.rng

    # Fläche plus sanftes E-Piano
    prev = None
    for bar, b0, ch, length in segs:
        v = voicing(ch, 50, 72, 5 if len(ch.intervals) > 4 else 4, prev, max_span=16)
        prev = v
        for m in v:
            mix.add("pad", pad(m, song.beats(length) * 1.05, 0.32, rng, attack=1.4, rel=2.4, spread=9, sub=0.0),
                    song.time(bar, b0), 0.5, rng.uniform(-0.7, 0.7))
        ep_notes = voicing(ch, 60, 79, 4, None, max_span=14)
        for k, beat in enumerate([0.0, 1.5, 2.5, 3.0]):
            if b0 <= beat < b0 + length:
                mix.add("ep", epiano(ep_notes[(k + bar) % len(ep_notes)], song.beats(1.5), 0.3, rng, bright=0.6),
                        song.time(bar, beat, 0.01), 0.55, rng.uniform(-0.5, 0.5))

    # Bass: lange, weiche Grundtöne
    for bar, b0, ch, length in segs:
        root = ch.bass_note(33, 45, near=38)
        mix.add("bass", sub_bass(root, song.beats(length) * 0.95, 0.7, rng, drive=1.1, rel=0.8, punch=0.15),
                song.time(bar, b0), 0.8)

    # Ganz leiser Puls: weiche Trommel, Rim, Shaker (ab Takt 4, nicht in der Coda)
    for bar in range(4, 24):
        drums(song, mix, "beat", bar, "x.........o.....", lambda v, r: kick(v, r, tone=0.9, length=0.4), 0.45)
        drums(song, mix, "beat", bar, "............x...", rim, 0.18, 0.3)
        drums(song, mix, "beat", bar, "o.,.o.,.o.,.o.,.", shaker, 0.12, -0.3)

    # Celesta-Melodie
    mel_a = [
        [(0.0, "A5", 1.5), (1.5, "F#5", .5), (2.0, "E5", 2.0)],
        [(0.0, "D5", 1.0), (1.0, "E5", 1.0), (2.0, "F#5", 2.0)],
        [(0.0, "B5", 1.5), (1.5, "A5", .5), (2.0, "F#5", 1.0), (3.0, "D5", 1.0)],
        [(0.0, "E5", 4.0)],
        [(0.0, "A5", 1.0), (1.0, "C#6", 1.0), (2.0, "B5", 1.0), (3.0, "A5", 1.0)],
        [(0.0, "F#5", 2.0), (2.0, "E5", 1.0), (3.0, "D5", 1.0)],
        [(0.0, "B4", 1.0), (1.0, "D5", 1.0), (2.0, "F#5", 1.0), (3.0, "A5", 1.0)],
        [(0.0, "E5", 2.0), (2.0, "B4", 2.0)],
    ]
    mel_b = [
        [(0.0, "G5", 2.0), (2.0, "F#5", 1.0), (3.0, "E5", 1.0)],
        [(0.0, "A5", 2.0), (2.0, "E5", 2.0)],
        [(0.0, "D6", 1.5), (1.5, "B5", .5), (2.0, "A5", 2.0)],
        [(0.0, "E5", 2.0), (2.0, "C#6", 2.0)],
        [(0.0, "B5", 1.0), (1.0, "G5", 1.0), (2.0, "F#5", 2.0)],
        [(0.0, "E5", 1.0), (1.0, "C#5", 1.0), (2.0, "A4", 2.0)],
        [(0.0, "B4", 2.0), (2.0, "D5", 2.0)],
        [(0.0, "E5", 4.0)],
    ]
    play_line(song, mix, "celesta", celesta, 0, mel_a, 0.55, 0.1, vel=0.62, human=0.01)
    play_line(song, mix, "celesta", celesta, 8, mel_b, 0.55, 0.1, vel=0.62, human=0.01)
    play_line(song, mix, "celesta", celesta, 16, mel_a, 0.55, 0.1, vel=0.6, human=0.01)

    # Extras: Funkel-Arpeggios in der zweiten Hälfte, leises Luftrauschen
    for bar, b0, ch, length in segs:
        if bar < 8:
            continue
        tones = ch.tones(81, 96)
        for k in range(int(length * 2)):
            beat = b0 + k * 0.5
            m = tones[(k * 3 + bar) % len(tones)]
            mix.add("glass", glass(m, 0.3, 0.3 * rng.uniform(0.7, 1.0), rng), song.time(bar, beat, 0.006), 0.35,
                    rng.uniform(-0.8, 0.8))
    mix.add_stereo("air", wind(song.loop_n, np.random.default_rng(13)), 0.0, 0.12)
    return song, mix, {"rt60": 3.6, "tone": 11000, "wow": 0.0012, "flutter": 0.0002, "predelay": 0.035,
                       "targets": {"keys": 0, "bass": -3, "beat": -9, "lead": -1, "extra": -6}}


TRACKS = [
    ("pflaster_pause", "Pflaster-Pause", pflaster_pause),
    ("haengematten_bossa", "Hängematten-Bossa", haengematten_bossa),
    ("eisbeutel_lounge", "Eisbeutel-Lounge", eisbeutel_lounge),
    ("tortenstrand", "Tortenstrand", tortenstrand),
    ("sternchen_kreisen", "Sternchen kreisen", sternchen_kreisen),
]
