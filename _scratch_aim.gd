extends SceneTree

## Reproduce the real gameplay aim: player stands near the relay tower,
## looks at the glowing beacon (the visible top, y=19.5), fires.
## Does the hook catch anything?

var world: Node = null
var hook: Node = null
var pj: RigidBody3D = null
var frames := 0
var fired := false
var hit := ""

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
	if frames == 5:
		hook = world.get_node("Player/GrapplingHook")
		pj = hook.get("_projectile")
		hook.set("_camera", null)
		pj.body_entered.connect(_on_hit)
		p.global_position = Vector3(16, 6, -6)
		# aim directly at the beacon glow = the visual top of the tower
		p.look_at(Vector3(16, 19.5, -16), Vector3.UP)
		hook.call("fire")
		fired = true
		print("[T] origin=", str(hook.call("_origin_position")), " aim=fwd")
	if fired and frames % 30 == 0 and frames <= 480:
		print("[T] f=%d state=%d pos=%s hit=%s" % [frames, hook.get("state"), str(pj.global_position), hit])
	if frames == 480:
		print("[T] FINAL state=", hook.get("state"), " hit=", hit)
		quit()
		return false
	return false

func _on_hit(b: Node) -> void:
	hit = str(b.get("name")) + " @ " + str(pj.global_position)
	print("[T] BODY_ENTERED: ", hit)