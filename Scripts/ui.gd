extends CanvasLayer

@onready var code_input: LineEdit = $Panel/prompt
@onready var terminal: Label = $Panel/terminal

var fps_label: Label
var crosshair: Label
var hit_marker: Label
var _hit_tween: Tween
var _crosshair_tween: Tween

func _ready() -> void:
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.position = Vector2(8, 8)
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fps_label)

	# Minimal center crosshair: cheap, readable, and useful for the hook.
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(5, 12)
	crosshair.add_theme_font_size_override("font_size", 20)
	crosshair.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 0.8))
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	hit_marker = Label.new()
	hit_marker.text = "✕"
	hit_marker.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(10, 17)
	hit_marker.add_theme_font_size_override("font_size", 28)
	hit_marker.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 0.0))
	hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hit_marker)

func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if crosshair:
		var center := get_viewport().get_visible_rect().size * 0.5
		crosshair.position = center - Vector2(5, 12)
	if hit_marker:
		var center := get_viewport().get_visible_rect().size * 0.5
		hit_marker.position = center - Vector2(10, 17)

func hook_fired() -> void:
	if crosshair == null:
		return
	if _crosshair_tween:
		_crosshair_tween.kill()
	crosshair.scale = Vector2(1.35, 1.35)
	_crosshair_tween = create_tween()
	_crosshair_tween.tween_property(crosshair, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hook_hit() -> void:
	if hit_marker == null:
		return
	if _hit_tween:
		_hit_tween.kill()
	hit_marker.modulate.a = 1.0
	hit_marker.scale = Vector2(1.35, 1.35)
	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(hit_marker, "modulate:a", 0.0, 0.22)
	_hit_tween.tween_property(hit_marker, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
