"""The five review-batch sounds. Each function returns the float signal (mono (n,) or stereo (n, 2)) at 48 kHz;
render.py finishes, measures and writes them. Only the first variant of each is built for review; the other
variants reuse the same machinery with different parameters once the direction is approved."""
import numpy as np
from scipy import signal

from dsp import (SR, add_modes, bp, harmonic_source, hp, lp, n_of, osc_phase, resonator, rng_for, saturate,
                 smooth_curve, sstep, tv_bandpass, white)

# ============================================================================ door_open (old wooden house door)
DOOR = {
    # short reluctant movement
    1: dict(dur=1.15, m0=0.09, m1=0.92, f=(205.0, 330.0), catches=[0.50]),
}


def door_open(seed, variant=1):
    p = DOOR[variant]
    rng = rng_for(seed)
    n = n_of(p["dur"])
    t = np.arange(n) / SR
    out = np.zeros(n)

    # 1. latch release: a small filtered-noise click, two quick spring ticks and three brief metallic resonances
    nb = n_of(0.03)
    tb = np.arange(nb) / SR
    burst = bp(white(nb, rng), 1200, 6000) * np.exp(-tb / 0.003)
    out[:nb] += 0.55 * burst
    out[n_of(0.021):n_of(0.021) + nb] += 0.22 * burst
    add_modes(out, 0.0, [rng.uniform(1900, 2500), rng.uniform(2900, 3700), rng.uniform(4300, 5200)],
              [0.30, 0.20, 0.10], [0.012, 0.008, 0.005], rng)

    # 2. hinge creak: a rough harmonic source whose fundamental wanders between 120 and 450 Hz, with a fast
    #    small jitter for rasp, a glide down as the tension releases and a jump up after each catch
    m0, m1 = p["m0"], p["m1"]
    win = sstep((t - m0) / 0.07) * sstep((m1 - t) / 0.12)
    lo, hi = p["f"]
    f = lo + (hi - lo) * (0.5 + 0.28 * np.tanh(smooth_curve(n, 2.2, rng)))
    f = f * (1.0 + 0.012 * smooth_curve(n, 35.0, rng))
    f = f * (1.0 - 0.07 * sstep((t - (m1 - 0.2)) / 0.2))
    for tc in p["catches"]:
        f = f * (1.0 + 0.11 * np.exp(-np.clip(t - tc, 0, None) / 0.07) * (t >= tc))
    f = np.clip(f, 120.0, 450.0)
    # friction catching and releasing: an irregular activity curve, a dip before each catch and a burst as it lets go
    act = np.clip(0.55 + 0.7 * smooth_curve(n, 9.0, rng), 0.0, 1.0) ** 1.4
    for tc in p["catches"]:
        act = act * (1.0 - 0.9 * np.exp(-0.5 * ((t - (tc - 0.035)) / 0.03) ** 2))
        act = act + 0.9 * np.exp(-np.clip(t - tc, 0, None) / 0.025) * (t >= tc)
    amp = win * act
    # A creak is a stick-slip train of irregular pulses ringing a few fixed, inharmonic hinge modes. (The first version
    # put a smooth buzz through moving resonances near 650 / 1350 / 2300 Hz: those are vowel formants, and it said "raaa".)
    cyc = np.cumsum(f) / SR
    cyc = np.maximum.accumulate(cyc + 0.22 * smooth_curve(n, 70.0, rng))            # timing jitter: the period is never steady
    ticks = np.diff(np.floor(cyc), prepend=np.floor(cyc[0])) > 0
    imp = ticks * rng.uniform(0.35, 1.6, n) * amp
    kk = n_of(0.003)
    kern = bp(white(kk, rng), 200, 3500) * np.exp(-(np.arange(kk) / SR) / 0.0009)
    pulses = signal.fftconvolve(imp, kern)[:n]
    creak = np.zeros(n)
    for fc, g, q in [(287.0, 1.0, 16.0), (611.0, 0.9, 20.0), (1043.0, 0.45, 24.0), (1736.0, 0.16, 26.0)]:
        drift = fc * (1.0 + 0.05 * np.tanh(smooth_curve(n, 1.5, rng)))              # each mode drifts on its own, with the load
        creak += g * tv_bandpass(pulses, drift, q)
    live = amp > 0.05
    creak = creak * (0.13 / (creak[live].std() + 1e-12))
    creak = creak + 0.3 * bp(white(n, rng), 300, 2200) * amp * 0.5                  # the grit of the friction itself
    out += creak

    # 3. the wood: door and frame modes excited by the latch, the catches and (quietly) by the movement
    modes_f = [118.0, 176.0, 243.0]
    add_modes(out, 0.0, modes_f, [0.12, 0.09, 0.07], [0.12, 0.09, 0.06], rng)
    for tc in p["catches"]:
        add_modes(out, tc, modes_f, [0.14, 0.10, 0.07], [0.10, 0.08, 0.05], rng)
    lpn = lp(white(n, rng), 350)
    wood = sum(g * resonator(lpn, fr, 14.0) for fr, g in zip(modes_f, [1.0, 0.7, 0.5]))
    out += 1.0 * wood * win * act

    # 4. a small release of tension, not a slam
    add_modes(out, m1 + 0.02, [92.0, 140.0], [0.16, 0.09], [0.06, 0.045], rng)
    i = n_of(m1 + 0.02)
    nn = n_of(0.05)
    out[i:i + nn] += 0.09 * bp(white(nn, rng), 200, 900) * np.exp(-np.arange(nn) / SR / 0.02)
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


# ============================================================================ skitter_chitter (variant 1: searching, then a quick answer)
def skitter_chitter(seed, variant=1):
    rng = rng_for(seed)
    n = n_of(1.75)
    out = np.zeros(n)

    def click(at, amp):
        i0 = n_of(at)
        nb = n_of(0.008)
        tb = np.arange(nb) / SR
        out[i0:i0 + nb] += amp * 0.5 * bp(white(nb, rng), 2000, 7500) * np.exp(-tb / 0.0012)
        d = n_of(0.03)
        td = np.arange(d) / SR
        fc = rng.uniform(2800, 4200)
        out[i0:i0 + d] += amp * 0.45 * np.sin(osc_phase(fc * (1.0 + 0.15 * np.exp(-td / 0.005)))) * np.exp(-td / 0.007)
        u = rng.uniform(0.9, 1.1)
        add_modes(out, at, [820 * u, 1650 * u], [0.22, 0.10], [0.010, 0.006], rng, gain=amp)   # the carapace

    def cluster(at, size, gap, amp):
        tt = at
        for k in range(size):
            click(tt, amp * (1.0 - 0.15 * k) * rng.uniform(0.85, 1.1))
            tt += gap * rng.uniform(0.8, 1.2)

    def grains(at, count, span):                     # restrained granular friction, only right after an event
        for _ in range(count):
            i = n_of(at + rng.uniform(0, span))
            m = n_of(rng.uniform(0.002, 0.005))
            out[i:i + m] += rng.uniform(0.05, 0.12) * bp(white(m, rng), 1500, 6000) * np.hanning(m)

    def chirp(at, f0, f1, d, amp):
        m = n_of(d)
        i = n_of(at)
        ff = np.linspace(f0, f1, m)
        env = np.hanning(m) ** 0.8 * (0.6 + 0.4 * np.sin(2 * np.pi * 95.0 * np.arange(m) / SR))
        out[i:i + m] += amp * np.sin(osc_phase(ff)) * env

    # a few exploratory clicks ...
    for at, size, amp in [(0.12, 2, 0.5), (0.34, 3, 0.42), (0.57, 2, 0.35)]:
        at += rng.uniform(-0.02, 0.02)
        cluster(at, size, 0.011, amp)
        grains(at + 0.01, 4, 0.04)
    # ... a pause ... then a faster, more insistent response
    at = 1.0
    for k in range(7):
        cluster(at, int(rng.integers(3, 5)), 0.009, 0.6)
        grains(at + 0.01, 6, 0.04)
        if k in (2, 5):
            chirp(at + 0.03, 2500.0, 3600.0, 0.035, 0.22)
        at += 0.095 - 0.007 * k
    return out
