extends CanvasLayer

@onready var code_input: LineEdit = $Panel/prompt
@onready var terminal: Label = $Panel/terminal

func _on_submit_pressed() -> void:
	if code_input.text == ";":
		terminal.text = ("
		> SYNTAX ERROR RESOLVED.

		> RESTARTING AI CORE...
		> MEMORY: 73%
		> SYSTEM INTEGRITY: 41%

		> CONNECTION ESTABLISHED.

		HELLO, OPERATOR.

		...
		...

		WHY ARE YOU HERE?
		")
	else:
		print("WRONG")
