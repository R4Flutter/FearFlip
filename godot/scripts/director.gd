class_name Director
extends RefCounted
## The menace meter (plans/06 P7, master plan §7): it sets the Devil's pace, so a floor runs quiet, then builds,
## peaks and relaxes. Pure: main.gd feeds it what the Devil senses each tick, gives the Devil your scent (chase pace)
## when advance() says a hint is due, and lets it run flat out only at the PEAK. The Devil always hunts you; RELAX
## only slows it down.

enum Phase { CALM, BUILD, PEAK, RELAX }

## Menace (0..100) rises per second by the strongest of these, else it falls.
const RISE_SEEN := 30.0
const RISE_NEAR := 12.0
const RISE_HEARD := 6.0
const FALL := 8.0
## Path tiles: "near" the Devil, and close enough for you to hear it.
const NEAR_TILES := 6
const HEARD_TILES := 10
## A chase only runs at the peak.
const PEAK_AT := 80.0
## Calm this long and it builds: a hint (your scent, so it picks up the pace), then one every HINT_EVERY s until the
## peak.
const CALM_LIMIT := 35.0
const HINT_EVERY := 10.0
## A peak lasts at most PEAK_LIMIT s, or until it hasn't seen you for LOST_LIMIT s; then it slows for RELAX_TIME.
const PEAK_LIMIT := 12.0
const LOST_LIMIT := 6.0
const RELAX_TIME := Vector2(15.0, 25.0)

var menace := 0.0
var phase := Phase.CALM
## Hidden mercy stretches the time between hints (RunState.mod("hint_stretch")).
var hint_stretch := 1.0
var _clock := 0.0
var _unseen := 0.0
var _hint_left := 0.0
var _relax_for := 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_rng.seed = hash([seed_value, "director"])


## One tick of what the Devil senses. True when it's due a hint.
func advance(delta: float, sees: bool, near: bool, heard: bool) -> bool:
	var rise := RISE_SEEN if sees else (RISE_NEAR if near else (RISE_HEARD if heard else -FALL))
	menace = clampf(menace + rise * delta, 0.0, 100.0)
	_clock += delta
	_unseen = 0.0 if sees else _unseen + delta
	match phase:
		Phase.CALM, Phase.BUILD:
			if menace >= PEAK_AT:
				_enter(Phase.PEAK)
			elif phase == Phase.CALM and _clock >= CALM_LIMIT:
				_enter(Phase.BUILD)
				return true
			elif phase == Phase.BUILD:
				_hint_left -= delta
				if _hint_left <= 0.0:
					_hint_left = HINT_EVERY * hint_stretch
					return true
		Phase.PEAK:
			if _clock >= PEAK_LIMIT or _unseen >= LOST_LIMIT:
				_enter(Phase.RELAX)
		Phase.RELAX:
			if _clock >= _relax_for:
				_enter(Phase.CALM)
	return false


func _enter(next: Phase) -> void:
	phase = next
	_clock = 0.0
	_hint_left = HINT_EVERY * hint_stretch
	_relax_for = _rng.randf_range(RELAX_TIME.x, RELAX_TIME.y)
