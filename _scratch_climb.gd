extends SceneTree

## Simulate the ground->top piton climb on the relay tower.
## Player hooks near wall, reels to anchor-0.6, re-hooks aiming up,
## repeats. Can we get onto the top (y>=17.5)?

var world: Node = null
var hook: Node = null
var pj: RigidBody3D = null
var frames := 0
var stage := 0
var steps := 0
var max_attach_y := 0.0
var total := 0
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
	total += 1
	frames += 1
	if total == 1200:
		print("[T] GLOBAL TIMEOUT stage=", stage, " state=", hook.get("state") if hook else -1)
		quit()
		return false
	var p := world.get_node("Player") as CharacterBody3D
	if frames == 5 and not _inited:
		_inited = true
		hook = world.get_node("Player/GrapplingHook")
		pj = hook.get("_projectile")
		hook.set("_camera", null)
		pj.body_entered.connect(_on_hit)
		p.global_position = Vector3(16, 6, -10)
		# aim at rim/top
		p.look_at(Vector3(16, 17.5, -16), Vector3.UP)
		hook.call("fire")
		firevars_collect()
		stage = 1
		frames = 0
		return false
	if frames == 2000:
		print("[T] GLOBAL TIMEOUT state=", hook.get("state"), " but stage=", stage)
		quit()
		return false
	match stage:
		1: # fired, wait for ATTACH
			if frames >= 480:
				print("[T] step %d: NO ATTACH state=%d" % [steps, hook.get("state")])
				quit()
				return false
			return false
		2: # attached: reel player to anchor-0.6, then re-fire aiming at next
			if frames < 60:
				return false
			steps += 1
			var anchor: Vector3 = hook.call("get_anchor_position")
			if anchor.y > max_attach_y:
				max_attach_y = anchor.y
			print("[T] step %d attach y=%.2f pos=%s" % [steps, anchor.y, str(anchor)])
			if anchor.y >= 17.5:
				print("[T] TOP REACHED at y=%.2f" % anchor.y)
				quit()
				return false
			if steps >= 8:
				print("[T] GAVE UP max_y=%.2f" % max_attach_y)
				quit()
				return false
			# reel: place the player 0.6m below the anchor toward ground
			var to_a := anchor - p.global_position
			var d := to_a.length()
			var stop := clampf(d - 0.6, 0.0, 100000.0)
			p.global_position = anchor - (to_a / d) * stop
			# keep the aim point above: aim at beacon to keep going up
			p.look_at(Vector3(16, 19.5, -16), Vector3.UP)
			reset_hook()
			hook.call("fire")
			stage = 1
			frames = 0
			return false
	return false

func firevars_collect() -> void:
	pass

func reset_hook() -> void:
	hook.set("state", 0)
	pj.freeze = true
	pj.visible = false
	pj.global_position = hook.call("_origin_position")
	pj.linear_velocity = Vector3.ZERO
	pj.angular_velocity = Vector3.ZERO

func _on_hit(b: Node) -> void:
	print("[T]  hit ", b.get("name"), " @ ", pj.global_position)
	stage = 2
	frames = 0