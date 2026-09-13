extends SceneTree

var world: Node = null
var hook: Node = null
var pj: RigidBody3D = null
var frames := 0
var stage := 0
var combos: Array = [
	[Vector3(16, 6, -10), 19.5],
	[Vector3(16, 6, -7), 19.5],
	[Vector3(16, 5, 0), 19.5],
	[Vector3(15, 6, -16), 19.5],
	[Vector3(17, 6, -21), 19.5],
	[Vector3(16, 12, -16), 19.5],
]
var results: Array = []
var _inited := false

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
			if combos.is_empty():
				for r in results:
					print("[T] ", r)
				print("[T] DONE")
				quit()
				return false
			var c: Array = combos.pop_front()
			_run(c[0], c[1])
			stage = 2
			frames = 0
			return false
		2:
			if frames >= 300:
				results.append("from %s aimBeacon19.5 -> %s climbable=%s" % [str(last_pos), hit, hook.is_climbable()])
				_reset()
				stage = 1
				frames = 0
				return false
			return false
	return false

var last_pos := Vector3.ZERO
var hit := ""

func _run(pos: Vector3, aim_y: float) -> void:
	last_pos = pos
	hit = ""
	var p := world.get_node("Player") as CharacterBody3D
	_reset()
	p.global_position = pos
	p.look_at(Vector3(16, aim_y, -16), Vector3.UP)
	hook.call("fire")

func _reset() -> void:
	hook.set("state", 0)
	pj.freeze = true
	pj.global_position = hook.call("_origin_position")
	pj.linear_velocity = Vector3.ZERO
	pj.angular_velocity = Vector3.ZERO

func _on_hit(b: Node) -> void:
	hit = "%s@%.1f" % [str(b.get("name")), pj.global_position.y]
	print("[T] BODY ", hit)