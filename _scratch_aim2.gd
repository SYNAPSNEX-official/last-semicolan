extends SceneTree

## Player on the ground around the tower, looks at the visible top (beacon,
## y=19.5) and at the rim (y=17.5). Does the hook catch the tower?

var world: Node = null
var hook: Node = null
var pj: RigidBody3D = null
var frames := 0
var stage := 0
var pos: Array = [Vector3(16, 5, 8), Vector3(16, 5, 0), Vector3(8, 5, -16), Vector3(24, 5, -16), Vector3(16, 5, -28)]
var heights: Array = [19.5, 17.5]
var results: Array = []

func _initialize() -> void:
	world = load("res://world.tscn").instantiate()
	root.add_child(world)
	var p := world.get_node("Player") as CharacterBody3D
	p.set_physics_process(false)
	p.set_process(false)
	for e in (world.get_node_or_null("enemies") as Node).get_children():
		e.set_physics_process(false)
		e.set_process(false)

func _physics_process(_d: float) -> bool:
	frames += 1
	var p := world.get_node("Player") as CharacterBody3D
	if frames == 5 and not _inited:
		_inited = true
		hook = world.get_node("Player/GrapplingHook")
		pj = hook.get("_projectile")
		hook.set("_camera", null)
		pj.body_entered.connect(_on_hit)
		stage = 1
		frames = 0
		return false
	match stage:
		1:
			if frames < 3:
				return false
			if pos.is_empty():
				for r in results:
					print("[T] ", r)
				print("[T] DONE")
				quit()
				return false
			var ppos: Vector3 = pos.pop_front()
			_teleport(ppos, heights[0])
			stage = 2
			frames = 0
			return false
		2:
			if frames >= 360:
				results.append("from %s aimBeacon -> hit=%s" % [str(cur_pos), hit or ("state-%d" % hook.get("state"))])
				_teleport(cur_pos, heights[1])
				_hit_done()
				stage = 3
				frames = 0
				return false
			return false
		3:
			if frames >= 360:
				results.append("from %s aimRim    -> hit=%s" % [str(cur_pos), hit or ("state-%d" % hook.get("state"))])
				_hit_done()
				stage = 1
				frames = 0
				return false
			return false
	return false

var cur_pos := Vector3.ZERO
var hit := ""
var _inited := false

func _teleport(p: Vector3, target_y: float) -> void:
	cur_pos = p
	hit = ""
	var pl := world.get_node("Player") as CharacterBody3D
	_reset()
	pl.global_position = p
	pl.look_at(Vector3(16, target_y, -16), Vector3.UP)
	hook.call("fire")

func _reset() -> void:
	hook.set("state", 0)
	pj.freeze = true
	pj.global_position = hook.call("_origin_position")
	pj.linear_velocity = Vector3.ZERO
	pj.angular_velocity = Vector3.ZERO

func _hit_done() -> void:
	_reset()

func _on_hit(b: Node) -> void:
	hit = "%s@%s" % [str(b.get("name")), str(pj.global_position)]
	print("[T] BODY hit ", hit)