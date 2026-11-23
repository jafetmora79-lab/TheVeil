"""Render the review batch: python game/tools/audio_synth/render.py
Writes 24-bit WAVs and manifest.json to game/tools/audio_synth/review/, and prints the numeric checks.
Numbers do not say whether a sound is convincing: that needs ears."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import dsp  # noqa: E402
import sounds  # noqa: E402

OUT = Path(__file__).parent / "review"

# name, builder, seed, finish arguments, channels note, intended use, loops
BATCH = [
    ("door_open_01", sounds.door_open, 1101, dict(peak_db=-13.0),
     "Old wooden house door opening: latch, hinge creak, wood resonance (short reluctant variant).", False),
    ("drag_heavy_01", sounds.drag_heavy, 2101, dict(peak_db=-9.0),
     "Loaded shelf or pallet dragged over a hard floor (rough scrape variant).", False),
    ("jumpscare_hit_01", sounds.jumpscare_hit, 3101, dict(peak_db=-4.0),
     "Accent for a scare: blunt pressure signature (stereo, cinematic).", False),
    ("drone_dark_01", sounds.drone_dark, 4101, dict(rms_db=-28.0, loop=True),
     "Fog-pressure bed, seamless loop (stereo, non-positional).", True),
    ("skitter_chitter_01", sounds.skitter_chitter, 5101, dict(peak_db=-10.0),
     "Skitter searching clicks, a pause, then a faster answer.", False),
]


def main():
    OUT.mkdir(exist_ok=True)
    manifest = []
    for name, fn, seed, fin, use, loops in BATCH:
        x = fn(seed)
        x = dsp.finish(x, **fin)
        dsp.write_wav24(OUT / (name + ".wav"), x)
        info = dsp.analyze(x, loop=loops)
        entry = {"file": name + ".wav", "duration_s": round(len(x) / dsp.SR, 3),
                 "channels": 1 if x.ndim == 1 else 2, "seed": seed, "use": use, "loops": loops, "checks": info}
        manifest.append(entry)
        print(name, json.dumps(info))
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
