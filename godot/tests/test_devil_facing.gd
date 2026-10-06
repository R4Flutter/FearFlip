extends McpTestSuite
## The Devil runs chest-first along its heading, not crabwise (its model is authored ~24 deg off +Z).


func suite_name() -> String:
	return "devil_facing"


func test_squared_up_devil_faces_plus_z() -> void:
	var model: Node3D = load("res://assets/character/skleton_added_devil.glb").instantiate()
	var rig := DevilRig.new(model)
	model.rotation.y = -rig.facing_yaw()
	var forward: Vector3 = model.basis * rig._left_axis.cross(Vector3.UP)
	assert_true(absf(atan2(forward.x, forward.z)) < 0.02, "devil faces %f rad off +Z" % atan2(forward.x, forward.z))
	model.free()


func test_player_model_measures_plus_x() -> void:
	# Cross-check of the measurement: main.gd's hand-tuned 90 deg turn says character2withrig.glb faces +X.
	var model: Node3D = load("res://assets/character/character2withrig.glb").instantiate()
	var rig := DevilRig.new(model, false)
	assert_true(absf(rig.facing_yaw() - PI / 2.0) < 0.05, "player yaw %f" % rig.facing_yaw())
	model.free()
