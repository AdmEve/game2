#!/usr/bin/env python3
"""Synthesises the game's sound effects from scratch (no samples, no licences).

The sonic identity is a santur-like plucked string: Karplus-Strong with two
slightly detuned "strings" per note and a hammer click, plus a short room
reverb. Run:  python3 -I tool/sfx/make_sfx.py assets/sfx
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 22050
rng = np.random.default_rng(7)


OS = 4  # strings are simulated at 4x the sample rate, so high notes stay in tune


def ks(freq, dur, decay=0.996, bright=0.55):
    """One Karplus-Strong string (simulated at OS x SR, then decimated)."""
    sr = SR * OS
    n = int(sr * dur)
    # the averaging filter adds half a sample of delay: compensate
    period = max(2, int(round(sr / freq - 0.5)))
    buf = rng.uniform(-1, 1, period)
    # soften the excitation: lower brightness = rounder attack
    for _ in range(int((1 - bright) * 6)):
        buf = 0.5 * (buf + np.roll(buf, 1))
    buf -= buf.mean()          # no DC: the loop filter would keep it forever
    # per-sample decay at the higher rate matches the requested decay at SR
    d = decay ** (1 / OS)
    out = np.empty(n)
    idx = 0
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % period
        buf[idx] = d * 0.5 * (buf[idx] + buf[nxt])
        idx = nxt
    # low-pass and decimate back to SR
    out = np.convolve(out, np.ones(OS) / OS, mode='same')[::OS]
    return out


def santur(freq, dur, vel=1.0, bright=0.6):
    """Two detuned strings plus a hammer click: the santur colour."""
    a = ks(freq * 1.0012, dur, 0.9965, bright)
    b = ks(freq * 0.9988, dur, 0.9958, bright)
    n = len(a)
    click = np.zeros(n)
    k = int(0.004 * SR)
    click[:k] = rng.uniform(-1, 1, k) * np.linspace(1, 0, k) * 0.35
    env = np.exp(-np.arange(n) / (SR * dur * 0.45))
    return vel * (0.5 * (a + b) * env + click)


def sine(freq, dur, vel=1.0, attack=0.005, release=None, vib=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    ph = 2 * np.pi * freq * t + (vib * np.sin(2 * np.pi * 5.5 * t) if vib else 0)
    s = np.sin(ph) + 0.25 * np.sin(2 * ph)
    env = np.minimum(1, t / attack) * np.exp(-t / (release or dur * 0.4))
    return vel * s * env


def noise_burst(dur, lo=0.0, vel=1.0, decay=0.02):
    n = int(SR * dur)
    x = rng.uniform(-1, 1, n)
    if lo:  # crude high-pass
        x = x - np.convolve(x, np.ones(int(lo)) / int(lo), mode='same')
    return vel * x * np.exp(-np.arange(n) / (SR * decay))


def place(track, sig, at):
    i = int(at * SR)
    end = min(len(track), i + len(sig))
    track[i:end] += sig[:end - i]


def reverb(x, wet=0.18, length=0.35):
    n = int(SR * length)
    ir = rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / (SR * length * 0.25))
    ir[0] = 0
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x) + n]
    y = y / (np.max(np.abs(y)) + 1e-9) * np.max(np.abs(x))
    out = np.zeros(len(x) + n)
    out[:len(x)] += x
    return out * (1 - wet) + y * wet


def dc_block(x, r=0.995):
    y = np.empty_like(x)
    prev_x = prev_y = 0.0
    for i, v in enumerate(x):
        prev_y = v - prev_x + r * prev_y
        prev_x = v
        y[i] = prev_y
    return y


def finish(x, peak=0.7, tail=0.02):
    x = dc_block(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    k = int(tail * SR)
    if k and len(x) > k:
        x[-k:] *= np.linspace(1, 0, k)
    # trim silence at the end
    nz = np.nonzero(np.abs(x) > 1e-3)[0]
    return x[:nz[-1] + 1] if len(nz) else x


def hz(note):
    """'C5', 'E4', and Persian koron (quarter-flat) with 'p': 'Ep4'."""
    names = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    semis = names[note[0]]
    rest = note[1:]
    if rest.startswith('#'):
        semis += 1; rest = rest[1:]
    elif rest.startswith('b'):
        semis -= 1; rest = rest[1:]
    elif rest.startswith('p'):  # koron: a quarter tone flat
        semis -= 0.5; rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semis + 12 * (octave + 1) - 69) / 12)


def seq(notes, step, dur=0.9, vel=1.0, bright=0.6, total=None):
    total = total or step * len(notes) + dur
    tr = np.zeros(int(SR * total))
    for i, n in enumerate(notes):
        if n:
            place(tr, santur(hz(n), dur, vel, bright), i * step)
    return tr


SOUNDS = {}

# UI tap: tiny wooden tick
t = np.zeros(int(SR * 0.06))
place(t, sine(1250, 0.05, 0.6, 0.001, 0.012), 0)
place(t, noise_burst(0.03, lo=6, vel=0.25, decay=0.004), 0)
SOUNDS['tap'] = finish(t, 0.45)

# select: one bright santur note
SOUNDS['select'] = finish(reverb(santur(hz('E6'), 0.35, bright=0.75), 0.12), 0.5)

# correct (you solved): rising Mahur arpeggio with a shimmer on top
c = seq(['C5', 'E5', 'G5', 'C6'], 0.07, dur=0.8, bright=0.7)
place(c, santur(hz('E6'), 0.6, 0.5, 0.85), 0.32)
place(c, santur(hz('G6'), 0.6, 0.4, 0.85), 0.37)
SOUNDS['correct'] = finish(reverb(c, 0.22), 0.75)

# someone else solved: two soft notes
SOUNDS['solved_other'] = finish(reverb(seq(['G5', 'C6'], 0.08, dur=0.5, vel=0.7), 0.18), 0.5)

# near miss: Shur colour, a koron step down and back ("hmm, almost")
n = np.zeros(int(SR * 0.45))
place(n, santur(hz('A5'), 0.4, 0.8, 0.5), 0)
place(n, santur(hz('Bp5'), 0.4, 0.8, 0.5), 0.11)
place(n, santur(hz('A5'), 0.4, 0.6, 0.5), 0.22)
SOUNDS['near'] = finish(reverb(n, 0.15), 0.55)

# clock tick for the last seconds
k = np.zeros(int(SR * 0.07))
place(k, sine(1900, 0.06, 0.7, 0.0005, 0.008), 0)
place(k, noise_burst(0.02, lo=4, vel=0.3, decay=0.003), 0)
SOUNDS['tick'] = finish(k, 0.4)

# time up: a low struck string and a soft low thud
u = np.zeros(int(SR * 0.9))
place(u, santur(hz('D3'), 0.9, 1.0, 0.4), 0)
place(u, santur(hz('A2'), 0.9, 0.7, 0.35), 0.02)
place(u, sine(70, 0.4, 0.8, 0.002, 0.12), 0)
SOUNDS['timeup'] = finish(reverb(u, 0.2), 0.7)

# turn start: an upward whoosh into a chime
w = np.zeros(int(SR * 0.8))
nn = int(SR * 0.28)
sweep = rng.uniform(-1, 1, nn)
for j in range(1, 4):
    sweep = 0.5 * (sweep + np.roll(sweep, j))
sweep *= np.sin(np.linspace(0, np.pi, nn)) ** 2 * 0.5
place(w, sweep, 0)
place(w, santur(hz('D6'), 0.5, 0.9, 0.8), 0.24)
place(w, santur(hz('A6'), 0.5, 0.6, 0.85), 0.29)
SOUNDS['turn'] = finish(reverb(w, 0.2), 0.6)

# steal window: fast santur tremolo alarm
SOUNDS['steal'] = finish(reverb(seq(['E6', 'D6'] * 4, 0.055, dur=0.3, vel=0.8, bright=0.8), 0.12), 0.65)

# hint letter revealed: sparkle
SOUNDS['hint'] = finish(reverb(seq(['A6', 'E7'], 0.05, dur=0.3, vel=0.7, bright=0.9), 0.25), 0.45)

# a player joins the lobby
SOUNDS['join'] = finish(reverb(seq(['G5', 'D6'], 0.07, dur=0.4, vel=0.7), 0.15), 0.45)

# incoming chat line: barely-there pop
p_ = np.zeros(int(SR * 0.05))
place(p_, sine(880, 0.04, 0.5, 0.001, 0.01), 0)
SOUNDS['chat'] = finish(p_, 0.25)

# win: a Mahur phrase ending on a tremolo chord
win = seq(['C5', 'E5', 'G5', 'C6', None, 'G5', 'C6', 'E6'], 0.09, dur=1.0, bright=0.7, total=2.2)
for j in range(10):
    place(win, santur(hz('C6' if j % 2 else 'E6'), 0.6, 0.55 - j * 0.03, 0.75), 0.8 + j * 0.06)
place(win, santur(hz('C4'), 1.4, 0.8, 0.4), 0.8)
SOUNDS['win'] = finish(reverb(win, 0.25), 0.8, tail=0.3)

# lose / tie: gentle descending Shur phrase, not sad
SOUNDS['end'] = finish(reverb(seq(['A5', 'G5', 'F5', 'Ep5', 'D5'], 0.11, dur=0.9, vel=0.8), 0.22), 0.65, tail=0.2)


def write(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == '__main__':
    out = Path(sys.argv[1] if len(sys.argv) > 1 else 'assets/sfx')
    out.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, x in SOUNDS.items():
        f = out / f'{name}.wav'
        write(f, x)
        total += f.stat().st_size
        print(f'{f}  {len(x) / SR:.2f}s  {f.stat().st_size // 1024} KB')
    print(f'total {total // 1024} KB')
