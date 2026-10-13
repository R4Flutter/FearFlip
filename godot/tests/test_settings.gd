extends McpTestSuite
## Settings: the options survive a relaunch, a missing or hand-edited file reads as safe values, and the volumes
## reach their buses (default_bus_layout.tres).

const PATH := "user://test_settings.cfg"


func suite_name() -> String:
	return "settings"


func setup() -> void:
	Settings.settings_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Settings.read(PATH)


func teardown() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Settings.read(PATH)
	Settings.apply()


func test_options_survive_a_relaunch() -> void:
	Settings.music = 0.3
	Settings.sensitivity = 1.75
	Settings.reduce_motion = true
	Settings.save()
	Settings.music = 1.0
	Settings.sensitivity = 1.0
	Settings.reduce_motion = false
	Settings.read(PATH)
	assert_eq(Settings.music, 0.3)
	assert_eq(Settings.sensitivity, 1.75)
	assert_true(Settings.reduce_motion)


func test_no_file_reads_as_the_defaults_and_bad_values_are_clamped() -> void:
	assert_eq(Settings.master, 1.0, "no file = the defaults")
	assert_false(Settings.invert_y)
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", 7.0)
	cfg.set_value("controls", "sensitivity", 0.0)
	cfg.save(PATH)
	Settings.read(PATH)
	assert_eq(Settings.sfx, 1.0)
	assert_eq(Settings.sensitivity, Settings.SENSITIVITY_RANGE.x)


## Reduce Flashing dims every full-screen flash, the death screen's hit included.
func test_reduce_flashing_dims_the_death_screens_hit_too() -> void:
	assert_eq(Settings.flash(0.6), 0.6, "off: full strength")
	Settings.reduce_flashing = true
	assert_eq(Settings.flash(0.6), 0.6 * Settings.FLASH_REDUCED)
	var screen := DeathScreen.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	track(screen)
	Settings.reduce_motion = true
	screen.show_death("THE DEVIL GOT YOU", "rule", "detail", "revive", false)
	assert_true(screen._flash.color.a <= Settings.flash(0.65) + 0.001, "the hit is dimmed")
	assert_false(screen._stage.has_meta("tween"), "and Reduce Motion keeps the screen still (no shake tween)")


func test_volumes_reach_their_buses() -> void:
	Settings.music = 0.5
	Settings.apply()
	var bus := AudioServer.get_bus_index(Settings.MUSIC_BUS)
	assert_true(bus > 0, "default_bus_layout.tres has a Music bus")
	assert_true(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.5)) < 0.01, "half volume = -6 dB")
	assert_true(AudioServer.get_bus_index(Settings.SFX_BUS) > 0, "and an SFX bus")
