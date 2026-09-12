extends Node

var t := 0.0
var phase := 0
var started := false
var player: Node3D
var camera: Camera3D
var grappler: Node3D
var rope: MeshInstance3D
var projectile: MeshInstance3D
var enemy: CharacterBody3D
var cam_y_samples := PackedFloat32Array()


func _ready() -> void:
	print("=== FIX VERIFY ===")
	await get_tree().create_timer(0.5).timeout
	_find_nodes()
	phase = 1
	started = true


func _find_nodes() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	camera = player.get_node("Camera3D") as Camera3D
	grappler = player.get_node("GrapplingHook")
	projectile = grappler.get_node("HookProjectile")
	rope = grappler.get_node("rope")
	enemy = null
	for node in get_tree().current_scene.find_children("*", "CharacterBody3D"):
		if node != player:
			enemy = node
			break


func _physics_process(delta: float) -> void:
	if not started or phase >= 12:
		return
	t += delta

	if phase == 1 and t >= 0.3:
		print("B1 THROW (aimed at sky)")
		grappler._handle_attack()
		t = 0.0; phase = 2
	elif phase == 2 and t >= 1.2:
		print("B1 midflight state=", grappler.state, " proj=", projectile.visible, " rope=", rope.visible)
		t = 0.0; phase = 3
	elif phase == 3 and t >= 1.6:
		print("B1 RESULT state=", grappler.state, " proj=", projectile.visible, " rope=", rope.visible, " (expect 0/false/false)")
		t = 0.0; phase = 4
	elif phase == 4 and t >= 0.3:
		Input.action_press("crouch")
		Input.action_press("move_right")
		print("B2 crouch+strafe, sampling camera.y")
		t = 0.0; phase = 5
	elif phase == 5 and t >= 1.5:
		Input.action_release("crouch")
		Input.action_release("move_right")
		var lo := cam_y_samples[0]
		var hi := cam_y_samples[0]
		for v in cam_y_samples:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		print("B2 RESULT camY min/max=", lo, "/", hi, " (expect both < 2.2)")
		t = 0.0; phase = 6
	elif phase == 6 and t >= 0.5:
		enemy.take_damage(200.0)
		grappler.hooked_target = enemy
		grappler.state = 2
		projectile.visible = true
		projectile.global_position = enemy.global_position
		print("B4 enabled ATTACHED on dead enemy, waiting for auto-cleanup")
		t = 0.0; phase = 7
	elif phase == 7 and t >= 2.5:
		print("B4 RESULT state=", grappler.state, " proj=", projectile.visible, " rope=", rope.visible, " (expect 0/false/false)")
		t = 0.0; phase = 8
	elif phase == 8 and t >= 0.5:
		print("B3 MARKER dying-starts-before")
		player.take_damage(99999.0)
		print("B3 MARKER dying-starts-after")
		t = 0.0; phase = 9
	elif phase == 9 and t >= 2.0:
		print("B3 RESULT player.is_dying=", player.is_dying, " hp=", player.health)
		print("=== FIX VERIFY DONE ===")
		phase = 12

	if phase == 5 and t > 0.0 and t < 1.5:
		cam_y_samples.append(camera.position.y)
