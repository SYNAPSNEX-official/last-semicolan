extends SceneTree

var frames := 0
var world: Node = null

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
	if frames < 6:
		return false
	var p := world.get_node("Player") as CharacterBody3D
	match frames:
		6:
			p.global_position = Vector3(16, 18.4, -16)
		10:
			print("[T] tower_done: ", world.objectives_done.size() == 1)
			p.global_position = Vector3(42, 12.5, -36)
		14:
			print("[T] bridge_done: ", world.objectives_done.size() == 2)
			p.global_position = Vector3(8, 7.5, -40)
		18:
			print("[T] cell_done: ", world.objectives_done.size() == 3)
			print("[T] unlock: ", world.is_server_unlocked())
			world.get_node("Server").open_puzzle()
			world.get_node("UI").code_input.text = ";"
			world.get_node("UI")._on_submit_pressed()
			print("[T] WIN")
			quit()
			return false
	return false