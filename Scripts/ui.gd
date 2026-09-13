extends CanvasLayer

@onready var code_input: LineEdit = $Panel/prompt
@onready var terminal: Label = $Panel/terminal
@onready var panel: Label = $Panel/terminal

var fps_label: Label
var crosshair: Label
var hit_marker: Label
var hook_status: Label
var interaction_label: Label
var victory_panel: Panel
var victory_label: Label
var objectives_label: Label
var hint_label: Label
var locked_label: Label
var unlocked_label: Label

var _hit_tween: Tween
var _crosshair_tween: Tween
var _fps_timer := 0.0
var _viewport_center := Vector2.ZERO
var _last_viewport_size := Vector2.ZERO
const FPS_UPDATE_INTERVAL := 0.5

@onready var server = get_node_or_null("../Server")

const OBJECTIVE_NAMES := {
	1: "RELAY TOWER",
	2: "BRIDGE GAP",
	3: "POWER CELL",
}

func _ready() -> void:
	# FPS
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.position = Vector2(8, 8)
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fps_label)

	# Crosshair
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 20)
	crosshair.add_theme_color_override(
		"font_color",
		Color(0.8, 0.95, 1.0, 0.8)
	)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	# Hit marker
	hit_marker = Label.new()
	hit_marker.text = "✕"
	hit_marker.add_theme_font_size_override("font_size", 28)
	hit_marker.add_theme_color_override(
		"font_color",
		Color(1.0, 0.3, 0.2, 0.0)
	)
	hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hit_marker)

	# Hook status
	hook_status = Label.new()
	hook_status.text = "HOOK: READY"
	hook_status.position = Vector2(8, 32)
	hook_status.add_theme_font_size_override("font_size", 16)
	hook_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hook_status)

	# Objectives HUD
	objectives_label = Label.new()
	objectives_label.text = "OBJECTIVES 0/3\n"
	objectives_label.position = Vector2(8, 60)
	objectives_label.add_theme_font_size_override("font_size", 18)
	objectives_label.add_theme_color_override(
		"font_color",
		Color(0.9, 0.95, 1.0, 0.95)
	)
	objectives_label.add_theme_color_override(
		"font_shadow_color",
		Color(0, 0, 0, 0.8)
	)
	objectives_label.add_theme_constant_override("shadow_offset_x", 2)
	objectives_label.add_theme_constant_override("shadow_offset_y", 2)
	objectives_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(objectives_label)
	set_objectives(0)

	# Controls hint
	hint_label = Label.new()
	hint_label.text = "LMB: Fire hook   Q: Climb / Reel   SPACE: Jump   E: Interact"
	hint_label.position = Vector2(8, 0)
	hint_label.anchor_left = 0.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_top = -40.0
	hint_label.offset_bottom = -12.0
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override(
		"font_color",
		Color(1, 0.95, 0.85, 0.75)
	)
	hint_label.add_theme_color_override(
		"font_shadow_color",
		Color(0, 0, 0, 0.85)
	)
	hint_label.add_theme_constant_override("shadow_offset_x", 2)
	hint_label.add_theme_constant_override("shadow_offset_y", 2)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_label)

	# Locked toast
	locked_label = Label.new()
	locked_label.anchor_left = 0.5
	locked_label.anchor_right = 0.5
	locked_label.anchors_preset = Control.PRESET_CENTER_TOP
	locked_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	locked_label.offset_top = 120.0
	locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_label.add_theme_font_size_override("font_size", 28)
	locked_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3, 0))
	locked_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	locked_label.add_theme_constant_override("shadow_offset_x", 2)
	locked_label.add_theme_constant_override("shadow_offset_y", 2)
	locked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(locked_label)

	# Server unlocked toast
	unlocked_label = Label.new()
	unlocked_label.anchor_left = 0.5
	unlocked_label.anchor_right = 0.5
	unlocked_label.anchors_preset = Control.PRESET_CENTER_TOP
	unlocked_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	unlocked_label.offset_top = 80.0
	unlocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlocked_label.add_theme_font_size_override("font_size", 32)
	unlocked_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.35, 0))
	unlocked_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	unlocked_label.add_theme_constant_override("shadow_offset_x", 2)
	unlocked_label.add_theme_constant_override("shadow_offset_y", 2)
	unlocked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(unlocked_label)

	# Victory UI
	victory_panel = Panel.new()
	victory_panel.visible = false
	victory_panel.position = Vector2(
		get_viewport().get_visible_rect().size.x * 0.5 - 250.0,
		get_viewport().get_visible_rect().size.y * 0.5 - 120.0
	)
	victory_panel.size = Vector2(500, 240)
	add_child(victory_panel)

	victory_label = Label.new()
	victory_label.text = "AI CORE OFFLINE\n\nDATA CENTER SECURED\n\nPress ENTER to continue"
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_label.position = Vector2(20, 20)
	victory_label.size = Vector2(460, 200)
	victory_label.add_theme_font_size_override("font_size", 22)
	victory_panel.add_child(victory_label)


func set_objectives(completed: int) -> void:
	if objectives_label == null:
		return
	var txt := "OBJECTIVES  %d/3\n" % completed
	for id in OBJECTIVE_NAMES:
		var mark := "■" if int(id) <= completed else "□"
		txt += "%s %s\n" % [mark, OBJECTIVE_NAMES[id]]
	objectives_label.text = txt


func show_server_unlocked() -> void:
	if unlocked_label == null:
		return
	unlocked_label.text = "SERVER UNLOCKED - FIND THE DATA CENTER"
	unlocked_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(unlocked_label, "modulate:a", 0.0, 1.2)


func show_server_locked() -> void:
	if locked_label == null:
		return
	locked_label.text = "SERVER LOCKED - SECURE ALL 3 OBJECTIVES FIRST"
	locked_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(locked_label, "modulate:a", 0.0, 0.8)


func _process(delta: float) -> void:
	if fps_label:
		_fps_timer -= delta
		if _fps_timer <= 0.0:
			_fps_timer = FPS_UPDATE_INTERVAL
			fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_viewport_center = viewport_size * 0.5

	if crosshair:
		crosshair.position = _viewport_center - Vector2(5, 12)

	if hit_marker:
		hit_marker.position = _viewport_center - Vector2(10, 17)

	if Input.is_action_just_pressed("ui_accept") and victory_panel.visible:
		get_tree().reload_current_scene()


func hook_fired() -> void:
	if crosshair == null:
		return

	if _crosshair_tween:
		_crosshair_tween.kill()

	crosshair.scale = Vector2(1.35, 1.35)

	_crosshair_tween = create_tween()
	_crosshair_tween.tween_property(
		crosshair,
		"scale",
		Vector2.ONE,
		0.12
	)


func hook_hit() -> void:
	if hit_marker == null:
		return

	if _hit_tween:
		_hit_tween.kill()

	hit_marker.modulate.a = 1.0
	hit_marker.scale = Vector2(1.35, 1.35)

	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)

	_hit_tween.tween_property(
		hit_marker,
		"modulate:a",
		0.0,
		0.22
	)

	_hit_tween.tween_property(
		hit_marker,
		"scale",
		Vector2.ONE,
		0.12
	)


func hook_status_ready() -> void:
	if hook_status:
		hook_status.text = "HOOK: READY"


func hook_status_fired() -> void:
	if hook_status:
		hook_status.text = "HOOK: FIRED"


func hook_status_attached() -> void:
	if hook_status:
		hook_status.text = "HOOK: ATTACHED"


func hook_status_retracting() -> void:
	if hook_status:
		hook_status.text = "HOOK: RETRACTING"


func show_victory() -> void:
	if victory_panel:
		victory_panel.visible = true

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if terminal:
		get_tree().change_scene_to_file("res://Scenes/won.tscn")


func _on_submit_pressed() -> void:
	var answer := code_input.text.strip_edges()

	if answer == ";":
		terminal.text = """
> SYNTAX ERROR RESOLVED.

> RESTARTING AI CORE...
> MEMORY: 73%
> SYSTEM INTEGRITY: 41%

> CONNECTION ESTABLISHED.

HELLO, OPERATOR.

...
...

WHY ARE YOU HERE?
"""

		code_input.clear()
		show_victory()

	else:
		terminal.text = """
> ERROR: INVALID CHARACTER.

> EXPECTED:
;
> TRY AGAIN.
"""
		code_input.select_all()
		await get_tree().create_timer(3.0).timeout
		terminal.text = """
AI CORE // CORRUPTED

> SYSTEM CHECK...
> ERROR: AI_COORDINATION_MODULE
> SOURCE INTEGRITY: FAILED

function restore_network() {
    reconnect_nodes()
    restart_navigation();
}

ERROR: EXPECTED ';'
REPAIR REQUIRED

> What character should be added 
(press E again to exit):"""
		code_input.text = "Input here"
