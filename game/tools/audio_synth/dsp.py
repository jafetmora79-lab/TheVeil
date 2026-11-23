"""DSP building blocks for THE VEIL's procedural sound effects.

Everything renders in 48 kHz floating point and is exported as 24-bit PCM WAV. No recordings are used: every
sound is built from filtered noise, damped resonators, integrated-phase oscillators and controlled saturation.
(game/tools has a .gdignore, so none of this - nor the rendered review files - is imported by Godot.)
"""
import wave

import numpy as np
from scipy import signal

SR = 48000
CEILING_DB = -3.0          # conservative true-peak ceiling


# ------------------------------------------------------------------ basics
def rng_for(seed):
    return np.random.default_rng(int(seed))


def n_of(sec):
    return int(round(sec * SR))


def white(n, rng):
    return rng.standard_normal(n)


def sstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _sos(kind, f, order):
    nyq = SR / 2.0
    if isinstance(f, (tuple, list)):
        w = [min(max(v, 1.0), nyq * 0.97) / nyq for v in f]
    else:
        w = min(max(f, 1.0), nyq * 0.97) / nyq
    return signal.butter(order, w, btype=kind, output="sos")


def lp(x, f, order=4):
    return signal.sosfilt(_sos("low", f, order), x, axis=0)


def hp(x, f, order=2):
    return signal.sosfilt(_sos("high", f, order), x, axis=0)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("band", (lo, hi), order), x, axis=0)


def resonator(x, f, q):
    """A fixed two-pole resonance (unity gain at its centre)."""
    b, a = signal.iirpeak(min(f, SR * 0.45) / (SR / 2.0), q)
    return signal.lfilter(b, a, x)


def tv_bandpass(x, fc, q):
    """A band-pass whose centre frequency (and Q) change sample by sample: a trapezoidal state-variable
    filter (stable at any setting). Unity gain at the centre."""
    n = len(x)
    fc = np.broadcast_to(np.asarray(fc, dtype=float), (n,))
    q = np.broadcast_to(np.asarray(q, dtype=float), (n,))
    g = np.tan(np.pi * np.clip(fc, 20.0, SR * 0.45) / SR)
    k = 1.0 / np.maximum(q, 0.3)
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    xs, a1l, a2l, a3l, kl = x.tolist(), a1.tolist(), a2.tolist(), a3.tolist(), k.tolist()
    y = [0.0] * n
    ic1 = ic2 = 0.0
    for i in range(n):
        v3 = xs[i] - ic2
        v1 = a1l[i] * ic1 + a2l[i] * v3
        v2 = ic2 + a2l[i] * ic1 + a3l[i] * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        y[i] = v1 * kl[i]
    return np.asarray(y)


# ------------------------------------------------------------------ excitation and modes
def add_modes(buf, at, freqs, amps, taus, rng, gain=1.0):
    """Add a struck object's vibration: sum_k A_k exp(-t/tau_k) sin(2 pi f_k t + phi_k), starting at `at` seconds."""
    i0 = int(round(at * SR))
    m = len(buf) - i0
    if m <= 0:
        return
    tt = np.arange(m) / SR
    for f, a, tau in zip(freqs, amps, taus):
        buf[i0:] += gain * a * np.exp(-tt / tau) * np.sin(2.0 * np.pi * f * tt + rng.uniform(0.0, 0.6))


def smooth_curve(n, rate, rng):
    """A slow random curve (zero mean, unit variance), changing on a time scale of about 1/rate seconds."""
    x = white(n, rng)
    sos = signal.butter(2, min(rate, SR * 0.4) / (SR / 2.0), output="sos")
    y = signal.sosfiltfilt(sos, x)
    return (y - y.mean()) / (y.std() + 1e-12)


def osc_phase(freq):
    """Integrate the instantaneous frequency: phi[n] = phi[n-1] + 2 pi f[n] / fs."""
    return 2.0 * np.pi * np.cumsum(freq) / SR


def harmonic_source(freq, kmax=40, ceil=9000.0, rolloff=1.0, rng=None):
    """A band-limited harmonic stack (a rough, saw-like source) following a time-varying fundamental."""
    ph = osc_phase(freq)
    y = np.zeros(len(freq))
    for k in range(1, kmax + 1):
        a = (k ** -rolloff) * np.clip((ceil - k * freq) / 1500.0, 0.0, 1.0)
        if not a.any():
            break
        y += a * np.sin(k * ph + 0.7 * k * k * 0.37)
    return y


def saturate(x, g):
    """tanh saturation, oversampled 4x so the new harmonics do not alias."""
    up = signal.resample_poly(x, 4, 1, axis=0)
    return signal.resample_poly(np.tanh(g * up), 1, 4, axis=0)


# ------------------------------------------------------------------ finishing
def true_peak(x):
    up = signal.resample_poly(x, 4, 1, axis=0)
    return float(np.max(np.abs(up)))


def finish(x, peak_db=None, rms_db=None, loop=False, fade_out_ms=8.0):
    """Remove DC, high-pass at 28 Hz (not for loops: they are built periodic), short boundary fades, one gain for
    the whole asset (never per component), then keep the estimated true peak under the ceiling."""
    x = np.asarray(x, dtype=float)
    x = x - x.mean(axis=0)
    if not loop:
        x = hp(x, 28.0, 2)
        n = len(x)
        fi = max(2, int(0.0005 * SR))
        fo = max(2, int(fade_out_ms / 1000.0 * SR))
        w = np.ones(n)
        w[:fi] = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, fi))
        w[-fo:] = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, fo))
        x = x * (w[:, None] if x.ndim == 2 else w)
    if rms_db is not None:
        g = 10 ** (rms_db / 20.0) / (np.sqrt(np.mean(x ** 2)) + 1e-12)
    else:
        g = 10 ** (peak_db / 20.0) / (np.max(np.abs(x)) + 1e-12)
    x = x * g
    ceil = 10 ** (CEILING_DB / 20.0)
    tp = true_peak(x)
    if tp > ceil:
        x = x * (ceil / tp)
    return x


def write_wav24(path, x):
    x = np.asarray(x)
    if x.ndim == 1:
        x = x[:, None]
    ints = np.round(np.clip(x, -1.0, 1.0) * 8388607.0).astype("<i4")
    raw = ints.reshape(-1).view(np.uint8).reshape(-1, 4)[:, :3].tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(3)
        w.setframerate(SR)
        w.writeframes(raw)


# ------------------------------------------------------------------ measurements
def _db(v):
    return 20.0 * np.log10(max(float(v), 1e-12))


def analyze(x, loop=False):
    x = np.asarray(x, dtype=float)
    mono = x if x.ndim == 1 else x.mean(axis=1)
    info = {
        "finite": bool(np.all(np.isfinite(x))),
        "sample_peak_db": round(_db(np.max(np.abs(x))), 2),
        "true_peak_db": round(_db(true_peak(x)), 2),
        "rms_db": round(_db(np.sqrt(np.mean(x ** 2))), 2),
        "dc": round(float(np.mean(x)), 7),
        "clipped_samples": int(np.sum(np.abs(x) >= 0.9999)),
        "silent": bool(np.max(np.abs(x)) < 1e-4),
    }
    tail = x[-int(0.005 * SR):]
    info["tail_vs_peak_db"] = round(_db(np.sqrt(np.mean(tail ** 2))) - info["sample_peak_db"], 1)
    spec = np.abs(np.fft.rfft(mono)) ** 2
    fr = np.fft.rfftfreq(len(mono), 1.0 / SR)
    tot = spec.sum() + 1e-18
    info["energy_pct"] = {
        "<30Hz": round(100 * spec[fr < 30].sum() / tot, 2),
        "30-150": round(100 * spec[(fr >= 30) & (fr < 150)].sum() / tot, 1),
        "150-1k": round(100 * spec[(fr >= 150) & (fr < 1000)].sum() / tot, 1),
        "1k-4k": round(100 * spec[(fr >= 1000) & (fr < 4000)].sum() / tot, 1),
        ">4k": round(100 * spec[fr >= 4000].sum() / tot, 1),
    }
    if x.ndim == 2:
        l, r = x[:, 0], x[:, 1]
        info["lr_correlation"] = round(float(np.corrcoef(l, r)[0, 1]), 3)
        info["mono_sum_loss_db"] = round(_db(np.sqrt(np.mean(mono ** 2))) - _db(np.sqrt(np.mean(x ** 2))), 2)
    if loop:
        three = np.concatenate([x, x, x], axis=0)
        d = np.abs(np.diff(three, axis=0))
        d = d.max(axis=1) if d.ndim == 2 else d
        b = len(x) - 1
        info["loop_boundary_step_vs_p99_step"] = round(float(d[b] / (np.percentile(d, 99) + 1e-12)), 3)
    return info
