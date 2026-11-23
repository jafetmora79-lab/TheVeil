"""The five review-batch sounds. Each function returns the float signal (mono (n,) or stereo (n, 2)) at 48 kHz;
render.py finishes, measures and writes them. Only the first variant of each is built for review; the other
variants reuse the same machinery with different parameters once the direction is approved."""
import numpy as np
from scipy import signal

from dsp import (SR, add_modes, bp, harmonic_source, hp, lp, n_of, osc_phase, resonator, rng_for, saturate,
                 smooth_curve, sstep, tv_bandpass, white)

# ============================================================================ door_open (old wooden house door)
def door_open(seed, variant=1):
    """What makes a door a door: the handle and latch (two metallic clacks), the seal letting go with a dull wooden
    knock, the swing (a soft push of air and a low wooden groan), two or three hinge squeaks, and a small knock as
    it comes to rest. (An earlier version was only a creak, and did not read as a door at all.)"""
    rng = rng_for(seed)
    n = n_of(1.45)
    t = np.arange(n) / SR
    out = np.zeros(n)

    def noise_hit(at, lo, hi, tau, amp, length=0.03):
        i = n_of(at)
        m = n_of(length)
        out[i:i + m] += amp * bp(white(m, rng), lo, hi) * np.exp(-(np.arange(m) / SR) / tau)

    # 1. the handle turns and the latch bolt retracts: a clack, then a smaller one as the spring lets it go
    noise_hit(0.0, 1500, 6000, 0.003, 0.5)
    add_modes(out, 0.0, [rng.uniform(2000, 2400), rng.uniform(3000, 3500)], [0.28, 0.16], [0.014, 0.009], rng)
    add_modes(out, 0.0, [150.0, 230.0], [0.25, 0.15], [0.04, 0.03], rng)               # the handle plate and the lock body
    noise_hit(0.065, 900, 4500, 0.004, 0.30)
    add_modes(out, 0.065, [rng.uniform(1500, 1800), rng.uniform(2500, 2900)], [0.20, 0.10], [0.012, 0.008], rng)

    # 2. the door comes off its seal: a dull wooden knock with a short soft rub
    noise_hit(0.15, 250, 1800, 0.012, 0.20, 0.05)
    add_modes(out, 0.15, [88.0, 135.0], [0.25, 0.15], [0.06, 0.045], rng)

    # 3. the swing: a soft push of air under a low wooden groan
    sw = sstep((t - 0.17) / 0.15) * sstep((1.2 - t) / 0.25)
    bump = np.sin(np.pi * np.clip((t - 0.17) / 1.03, 0.0, 1.0))
    out += 0.9 * lp(white(n, rng), 420) * sw * (0.35 + 0.65 * bump)
    rate = 30.0 + 25.0 * (0.5 + 0.5 * np.tanh(smooth_curve(n, 1.2, rng)))
    cyc = np.maximum.accumulate(np.cumsum(rate) / SR + 0.25 * smooth_curve(n, 40.0, rng))
    ticks = (np.diff(np.floor(cyc), prepend=np.floor(cyc[0])) > 0) * rng.uniform(0.4, 1.5, n)
    kk = n_of(0.006)
    kern = lp(white(kk, rng), 700) * np.exp(-(np.arange(kk) / SR) / 0.002)
    groan_in = signal.fftconvolve(ticks, kern)[:n]
    groan = sum(g * resonator(groan_in, fr, 10.0) for fr, g in [(140.0, 1.0), (230.0, 0.7), (340.0, 0.4)])
    gact = sw * np.clip(0.5 + 0.5 * np.tanh(smooth_curve(n, 6.0, rng)), 0.0, 1.0)
    live = gact > 0.05
    out += groan * gact * (0.05 / (np.std(groan[live] * gact[live]) + 1e-12))

    # 4. the hinge squeaks: a metal tone gliding up or down, with the stick-slip flutter of a dry pin
    def squeak(at, d, f0, f1, amp):
        m = n_of(d)
        i = n_of(at)
        tt = np.arange(m) / SR
        fq = np.linspace(f0, f1, m) * (1.0 + 0.008 * smooth_curve(m, 40.0, rng))
        ph = osc_phase(fq)
        src = np.sin(ph) + 0.38 * np.sin(2 * ph + 0.5) + 0.14 * np.sin(3 * ph + 1.1)
        flutter = np.clip(0.75 + 0.35 * smooth_curve(m, 30.0, rng), 0.2, 1.3)
        am = 1.0 - 0.3 * (0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(55, 95) * tt + rng.uniform(0, 6)))
        env = np.hanning(m) ** 0.7
        out[i:i + m] += amp * (src * flutter * am + 0.12 * bp(white(m, rng), 1200, 4500)) * env

    squeak(0.30, 0.19, 640.0, 980.0, 0.20)
    squeak(0.58, 0.29, 900.0, 1500.0, 0.18)
    squeak(0.95, 0.12, 1250.0, 820.0, 0.14)

    # 5. it comes to rest: a small, soft knock (restrained, not a slam)
    add_modes(out, 1.22, [78.0, 118.0, 170.0], [0.30, 0.20, 0.12], [0.06, 0.05, 0.035], rng)
    noise_hit(1.22, 200, 1200, 0.006, 0.12)
    return out


# ============================================================================ drag_heavy (loaded shelf, rough scrape)
def drag_heavy(seed, variant=1):
    rng = rng_for(seed)
    dur = 2.4
    n = n_of(dur)
    t = np.arange(n) / SR
    # movement speed: it eases up, runs unevenly, then slows to a stop (skewed bump x slow irregularity)
    u = np.clip((t - 0.08) / 1.88, 0.0, 1.0)
    base = (u ** 1.25) * ((1.0 - u) ** 0.85)
    base = base / base.max()
    v = np.clip(base * np.clip(0.8 + 0.25 * np.tanh(smooth_curve(n, 3.0, rng)), 0.3, 1.2), 0.0, 1.1)

    # stick-slip: the slip rate follows the speed; each slip is a burst that dies away while the load sticks again
    phi = np.cumsum(14.0 + 36.0 * v * (1.0 + 0.18 * smooth_curve(n, 6.0, rng))) / SR
    fr = phi - np.floor(phi)
    slip = (1.0 - fr) ** 2.2 * 0.75 + 0.25

    wn = white(n, rng)
    fric = (bp(wn, 250, 2400) * 0.6 + bp(wn, 2400, 6500) * 0.10) * slip * v

    # the furniture's mass: the friction excites low-mid resonances
    mass_in = lp(wn, 900) * slip * v ** 1.2
    mass = sum(a * resonator(mass_in, f0, q) for f0, q, a in
               [(88, 9, 1.0), (131, 10, 0.8), (187, 8, 0.6), (262, 8, 0.4), (398, 7, 0.3)])

    # contact impulses at uneven intervals; their density follows the speed (Poisson, thinned by v)
    rate = 12.0 + 160.0 * v
    hits = (rng.random(n) < rate / SR) * rng.choice([-1.0, 1.0], n) * rng.exponential(1.0, n) * v
    pick = rng.random(n) < 0.5
    kk = n_of(0.006)
    tk = np.arange(kk) / SR
    ka = bp(white(kk, rng), 500, 3800) * np.exp(-tk / 0.0016)
    kb = bp(white(kk, rng), 900, 5200) * np.exp(-tk / 0.0011)
    contacts = signal.fftconvolve(hits * pick, ka)[:n] + signal.fftconvolve(hits * ~pick, kb)[:n]

    out = 0.8 * fric + 0.35 * mass + 0.3 * contacts

    # two or three narrow squeals with a wandering pitch (quiet: a catch of the load, not a siren)
    for ts in sorted(rng.uniform(0.35, 1.7, 3)):
        d = rng.uniform(0.09, 0.2)
        m = n_of(d)
        i0 = n_of(ts)
        fq = rng.uniform(900, 2000) + 90.0 * smooth_curve(m, 14.0, rng)
        ph = osc_phase(fq)
        env = np.hanning(m) ** 1.5 * 0.035 * float(v[i0])
        out[i0:i0 + m] += (np.sin(ph) + 0.3 * np.sin(2 * ph)) * env

    # the settling knock, then a smaller rebound
    for at, g in [(2.0, 0.55), (2.11, 0.17)]:
        add_modes(out, at, [64.0, 97.0, 143.0, 211.0], [0.8, 0.5, 0.35, 0.2], [0.09, 0.07, 0.05, 0.035], rng, gain=g)
        i = n_of(at)
        nn = n_of(0.012)
        out[i:i + nn] += g * 0.35 * bp(white(nn, rng), 300, 1500) * np.exp(-np.arange(nn) / SR / 0.004)
    return out


# ============================================================================ jumpscare_hit (variant 1: blunt pressure)
def jumpscare_hit(seed, variant=1):
    rng = rng_for(seed)
    n = n_of(2.6)
    t = np.arange(n) / SR
    nb = n_of(0.03)
    tb = np.arange(nb) / SR
    trans = np.zeros(n)
    trans[:nb] = bp(white(nb, rng), 700, 9000) * np.exp(-tb / 0.004)                  # the very short broadband attack
    f = 48.0 + 95.0 * np.exp(-t / 0.11)                                                # a low pitch-dropping oscillator
    ph = osc_phase(f)
    body = (np.sin(ph) + 0.28 * np.sin(2 * ph + 0.4)) * (1.0 - np.exp(-t / 0.002)) * np.exp(-t / 0.34)
    base = np.array([187.0, 312.0, 489.0, 731.0, 1190.0])                              # inharmonic: no chord
    amps = [0.5, 0.4, 0.3, 0.2, 0.12]
    taus = [0.45, 0.35, 0.28, 0.2, 0.12]
    chans = []
    for c in (0, 1):
        res = np.zeros(n)
        add_modes(res, 0.0, base * (1.0 + rng.uniform(-0.004, 0.004, 5)), amps, taus, rng)
        core = 1.0 * body + 0.9 * res + 0.9 * trans
        core = saturate(core * 1.2, 2.0) * 0.8                                         # controlled saturation for density
        tail = np.zeros(n)                                                             # a structured tail: three pressure pulses
        for t0, a, tau in [(0.28, 0.25, 0.12), (0.55, 0.15, 0.14), (0.92, 0.08, 0.18)]:
            tail += a * 6.0 * lp(white(n, rng), 380) * np.exp(-np.clip(t - t0, 0, None) / tau) * sstep((t - t0) / 0.006)
        tail += 0.12 * 8.0 * lp(white(n, rng), 600) * np.exp(-t / 0.4) * sstep(t / 0.05)   # and a dark, decaying air
        chans.append(core + tail)
    return np.stack(chans, axis=1)


# ============================================================================ drone_dark (variant 1: fog pressure), a seamless loop
def drone_dark(seed, variant=1, T=30.0):
    """Built periodic on purpose: the noise layers are synthesised in the frequency domain with random phases (so
    the end of the buffer is the start again), the slow modulations are periodic curves made the same way, and
    every tone sits on a whole number of cycles per loop. No fade is needed or used."""
    rng = rng_for(seed)
    n = n_of(T)
    t = np.arange(n) / SR
    f = np.fft.rfftfreq(n, 1.0 / SR)

    def pnoise(mag):
        spec = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(f)))
        spec[0] = 0.0
        x = np.fft.irfft(spec, n)
        return x / (x.std() + 1e-12)

    def lpf(fc, o=4):
        return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * o))

    base = 1.0 / np.sqrt(np.maximum(f, 15.0))
    hpf = 1.0 / np.sqrt(1.0 + (36.0 / np.maximum(f, 1e-3)) ** 12)

    def slow(cut):                                  # a periodic gain curve 0..1 that wanders at roughly `cut` Hz
        c = pnoise(1.0 / np.sqrt(1.0 + (f / cut) ** 4))
        return 0.5 + 0.5 * np.tanh(1.1 * c)

    low = pnoise(base * hpf * lpf(95.0))                                              # the deep pressure (identical in L and R: a stable centre)
    mid_l, mid_r = [pnoise(base * hpf * lpf(240.0, 3)) for _ in range(2)]             # the fog body, decorrelated for width
    hi_l, hi_r = [pnoise(base * hpf * lpf(560.0, 3)) for _ in range(2)]               # a faint upper veil that opens and closes
    g_low, g_mid, g_hi = slow(0.10), slow(0.17), slow(0.29)
    pan = 0.18 * np.tanh(pnoise(1.0 / np.sqrt(1.0 + (f / 0.08) ** 4)))                # slow, moderate stereo drift

    def snapped(fr):
        return np.round(fr * T) / T

    pairs = []                                       # (f1, f2, level, slow amplitude curve, phases left, phases right)
    for bf, det, a in [(41.0, 0.21, 0.9), (55.0, 0.33, 0.7), (73.3, 0.17, 0.5), (110.0, 0.27, 0.25)]:
        pl = rng.uniform(0, 2 * np.pi, 2)
        pr = pl.copy() if bf < 100.0 else rng.uniform(0, 2 * np.pi, 2)    # the lows share their phase in both channels
        pairs.append((snapped(bf), snapped(bf + det), a, slow(0.12 + 0.05 * rng.random()), pl, pr))
    chan = []
    for side, (mid, hi) in enumerate([(mid_l, hi_l), (mid_r, hi_r)]):
        sgn = 1.0 if side == 0 else -1.0
        tones = np.zeros(n)
        for f1, f2, a, amp, pl, pr in pairs:
            p = pl if side == 0 else pr
            tones += 0.18 * a * amp * (np.sin(2 * np.pi * f1 * t + p[0]) + 0.8 * np.sin(2 * np.pi * f2 * t + p[1]))
        x = 1.0 * low * (0.35 + 0.65 * g_low) + 0.8 * mid * (0.25 + 0.75 * g_mid) * (1.0 + sgn * pan) \
            + 0.30 * hi * g_hi * (1.0 + sgn * pan) + tones
        chan.append(x)
    return np.stack(chan, axis=1)


# ============================================================================ skitter_chitter (variant 1: searching, then a quick answer; leathery)
def skitter_chitter(seed, variant=1):
    """Leathery: dull snaps of taut hide (a soft tick on a membrane thump at 230 - 700 Hz), each followed by a short
    rub of leather on leather (fast irregular stick-slip), and a few rough, low creaks. Nothing hard or glassy."""
    rng = rng_for(seed)
    n = n_of(1.75)
    out = np.zeros(n)

    def rub(at, d, amp):
        m = n_of(d)
        i = n_of(at)
        tt = np.arange(m) / SR
        rate = rng.uniform(55, 95) * (1.0 + 0.25 * smooth_curve(m, 20.0, rng))
        slip = (0.5 + 0.5 * np.sin(osc_phase(np.clip(rate, 25.0, 200.0)))) ** 2
        out[i:i + m] += amp * bp(white(m, rng), 700, 4200) * slip * np.exp(-tt / (d * 0.5)) * 1.6

    def snap(at, amp):
        i0 = n_of(at)
        nb = n_of(0.02)
        tb = np.arange(nb) / SR
        out[i0:i0 + nb] += amp * 0.5 * bp(white(nb, rng), 450, 3000) * (1.0 - np.exp(-tb / 0.0008)) * np.exp(-tb / 0.006)
        u = rng.uniform(0.85, 1.15)
        add_modes(out, at, [230 * u, 410 * u, 690 * u], [0.28, 0.17, 0.08], [0.025, 0.018, 0.012], rng, gain=amp)
        rub(at + 0.004, rng.uniform(0.025, 0.06), amp * 0.7)

    def cluster(at, size, gap, amp):
        tt = at
        for k in range(size):
            snap(tt, amp * (1.0 - 0.15 * k) * rng.uniform(0.85, 1.1))
            tt += gap * rng.uniform(0.8, 1.2)

    def creak(at, f0, f1, d, amp):                  # a short rough leather creak: strong timing jitter, a fast flutter
        m = n_of(d)
        i = n_of(at)
        tt = np.arange(m) / SR
        fq = np.linspace(f0, f1, m) * (1.0 + 0.12 * smooth_curve(m, 120.0, rng))
        src = harmonic_source(np.clip(fq, 50.0, 2000.0), kmax=8, ceil=2500.0)
        am = 0.6 + 0.4 * np.sin(2 * np.pi * 70.0 * tt)
        out[i:i + m] += amp * lp(src, 1800) * am * np.hanning(m) ** 0.8

    for at, size, amp in [(0.12, 2, 0.5), (0.34, 3, 0.42), (0.57, 2, 0.35)]:
        at += rng.uniform(-0.02, 0.02)
        cluster(at, size, 0.016, amp)
    at = 1.0
    for k in range(7):
        cluster(at, int(rng.integers(3, 5)), 0.013, 0.6)
        if k in (2, 5):
            creak(at + 0.04, 900.0, 620.0, 0.05, 0.12)
        at += 0.1 - 0.008 * k
    return out
