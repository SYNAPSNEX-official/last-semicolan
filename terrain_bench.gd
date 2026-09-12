extends SceneTree

var world: Node = null
var cam: Node = null
var elapsed := 0.0
var frames := 0
var last_report := 0.0

func _initialize() -> void:
	var scene: PackedScene = load("res://world.tscn")
	world = scene.instantiate()
	root.add_child(world)

	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_position(Vector2i(0, 0))

	var terrain: Terrain3D = null
	for c in world.get_children():
		if c is Terrain3D:
			terrain = c
			break

	# Freeze gameplay: player and enemy
	var player = world.get_node_or_null("Player")
	if player:
		player.set_physics_process(false)
		player.set_process(false)
		var anim = player.get_node_or_null("mesh/AnimationPlayer")
		if anim: anim.stop()
		cam = player.get_node_or_null("Camera3D")
	# Enemy might chase/knockback; disable it
	var enemy = world.get_node_or_null("Enemy")
	if enemy:
		enemy.set_physics_process(false)
		enemy.set_process(false)
	# Do NOT move the camera: the terrain clipmap centers on the camera grabbed
	# at startup (the player camera at spawn). Keep that exact deterministic view.

func _process(delta: float) -> bool:
	elapsed += delta
	frames += 1
	last_report += delta
	if last_report >= 2.0:
		last_report = 0.0
		var avgfps: float = float(frames) / elapsed
		print("REPORT avg_fps=", avgfps,
			" inst_fps=", Performance.get_monitor(Performance.TIME_FPS),
			" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			" objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if elapsed >= 26.0:
		quit()
	return false