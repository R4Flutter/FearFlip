extends McpTestSuite
## Integration: the real main scene wires FloorLayout + FlipSystem into physics, visuals and win/lose.

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE


func suite_name() -> String:
	return "main_floor"


func teardown() -> void:
	RunState.mode = "campaign"


## A debug floor (fixed seed) built from `cards` on `floor_number`; RunState goes back to Act 1 F1 after.
func _spawn_floor(cards: Array = [], floor_number := 1) -> Node3D:
	RunState.floor_cards.assign(cards)
	RunState.run_cards.clear()
	RunState.current_floor = floor_number
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.fixed_seed = 42
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	track(main)
	RunState.floor_cards.clear()
	RunState.current_floor = 1
	return main


func test_flip_swaps_collision_and_visuals() -> void:
	var main := _spawn_floor()
	assert_eq(main.world, WAKE)
	assert_eq(main.player.collision_mask, main.LAYER_SHARED | main.LAYER_WAKE)
	assert_false(main.devil.visible, "Devil only exists in NIGHTMARE")
	assert_true(main.flip.request_flip(main._spot_open(NIGHTMARE)), "spawn is open in both worlds")
	assert_eq(main.world, NIGHTMARE)
	assert_eq(main.player.collision_mask, main.LAYER_SHARED | main.LAYER_NIGHTMARE)
	assert_true(main.nightmare_walls.visible and not main.wake_walls.visible)
	assert_false(main.devil.visible, "asleep until it wakes")
	main._wake_devil()
	assert_true(main.devil.visible)


func test_all_keys_open_exit_then_win() -> void:
	var main := _spawn_floor()
	for i in main.layout.sigils.size():
		main._apply_world(main.layout.sigil_worlds[i])
		main.player_cell = main.layout.sigils[i]
		main._collect_sigils()
	assert_true(main.exit_open)
	main.player_cell = main.layout.exit
	main.devil_cell = main.layout.devil_spawn
	main._process(0.016)
	assert_eq(main.game_state, "unlocking", "keys go into the chest first; clock and Devil freeze")
	main._on_chest_opened()
	main._win_game()
	assert_eq(main.game_state, "won")


func test_keys_collect_and_show_in_either_world() -> void:
	var main := _spawn_floor()
	main._apply_world(NIGHTMARE)
	for i in main.layout.sigils.size():
		assert_true(main.sigil_nodes[i].visible, "key %d visible in NIGHTMARE" % i)
		for w in [WAKE, NIGHTMARE]:
			assert_true(main.layout.is_open(w, main.layout.sigils[i]), "key %d cell open in world %d" % [i, w])
	var nightmare_sigil: int = main.layout.sigil_worlds.find(NIGHTMARE)
	main._apply_world(WAKE)
	main.player_cell = main.layout.sigils[nightmare_sigil]
	main._collect_sigils()
	assert_eq(main.sigils_collected, 1, "a NIGHTMARE-coloured key is collectible in WAKE")


## The first wall multimesh of a world's wall set.
func _wall_mesh(walls: Node3D) -> MultiMeshInstance3D:
	for child in walls.get_children():
		if child is MultiMeshInstance3D:
			return child
	return null


func _run(main: Node3D, seconds: float) -> void:
	for _frame in int(seconds / 0.05):
		main._process(0.05)


func test_devil_walks_shortest_path_through_open_cells() -> void:
	var main := _spawn_floor()
	main._wake_devil()
	main.devil_cell = main.layout.devil_spawn
	main.brain.sense(true, false, 0.0)  # it knows where you are: the shortest way there
	var left: int = main._devil_distance()
	while left > 0:
		var from: Vector2i = main.devil_cell
		main._step_devil()
		var to: Vector2i = main.devil_cell
		assert_eq(absi(to.x - from.x) + absi(to.y - from.y), 1, "one neighbour per step")
		assert_true(main.layout.is_open(main.world, to), "walked into a wall at %s" % to)
		left -= 1
		assert_eq(main._devil_distance(), left, "not the shortest path")
	assert_eq(main.devil_cell, main.player_cell)


func test_devil_grabs_in_both_worlds_with_a_lunge() -> void:
	for w: int in [WAKE, NIGHTMARE]:
		var main := _spawn_floor()
		main._wake_devil()
		main._apply_world(w)
		main.catch_grace = 0.0
		main.devil_cell = main.player_cell
		main.devil.position = main._devil_world_position()
		main._process(0.05)
		assert_gt(main.lunge_left, 0.0, "a catch is a visible lunge first (world %d)" % w)
		assert_eq(main.game_state, "playing")
		_run(main, 0.5)
		assert_eq(main.game_state, "lost", "world %d" % w)
		assert_true(main.death_screen.visible)


func test_safe_circle_blocks_catch_and_revive_returns_there() -> void:
	var main := _spawn_floor()
	var circle: Vector2i = main.circles.cells[0]
	main._wake_devil()
	main._apply_world(NIGHTMARE)
	main.catch_grace = 0.0
	main._enter_cell(circle)
	assert_false(main.snapshot.is_empty(), "entering a circle saves the revive point")
	assert_true(main.devil_retreating)
	main.devil_cell = circle
	_run(main, 0.5)
	assert_eq(main.game_state, "playing", "no catch inside a circle")
	RunState.save_path = "user://test_run_state.cfg"
	main._lose_game("time")
	var revives: int = RunState.revives_left()
	main._revive()
	assert_eq(main.game_state, "playing")
	assert_true(main.get_node("HUD").visible, "the HUD comes back with you")
	assert_eq(main.player_cell, circle)
	assert_eq(RunState.revives_left(), revives - 1)
	RunState.revives_used = 0


func test_cracked_floor_kills_on_second_step() -> void:
	var main := _spawn_floor()
	var away: Vector2i = main.player_cell
	var cell := away
	for d in FloorLayout.DIRS:
		if main.layout.is_open(WAKE, away + d):
			cell = away + d
	main.traps.cells.assign([cell])
	main.traps.states.assign([TrapField.State.HIDDEN])
	main.traps._primed.assign([true])
	main.trap_nodes.clear()
	main._build_traps()
	main._enter_cell(cell)
	assert_eq(main.traps.states[0], TrapField.State.CRACKED)
	assert_eq(main.game_state, "playing", "the first step is always safe")
	main._enter_cell(away)
	main._enter_cell(cell)
	assert_eq(main.game_state, "dying")


func test_clock_zero_loses() -> void:
	var main := _spawn_floor()
	assert_gt(main.time_left, 60.0)
	main.time_left = 0.01
	main._process(0.05)
	assert_eq(main.game_state, "lost")


func test_forced_flip_moves_close_devil_away() -> void:
	var main := _spawn_floor()
	main._wake_devil()
	for d in FloorLayout.DIRS:
		if main.layout.is_open(NIGHTMARE, main.player_cell + d):
			main.devil_cell = main.player_cell + d
	main._on_flipped(NIGHTMARE, true)
	var dist: PackedInt32Array = main.layout.distances(NIGHTMARE, main.player_cell)
	assert_true(dist[main.devil_cell.y * main.layout.size + main.devil_cell.x] >= main.DEVIL_RETREAT_DISTANCE)
	assert_eq(main.floor_shards, 0, "Flipping Time's own flip is no Phase Dodge")


func test_flipping_time_inverts_movement() -> void:
	var main := _spawn_floor()
	Input.action_press("move_forward")
	Input.action_press("move_left")
	var normal: Vector2 = main._move_input()
	main.flip.forced_active = true
	var inverted: Vector2 = main._move_input()
	Input.action_release("move_forward")
	Input.action_release("move_left")
	assert_true(normal.y < 0.0 and normal.x < 0.0, "W forward, A left normally")
	assert_eq(inverted, -normal, "Flipping Time: W goes back, A goes right")


func test_keys_chest_and_floor_clear_pay_shards() -> void:
	var main := _spawn_floor()
	for i in main.layout.sigils.size():
		main._apply_world(main.layout.sigil_worlds[i])
		main.player_cell = main.layout.sigils[i]
		main._collect_sigils()
	var keys := FloorLayout.SIGIL_COUNT * MetaState.SIGIL_SHARDS
	assert_eq(main.floor_shards, keys, "every key pays")
	main._on_chest_opened()
	var chest: int = MetaState.chest_roll(main.seed_value)["shards"]
	assert_eq(main.floor_shards, keys + chest, "the chest pays its roll for this floor's seed")
	main._win_game()
	assert_true(main.floor_shards >= keys + chest + MetaState.floor_clear_shards(main.rule.floor_in_act, "C"), "the clear pays")
	main._update_hud()
	assert_true(main.shard_label.text.ends_with(str(MetaState.shards + main.floor_shards)), main.shard_label.text)


func test_a_missed_lunge_is_a_close_call() -> void:
	var main := _lunging_floor()
	main.player.global_position += Vector3(main.LUNGE_RANGE * 5.0, 0, 0)
	_run(main, 0.5)
	assert_eq(main.game_state, "playing", "out of reach when it lands")
	assert_eq(main.floor_shards, MetaState.CLOSE_CALL_SHARDS, "a near miss pays")
	assert_true(Engine.time_scale < 1.0, "a beat of slow motion")
	Engine.time_scale = 1.0


func test_diving_into_a_circle_mid_lunge_is_a_close_call() -> void:
	var main := _lunging_floor()
	main._enter_cell(main.circles.cells[0])
	assert_eq(main.lunge_left, 0.0, "the circle breaks the grab")
	assert_eq(main.floor_shards, MetaState.CLOSE_CALL_SHARDS)
	Engine.time_scale = 1.0


func test_flipping_out_of_a_lunge_is_a_phase_dodge() -> void:
	var main := _lunging_floor()
	assert_true(main.flip.request_flip(main._spot_open(WAKE)), "spawn is open in both worlds")
	assert_eq(main.lunge_left, 0.0, "the flip breaks the grab")
	assert_eq(main.floor_shards, MetaState.CLOSE_CALL_SHARDS, "and pays a Phase Dodge")
	Engine.time_scale = 1.0


## The Devil awake in NIGHTMARE, on your cell, its lunge under way.
func _lunging_floor() -> Node3D:
	var main := _spawn_floor()
	main._wake_devil()
	main._apply_world(NIGHTMARE)
	main.catch_grace = 0.0
	main.devil_cell = main.player_cell
	main.devil.position = main._devil_world_position()
	main._process(0.05)
	assert_gt(main.lunge_left, 0.0, "a lunge is under way")
	return main


func test_death_screen_shows_unfinished_business() -> void:
	MetaState.acts_unlocked = 1
	var main := _spawn_floor([], 8)
	main._lose_game("time")
	var line: String = main.death_screen._business.text
	assert_true(line.contains("3 FLOORS TO THE ACT 2 SHORTCUT"), line)
	assert_true(line.contains("SHARDS THIS RUN"), line)
	assert_eq(main.death_screen._unlock_bar.value, MetaState.unlock_progress())


func test_shard_pops_stack_under_the_counter() -> void:
	var main := _spawn_floor()
	main._earn(3)
	main._earn(4, "CLOSE CALL")
	var pops: Array = main.shard_label.get_parent().get_children().filter(func(node: Node) -> bool:
		return node is Label and (node as Label).text.begins_with("+"))
	assert_eq(pops.size(), 2)
	var counter_bottom: float = main.shard_label.position.y + main.shard_label.size.y
	for pop: Label in pops:
		assert_true(pop.position.y >= counter_bottom, "a pop never covers the counter (%.0f < %.0f)" % [pop.position.y, counter_bottom])
	assert_true(absf(pops[0].position.y - pops[1].position.y) >= (pops[0] as Label).size.y, "two at once stack, not overlap")


func test_blackout_kills_the_ceiling_lights() -> void:
	var plain := _spawn_floor([], 2)
	var main := _spawn_floor(["blackout"], 2)
	assert_gt(plain.world_lights.size(), 0)
	assert_eq(main.world_lights.size(), 0, "no ceiling light anywhere")
	assert_eq(main.light_material.emission, Color.BLACK, "the fixtures hang dead")


func test_fog_circles_and_clock_follow_the_cards() -> void:
	var plain := _spawn_floor([], 32)
	var main := _spawn_floor(["thick_fog", "safe_haven", "tight_clock"], 32)
	assert_true(is_equal_approx(main.env.fog_density, plain.env.fog_density * 1.8), "thick fog")
	assert_eq(main.circles.cells.size(), plain.circles.cells.size() * 2, "safe haven: twice the circles")
	assert_true(is_equal_approx(main.circles.capacity, plain.circles.capacity * 0.5), "draining twice as fast")
	assert_true(main.time_left < plain.time_left, "tight clock")


func test_cracked_earth_and_short_fuse() -> void:
	var plain := _spawn_floor([], 12)
	var main := _spawn_floor(["cracked_earth", "short_fuse"], 12)
	assert_gt(main.traps.cells.size(), plain.traps.cells.size(), "more cracked floors")
	assert_gt(main.trap_nodes[0].cue, plain.trap_nodes[0].cue, "and they glow")
	assert_true(main.flip.next_forced_in < plain.flip.next_forced_in, "Flipping Time comes sooner")
	assert_true(main.flip.forced_interval_max < plain.flip.forced_interval_max)


func test_the_sanctuary_is_small_and_nothing_hunts_you() -> void:
	var main := _spawn_floor(["sanctuary"], 5)
	assert_true(main.layout.size < StageRule.for_floor(5).rooms * 2 + 1, "a smaller floor")
	main.elapsed = 999.0
	main.player_cell = main.layout.exit
	main._tick_devil(0.1)
	assert_false(main.devil_active or main.devil_spawning, "nothing hunts you here")


func test_the_ritual_gate_needs_five_keys() -> void:
	var main := _spawn_floor(["ritual"], 20)
	assert_eq(main.layout.sigils.size(), 5)
	assert_eq(main.key_hud.slots.size(), 5)
	assert_eq(main.chest.lock_count(), 5, "a lock for every key")


func test_first_blood_wakes_it_from_the_start() -> void:
	var main := _spawn_floor(["first_blood"], 10)
	assert_true(main.devil_active, "awake from the start")
	assert_true(main._devil_distance() >= FloorLayout.MIN_DEVIL_DISTANCE, "but far away")


func test_hunt_doubles_shards_and_its_chest_is_rare() -> void:
	var main := _spawn_floor(["hunt", "thick_fog", "safe_haven"], 3)
	main._earn(4)
	assert_eq(main.floor_shards, 8, "double shards")
	main._on_chest_opened()
	assert_eq(main.floor_shards, 8 + MetaState.RARE_SHARDS * 2, "a rare chest, doubled")


func test_vault_hides_chests_down_dead_ends_that_pay() -> void:
	var main := _spawn_floor(["vault", "thick_fog"], 3)
	assert_eq(main.layout.sigils.size(), FloorLayout.SIGIL_COUNT + 1, "one more key")
	assert_eq(main.bonus_chests.size(), 2, "two chests down dead ends")
	var cell: Vector2i = main.bonus_chests.keys()[0]
	main._enter_cell(cell)
	assert_eq(main.bonus_chests.size(), 1, "it opens as you reach it")
	assert_eq(main.floor_shards, MetaState.chest_roll(hash([main.seed_value, cell]))["shards"])


func test_shrine_pays_less() -> void:
	var main := _spawn_floor(["shrine"], 3)
	main._earn(4)
	assert_eq(main.floor_shards, 3, "three quarters (its omen pick comes after: RunState)")


func test_omens_reach_the_systems_they_change() -> void:
	var plain := _spawn_floor([], 12)
	var main := _spawn_floor(["quick_veil", "twin_flip", "cold_blood", "borrowed_time", "night_owl", "feather_step",
			"keen_eye", "cartographer", "locksmith"], 12)
	assert_true(main.flip.cooldown < plain.flip.cooldown, "Quick Veil")
	assert_eq(main.flip.charges_left, 2, "Twin Flip")
	assert_eq(main.heartbeat_tiles, plain.heartbeat_tiles + 3, "Cold Blood")
	assert_true(is_equal_approx(main.time_left, plain.time_left + 20.0), "Borrowed Time: more clock")
	assert_true(main.devil_delay < plain.devil_delay, "and it wakes sooner")
	main._apply_world(NIGHTMARE)
	plain._apply_world(NIGHTMARE)
	assert_true(is_equal_approx(main.env.fog_density, plain.env.fog_density * 0.7), "Night Owl")
	assert_eq(main.traps.holds, 1, "Feather Step")
	assert_eq(main.traps.creak_range, 2, "Keen Eye")
	assert_gt(main.trap_nodes[0].cue, plain.trap_nodes[0].cue, "Keen Eye: brighter cracks")
	assert_eq(main.minimap.crack_reveal, 6, "Cartographer")
	assert_eq(main.bonus_chests.size(), plain.bonus_chests.size() + 1, "Locksmith")


func test_ghost_sight_shows_the_other_worlds_walls_as_glass() -> void:
	var main := _spawn_floor(["ghost_sight"], 2)
	assert_true(main.nightmare_walls.visible, "NIGHTMARE's walls show in WAKE")
	assert_eq(_wall_mesh(main.nightmare_walls).material_override, main.ghost_material)
	assert_ne(_wall_mesh(main.wake_walls).material_override, main.ghost_material)
	main._apply_world(NIGHTMARE)
	assert_eq(_wall_mesh(main.wake_walls).material_override, main.ghost_material, "and the other way round")
	assert_ne(_wall_mesh(main.nightmare_walls).material_override, main.ghost_material)
	assert_eq(main.player.collision_mask, main.LAYER_SHARED | main.LAYER_NIGHTMARE, "you still only bump into your own world")


func test_last_breath_turns_one_catch_a_floor_into_a_trip_back() -> void:
	var main := _spawn_floor(["last_breath"], 2)
	main._wake_devil()
	for attempt in 2:
		main.catch_grace = 0.0
		main.devil_retreating = false
		main.devil_cell = main.player_cell
		main.devil.position = main._devil_world_position()
		main._process(0.05)
		_run(main, 0.5)
		if attempt == 0:
			assert_eq(main.game_state, "playing", "the first catch sends you back")
			assert_eq(main.player_cell, main.layout.spawn, "to your last circle (the start, before any)")
			assert_eq(main.floor_revives, 0, "free: it costs no revive and no grade")
	assert_eq(main.game_state, "lost", "once a floor")


func test_mirror_night_mirrors_controls_in_nightmare_only() -> void:
	var main := _spawn_floor(["mirror_night"], 22)
	Input.action_press("move_forward")
	var wake: Vector2 = main._move_input()
	main._apply_world(NIGHTMARE)
	var nightmare: Vector2 = main._move_input()
	Input.action_release("move_forward")
	assert_true(wake.y < 0.0, "WAKE plays normally")
	assert_eq(nightmare, -wake, "NIGHTMARE is mirrored")


func test_static_and_deaf_night_take_the_map_and_the_music() -> void:
	var main := _spawn_floor(["static", "deaf_night"], 22)
	assert_false(main.minimap.visible, "no map")
	assert_true(main.calm_player.volume_db <= -60.0, "no music")


func test_relentless_keeps_its_nightmare_pace_in_wake() -> void:
	var main := _spawn_floor(["relentless"], 42)
	main._wake_devil()
	main._apply_world(WAKE)
	var wake: float = main._devil_step_interval()
	main._apply_world(NIGHTMARE)
	assert_eq(main._devil_step_interval(), wake)


func test_each_act_tints_wake_but_nightmare_stays_red() -> void:
	var act1 := _spawn_floor([], 2)
	var act3 := _spawn_floor([], 22)
	assert_eq(act1.fog_colors[WAKE], act1.FOG_COLORS[WAKE], "Act 1 keeps the original look")
	assert_ne(act3.fog_colors[WAKE], act1.fog_colors[WAKE], "Act 3 has its own")
	assert_eq(act3.fog_colors[NIGHTMARE], act1.fog_colors[NIGHTMARE], "NIGHTMARE always reads red")


func test_a_floor_shows_its_cards_as_it_starts() -> void:
	var main := _spawn_floor(["vault", "thick_fog"], 3)
	assert_true(main.card_choice.visible)
	assert_eq(main.card_choice._ids, ["vault", "thick_fog"])
	var calm := _spawn_floor([], 1)
	assert_false(calm.card_choice.visible, "no cards, nothing to show")


func test_a_chest_find_waits_to_be_banked_with_the_floor() -> void:
	var main := _spawn_floor()
	main._pay_chest({"kind": "omen", "shards": 0})
	assert_eq(main.floor_finds, ["omen"], "kept with the floor's shards: a quit before the floor ends replays it")


# --- plans/06 P5: the meta hub reaches the floor ------------------------------------------------

func test_a_floor_counts_what_you_did_for_the_challenges() -> void:
	var main := _spawn_floor()
	main._wake_devil()
	for i in main.layout.sigils.size():
		main._apply_world(main.layout.sigil_worlds[i])
		main.player_cell = main.layout.sigils[i]
		main._collect_sigils()
	main._pay_chest({"kind": "shards", "shards": 5})
	main._close_call("CLOSE CALL")
	main._close_call("PHASE DODGE")
	Engine.time_scale = 1.0
	main._on_flipped(NIGHTMARE, true)
	main._enter_cell(main.circles.cells[0])
	main._lose_game("trap")
	var counts: Dictionary = main.floor_stats
	assert_eq(counts.get("devil_wakes"), 1)
	assert_eq(counts.get("sigils"), main.layout.sigils.size())
	assert_eq(counts.get("chests"), 1)
	assert_eq(counts.get("close_calls"), 1)
	assert_eq(counts.get("phase_dodges"), 1)
	assert_eq(counts.get("devil_escapes"), 2, "the bestiary's 'you got away'")
	assert_eq(counts.get("flips"), 1)
	assert_eq(counts.get("forced_flips"), 1)
	assert_eq(counts.get("circles"), 1)
	assert_eq(counts.get("deaths"), 1)
	assert_eq(counts.get("deaths_trap"), 1)


func test_clearing_the_sanctuary_counts_the_floor_and_leaves_a_note() -> void:
	var main := _spawn_floor([], 5)
	assert_true(main.rule.is_sanctuary)
	main._win_game()
	assert_eq(main.floor_stats.get("floors"), 1)
	assert_true(main.floor_finds.has("note"), "its lore note, banked with the floor")


func test_a_gate_plays_its_ending_the_first_time_only() -> void:
	var stats: Dictionary = MetaState.stats
	var start := RunState.start_floor
	MetaState.stats = {}
	var gate := _spawn_floor([], 10)
	assert_eq(gate._gate_ending(), Lore.ACT_ENDINGS[0], "first clear of Act 1")
	MetaState.stats = {"clears_act_1": 1}
	assert_eq(gate._gate_ending(), "", "seen it")
	RunState.start_floor = 1
	var last := _spawn_floor([], StageRule.LAST_FLOOR)
	assert_eq(last._gate_ending(), Lore.TRUE_ENDING, "floor 1 to 50 in one run")
	RunState.start_floor = 41
	assert_eq(last._gate_ending(), Lore.ACT_ENDINGS[4])
	MetaState.stats = stats
	RunState.start_floor = start


func test_an_ending_waits_for_you_to_carry_on() -> void:
	var main := _spawn_floor([], 10)
	main._show_ending("THE END OF ACT I", Lore.ACT_ENDINGS[0])
	var ending: Control = main.get_node("Overlays/Ending")
	var texts := ending.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_true(texts.has(Lore.ACT_ENDINGS[0]), str(texts))
	assert_true(texts.has("THE END OF ACT I"))
	assert_true(ending.find_child("CarryOn", true, false) is Button)


func test_the_voice_speaks_on_the_death_screen() -> void:
	var main := _spawn_floor([], 3)
	main._lose_game("devil")
	var line := Lore.voice("devil", MetaState.stat("deaths"), clampf(main._progress(), 0.0, 1.0), main.rule.floor_in_act)
	assert_true(main.death_screen._detail.text.ends_with(line), main.death_screen._detail.text)


func test_worn_gear_shapes_the_flashlight_and_the_flip() -> void:
	MetaState.unlocked.assign(["lantern", "ember_light", "gold_flash"])
	MetaState.equipped = {"torch": "lantern", "light": "ember_light", "flash": "gold_flash"}
	var main := _spawn_floor()
	MetaState.unlocked.clear()
	MetaState.equipped = {}
	assert_eq(main.flashlight.light_color, Unlocks.item("ember_light")["color"])
	assert_true(is_equal_approx(main.flashlight.spot_angle, main.feel.flashlight_angle * Cards.find("lantern")["mods"]["beam_angle"]))
	assert_true(main.flashlight.spot_range < main.feel.flashlight_range, "the Lantern trades reach for width")
	main._on_flipped(NIGHTMARE, false)
	var flash: Color = main.flash_rect.color
	assert_eq(Color(flash, 1.0), Color(Unlocks.item("gold_flash")["color"], 1.0), "the flip flashes gold")


func test_the_camera_flash_freezes_it_once_a_floor() -> void:
	MetaState.unlocked.assign(["camera_flash"])
	MetaState.equipped = {"torch": "camera_flash"}
	var main := _spawn_floor()
	MetaState.unlocked.clear()
	MetaState.equipped = {}
	main._wake_devil()
	main._apply_world(NIGHTMARE)
	main.catch_grace = 0.0
	main.devil_cell = main.player_cell
	main.devil.position = main._devil_world_position() + Vector3(0.5, 0, 0)  # mid-glide
	var press := InputEventAction.new()
	press.action = "flashlight"
	press.pressed = true
	main._unhandled_input(press)
	assert_eq(main.flash_stuns, 0, "once a floor")
	assert_true(main.flashlight_on, "the flash isn't the light switch")
	var frozen_at: Vector3 = main.devil.position
	main._process(0.05)
	assert_eq(main.lunge_left, 0.0, "frozen: no grab")
	assert_eq(main.devil.position, frozen_at, "not even a step")
	main.devil_stun = 0.0
	main._process(0.05)
	assert_gt(main.lunge_left, 0.0, "and then it moves again")
	main._unhandled_input(press)
	assert_false(main.flashlight_on, "spent: F is the light switch again")


# --- Delivered art (assets/ASSET_PROMPTS.md): checked wherever the file exists (art is git-ignored) ---------------

func test_delivered_art_dresses_the_maze_in_each_world() -> void:
	if not ResourceLoader.exists(Art.WORLD + "wake_wall_albedo.jpg"):
		return
	var main := _spawn_floor()
	assert_ne(main.floor_material.albedo_texture, null, "a stone floor")
	assert_true(main.shared_wall_material.albedo_texture.resource_path.contains("wake_wall"))
	var wake_floor: Texture2D = main.floor_material.albedo_texture
	main._apply_world(NIGHTMARE)
	assert_ne(main.floor_material.albedo_texture, wake_floor, "NIGHTMARE has its own floor")
	assert_true(main.shared_wall_material.albedo_texture.resource_path.contains("nightmare_wall"), "walls both worlds share change too")
	assert_true(main.ceiling_material.albedo_texture.resource_path.contains("nightmare_ceiling"))


func test_delivered_decals_replace_the_neon() -> void:
	if not ResourceLoader.exists(Art.DECALS + "safe_circle.png"):
		return
	var main := _spawn_floor()
	var circle: MeshInstance3D = main.find_children("SafeCircle*", "MeshInstance3D", true, false)[0]
	assert_true(circle.mesh is PlaneMesh, "the rune circle, not the neon torus")
	var full: Color = main.circle_materials[0].albedo_color
	main.circles.charge[0] = 0.0
	main._refresh_circles()
	assert_true(main.circle_materials[0].albedo_color.v < full.v, "a drained circle dims")
	assert_ne(main.find_child("ExitCircle", true, false), null)
	var dressing: Node3D = main.find_child("Dressing", true, false)
	assert_false(dressing.visible, "blood and scratches only in NIGHTMARE")
	main._apply_world(NIGHTMARE)
	assert_true(dressing.visible)


func test_delivered_models_furnish_the_floor() -> void:
	if Art.model("chest") == null:
		return
	var main := _spawn_floor()
	assert_true(main.has_node("Lamps"), "lamps hang where the light boxes were")
	assert_true(main.chest.has_node("Model"), "the chest model")
	assert_eq(main.chest.lid.name, "Lid", "its own lid swings open")
	assert_eq(main.sigil_nodes[0]._key.get_child(0).scene_file_path, Art.MODELS + "key.glb")
	var gate := _spawn_floor([], StageRule.GATE_FLOOR)
	assert_true(gate.has_node("ExitPortal/GateArch"), "the Gate stands behind the chest on floor 10")
	var sanctuary := _spawn_floor([], StageRule.SANCTUARY_FLOOR)
	assert_true(sanctuary.has_node("Altar"), "the Sanctuary keeps an altar down a dead end")


func test_delivered_cracks_and_fx_show_on_the_traps() -> void:
	if not ResourceLoader.exists(Art.DECALS + "crack_glow.png"):
		return
	var main := _spawn_floor(["cracked_earth"], 12)
	var pit: TrapPit = main.trap_nodes[0]
	assert_true(pit.get_node("Hairline").visible, "a weak tile shows hairline cracks")
	assert_false(pit.get_node("CrackGlow").visible)
	pit.show_state(TrapField.State.CRACKED)
	assert_true(pit.get_node("CrackGlow").visible, "cracked: molten light in the seams")
	assert_false(pit.get_node("Hairline").visible)
	assert_true((pit._dust.mesh as QuadMesh) != null, "dust puffs, not cubes")


func test_delivered_hud_art_frames_the_screen() -> void:
	if not ResourceLoader.exists(Art.HUD + "hud_plate.png"):
		return
	var main := _spawn_floor()
	assert_true(main.has_node("HUD/Plate") and main.has_node("HUD/MinimapFrame"))
	assert_true(main.status_label.get_theme_font("font").resource_path.ends_with("ui.ttf"), "the HUD speaks Oswald")
	main._show_message("FLOOR 1")
	assert_true(main.get_node("HUD/Banner").visible, "smoke behind a message")
	main._show_message("")
	assert_false(main.get_node("HUD/Banner").visible)
	assert_false(main.get_node("HUD/NightmareOverlay").visible)
	main._apply_world(NIGHTMARE)
	assert_true(main.get_node("HUD/NightmareOverlay").visible)
	main._on_flipping_time_warning()
	assert_true(main.get_node("HUD/WarningOverlay").visible)
	assert_gt(main.get_node("HUD/Hints").get_child_count(), 5, "keycaps for the controls")


# --- plans/06 P6: the Daily on the floor -----------------------------------------------------------------------

## A Daily floor in practice (nothing banked, nothing saved), `daily_floor` of today's five.
func _spawn_daily(daily_floor := 1) -> Node3D:
	MetaState.profile_path = "user://test_profile.cfg"
	RunState.save_path = "user://test_run_state.cfg"
	RunState.mode = "practice"
	RunState.daily_date = Daily.today()
	RunState.daily_floor = daily_floor
	return _spawn_floor(Daily.cards(Daily.today(), daily_floor), Daily.STAGE_FLOORS[daily_floor - 1])


func test_a_daily_floor_names_itself() -> void:
	var main := _spawn_daily(2)
	var daily := "DAILY #%d" % Daily.number(Daily.today())
	assert_true(main._floor_title().begins_with(daily + "  ·  FLOOR 2 / %d" % Daily.FLOORS), main._floor_title())
	assert_true(main._floor_title().contains("PRACTICE"), "practice says so")
	main._update_hud()
	assert_true(main.status_label.text.begins_with(daily), main.status_label.text)


func test_practice_banks_nothing() -> void:
	var main := _spawn_daily()
	main.fixed_seed = 0
	main._earn(10, "CLOSE CALL")
	assert_eq(main.floor_shards, 0, "practice pays nothing: the same maze again would be a farm")
	main._count("floors")
	main._bank()
	assert_eq(main.floor_stats.get("floors"), 1, "and banks nothing")


func test_dying_in_the_daily_offers_its_result_and_practice() -> void:
	Daily.result.assign(["s"])
	Daily.result_time = 60.0
	var main := _spawn_daily(2)
	RunState.mode = "daily"
	main._lose_game("devil")
	assert_true(main.death_screen._retry_sub.text.begins_with("PRACTICE"), main.death_screen._retry_sub.text)
	assert_true(main.death_screen._revive.disabled, "one life in the Daily")
	assert_true(main.death_screen._share.visible, "the ranked result, ready to copy")
	assert_eq(main.death_screen._share_text, Daily.share_text(Daily.today(), Daily.result, Daily.result_time))
	var detail: String = main.death_screen._detail.text
	assert_true(detail.contains("Daily #%d, floor 2 / %d" % [Daily.number(Daily.today()), Daily.FLOORS]), detail)
	assert_false(detail.contains("Act "), "a Daily isn't an act")
	Daily.result.clear()
	Daily.result_time = 0.0


func test_the_last_daily_floor_ends_on_its_result() -> void:
	var main := _spawn_daily(Daily.FLOORS)
	RunState.mode = "daily"
	main._finish_daily()
	var page: Node = main.get_node("Overlays/Ending")
	var copy: Button = page.find_child("CopyResult", true, false)
	assert_ne(copy, null, "a ranked Daily ends with its result to copy")
	copy.pressed.emit()
	assert_eq(copy.text, "COPIED", "pasted anywhere: Discord, X, a group chat")


# --- plans/06 P7: the Devil's senses and the Director on the floor ---------------------------------------------------

## You walk `steps` cells along the route; the Devil wakes at its far spawn, sensing nothing.
func _stalked_floor(steps := 4) -> Node3D:
	var main := _spawn_floor()
	main._apply_world(NIGHTMARE)
	for i in steps:
		main._enter_cell(main.route[i + 1])
	main._wake_devil()
	main.devil_cell = main.layout.devil_spawn
	main.devil.position = main._devil_world_position()
	return main


func test_the_devil_no_longer_knows_where_you_are() -> void:
	var main := _stalked_floor()
	main._tick_devil(0.1)
	assert_eq(main.brain.mode(), "patrol", "nothing seen, nothing heard")
	assert_ne(main._devil_goal(), main.player_cell, "it follows your scent, not you")
	main.brain.sense(true, false, 0.0)
	assert_eq(main._devil_goal(), main.player_cell, "once it senses you, straight at you")


func test_a_sprint_is_heard_down_the_corridors_unless_soft_soles() -> void:
	var main := _stalked_floor()
	main.devil_cell = _cell_at_distance(main, 4)
	main._play_footstep(false)
	assert_eq(main.brain.mode(), "patrol", "a walk carries %d cells" % DevilBrain.NOISE_WALK)
	main._play_footstep(true)
	assert_eq(main.brain.mode(), "chase", "a sprint carries %d" % DevilBrain.HEAR_SPRINT_TILES)
	var soft := _stalked_floor()
	soft.quiet_sprint = true
	soft.devil_cell = _cell_at_distance(soft, 4)
	soft._play_footstep(true)
	assert_eq(soft.brain.mode(), "patrol", "Soft Soles: a sprint is as quiet as a walk")


func test_echo_step_sends_it_after_an_echo() -> void:
	var main := _stalked_floor()
	main.devil_cell = _cell_at_distance(main, 3)
	main._on_flipped(NIGHTMARE, false)
	assert_eq(main.brain.mode(), "chase", "it heard where you flipped")
	var echo := _stalked_floor()
	echo.flip_echo = true
	echo.devil_cell = _cell_at_distance(echo, 3)
	echo.brain.sense(true, false, 0.0)
	echo._on_flipped(NIGHTMARE, false)
	assert_eq(echo.brain.mode(), "investigate", "it goes after the echo instead of you")
	assert_ne(echo.brain.interest, echo.player_cell)


func test_a_chase_only_runs_flat_out_at_the_peak() -> void:
	var main := _stalked_floor()
	main.devil_cell = _cell_at_distance(main, 12)
	main.brain.sense(true, false, 0.0)
	var calm: float = main._devil_step_interval()
	assert_true(calm >= main.CELL_SIZE / DevilBrain.CALM_SPEEDS["chase"] - 0.001, "before the peak it only closes in")
	main.director.phase = Director.Phase.PEAK
	assert_true(main._devil_step_interval() < calm, "at the peak it runs")


func test_relief_pulls_it_back_and_a_build_hint_points_near_you() -> void:
	var main := _stalked_floor()
	main.director.phase = Director.Phase.PEAK
	main.director.menace = 100.0
	main.director._clock = Director.PEAK_LIMIT
	main._tick_devil(0.1)
	assert_eq(main.director.phase, Director.Phase.RELAX)
	assert_true(main.devil_retreating, "the peak is over: it backs off")
	var built := _stalked_floor()
	built.director._clock = Director.CALM_LIMIT
	built._tick_devil(0.1)
	assert_eq(built.director.phase, Director.Phase.BUILD)
	assert_eq(built.brain.mode(), "investigate", "a fuzzy hint")
	var gap: int = built.player_dist[built.brain.interest.y * built.layout.size + built.brain.interest.x]
	assert_true(gap >= 0 and gap <= Director.HINT_RADIUS, "within %d cells of you: %d" % [Director.HINT_RADIUS, gap])


func test_your_beam_gives_you_away_unless_lantern_heart() -> void:
	var main := _stalked_floor()
	var spot := _straight_line(main, 3)
	if spot.is_empty():
		return
	main.player_cell = spot[0]
	main.player.global_position = main.cell_to_world(spot[0]) + Vector3(0, main.PLAYER_HEIGHT, 0)
	main.devil_cell = spot[3]
	main.devil.position = main._devil_world_position()
	main.devil_facing = spot[3] - spot[2]  # walking away: you're behind it
	var to_devil: Vector3 = main.cell_to_world(spot[3]) - main.cell_to_world(spot[0])
	main.yaw = atan2(-to_devil.x, -to_devil.z)
	main.player.rotation.y = main.yaw
	main.flashlight_on = true
	assert_true(main._devil_sees(), "your beam on its back")
	main.flashlight_on = false
	assert_false(main._devil_sees(), "dark: it walks on")
	main.flashlight_on = true
	main.beam_hidden = true
	assert_false(main._devil_sees(), "Lantern Heart: the beam never gives you away")


func test_mercy_adds_a_circle_to_the_floor_that_keeps_killing_you() -> void:
	var plain := _spawn_floor([], 2)
	MetaState.deaths_at = {2: MetaState.MERCY_DEATHS}
	var kind := _spawn_floor([], 2)
	MetaState.deaths_at = {}
	assert_eq(kind.circles.cells.size(), plain.circles.cells.size() + 1, "one more safe circle")
	assert_true(kind.devil_speed < plain.devil_speed, "a slower Devil")
	assert_true(kind.director.hint_stretch > plain.director.hint_stretch, "fewer hints")


## Open cells in a straight line `length` long from some cell, in the current world (empty if none).
func _straight_line(main: Node3D, length: int) -> Array[Vector2i]:
	for i in main.layout.size * main.layout.size:
		var cell: Vector2i = main.layout.cell_at(i)
		for d: Vector2i in FloorLayout.DIRS:
			var line: Array[Vector2i] = []
			for k in length + 1:
				if not main.layout.is_open(main.world, cell + d * k):
					break
				line.append(cell + d * k)
			if line.size() == length + 1:
				return line
	return []


## A cell exactly `gap` path tiles from you in the current world, out of your line of sight.
func _cell_at_distance(main: Node3D, gap: int) -> Vector2i:
	for i in main.player_dist.size():
		var cell: Vector2i = main.layout.cell_at(i)
		if main.player_dist[i] == gap and not DevilBrain.line_of_sight(main.layout, main.world, cell, main.player_cell):
			return cell
	for i in main.player_dist.size():
		if main.player_dist[i] == gap:
			return main.layout.cell_at(i)
	return main.player_cell


func test_the_devil_cam_replays_the_catch_from_its_eyes() -> void:
	var main := _stalked_floor()
	for i in roundi(main.TAPE_SECONDS / main.TAPE_STEP) + 10:
		main.devil.position += Vector3(0.05, 0, 0)  # it closes in
		main._record_tape(main.TAPE_STEP)
	assert_eq(main.tape.size(), roundi(main.TAPE_SECONDS / main.TAPE_STEP), "only the last %.0f s are kept" % main.TAPE_SECONDS)
	main._lose_game("devil")
	var view: SubViewportContainer = main.death_screen.get_node_or_null("DevilCam")
	assert_ne(view, null, "caught: the last seconds from its eyes")
	var sub := view.get_child(0) as SubViewport
	assert_eq(sub.world_3d, main.get_viewport().find_world_3d(), "the same maze, seen from elsewhere")
	var eye := sub.get_child(0) as Camera3D
	assert_eq(eye.cull_mask & main.DEVIL_LAYER, 0, "it doesn't see the inside of its own head")
	assert_true(eye.environment != null and eye.environment.ambient_light_energy > main.env.ambient_light_energy, "it sees in the dark")
	assert_false(main.get_node("HUD").visible, "the death screen stands alone")
	var start: Vector3 = eye.global_position
	main._process(1.0)
	assert_ne(eye.global_position, start, "the replay moves")
	main._stop_devil_cam()
	assert_eq(main.death_screen.get_node_or_null("DevilCam"), null)
	assert_eq(main.devil.position, main._devil_world_position(), "the Devil is back where it stands")
	var fallen := _stalked_floor()
	for i in 20:
		fallen._record_tape(fallen.TAPE_STEP)
	fallen._lose_game("trap")
	assert_eq(fallen.death_screen.get_node_or_null("DevilCam"), null, "only the Devil gets a camera")

