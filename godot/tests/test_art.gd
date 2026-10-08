extends McpTestSuite
## Delivered art (assets/ASSET_PROMPTS.md): each slot loads only once its file exists (the art is git-ignored, so a
## fresh checkout has none), and the stand-in stays otherwise.


func suite_name() -> String:
	return "art"


func test_a_missing_file_is_no_art() -> void:
	assert_eq(Art.tex("res://assets/no_such_art.png"), null)
	assert_eq(Art.model("no_such_model"), null)
	assert_eq(Art.decal("res://assets/no_such_art.png", 1.0, Color.WHITE, true), null)
	var material := StandardMaterial3D.new()
	assert_false(Art.dress(material, "no_such_surface", Vector3.ONE))
	assert_eq(material.albedo_texture, null, "a stand-in keeps its plain colour")
	assert_ne(Art.key_icon(), null, "the old key art stands in for the icon")


func test_a_surface_tiles_in_world_space() -> void:
	if not ResourceLoader.exists(Art.WORLD + "wake_wall_albedo.jpg"):
		return
	var material := StandardMaterial3D.new()
	assert_true(Art.dress(material, "wake_wall", Vector3.ONE * 2.4))
	assert_true(material.uv1_triplanar and material.uv1_world_triplanar, "neighbouring cells line up")
	assert_true(material.normal_enabled)
	assert_true(is_equal_approx(material.uv1_scale.x, 1.0 / 2.4), "one tile per cell")


func test_glow_decals_add_light_and_the_rest_blend() -> void:
	if not ResourceLoader.exists(Art.DECALS + "safe_circle.png"):
		return
	var glow := Art.decal(Art.DECALS + "safe_circle.png", 2.0, Color.CYAN, true)
	assert_eq((glow.material_override as StandardMaterial3D).blend_mode, BaseMaterial3D.BLEND_MODE_ADD)
	assert_eq((glow.mesh as PlaneMesh).size, Vector2(2, 2))
	glow.free()
	var blood := Art.decal(Art.DECALS + "decal_blood.png", 1.0, Color.WHITE, false)
	assert_eq((blood.material_override as StandardMaterial3D).blend_mode, BaseMaterial3D.BLEND_MODE_MIX)
	blood.free()


func test_fx_cells_pick_their_quarter_of_the_sheet() -> void:
	if not ResourceLoader.exists(Art.FX):
		return
	assert_eq(Art.fx_material(Art.Fx.DUST, Color.WHITE, false).uv1_offset, Vector3.ZERO)
	assert_eq(Art.fx_material(Art.Fx.SPARKLE, Color.WHITE, true).uv1_offset, Vector3(0.5, 0.5, 0.0))
	assert_eq(Art.fx_material(Art.Fx.SMOKE, Color.WHITE, false).uv1_scale, Vector3(0.5, 0.5, 1.0))
