"""Generate FearFlip's sound effects with ElevenLabs from the audio table in godot/assets/ASSET_PROMPTS.md.

Usage:  python tools/gen_audio.py [--dry-run] [--only sfx_flip.mp3 ...]
Needs ELEVENLABS_API_KEY in the environment (never pass it on the command line or commit it).
Overwrites godot/assets/audio/<file>; the originals are in git.
"""
import argparse
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEET = ROOT / "godot" / "assets" / "ASSET_PROMPTS.md"
OUT = ROOT / "godot" / "assets" / "audio"
URL = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"
# API limits: 0.5-30 s. Longer "loops" in the sheet are made 30 s and loop seamlessly.
MIN_SECONDS, MAX_SECONDS = 0.5, 30.0


def rows():
    """(file, prompt, seconds or None, loop) for every row of the sheet's audio table."""
    in_audio = False
    for line in SHEET.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            in_audio = line.startswith("## 6. Audio")
        match = re.match(r"\| `([^`]+)`[^|]*\| (.+) \|$", line) if in_audio else None
        if not match:
            continue
        name, prompt = match.groups()
        secs = re.search(r"(\d+(?:\.\d+)?)(?:-second| s\b)", prompt)
        seconds = min(max(float(secs.group(1)), MIN_SECONDS), MAX_SECONDS) if secs else None
        takes = re.match(r"(.+_)(\d(?:/\d)+)\.mp3$", name)  # sfx_footstep_1/2/3.mp3 -> three files
        names = [f"{takes.group(1)}{n}.mp3" for n in takes.group(2).split("/")] if takes else [name]
        for n in names:
            yield n, prompt, seconds, "loop" in prompt


def generate(prompt, seconds, loop, key):
    body = {"text": prompt, "prompt_influence": 0.5, "loop": loop}
    if seconds:
        body["duration_seconds"] = seconds
    request = urllib.request.Request(URL, data=json.dumps(body).encode(),
                                     headers={"xi-api-key": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=180) as response:
        return response.read()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--only", nargs="*", default=[])
    args = parser.parse_args()
    jobs = [r for r in rows() if not args.only or r[0] in args.only]
    if not jobs:
        sys.exit("No matching rows in the audio table.")
    key = os.environ.get("ELEVENLABS_API_KEY", "")
    if not args.dry_run and not key:
        sys.exit("Set ELEVENLABS_API_KEY first.")
    failed = 0
    for name, prompt, seconds, loop in jobs:
        label = f"{name:26s} {('%.1f s' % seconds) if seconds else 'auto':>7s} {'loop' if loop else '':4s}"
        if args.dry_run:
            print(label, prompt[:70])
            continue
        try:
            audio = generate(prompt, seconds, loop, key)
            (OUT / name).write_bytes(audio)
            print(label, f"ok {len(audio) / 1024:.0f} KB")
        except urllib.error.HTTPError as e:
            failed += 1
            print(label, f"FAILED {e.code}: {e.read().decode(errors='replace')[:200]}")
        except urllib.error.URLError as e:
            failed += 1
            print(label, f"FAILED {e.reason}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
