extends SceneTree

var world: Node = null
var hook: Node = null
var pj: RigidBody3D = null
var frames := 0
var stage := 0
var angles: Array = [75.0, 80.0, 83.0, 85.0, 87.0, 88.0, 89.0]
var results: Array = []
var current_angle: float = 0.0
var hit_name: String = ""
var hit_pos := ""
var _inited := false

func _initialize() -> void:
	world = load("res://world.tscn").instantiate()
	root.add_child(world)
	var p := world.get_node("Player")
	p.set_physics_process(false)
	p.set_process(false)
	for e in (world.get_node_or_null("enemies") as Node).get_children():
		e.set_physics_process(false)
		e.set_process(false)

func reset_hook() -> void:
	hook.set("state", 0)
	pj.freeze = true
	pj.visible = false
	pj.global_position = hook.call("_origin_position")
	pj.linear_velocity = Vector3.ZERO
	pj.angular_velocity = Vector3.ZERO

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
			if angles.is_empty():
				for r in results:
					print("[T] ", r)
				print("[T] DONE")
				quit()
				return false
			var ang: float = angles.pop_front()
			reset_hook()
			var p := world.get_node("Player")
			p.global_position = Vector3(16, 6, -10)
			p.rotation = Vector3(deg_to_rad(ang), 0, 0)
			hook.call("fire")
			current_angle = ang
			hit_name = ""
			hit_pos = ""
			stage = 2
			frames = 0
			return false
		2:
			if frames >= 480:
				var outcome: String = hit_name if hit_name != "" else ("state-%d" % hook.get("state"))
				results.append("%.0f deg -> %s pos=%s" % [current_angle, outcome, hit_pos])
				stage = 1
				frames = 0
				return false
	return false

func _on_hit(b: Node) -> void:
	hit_name = str(b.get("name"))
	hit_pos = "y=%.1f" % pj.global_position.y
	print("[T] %.0f deg hit %s y=%.2f" % [current_angle, b.get("name"), pj.global_position.y])