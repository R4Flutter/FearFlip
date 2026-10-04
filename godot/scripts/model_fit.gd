class_name ModelFit
## Sizes imported models to world units, independent of how they were authored.


## Scales `model` uniformly to `height` metres and puts its lowest vertex at local `feet_y`.
static func fit_height(model: Node3D, height: float, feet_y: float) -> void:
	var box: AABB = mesh_bounds(model)
	if box.size.y <= 0.0:
		push_warning("%s has no mesh bounds; height not fitted" % model.name)
		return
	var s: float = height / box.size.y
	model.scale = Vector3.ONE * s
	model.position.y = feet_y - box.position.y * s


## Combined AABB of every MeshInstance3D under `node`, in `node`'s local space (its own transform excluded).
static func mesh_bounds(node: Node, xform: Transform3D = Transform3D()) -> AABB:
	var box := AABB()
	if node is MeshInstance3D:
		box = xform * (node as MeshInstance3D).get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var sub: AABB = mesh_bounds(child, xform * (child as Node3D).transform)
			if sub.has_volume():
				box = box.merge(sub) if box.has_volume() else sub
	return box
