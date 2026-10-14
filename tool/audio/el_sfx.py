"""ElevenLabs sound-generation helper. Key comes from the ELEVENLABS_API_KEY env var (never stored in the repo).

usage: python el_sfx.py <name> <seconds> <loop 0/1> <prompt_influence> "<prompt>"
writes raw/<name>.mp3 (skips if it already exists unless FORCE=1)
"""
import json, os, sys, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
KEY = os.environ["ELEVENLABS_API_KEY"]
RAW = os.path.join(HERE, "raw")
os.makedirs(RAW, exist_ok=True)


def credits_used():
    req = urllib.request.Request("https://api.elevenlabs.io/v1/user/subscription", headers={"xi-api-key": KEY})
    return json.load(urllib.request.urlopen(req))["character_count"]


def gen(name, seconds, loop, influence, prompt):
    out = os.path.join(RAW, name + ".mp3")
    if os.path.exists(out) and not os.environ.get("FORCE"):
        print("skip", name)
        return
    body = {"text": prompt, "duration_seconds": seconds, "prompt_influence": influence,
            "loop": bool(loop), "model_id": "eleven_text_to_sound_v2"}
    req = urllib.request.Request(
        "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128",
        data=json.dumps(body).encode(), method="POST",
        headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    try:
        data = urllib.request.urlopen(req, timeout=180).read()
    except urllib.error.HTTPError as e:
        sys.exit(f"{name}: HTTP {e.code} {e.read()[:300]!r}")
    open(out, "wb").write(data)
    print(f"ok {name} {len(data)//1024}KB")


if __name__ == "__main__":
    if sys.argv[1] == "credits":
        print("credits used:", credits_used())
    else:
        n, s, l, pi, p = sys.argv[1:6]
        gen(n, float(s), int(l), float(pi), p)
