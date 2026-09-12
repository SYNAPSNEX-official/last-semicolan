extends CanvasLayer

@onready var code_input: LineEdit = $Panel/prompt

func _on_submit_pressed() -> void:
	if code_input.text == ";":
		print("CORRECT")
	else:
		print("WRONG")
