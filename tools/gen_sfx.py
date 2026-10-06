#!/usr/bin/env python3
"""terminal-gun SFX generator — deterministic, stdlib only.

Sintesi square/noise con inviluppo ADSR. Nessuna dipendenza oltre la
libreria standard (wave, math, struct, random, argparse).
Determinismo: SEED fisso in cima, un RNG per suono derivato dal seed,
nessun timestamp nei dati scritti.
"""
import argparse
import math
import os
import random
import struct
import wave

SEED = 1337
SAMPLE_RATE = 44100


def adsr_envelope(t, dur, attack=0.005, decay=0.05, sustain=0.7, release=0.08):
    """Inviluppo ADSR lineare. attack/decay/release in secondi."""
    if dur <= 0:
        return 0.0
    # attack
    if t < attack:
        return t / attack if attack > 0 else 1.0
    # decay -> sustain
    if t < attack + decay:
        k = (t - attack) / decay if decay > 0 else 1.0
        return 1.0 - (1.0 - sustain) * k
    # sustain fino al release
    if t < dur - release:
        return sustain
    # release
    if t < dur:
        k = (dur - t) / release if release > 0 else 0.0
        return sustain * max(0.0, k)
    return 0.0


def square_phase(phase):
    return 1.0 if math.sin(phase) < 0 else -1.0


def sweep_freq(f0, f1, t, dur):
    # sweep esponenziale (percepito lineare)
    if f0 <= 0 or f1 <= 0:
        return f0
    k = t / dur if dur > 0 else 0.0
    return f0 * ((f1 / f0) ** k)


def render_tone(dur, freqs, wave_kind="square", noise_amt=0.0, rng=None,
                attack=0.005, decay=0.05, sustain=0.7, release=0.08,
                volume=0.8):
    """freqs: (f0, f1) sweep su tutta la durata, oppure lista di (dur_frac, f0, f1)."""
    n = int(dur * SAMPLE_RATE)
    if isinstance(freqs, tuple):
        segs = [(1.0, freqs[0], freqs[1])]
    else:
        segs = freqs
    # normalizza frazioni
    total = sum(s[0] for s in segs)
    bounds = []
    acc = 0.0
    for frac, f0, f1 in segs:
        acc += frac / total
        bounds.append((acc, f0, f1))
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # trova segmento
        k = t / dur if dur > 0 else 0.0
        f0, f1 = bounds[0][1], bounds[0][2]
        seg_start = 0.0
        for b, a0, a1 in bounds:
            if k <= b:
                f0, f1 = a0, a1
                break
            seg_start = b
        # freq istantanea dentro il segmento
        local = (k - seg_start) / ((b - seg_start) if (b - seg_start) > 0 else 1.0)
        local = max(0.0, min(1.0, local))
        if f0 == f1:
            freq = f0
        else:
            freq = f0 * ((f1 / f0) ** local) if f0 > 0 and f1 > 0 else f0
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        if wave_kind == "sine":
            v = math.sin(phase)
        elif wave_kind == "square":
            v = square_phase(phase)
        elif wave_kind == "saw":
            v = 2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0
        else:
            v = math.sin(phase)
        if noise_amt > 0 and rng is not None:
            v = (1.0 - noise_amt) * v + noise_amt * rng.uniform(-1.0, 1.0)
        env = adsr_envelope(t, dur, attack, decay, sustain, release)
        out.append(volume * env * v)
    return out


def soft_clip(samples):
    # tanh soft per evitare clipping dopo il mix
    return [math.tanh(s) for s in samples]


def to_int16(samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.89 / peak if peak > 0.89 else 1.0
    return [max(-32768, min(32767, int(round(s * gain * 32767)))) for s in samples]


def write_wav(path, samples):
    data = to_int16(soft_clip(samples))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack("<%dh" % len(data), *data))


def gen_sound(name, rng):
    if name == "bonk":
        # colpo pieno anni '80: square che scende 420->140 + click noise
        return render_tone(0.18, (420.0, 140.0), wave_kind="square",
                           noise_amt=0.15, rng=rng,
                           attack=0.002, decay=0.05, sustain=0.5, release=0.06)
    if name == "hit":
        # impatto nemico: noise corto + square 220->90
        return render_tone(0.12, (220.0, 90.0), wave_kind="square",
                           noise_amt=0.45, rng=rng,
                           attack=0.001, decay=0.03, sustain=0.4, release=0.04)
    if name == "hurt":
        # danno al player: saw discendente 300->90
        return render_tone(0.25, (300.0, 90.0), wave_kind="saw",
                           noise_amt=0.2, rng=rng,
                           attack=0.003, decay=0.08, sustain=0.55, release=0.07)
    if name == "coin":
        # due blip sine 990 poi 1320
        return render_tone(0.20, [(1.0, 990.0, 990.0), (1.0, 1320.0, 1320.0)],
                           wave_kind="sine", noise_amt=0.0, rng=rng,
                           attack=0.004, decay=0.04, sustain=0.8, release=0.05)
    if name == "levelup":
        # arpeggio square 523/659/784/1046 in 0.5 s (< 0.6)
        return render_tone(0.50,
                           [(1.0, 523.25, 523.25), (1.0, 659.25, 659.25),
                            (1.0, 783.99, 783.99), (1.0, 1046.5, 1046.5)],
                           wave_kind="square", noise_amt=0.05, rng=rng,
                           attack=0.005, decay=0.04, sustain=0.75, release=0.08)
    if name == "spawn":
        # sweep in salita 200->800 sine/square leggero
        return render_tone(0.22, (200.0, 800.0), wave_kind="square",
                           noise_amt=0.1, rng=rng,
                           attack=0.01, decay=0.05, sustain=0.7, release=0.06)
    if name == "gameover":
        # discesa 400->100 in tre gradini, 0.55 s (< 0.6)
        return render_tone(0.55,
                           [(1.0, 400.0, 300.0), (1.0, 300.0, 200.0),
                            (1.0, 200.0, 100.0)],
                           wave_kind="saw", noise_amt=0.08, rng=rng,
                           attack=0.005, decay=0.1, sustain=0.6, release=0.12)
    raise ValueError("unknown sound: %s" % name)


SOUNDS = ["bonk", "hit", "hurt", "coin", "levelup", "spawn", "gameover"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    base = random.Random(SEED)
    # seed per suono derivati in modo stabile dall'ordine di SOUNDS
    seeds = {name: base.randrange(1 << 30) for name in SOUNDS}
    for name in SOUNDS:
        rng = random.Random(seeds[name])
        samples = gen_sound(name, rng)
        # guardia: sotto 0.6 s
        assert len(samples) / SAMPLE_RATE < 0.6, name
        write_wav(os.path.join(args.out, name + ".wav"), samples)
        print("wrote %s.wav (%d samples)" % (name, len(samples)))


if __name__ == "__main__":
    main()
