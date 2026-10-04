extends McpTestSuite
## Models are sized by their real mesh bounds: exact height, feet on the requested floor line.


func suite_name() -> String:
	return "model_fit"


## 1 m tall box whose bottom sits 0.2 m below its origin, nested under an offset child.
func _model() -> Node3D:
	var root := Node3D.new()
	var child := Node3D.new()
	child.position.y = 0.3
	root.add_child(child)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 1.0, 0.5)
	mesh.mesh = box
	child.add_child(mesh)
	return root


func test_bounds_include_child_transforms() -> void:
	var model: Node3D = _model()
	var bounds: AABB = ModelFit.mesh_bounds(model)
	assert_true(is_equal_approx(bounds.size.y, 1.0))
	assert_true(is_equal_approx(bounds.position.y, -0.2))
	model.free()


func test_fit_height_scales_and_grounds() -> void:
	var model: Node3D = _model()
	ModelFit.fit_height(model, 2.52, -0.75)
	var top: float = model.position.y + (ModelFit.mesh_bounds(model).end.y) * model.scale.y
	var bottom: float = model.position.y + ModelFit.mesh_bounds(model).position.y * model.scale.y
	assert_true(is_equal_approx(top - bottom, 2.52), "height %f" % (top - bottom))
	assert_true(is_equal_approx(bottom, -0.75), "feet %f" % bottom)
	model.free()


func test_empty_model_is_left_alone() -> void:
	var model := Node3D.new()
	ModelFit.fit_height(model, 2.0, 0.0)
	assert_eq(model.scale, Vector3.ONE)
	model.free()
