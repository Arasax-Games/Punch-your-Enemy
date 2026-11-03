"""Kleiner Synthesizer für die Spielmusik (numpy + scipy).

Alles ist deterministisch (feste Zufalls-Seeds), damit `tools/make_music.py` bei jedem Lauf
dieselben Dateien erzeugt. Instrumente liefern Mono-Arrays (float64); der `Mix` verteilt sie
auf Busse (mit Panorama, Hall-Anteil, Nachbearbeitung) und Busse auf Schichten (Stems).
"""
from __future__ import annotations

import itertools
import math

import numpy as np
from scipy import signal

SR = 44100
TAU = 2.0 * math.pi

NOTE_PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
           "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


# ---------------------------------------------------------------------------
# Grundlagen
# ---------------------------------------------------------------------------

def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def note(name: str) -> int:
    """'F#4' -> 66"""
    pc = name[:-1]
    octave = int(name[-1])
    return NOTE_PC[pc] + 12 * (octave + 1)


def _t(n: int) -> np.ndarray:
    return np.arange(n) / SR


def _sos(kind: str, fc, order: int = 2):
    return signal.butter(order, fc, kind, fs=SR, output="sos")


def lowpass(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("lowpass", min(fc, SR * 0.45), order), x, axis=0)


def highpass(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("highpass", fc, order), x, axis=0)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("bandpass", [lo, min(hi, SR * 0.45)], order), x, axis=0)


def peaking(x: np.ndarray, f0: float, gain_db: float, q: float = 1.0) -> np.ndarray:
    """RBJ-Peaking-EQ."""
    a = 10 ** (gain_db / 40)
    w0 = TAU * f0 / SR
    alpha = math.sin(w0) / (2 * q)
    b = [1 + alpha * a, -2 * math.cos(w0), 1 - alpha * a]
    den = [1 + alpha / a, -2 * math.cos(w0), 1 - alpha / a]
    return signal.lfilter(b, den, x, axis=0)


def one_pole(x: np.ndarray, a: float) -> np.ndarray:
    """Weicher Tiefpass y = a*x + (1-a)*y[-1]."""
    return signal.lfilter([a], [1, -(1 - a)], x)


def saturate(x: np.ndarray, drive: float) -> np.ndarray:
    return np.tanh(drive * x) / math.tanh(drive)


def saw(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """Bandbegrenzte Sägezahnwelle (PolyBLEP); freq als Zahl oder Array."""
    dt = np.broadcast_to(np.asarray(freq, dtype=float) / SR, (n,)).copy()
    ph = (phase0 + np.cumsum(dt) - dt[0]) % 1.0
    y = 2.0 * ph - 1.0
    m1 = ph < dt
    t1 = ph[m1] / dt[m1]
    y[m1] -= t1 + t1 - t1 * t1 - 1.0
    m2 = ph > 1.0 - dt
    t2 = (ph[m2] - 1.0) / dt[m2]
    y[m2] -= t2 * t2 + t2 + t2 + 1.0
    return y


def release_env(n: int, gate: float, rel: float) -> np.ndarray:
    """1 bis zum Loslassen, danach exponentiell abklingend (rel ≈ Zeit bis -40 dB)."""
    env = np.ones(n)
    off = int(gate * SR)
    if off < n:
        env[off:] = np.exp(-(np.arange(n - off) / SR) * (4.6 / max(rel, 1e-3)))
    return env


def attack_env(n: int, attack: float) -> np.ndarray:
    a = max(1, int(attack * SR))
    env = np.ones(n)
    k = min(a, n)
    env[:k] = np.sin(np.linspace(0, math.pi / 2, k, endpoint=False)) ** 2
    return env


# ---------------------------------------------------------------------------
# Instrumente (Rückgabe: Mono-Array)
# ---------------------------------------------------------------------------

def epiano(midi: float, dur: float, vel: float, rng, bright: float = 1.0) -> np.ndarray:
    """E-Piano im Stil eines Rhodes: FM 1:1 mit abklingendem Index, leichter Chorus, kurzer Tine-Ping."""
    f = hz(midi)
    n = int((dur + 1.3) * SR)
    t = _t(n)
    tau = 2.1 * (261.6 / f) ** 0.5
    amp = np.exp(-t / tau) * release_env(n, dur, 0.9)
    index = ((0.5 + 1.6 * vel) * np.exp(-t / 0.28) + 0.2) * bright
    s = np.zeros(n)
    car_phase, mod_phase = rng.uniform(0, TAU), rng.uniform(0, TAU)
    for detune in (1.0, 1.0032):  # beide Stimmen starten gleichphasig und laufen langsam auseinander
        ff = f * detune
        s += np.sin(TAU * ff * t + car_phase + index * np.sin(TAU * ff * t + mod_phase))
    s *= 0.5
    tine = np.sin(TAU * f * 7.0 * t) * np.exp(-t / 0.009) * (0.06 + 0.16 * vel) * bright
    return (s + tine) * amp * attack_env(n, 0.002) * vel


def pad(midi: float, dur: float, vel: float, rng, attack: float = 0.9, rel: float = 2.0,
        voices: int = 5, spread: float = 11.0, sub: float = 0.0) -> np.ndarray:
    """Breite Fläche aus verstimmten Sägezähnen (wird auf dem Bus tiefpassgefiltert)."""
    f = hz(midi)
    n = int((dur + rel) * SR)
    t = _t(n)
    s = np.zeros(n)
    for i in range(voices):
        cents = (i - (voices - 1) / 2) / max(1, (voices - 1) / 2) * spread
        drift = 1 + 0.0012 * np.sin(TAU * rng.uniform(0.1, 0.3) * t + rng.uniform(0, TAU))
        s += saw(f * 2 ** (cents / 1200) * drift, n, rng.uniform())
    s /= voices
    if sub:
        s += sub * np.sin(TAU * f * 0.5 * t)
    env = (1 - np.exp(-t / (attack / 3))) * release_env(n, dur, rel)
    return s * env * vel


def sub_bass(midi: float, dur: float, vel: float, rng, drive: float = 1.4, rel: float = 0.12,
             punch: float = 0.35) -> np.ndarray:
    """Runder, leicht angezerrter Sinus-Bass."""
    f = hz(midi)
    n = int((dur + rel + 0.02) * SR)
    t = _t(n)
    ph = TAU * f * t
    s = np.sin(ph) + 0.25 * np.sin(2 * ph + 0.4) + 0.06 * np.sin(3 * ph)
    env = attack_env(n, 0.007) * ((1 - punch) + punch * np.exp(-t / 0.22)) * release_env(n, dur, rel)
    return saturate(s * env, drive) * vel


def karplus(f: float, n: int, rng, decay: float = 0.996, bright: float = 0.5, pick: float = 0.2) -> np.ndarray:
    """Gezupfte Saite (Karplus-Strong), blockweise vektorisiert."""
    period = max(2, int(round(SR / f)))
    exc = rng.uniform(-1, 1, period)
    exc = one_pole(exc, bright)
    shift = max(1, int(period * pick))
    exc = exc - np.roll(exc, shift)  # Anschlagstelle: Kammfilter
    exc -= exc.mean()
    y = np.zeros(n + period + 1)
    y[:period] = exc
    i = period
    while i < n:
        j = min(i + period, n)
        k = j - i
        prev = y[i - period:i - period + k]
        if i - period - 1 >= 0:
            prev2 = y[i - period - 1:i - period - 1 + k]
        else:
            prev2 = np.concatenate(([0.0], y[0:k - 1]))
        y[i:j] = decay * 0.5 * (prev + prev2)
        i = j
    return y[:n]


def nylon(midi: float, dur: float, vel: float, rng) -> np.ndarray:
    """Nylonsaiten-Gitarre: Karplus-Strong plus Korpus-Resonanz."""
    f = hz(midi)
    n = int((dur + 0.35) * SR)
    s = karplus(f, n, rng, decay=0.9982, bright=0.32 + 0.25 * vel, pick=0.18)
    s = peaking(s, 220, 4.0, 1.2)
    s = lowpass(s, 4200)
    s *= release_env(n, dur, 0.3) * attack_env(n, 0.0015)
    return s * vel * 1.6


def upright(midi: float, dur: float, vel: float, rng) -> np.ndarray:
    """Kontrabass: gezupfte Saite mit Grundton-Stütze, kurzem Finger-Geräusch und Abdämpfen."""
    f = hz(midi)
    n = int((dur + 0.18) * SR)
    t = _t(n)
    s = karplus(f, n, rng, decay=0.9975, bright=0.18, pick=0.12)
    s = s / (np.max(np.abs(s[:int(0.1 * SR)])) + 1e-9)
    body = np.sin(TAU * f * t) * np.exp(-t / 0.55) * 0.8
    thump = lowpass(rng.standard_normal(n), 300) * np.exp(-t / 0.012) * 0.25
    out = (0.7 * s + body + thump) * release_env(n, dur, 0.15) * attack_env(n, 0.004)
    return lowpass(out, 1400) * vel


def mallet(midi: float, dur: float, vel: float, rng, partials, attack: float = 0.0015,
           damp: float | None = None, tremolo: tuple[float, float] | None = None,
           click: float = 0.0) -> np.ndarray:
    """Additives Schlaginstrument: partials = [(Frequenz-Verhältnis, Lautstärke, Abklingzeit)]."""
    f = hz(midi)
    longest = max(p[2] for p in partials)
    total = min(longest * 5.0, (dur + damp * 2.5) if damp else longest * 5.0)
    n = int(max(total, 0.05) * SR)
    t = _t(n)
    s = np.zeros(n)
    for ratio, amp, decay in partials:
        if f * ratio >= SR * 0.45:
            continue
        # tiefe Töne klingen länger
        d = decay * (440.0 / f) ** 0.35
        s += amp * np.sin(TAU * f * ratio * t + rng.uniform(0, TAU)) * np.exp(-t / d)
    if tremolo:
        rate, depth = tremolo
        s *= 1 - depth * (0.5 + 0.5 * np.sin(TAU * rate * t + rng.uniform(0, TAU)))
    if click:
        s += click * bandpass(rng.standard_normal(n), 1500, 6000) * np.exp(-t / 0.004)
    if damp:
        s *= release_env(n, dur, damp)
    return s * attack_env(n, attack) * vel


def vibraphone(midi, dur, vel, rng):
    return mallet(midi, dur, vel, rng, [(1, 1.0, 2.2), (4.0, 0.22, 0.5), (10.0, 0.05, 0.12)],
                  damp=0.6, tremolo=(5.2, 0.32), attack=0.002)


def marimba(midi, dur, vel, rng):
    return mallet(midi, dur, vel, rng, [(1, 1.0, 0.55), (3.93, 0.32, 0.13), (10.1, 0.07, 0.04)],
                  click=0.05, attack=0.001)


def kalimba(midi, dur, vel, rng):
    return mallet(midi, dur, vel, rng, [(1, 1.0, 1.1), (2.0, 0.06, 0.35), (5.95, 0.2, 0.06)],
                  click=0.04, attack=0.001)


def celesta(midi, dur, vel, rng):
    return mallet(midi, dur, vel, rng, [(1, 1.0, 1.3), (2.0, 0.18, 0.5), (4.0, 0.08, 0.25),
                                        (6.98, 0.03, 0.08)], attack=0.0015)


def glass(midi, dur, vel, rng):
    """Glockenspiel/Glasglocke für Funkel-Arpeggios."""
    return mallet(midi, dur, vel, rng, [(1, 1.0, 0.9), (2.76, 0.25, 0.35), (5.4, 0.1, 0.12)],
                  attack=0.001)


def flute(midi: float, dur: float, vel: float, rng, vib_depth: float = 0.0035, breath: float = 0.05,
          pure: bool = False) -> np.ndarray:
    """Weiche Flöte (oder mit pure=True ein Pfeifen): Vibrato setzt verzögert ein, leiser Atem."""
    f = hz(midi)
    rel = 0.16
    n = int((dur + rel) * SR)
    t = _t(n)
    vib = vib_depth * np.sin(TAU * (5.6 if pure else 5.0) * t + rng.uniform(0, TAU)) * np.clip((t - 0.18) / 0.4, 0, 1)
    scoop = -0.01 * np.exp(-t / 0.035)
    ph = TAU * np.cumsum(f * (1 + vib + scoop)) / SR
    if pure:
        s = np.sin(ph) + 0.06 * np.sin(2 * ph)
    else:
        s = np.sin(ph) + 0.2 * np.sin(2 * ph + 0.5) + 0.06 * np.sin(3 * ph) + 0.025 * np.sin(4 * ph)
    noise = bandpass(rng.standard_normal(n), f * 1.2, f * 4.0) * breath * (0.5 + 0.8 * np.exp(-t / 0.08))
    env = (1 - np.exp(-t / 0.03)) * release_env(n, dur, rel) * (0.92 + 0.08 * np.minimum(1, t / 0.6))
    return (s + noise) * env * vel


# --- Schlagzeug und Percussion ---------------------------------------------

def kick(vel: float, rng, tone: float = 1.0, length: float = 0.45) -> np.ndarray:
    n = int(length * SR)
    t = _t(n)
    f = (46 + 85 * np.exp(-t / 0.032)) * tone
    body = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / (0.26 * length / 0.45))
    click = lowpass(rng.standard_normal(n), 2500) * np.exp(-t / 0.004) * 0.25
    return saturate(body + click, 1.3) * vel


def snare_lofi(vel: float, rng) -> np.ndarray:
    n = int(0.35 * SR)
    t = _t(n)
    noise = bandpass(rng.standard_normal(n), 1000, 6500) * np.exp(-t / 0.09) * 0.75
    tone = np.sin(TAU * 185 * t) * np.exp(-t / 0.05) * 0.55 + np.sin(TAU * 320 * t) * np.exp(-t / 0.03) * 0.2
    return lowpass(noise + tone, 5200) * vel


def rim(vel: float, rng) -> np.ndarray:
    """Cross-Stick (Bossa)."""
    n = int(0.12 * SR)
    t = _t(n)
    s = np.sin(TAU * 1700 * t) * np.exp(-t / 0.007) * 0.6 + np.sin(TAU * 440 * t) * np.exp(-t / 0.018) * 0.5
    s += bandpass(rng.standard_normal(n), 2000, 5500) * np.exp(-t / 0.008) * 0.5
    return s * vel


def snap(vel: float, rng) -> np.ndarray:
    """Fingerschnipsen."""
    n = int(0.15 * SR)
    t = _t(n)
    s = bandpass(rng.standard_normal(n), 1800, 4200) * np.exp(-t / 0.012)
    s += np.sin(TAU * 2600 * t) * np.exp(-t / 0.006) * 0.3
    return s * vel


def hat(vel: float, rng, length: float = 0.045, tone: float = 1.0) -> np.ndarray:
    n = int(max(length * 4, 0.05) * SR)
    t = _t(n)
    s = highpass(rng.standard_normal(n), 7000 * tone, 2) * np.exp(-t / length)
    return lowpass(s, 12500) * vel


def shaker(vel: float, rng) -> np.ndarray:
    n = int(0.12 * SR)
    t = _t(n)
    env = (1 - np.exp(-t / 0.008)) * np.exp(-t / 0.035)
    return bandpass(rng.standard_normal(n), 3500, 9500) * env * vel


def brush_tap(vel: float, rng) -> np.ndarray:
    n = int(0.25 * SR)
    t = _t(n)
    s = bandpass(rng.standard_normal(n), 1500, 7000) * np.exp(-t / 0.05)
    s += np.sin(TAU * 200 * t) * np.exp(-t / 0.03) * 0.15
    return s * vel


def brush_swish(vel: float, rng, length: float) -> np.ndarray:
    n = int(length * SR)
    s = bandpass(rng.standard_normal(n), 1800, 6000)
    env = np.sin(np.linspace(0, math.pi, n)) ** 1.5
    return s * env * vel


def ride(vel: float, rng, length: float = 1.6) -> np.ndarray:
    """Weiches Ride-Becken: viele unharmonische Teiltöne plus Rauschen."""
    n = int(length * SR)
    t = _t(n)
    s = np.zeros(n)
    for _ in range(14):
        fr = rng.uniform(2800, 9000)
        s += rng.uniform(0.3, 1.0) * np.sin(TAU * fr * t + rng.uniform(0, TAU)) * np.exp(-t / rng.uniform(0.4, 1.4))
    s /= 14
    s += highpass(rng.standard_normal(n), 5000) * np.exp(-t / 0.5) * 0.25
    s += np.sin(TAU * 3300 * t) * np.exp(-t / 0.05) * 0.25  # "Ping"
    return lowpass(s, 9500) * vel


def bongo(vel: float, rng, f0: float = 340.0) -> np.ndarray:
    n = int(0.3 * SR)
    t = _t(n)
    f = f0 * (1 + 0.15 * np.exp(-t / 0.02))
    s = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.09)
    s += bandpass(rng.standard_normal(n), 800, 4000) * np.exp(-t / 0.006) * 0.3
    return s * vel


def clap_soft(vel: float, rng) -> np.ndarray:
    n = int(0.4 * SR)
    t = _t(n)
    env = np.zeros(n)
    for k, d in enumerate((0.0, 0.009, 0.019)):
        i = int(d * SR)
        env[i:] += np.exp(-(t[: n - i]) / (0.008 if k < 2 else 0.11)) * (0.7 if k < 2 else 1.0)
    return bandpass(rng.standard_normal(n), 900, 3500) * env * vel * 0.8


# --- Geräusche ---------------------------------------------------------------

def vinyl(n: int, rng, rate: float = 7.0, level: float = 1.0) -> np.ndarray:
    """Schallplattenknistern (stereo): spärliche Knackser, gelegentliche Plopps, leises Rauschen."""
    out = np.zeros((n, 2))
    for ch in range(2):
        clicks = np.zeros(n)
        count = rng.poisson(rate * n / SR)
        pos = rng.integers(0, n - 4, count)
        clicks[pos] = rng.lognormal(-1.2, 0.7, count) * rng.choice([-1, 1], count)
        crackle = bandpass(clicks, 1200, 9000)
        pops = np.zeros(n)
        count = rng.poisson(0.25 * n / SR)
        pos = rng.integers(0, n - 4, count)
        pops[pos] = rng.uniform(1.5, 3.0, count)
        pops = lowpass(pops, 1500)
        hiss = bandpass(rng.standard_normal(n), 1500, 8000) * 0.012
        out[:, ch] = (crackle * 0.5 + pops * 0.15 + hiss) * level
    return out


def wind(n: int, rng, level: float = 1.0) -> np.ndarray:
    """Sanftes Rauschen mit langsamer Bewegung (Meer/Wind), stereo."""
    out = np.zeros((n, 2))
    t = _t(n)
    for ch in range(2):
        noise = lowpass(rng.standard_normal(n), 700, 2)
        swell = 0.55 + 0.45 * np.sin(TAU * (0.07 + 0.02 * ch) * t + rng.uniform(0, TAU))
        out[:, ch] = noise * swell * level
    return out


# ---------------------------------------------------------------------------
# Effekte
# ---------------------------------------------------------------------------

def make_ir(rt60: float, seed: int, predelay: float = 0.018, hf: float = 0.45, length: float | None = None,
            low_cut: float = 180.0) -> np.ndarray:
    """Synthetische Stereo-Raumantwort: abklingendes Rauschen, Höhen klingen schneller ab."""
    rng = np.random.default_rng(seed)
    length = length or min(rt60 * 1.4, 5.0)
    n = int(length * SR)
    t = _t(n)
    ir = np.zeros((n, 2))
    for ch in range(2):
        noise = rng.standard_normal(n)
        lo = lowpass(noise, 1600, 2)
        hi = noise - lo
        tail = lo * 10 ** (-3 * t / rt60) + 0.55 * hi * 10 ** (-3 * t / (rt60 * hf))
        tail *= np.minimum(1, t / 0.025)
        for k in range(7):  # frühe Reflexionen
            i = int(rng.uniform(0.004, 0.045) * SR)
            tail[i] += rng.uniform(0.8, 2.0) * (-1) ** k
        ir[:, ch] = tail
    ir = highpass(ir, low_cut)
    ir = np.concatenate([np.zeros((int(predelay * SR), 2)), ir])
    ir /= np.sqrt(np.sum(ir ** 2) / 2)
    return ir


def reverb(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    out = np.zeros((len(x) + len(ir) - 1, 2))
    for ch in range(2):
        out[:, ch] = signal.oaconvolve(x[:, ch], ir[:, ch])
    return out[: len(x)]


def pingpong(x: np.ndarray, delay: float, feedback: float = 0.4, mix: float = 0.3, taps: int = 6,
             tone: float = 3500.0) -> np.ndarray:
    """Ping-Pong-Echo (stereo), als feste Echos ohne Rückkopplungsschleife."""
    d = int(delay * SR)
    mono = x.mean(axis=1)
    wet = np.zeros_like(x)
    g = mix
    for k in range(1, taps + 1):
        if k * d >= len(x):
            break
        ch = k % 2
        wet[k * d:, ch] += mono[: len(x) - k * d] * g
        g *= feedback
    return x + lowpass(wet, tone)


def autopan(x: np.ndarray, rate: float, depth: float) -> np.ndarray:
    m = depth * np.sin(TAU * rate * _t(len(x)))
    y = x.copy()
    y[:, 0] *= 1 + m
    y[:, 1] *= 1 - m
    return y


def circular(x: np.ndarray, fn, pad: float = 1.0) -> np.ndarray:
    """Filter so anwenden, als ginge die Schleife unendlich weiter (kein Knacks am Schleifenpunkt)."""
    p = min(int(pad * SR), len(x))
    xx = np.concatenate([x[-p:], x])
    return fn(xx)[p:]


def wow_flutter(layers: list[np.ndarray], loop_seconds: float, wow: float, flutter: float, seed: int) -> list[np.ndarray]:
    """Band-Leiern: gleiche zeitliche Verzerrung für alle Schichten, periodisch über die Schleife."""
    n = len(layers[0])
    rng = np.random.default_rng(seed)
    idx = np.arange(n, dtype=float)
    k_wow = max(1, round(0.45 * loop_seconds))
    k_fl = max(1, round(5.5 * loop_seconds))
    # Auslenkung in Samples aus Tonhöhenschwankung: d = depth * SR / (2π f)
    f_wow = k_wow / loop_seconds
    f_fl = k_fl / loop_seconds
    offset = (wow * SR / (TAU * f_wow)) * np.sin(TAU * f_wow * idx / SR + rng.uniform(0, TAU))
    offset += (flutter * SR / (TAU * f_fl)) * np.sin(TAU * f_fl * idx / SR + rng.uniform(0, TAU))
    pos = (idx + offset) % n
    out = []
    for x in layers:
        ext = np.concatenate([x, x[:2]])
        y = np.empty_like(x)
        for ch in range(2):
            y[:, ch] = np.interp(pos, np.arange(n + 2), ext[:, ch])
        out.append(y)
    return out


# ---------------------------------------------------------------------------
# Harmonik
# ---------------------------------------------------------------------------

QUALITIES = {
    "": [0, 4, 7], "m": [0, 3, 7], "maj7": [0, 4, 7, 11], "maj9": [0, 4, 7, 11, 14], "6": [0, 4, 7, 9],
    "69": [0, 4, 7, 9, 14], "add9": [0, 4, 7, 14], "m7": [0, 3, 7, 10], "m9": [0, 3, 7, 10, 14],
    "m11": [0, 3, 7, 10, 14, 17], "m6": [0, 3, 7, 9], "7": [0, 4, 7, 10], "9": [0, 4, 7, 10, 14],
    "13": [0, 4, 10, 14, 21], "7b9": [0, 4, 7, 10, 13], "7#9": [0, 4, 7, 10, 15], "7b13": [0, 4, 10, 20],
    "m7b5": [0, 3, 6, 10], "sus4": [0, 5, 7], "7sus4": [0, 5, 7, 10], "9sus4": [0, 5, 7, 10, 14],
    "sus2": [0, 2, 7], "6sus4": [0, 5, 7, 9, 14],
}


class Chord:
    def __init__(self, symbol: str):
        self.symbol = symbol
        main, _, bass = symbol.partition("/")
        root = main[:2] if len(main) > 1 and main[1] in "#b" else main[:1]
        self.root = NOTE_PC[root]
        self.intervals = QUALITIES[main[len(root):]]
        self.bass = NOTE_PC[bass] if bass else self.root

    def pcs(self) -> list[int]:
        return [(self.root + i) % 12 for i in self.intervals]

    def tones(self, lo: int, hi: int) -> list[int]:
        """Alle Akkordtöne im Bereich (für Arpeggios und Melodien)."""
        pcs = set(self.pcs())
        return [m for m in range(lo, hi + 1) if m % 12 in pcs]

    def bass_note(self, lo: int, hi: int, near: int | None = None, fifth: bool = False) -> int:
        pc = (self.root + 7) % 12 if fifth else self.bass
        options = [m for m in range(lo, hi + 1) if m % 12 == pc]
        if near is None:
            return options[0]
        return min(options, key=lambda m: abs(m - near))


def voicing(ch: Chord, lo: int, hi: int, size: int = 4, prev: list[int] | None = None,
            rootless: bool = False, max_span: int = 15) -> list[int]:
    """Akkord-Lage mit möglichst kleinen Bewegungen zur vorherigen Lage (Stimmführung)."""
    intervals = list(dict.fromkeys(i % 12 for i in ch.intervals))
    if rootless and len(intervals) > 3:
        intervals = [i for i in intervals if i != 0]
    while len(intervals) > size:
        # zuerst die Quinte, dann den Grundton weglassen
        for drop in (7, 0, 2):
            if drop in intervals and len(intervals) > size:
                intervals.remove(drop)
                break
        else:
            intervals = intervals[:size]
    pcs = [(ch.root + i) % 12 for i in intervals]
    options = [[m for m in range(lo, hi + 1) if m % 12 == pc] for pc in pcs]
    best, best_cost = None, 1e9
    for combo in itertools.product(*options):
        notes = sorted(combo)
        if notes[-1] - notes[0] > max_span:
            continue
        gaps = np.diff(notes)
        if np.any(gaps == 0):
            continue
        cost = 0.0
        for a, b in zip(notes, notes[1:]):
            if b - a == 1 and a < 64:
                cost += 4  # enge Reibung tief klingt matschig
            if b - a <= 2 and a < 52:
                cost += 6
        if prev:
            cost += sum(min(abs(a - b) for b in prev) for a in notes) + 0.6 * abs(notes[-1] - prev[-1])
        else:
            cost += abs(np.mean(notes) - (lo + hi) / 2)
        if cost < best_cost:
            best, best_cost = notes, cost
    return best or sorted(m for opts in options for m in opts[:1])


# ---------------------------------------------------------------------------
# Lied: Zeitraster, Swing, Mischpult
# ---------------------------------------------------------------------------

class Song:
    def __init__(self, bpm: float, bars: int, swing: float = 0.5, swing_unit: float = 0.5,
                 beats_per_bar: int = 4, seed: int = 1, tail: float = 6.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.bpb = beats_per_bar
        self.swing = swing
        self.unit = swing_unit
        self.rng = np.random.default_rng(seed)
        self.loop_seconds = bars * beats_per_bar * self.beat
        self.loop_n = int(round(self.loop_seconds * SR))
        self.total_n = self.loop_n + int(tail * SR)

    def time(self, bar: float, beat: float, human: float = 0.0) -> float:
        pair = 2 * self.unit
        k = math.floor(beat / pair)
        x = beat - k * pair
        r = self.swing
        x2 = x * 2 * r if x < self.unit else pair * r + (x - self.unit) * 2 * (1 - r)
        t = (bar * self.bpb + k * pair + x2) * self.beat
        if human:
            t += self.rng.normal(0, human)
        return max(0.0, t)

    def periodic(self, freq: float) -> float:
        """Nächste Frequenz, die genau ganzzahlig oft in die Schleife passt."""
        return max(1, round(freq * self.loop_seconds)) / self.loop_seconds

    def beats(self, n: float) -> float:
        return n * self.beat


class Bus:
    def __init__(self, n: int, layer: str, send: float, post=None, pan_spread: float = 0.0):
        self.buf = np.zeros((n, 2), dtype=np.float32)
        self.layer = layer
        self.send = send
        self.post = post
        self.pan_spread = pan_spread


class Mix:
    LAYERS = ["keys", "bass", "beat", "lead", "extra"]

    def __init__(self, song: Song):
        self.song = song
        self.buses: dict[str, Bus] = {}

    def bus(self, name: str, layer: str, send: float = 0.2, post=None) -> None:
        self.buses[name] = Bus(self.song.total_n, layer, send, post)

    def add(self, bus: str, sig: np.ndarray, t0: float, gain: float = 1.0, pan: float = 0.0) -> None:
        b = self.buses[bus]
        i = int(round(t0 * SR))
        if i < 0:
            i += self.song.loop_n  # etwas vor dem Anfang = Ende der Schleife
        if i >= len(b.buf):
            return
        seg = sig[: len(b.buf) - i] * gain
        th = (pan + 1) * math.pi / 4
        b.buf[i:i + len(seg), 0] += (seg * math.cos(th) * math.sqrt(2)).astype(np.float32)
        b.buf[i:i + len(seg), 1] += (seg * math.sin(th) * math.sqrt(2)).astype(np.float32)

    def add_stereo(self, bus: str, sig: np.ndarray, t0: float = 0.0, gain: float = 1.0) -> None:
        b = self.buses[bus]
        i = int(round(t0 * SR))
        seg = sig[: len(b.buf) - i] * gain
        b.buf[i:i + len(seg)] += seg.astype(np.float32)

    def render(self, ir: np.ndarray) -> dict[str, np.ndarray]:
        """Busse → Schichten (mit Hall), noch ohne Schleifen-Umbruch."""
        n = self.song.total_n
        dry = {l: np.zeros((n, 2)) for l in self.LAYERS}
        send = {l: np.zeros((n, 2)) for l in self.LAYERS}
        for b in self.buses.values():
            y = b.buf.astype(np.float64)
            if b.post:
                y = b.post(y)
            dry[b.layer] += y
            send[b.layer] += y * b.send
        out = {}
        for l in self.LAYERS:
            out[l] = dry[l] + (reverb(send[l], ir) if np.any(send[l]) else 0.0)
        return out

    def wrap(self, x: np.ndarray) -> np.ndarray:
        """Nachklang hinter dem Schleifenende auf den Anfang legen → nahtlose Schleife."""
        L = self.song.loop_n
        out = x[:L].copy()
        pos = L
        while pos < len(x):
            chunk = x[pos:pos + L]
            out[: len(chunk)] += chunk
            pos += L
        return out
