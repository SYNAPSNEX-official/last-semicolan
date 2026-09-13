extends SceneTree

var frames := 0
var pts: Array = [
	Vector3(20, 30, -16),
	Vector3(23, 30, -16),
	Vector3(16, 30, -9),
	Vector3(11, 30, -16),
	Vector3(20, 30, -23),
]

func _initialize() -> void:
	var world = load("res://world.tscn").instantiate()
	root.add_child(world)

func _physics_process(_d: float) -> bool:
	frames += 1
	if frames < 10:
		return false
	var world = root.get_node("Node3D")
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for p in pts:
		var from: Vector3 = p + Vector3(0, 20, 0)
		var to: Vector3 = p - Vector3(0, 40, 0)
		var q := PhysicsRayQueryParameters3D.create(from, to, 1)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			print("[T] ", p, " -> NO HIT")
		else:
			print("[T] ", p, " -> ground y=%.2f on %s" % [hit.position.y, str(hit.collider.get("name"))])
	quit()
	return false