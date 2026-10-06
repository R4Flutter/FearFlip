"""Generate FearFlip SFX with ElevenLabs. Usage: ELEVENLABS_API_KEY=... python godot/tools/gen_sfx.py [name ...]
Key is read from env only - never commit it. Existing files are skipped unless named explicitly."""
import json, os, sys, urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
# Shared style: keep everything soft-edged so repeats never grate.
STYLE = "high quality, clean, mixed for headphones, no harsh high frequencies, no clipping"
# name: (prompt, seconds, loop)
SFX = {
	"footstep_1": ("single soft footstep on damp stone floor, muffled leather boot, close and dry", 0.5, False),
	"footstep_2": ("single quiet footstep on gritty stone, light scuff, muffled, close", 0.5, False),
	"footstep_3": ("single soft footstep on cold concrete, gentle heel tap, muffled", 0.5, False),
	"flip": ("deep cinematic whoosh, reality bending, low sub bass swell into soft reversed swell, dark", 1.6, False),
	"flip_denied": ("short soft muted low thud, dull subtle error, gentle, not buzzy", 0.6, False),
	"flipping_warning": ("ominous low cinematic riser with faint distant whispers, building dread, dark horror", 3.0, False),
	"sigil": ("soft ethereal glass chime with warm magical shimmer, mysterious, gentle reward", 1.5, False),
	"devil_approach": ("distant deep demonic growl with slow heavy breathing, menacing, horror, low", 3.5, False),
	"heartbeat": ("slow deep human heartbeat, low muffled thumps, steady rhythm", 4.0, True),
	"low_time": ("low pulsing tension drone with soft ticking clock, rising urgency, subtle, not shrill", 4.0, False),
	"floor_crack": ("heavy stone floor cracking and crumbling, deep rumble, falling debris", 1.6, False),
	"floor_creak": ("quiet slow creak of strained old stone and wood under weight, subtle", 1.2, False),
	"safe_circle": ("warm protective low hum with soft distant choir pad, calming, sacred", 2.0, False),
	"devil_wakes": ("distant deep demonic roar echoing through stone corridors, horror sting", 2.2, False),
	"win": ("dark but triumphant orchestral sting, warm brass swell, relief, short", 3.0, False),
	"lose": ("deep horror impact with low boom and dissonant strings fading out", 3.0, False),
	"ambient_calm": ("dark ambient horror drone, low wind through stone corridors, distant water drips, eerie but calm", 30.0, True),
	"ambient_intense": ("tense horror ambience, pulsing low drone, slow muffled percussion, dread, chase", 30.0, True),
}


def generate(key: str, name: str) -> None:
	prompt, seconds, loop = SFX[name]
	body = {"text": f"{prompt}. {STYLE}", "duration_seconds": seconds, "prompt_influence": 0.5,
		"model_id": "eleven_text_to_sound_v2", "loop": loop}
	req = urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128",
		data=json.dumps(body).encode(), headers={"xi-api-key": key, "Content-Type": "application/json"})
	with urllib.request.urlopen(req, timeout=120) as r:
		(OUT / f"sfx_{name}.mp3").write_bytes(r.read())
	print("ok", name)


if __name__ == "__main__":
	key = os.environ.get("ELEVENLABS_API_KEY") or sys.exit("set ELEVENLABS_API_KEY")
	names = sys.argv[1:] or [n for n in SFX if not (OUT / f"sfx_{n}.mp3").exists()]
	for n in names:
		try:
			generate(key, n)
		except urllib.error.HTTPError as e:
			print("FAIL", n, e.code, e.read().decode()[:300])
