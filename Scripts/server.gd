extends StaticBody3D

@onready var terminal: Panel = $"../UI/Panel"

var in_terminal := false


func _ready() -> void:
	terminal.hide()


func _world() -> Node:
	var parent := get_parent()
	if parent is Node3D and parent.has_method("is_server_unlocked"):
		return parent
	return null


func is_unlocked() -> bool:
	var world := _world()
	return world != null and world.is_server_unlocked()


func get_interaction_label() -> String:
	if is_unlocked():
		return "[E] REPAIR CORRUPTED SERVER"
	return "LOCKED - SECURE ALL 3 OBJECTIVES"


func open_puzzle() -> void:
	if in_terminal:
		terminal.hide()
		in_terminal = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if not is_unlocked():
		var ui := get_node_or_null("../UI")
		if ui != null and ui.has_method("show_server_locked"):
			ui.show_server_locked()
		return

	terminal.show()
	in_terminal = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
