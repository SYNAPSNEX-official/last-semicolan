extends Node

const WALK := "res://animations/mixamo.tres"

var svp: SubViewport
var ap: AnimationPlayer

func _ready() -> void:
	get_window().size = Vector2i(256, 256)
	svp = SubViewport.new()
	svp.size = Vector2i(900, 900)
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svp.msaa_3d = Viewport.MSAA_4X
	get_tree().root.add_child.call_deferred(svp)
	_call.call_deferred()

func _call() -> void:
	var arena := Node3D.new()
	svp.add_child(arena)
	var floor_static := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	floor_static.add_child(shape)
	floor_static.position.y = 0.0
	arena.add_child(floor_static)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 25, 0)
	sun.light_energy = 1.5
	arena.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.58, 0.62)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 1.0
	arena.add_child(env)

	var girl: Node3D = (load("res://Scenes/girl_character.tscn") as PackedScene).instantiate()
	girl.name = "girl"
	arena.add_child(girl)
	ap = AnimationPlayer.new()
	ap.name = "AP"
	arena.add_child(ap)
	ap.root_node = NodePath("../girl")
	var lib := load(WALK) as AnimationLibrary
	ap.add_animation_library("", lib)

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 42
	svp.add_child(cam)
	await get_tree().process_frame
	cam.global_position = Vector3(2.0, 1.15, 1.4)
	cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	for i in 8:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	(svp.get_texture().get_image()).save_png("/tmp/opencode/before_walk.png")

	ap.play("walking")
	for frame in 12:
		await get_tree().create_timer(0.12).timeout
		await get_tree().process_frame
		(svp.get_texture().get_image()).save_png("/tmp/opencode/walkframe_%02d.png" % frame)
	print("saved walk frames")
	get_tree().quit(0)