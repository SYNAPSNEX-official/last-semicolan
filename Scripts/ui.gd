extends CanvasLayer

@onready var code_input: LineEdit = $Panel/prompt
@onready var terminal: Label = $Panel/terminal

var fps_label: Label

func _ready() -> void:
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.position = Vector2(8, 8)
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fps_label)

func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

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
