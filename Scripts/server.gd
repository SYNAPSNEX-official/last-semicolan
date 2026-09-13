extends StaticBody3D

@onready var terminal: Panel = $"../UI/Panel"

var in_terminal := false


func _ready() -> void:
	terminal.hide()


func open_puzzle() -> void:
	if in_terminal:
		terminal.hide()
		in_terminal = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		terminal.show()
		in_terminal = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
