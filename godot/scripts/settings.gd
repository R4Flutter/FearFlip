class_name Settings
extends RefCounted
## The player's options (the menu's SETTINGS screen): volumes, look, brightness and comfort. Their own file, apart
## from the profile: they belong to this device, not to the run or the cloud save.

## The buses in default_bus_layout.tres. Every AudioStreamPlayer picks one; Master scales both.
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
## Slider limits, (min, max).
const SENSITIVITY_RANGE := Vector2(0.25, 2.5)
const BRIGHTNESS_RANGE := Vector2(0.6, 1.6)
## Reduce flashing keeps this share of a full-screen flash: still a cue, never a strobe.
const FLASH_REDUCED := 0.25

static var settings_path := "user://settings.cfg"
## Volumes, 0..1.
static var master := 1.0
static var music := 1.0
static var sfx := 1.0
## x PlayerFeel's mouse and stick look speeds.
static var sensitivity := 1.0
static var invert_y := false
## x the maze's exposure: lift it when the dark is too dark to read.
static var brightness := 1.0
static var fullscreen := false
## Full-screen flashes (flip, chest, Camera Flash, grab) at FLASH_REDUCED, and no menu lightning.
static var reduce_flashing := false
## No flip roll, Flipping Time tilt, camera shake or head-bob.
static var reduce_motion := false
static var _loaded := false


## Once per process (the menu calls it at boot). Tests keep the defaults, whatever this machine saved.
static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	if RunState.is_game():
		read(settings_path)


## No file (or no key) reads as the default; a hand-edited value is clamped back into range.
static func read(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	master = clampf(cfg.get_value("audio", "master", 1.0), 0.0, 1.0)
	music = clampf(cfg.get_value("audio", "music", 1.0), 0.0, 1.0)
	sfx = clampf(cfg.get_value("audio", "sfx", 1.0), 0.0, 1.0)
	sensitivity = clampf(cfg.get_value("controls", "sensitivity", 1.0), SENSITIVITY_RANGE.x, SENSITIVITY_RANGE.y)
	invert_y = cfg.get_value("controls", "invert_y", false)
	brightness = clampf(cfg.get_value("video", "brightness", 1.0), BRIGHTNESS_RANGE.x, BRIGHTNESS_RANGE.y)
	fullscreen = cfg.get_value("video", "fullscreen", false)
	reduce_flashing = cfg.get_value("comfort", "reduce_flashing", false)
	reduce_motion = cfg.get_value("comfort", "reduce_motion", false)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("comfort", "reduce_flashing", reduce_flashing)
	cfg.set_value("comfort", "reduce_motion", reduce_motion)
	cfg.save(settings_path)


## Pushes what the engine owns: the bus volumes, and the window on desktop (a browser only goes fullscreen from its
## own button). The game reads the rest as it builds a floor.
static func apply() -> void:
	_volume(&"Master", master)
	_volume(MUSIC_BUS, music)
	_volume(SFX_BUS, sfx)
	if OS.has_feature("web"):
		return
	var mode := DisplayServer.window_get_mode()
	var full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != full:  # only on a change, so a maximized window stays maximized
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


static func _volume(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(volume))
