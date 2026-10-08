class_name Art
extends RefCounted
## Every delivered art slot the game reads (prompts and sizes: assets/ASSET_PROMPTS.md). Each one is optional:
## tex() and model() return null until the file exists, and every caller keeps its code-built stand-in.

const WORLD := "res://assets/textures/world/"
const DECALS := "res://assets/textures/decals/"
const HUD := "res://assets/images/hud/"
const MODELS := "res://assets/models/"
## 2x2 sheet, white with alpha: dust specks, a streak, a smoke puff, a star sparkle.
const FX := "res://assets/textures/fx/fx_sheet.png"
enum Fx { DUST, STREAK, SMOKE, SPARKLE }


static func tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


static func model(model_name: String) -> PackedScene:
	var path := MODELS + model_name + ".glb"
	return load(path) if ResourceLoader.exists(path) else null


## Puts `surface`'s textures (WORLD/<surface>_albedo.jpg + _normal.png) on `material`, mapped in world space so
## one tile covers `tile` metres on every face and neighbouring cells line up. False (material untouched) until
## the albedo exists.
static func dress(material: StandardMaterial3D, surface: String, tile: Vector3) -> bool:
	var albedo := tex(WORLD + surface + "_albedo.jpg")
	if albedo == null:
		return false
	material.albedo_texture = albedo
	material.normal_texture = tex(WORLD + surface + "_normal.png")
	material.normal_enabled = material.normal_texture != null
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / tile
	return true


## A flat decal lying on the floor (or, turned, on a wall): `size` metres square. `glow` art is painted on black
## and adds light; the rest has alpha. Null until the texture exists.
static func decal(path: String, size: float, color: Color, glow: bool) -> MeshInstance3D:
	var texture := tex(path)
	if texture == null:
		return null
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glow else BaseMaterial3D.BLEND_MODE_MIX
	material.albedo_texture = texture
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * size
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## A camera-facing particle material showing one cell of the FX sheet, null until the sheet exists.
static func fx_material(cell: Fx, color: Color, glow: bool) -> StandardMaterial3D:
	var texture := tex(FX)
	if texture == null:
		return null
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glow else BaseMaterial3D.BLEND_MODE_MIX
	material.albedo_texture = texture
	material.albedo_color = color
	material.uv1_scale = Vector3(0.5, 0.5, 1.0)
	material.uv1_offset = Vector3(0.5 * (cell % 2), 0.5 * floori(cell / 2.0), 0.0)
	return material


## The 2D key (HUD slots, minimap): the delivered icon, else the old key art.
static func key_icon() -> Texture2D:
	var icon := tex(HUD + "key_icon.png")
	return icon if icon != null else load("res://assets/images/key.png")
