extends Node3D

func _ready() -> void:
	await get_tree().process_frame
	var world := get_tree().current_scene
	var hook := world.get_node("Player/GrapplingHook")
	var frame_body := world.get_node("frame/StaticBody3D")
	hook._attach_surface(frame_body.global_position, frame_body)
	print("[PROBE] attached, is_climbable=", hook.is_climbable())
	await get_tree().process_frame
	if hook.is_climbable():
		print("[PROBE] PASS: frame is climbable")
	else:
		print("[PROBE] FAIL: frame not climbable")
	get_tree().quit(0)