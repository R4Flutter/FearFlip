extends Node3D

const CELL_SIZE := 2.4
const WALL_HEIGHT := 2.8
const PLAYER_HEIGHT := 1.7
const PLAYER_SPEED := 4.2
const DEVIL_STEP_INTERVAL := 0.7
const CEILING_HEIGHT := 3.0
const WALL_TRIM_HEIGHT := 0.12
const LIGHT_INTERVAL := 3
const TRAP_CELLS := [Vector2i(5, 1), Vector2i(3, 3), Vector2i(7, 5), Vector2i(9, 7)]
const SAFE_ZONE_CELLS := [Vector2i(1, 7), Vector2i(11, 9)]

const MAZE: Array[String] = [
    "1111111111111",
    "1000001000001",
    "1011101011101",
    "1010001000101",
    "1010111110101",
    "1010000010101",
    "1011111010101",
    "1000001010001",
    "1111101011111",
    "1000101000001",
    "1010101111101",
    "1000000000001",
    "1111111111111"
]

var player: CharacterBody3D
var camera_pivot: Node3D
var devil: Node3D
var goal: Node3D
var minimap: Control
var player_cell := Vector2i(1, 1)
var devil_cell := Vector2i(11, 1)
var goal_cell := Vector2i(11, 11)
var explored: Dictionary = {}
var devil_timer := 0.0
var mouse_sensitivity := 0.0025
var pitch := 0.0
var yaw := 0.0

func _ready() -> void:
    _build_environment()
    _build_audio()
    _build_maze()
    _build_player()
    _build_goal()
    _build_devil()
    _build_hud()
    explored[player_cell] = true
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
    devil_timer += delta
    if devil_timer >= DEVIL_STEP_INTERVAL:
        devil_timer = 0.0
        _move_devil_one_cell()
    _update_markers()
    if player_cell == goal_cell:
        _show_message("EXIT FOUND - STAGE CLEAR")

func _physics_process(delta: float) -> void:
    if player == null:
        return
    var input := Vector2.ZERO
    input.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    input.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    input = input.normalized()
    var direction := (player.transform.basis * Vector3(input.x, 0, input.y)).normalized()
    if direction.length() > 0.0:
        player.velocity.x = direction.x * PLAYER_SPEED
        player.velocity.z = direction.z * PLAYER_SPEED
    else:
        player.velocity.x = move_toward(player.velocity.x, 0.0, PLAYER_SPEED * 8.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, PLAYER_SPEED * 8.0 * delta)
    player.velocity.y = 0.0
    player.move_and_slide()
    _update_player_cell()

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * mouse_sensitivity
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
        player.rotation.y = yaw
        camera_pivot.rotation.x = pitch
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _build_environment() -> void:
    var environment := WorldEnvironment.new()
    var settings := Environment.new()
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = Color(0.003, 0.005, 0.01)
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color(0.025, 0.04, 0.07)
    settings.ambient_light_energy = 0.45
    settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    settings.glow_enabled = true
    environment.environment = settings
    add_child(environment)

    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-55, -25, 0)
    moon.light_color = Color(0.25, 0.35, 0.55)
    moon.light_energy = 0.25
    add_child(moon)

func _build_audio() -> void:
    var ambience := AudioStreamPlayer.new()
    ambience.name = "WorldAmbience"
    ambience.stream = load("res://assets/audio/background_audio.mp3")
    ambience.volume_db = -18.0
    ambience.autoplay = true
    add_child(ambience)

func _build_maze() -> void:
    var floor := MeshInstance3D.new()
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(MAZE[0].length() * CELL_SIZE, 0.15, MAZE.size() * CELL_SIZE)
    floor.mesh = floor_mesh
    floor.position = Vector3((MAZE[0].length() - 1) * CELL_SIZE * 0.5, -0.08, (MAZE.size() - 1) * CELL_SIZE * 0.5)
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.025, 0.035, 0.05)
    floor_material.roughness = 0.9
    floor.material_override = floor_material
    add_child(floor)

    var ceiling := MeshInstance3D.new()
    var ceiling_mesh := BoxMesh.new()
    ceiling_mesh.size = Vector3(MAZE[0].length() * CELL_SIZE, 0.18, MAZE.size() * CELL_SIZE)
    ceiling.mesh = ceiling_mesh
    ceiling.position = Vector3((MAZE[0].length() - 1) * CELL_SIZE * 0.5, CEILING_HEIGHT, (MAZE.size() - 1) * CELL_SIZE * 0.5)
    var ceiling_material := StandardMaterial3D.new()
    ceiling_material.albedo_color = Color(0.008, 0.012, 0.02)
    ceiling_material.roughness = 1.0
    ceiling.material_override = ceiling_material
    add_child(ceiling)

    for y in MAZE.size():
        for x in MAZE[y].length():
            if MAZE[y][x] == "1":
                _create_wall(Vector2i(x, y))
            elif (x + y) % LIGHT_INTERVAL == 0:
                _create_world_light(Vector2i(x, y))

    _create_floor_accents()
    _create_pillars()
    _create_world_props()

func _create_wall(cell: Vector2i) -> void:
    var wall := StaticBody3D.new()
    wall.position = cell_to_world(cell) + Vector3(0, WALL_HEIGHT * 0.5, 0)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
    mesh.mesh = box
    mesh.material_override = _wall_material()
    wall.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box.size
    collision.shape = shape
    wall.add_child(collision)

    var trim := MeshInstance3D.new()
    var trim_mesh := BoxMesh.new()
    trim_mesh.size = Vector3(CELL_SIZE + 0.03, WALL_TRIM_HEIGHT, CELL_SIZE + 0.03)
    trim.mesh = trim_mesh
    trim.position.y = WALL_HEIGHT * 0.5 - WALL_TRIM_HEIGHT * 0.5
    trim.material_override = _trim_material()
    wall.add_child(trim)

    var base_trim := MeshInstance3D.new()
    var base_mesh := BoxMesh.new()
    base_mesh.size = Vector3(CELL_SIZE + 0.04, 0.08, CELL_SIZE + 0.04)
    base_trim.mesh = base_mesh
    base_trim.position.y = -WALL_HEIGHT * 0.5 + 0.04
    base_trim.material_override = _trim_material()
    wall.add_child(base_trim)
    add_child(wall)

func _create_world_light(cell: Vector2i) -> void:
    var fixture := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.5, 0.05, 0.5)
    fixture.mesh = mesh
    fixture.position = cell_to_world(cell) + Vector3(0, CEILING_HEIGHT - 0.12, 0)
    fixture.material_override = _light_material()
    add_child(fixture)

    var light := OmniLight3D.new()
    light.light_color = Color(0.12, 0.32, 0.55)
    light.light_energy = 0.55
    light.omni_range = 4.5
    light.shadow_enabled = true
    light.position = fixture.position
    add_child(light)

func _create_floor_accents() -> void:
    for y in MAZE.size():
        for x in MAZE[y].length():
            if MAZE[y][x] != "0" or (x + y) % 2 != 0:
                continue
            var accent := MeshInstance3D.new()
            var mesh := BoxMesh.new()
            mesh.size = Vector3(CELL_SIZE * 0.72, 0.012, 0.04)
            accent.mesh = mesh
            accent.position = cell_to_world(Vector2i(x, y)) + Vector3(0, 0.015, 0)
            accent.material_override = _floor_accent_material()
            add_child(accent)

func _create_pillars() -> void:
    for cell in [Vector2i(1, 1), Vector2i(11, 1), Vector2i(1, 11), Vector2i(11, 11)]:
        if not is_walkable(cell):
            continue
        var pillar := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.14
        mesh.bottom_radius = 0.18
        mesh.height = 1.2
        pillar.mesh = mesh
        pillar.position = cell_to_world(cell) + Vector3(0, 0.6, 0)
        pillar.material_override = _trim_material()
        add_child(pillar)

func _create_world_props() -> void:
    for cell in TRAP_CELLS:
        if is_walkable(cell):
            _create_trap_pad(cell)
    for cell in SAFE_ZONE_CELLS:
        if is_walkable(cell):
            _create_safe_zone(cell)

func _create_trap_pad(cell: Vector2i) -> void:
    var pad := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.55
    mesh.bottom_radius = 0.55
    mesh.height = 0.035
    pad.mesh = mesh
    pad.position = cell_to_world(cell) + Vector3(0, 0.035, 0)
    pad.material_override = _trap_material()
    add_child(pad)

    var ring := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.45
    ring_mesh.outer_radius = 0.5
    ring.mesh = ring_mesh
    ring.position = pad.position + Vector3(0, 0.035, 0)
    ring.material_override = _trap_material()
    add_child(ring)

    var texture := load("res://assets/images/breaking_trap.png") as Texture2D
    if texture != null:
        var sprite := Sprite3D.new()
        sprite.texture = texture
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        sprite.pixel_size = 0.0025
        sprite.position = pad.position + Vector3(0, 0.12, 0)
        add_child(sprite)

func _create_safe_zone(cell: Vector2i) -> void:
    var zone := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.64
    mesh.bottom_radius = 0.64
    mesh.height = 0.025
    zone.mesh = mesh
    zone.position = cell_to_world(cell) + Vector3(0, 0.025, 0)
    zone.material_override = _safe_zone_material()
    add_child(zone)

func _trap_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.95, 0.07, 0.06)
    material.emission_enabled = true
    material.emission = Color(0.45, 0.01, 0.0)
    material.emission_energy_multiplier = 2.5
    return material

func _safe_zone_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.1, 0.62, 0.85)
    material.emission_enabled = true
    material.emission = Color(0.02, 0.3, 0.5)
    material.emission_energy_multiplier = 2.0
    return material

func _wall_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.038, 0.055, 0.08)
    material.metallic = 0.18
    material.roughness = 0.82
    return material

func _trim_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.08, 0.2, 0.28)
    material.emission_enabled = true
    material.emission = Color(0.015, 0.09, 0.13)
    material.emission_energy_multiplier = 1.5
    material.metallic = 0.4
    material.roughness = 0.4
    return material

func _light_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.2, 0.65, 1.0)
    material.emission_enabled = true
    material.emission = Color(0.1, 0.4, 1.0)
    material.emission_energy_multiplier = 4.0
    return material

func _floor_accent_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.05, 0.18, 0.24)
    material.emission_enabled = true
    material.emission = Color(0.01, 0.08, 0.12)
    material.emission_energy_multiplier = 1.2
    return material

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = cell_to_world(player_cell) + Vector3(0, PLAYER_HEIGHT, 0)
    add_child(player)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.6
    collision.shape = capsule
    collision.position.y = -0.8
    player.add_child(collision)
    camera_pivot = Node3D.new()
    camera_pivot.position.y = 0.45
    player.add_child(camera_pivot)
    var camera := Camera3D.new()
    camera.current = true
    camera.fov = 76.0
    camera_pivot.add_child(camera)
    var flashlight := SpotLight3D.new()
    flashlight.light_color = Color(0.68, 0.82, 1.0)
    flashlight.light_energy = 4.0
    flashlight.spot_range = 14.0
    flashlight.spot_angle = 32.0
    flashlight.shadow_enabled = true
    camera.add_child(flashlight)

func _build_goal() -> void:
    goal = Node3D.new()
    goal.name = "ExitPortal"
    goal.position = cell_to_world(goal_cell)
    add_child(goal)

    var base := MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.72
    base_mesh.bottom_radius = 0.72
    base_mesh.height = 0.08
    base.mesh = base_mesh
    base.position.y = 0.06
    goal.add_child(base)

    var ring := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.48
    ring_mesh.outer_radius = 0.58
    ring_mesh.rings = 32
    ring_mesh.ring_segments = 12
    ring.mesh = ring_mesh
    ring.position.y = 1.0
    ring.rotation_degrees.x = 90
    goal.add_child(ring)

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.1, 1.0, 0.45)
    material.emission_enabled = true
    material.emission = Color(0.03, 0.65, 0.2)
    material.emission_energy_multiplier = 3.0
    base.material_override = material
    ring.material_override = material

    var beam := MeshInstance3D.new()
    var beam_mesh := CylinderMesh.new()
    beam_mesh.top_radius = 0.06
    beam_mesh.bottom_radius = 0.06
    beam_mesh.height = 2.0
    beam.mesh = beam_mesh
    beam.position.y = 1.0
    beam.material_override = material
    goal.add_child(beam)

    var portal_texture := load("res://assets/images/exit_portal.png") as Texture2D
    if portal_texture != null:
        var portal_sprite := Sprite3D.new()
        portal_sprite.texture = portal_texture
        portal_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        portal_sprite.pixel_size = 0.004
        portal_sprite.position = Vector3(0, 1.0, 0)
        goal.add_child(portal_sprite)

    var light := OmniLight3D.new()
    light.light_color = Color(0.1, 1.0, 0.35)
    light.light_energy = 2.5
    light.omni_range = 4.0
    goal.add_child(light)

func _build_devil() -> void:
    devil = Node3D.new()
    devil.name = "Devil"
    devil.position = cell_to_world(devil_cell) + Vector3(0, 0.75, 0)
    add_child(devil)

    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.48
    body_mesh.height = 1.25
    body.mesh = body_mesh
    body.position.y = 0.0
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.8, 0.015, 0.02)
    material.emission_enabled = true
    material.emission = Color(0.38, 0.0, 0.0)
    material.emission_energy_multiplier = 2.0
    body.material_override = material
    devil.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.38
    head_mesh.height = 0.72
    head.mesh = head_mesh
    head.position = Vector3(0, 0.82, -0.05)
    head.material_override = material
    devil.add_child(head)

    for side in [-1.0, 1.0]:
        var eye := MeshInstance3D.new()
        var eye_mesh := SphereMesh.new()
        eye_mesh.radius = 0.055
        eye_mesh.height = 0.11
        eye.mesh = eye_mesh
        eye.position = Vector3(0.14 * side, 0.88, -0.37)
        var eye_material := StandardMaterial3D.new()
        eye_material.albedo_color = Color(1.0, 0.4, 0.05)
        eye_material.emission_enabled = true
        eye_material.emission = Color(1.0, 0.12, 0.0)
        eye_material.emission_energy_multiplier = 8.0
        eye.material_override = eye_material
        devil.add_child(eye)

    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.02, 0.02)
    light.light_energy = 1.2
    light.omni_range = 3.0
    devil.add_child(light)

func _build_hud() -> void:
    var hud := CanvasLayer.new()
    hud.name = "HUD"
    add_child(hud)
    var minimap_script = preload("res://scripts/minimap.gd")
    minimap = minimap_script.new()
    minimap.position = Vector2(20, 20)
    minimap.maze = MAZE
    hud.add_child(minimap)
    var label := Label.new()
    label.name = "Hint"
    label.text = "WASD  MOVE     MOUSE  LOOK     ESC  RELEASE MOUSE"
    label.position = Vector2(24, 690)
    label.add_theme_color_override("font_color", Color(0.55, 0.7, 0.82, 0.8))
    hud.add_child(label)

func _update_player_cell() -> void:
    var candidate := world_to_cell(player.global_position)
    if candidate != player_cell and is_walkable(candidate):
        player_cell = candidate
        explored[player_cell] = true

func _move_devil_one_cell() -> void:
    var options := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    var best := devil_cell
    var best_distance := _manhattan(devil_cell, player_cell)
    for direction in options:
        var candidate: Vector2i = devil_cell + direction
        if is_walkable(candidate):
            var distance := _manhattan(candidate, player_cell)
            if distance < best_distance:
                best = candidate
                best_distance = distance
    devil_cell = best
    devil.position = cell_to_world(devil_cell) + Vector3(0, 0.75, 0)

func _update_markers() -> void:
    if minimap == null:
        return
    minimap.player_cell = player_cell
    minimap.devil_cell = devil_cell
    minimap.goal_cell = goal_cell
    minimap.explored = explored

func _show_message(text: String) -> void:
    var label := get_node_or_null("HUD/Message") as Label
    if label == null:
        label = Label.new()
        label.name = "Message"
        label.position = Vector2(480, 120)
        label.add_theme_font_size_override("font_size", 30)
        label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
        $HUD.add_child(label)
    label.text = text

func cell_to_world(cell: Vector2i) -> Vector3:
    return Vector3(cell.x * CELL_SIZE, 0, cell.y * CELL_SIZE)

func world_to_cell(position: Vector3) -> Vector2i:
    return Vector2i(round(position.x / CELL_SIZE), round(position.z / CELL_SIZE))

func is_walkable(cell: Vector2i) -> bool:
    return cell.y >= 0 and cell.y < MAZE.size() and cell.x >= 0 and cell.x < MAZE[cell.y].length() and MAZE[cell.y][cell.x] == "0"

func _manhattan(a: Vector2i, b: Vector2i) -> int:
    return abs(a.x - b.x) + abs(a.y - b.y)
