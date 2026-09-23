#!/usr/bin/env python3
"""
Generates the three placeholder UI sounds as 16-bit mono 44.1 kHz WAV files (pure Python, no deps).
The recipe is the same as the Web Audio synthesis in reference/prototype.js, so what you hear in the
prototype is what ships in assets/sounds/. Replace with commissioned recordings later; keep the
duration budget in docs/02-tokens.md (each sound <= 120 ms, except 'done').

  python3 tools/generate_sounds.py [output_dir]
"""
import math, random, struct, sys, wave, pathlib

SR = 44100
random.seed(7)

def buf(seconds): return [0.0] * int(SR * seconds)

def lowpass(x, fc, passes=2):
    a = math.exp(-2 * math.pi * fc / SR)
    for _ in range(passes):
        y, prev = [], 0.0
        for v in x:
            prev = (1 - a) * v + a * prev
            y.append(prev)
        x = y
    return x

def add(dst, src, t0):
    o = int(t0 * SR)
    for i, v in enumerate(src):
        if o + i < len(dst): dst[o + i] += v

def knock(gain, freq):
    n = int(SR * 0.06)
    noise = [(random.random() * 2 - 1) * (1 - i / n) ** 3 for i in range(n)]
    noise = lowpass(noise, 900)
    noise = [v * gain * (0.001 / gain) ** (i / n) * 3.2 for i, v in enumerate(noise)]  # 3.2 ~ filter loss make-up
    m = int(SR * 0.08); ph = 0.0; body = []
    for i in range(m):
        t = i / SR
        f = freq * (0.55 ** min(t / 0.05, 1.0))
        ph += 2 * math.pi * f / SR
        g = gain * 0.5 * (0.001 / (gain * 0.5)) ** min(t / 0.07, 1.0)
        body.append(math.sin(ph) * g)
    out = [0.0] * max(len(noise), len(body))
    for i, v in enumerate(noise): out[i] += v
    for i, v in enumerate(body): out[i] += v
    return out

def note(freq, gain, length):
    n = int(SR * (length + 0.02)); out = []
    for i in range(n):
        t = i / SR
        if t < 0.02: env = 0.0001 * (gain / 0.0001) ** (t / 0.02)
        else: env = gain * (0.0001 / gain) ** ((t - 0.02) / max(length - 0.02, 1e-3))
        out.append(math.sin(2 * math.pi * freq * t) * env)
    return out

def write(path, x):
    peak = max(abs(v) for v in x) or 1.0
    scale = min(1.0, 0.85 / peak)
    fade = int(SR * 0.004)
    for i in range(min(fade, len(x))): x[-1 - i] *= i / fade
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in x))

def main(out):
    out = pathlib.Path(out); out.mkdir(parents=True, exist_ok=True)
    mv = buf(0.12); add(mv, knock(0.32, 190), 0);            write(out / "move.wav", mv)
    wr = buf(0.30); add(wr, knock(0.20, 150), 0); add(wr, knock(0.16, 120), 0.11); write(out / "wrong.wav", wr)
    dn = buf(0.95); add(dn, note(392.00, 0.09, 0.50), 0); add(dn, note(523.25, 0.08, 0.70), 0.16); write(out / "done.wav", dn)
    print("wrote", [p.name for p in sorted(out.glob("*.wav"))])

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent / "assets" / "sounds")
