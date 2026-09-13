extends "res://Scripts/player.gd"

## Arcade grappling movement:
## - Gravity remains active while attached.
## - The initial hook distance becomes the rope length.
## - Holding Q reels the rope in.
## - Tangential momentum is preserved so the player swings through a valley
##   instead of flying in a straight line toward the anchor.

@export_category("Rope Physics")
@export var rope_reel_speed := 4.5
@export var rope_min_length := 1.5
@export var rope_max_speed := 25.0
@export var rope_position_correction := 0.35

var rope_active := false
var rope_length := 0.0


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if action_lock_timer > 0.0:
		action_lock_timer = max(action_lock_timer - delta, 0.0)

	var climbing := _should_climb()

	if climbing:
		if not rope_active:
			_start_rope()
		_handle_rope_physics(delta)
	else:
		if rope_active:
			_end_rope()
		_handle_crouch(delta)
		_handle_movement(delta)
		_handle_jump(delta)
		_handle_landing_check()

	_handle_health_regen(delta)

	if climbing:
		_play_animation("idle")
	else:
		_handle_animation()

	_handle_camera(delta)
	_handle_trauma_shake(delta)
	_handle_jump_kick(delta)
	move_and_slide()

	was_rope_climbing = climbing


func _start_rope() -> void:
	if grappling_hook == null or not grappling_hook.has_method("get_anchor_position"):
		return

	var anchor: Vector3 = grappling_hook.get_anchor_position()
	rope_length = maxf(
		global_position.distance_to(anchor),
		rope_min_length
	)
	rope_active = true


func _handle_rope_physics(delta: float) -> void:
	if grappling_hook == null or not grappling_hook.has_method("get_anchor_position"):
		return

	var anchor: Vector3 = grappling_hook.get_anchor_position()

	# Normal gravity keeps the swing natural.
	velocity.y -= gravity * delta

	# Holding Q reels the rope in instead of directly steering the player.
	rope_length = maxf(
		rope_length - rope_reel_speed * delta,
		rope_min_length
	)

	# Keep momentum bounded so a long swing cannot become unstable.
	var speed := velocity.length()
	if speed > rope_max_speed:
		velocity = velocity.normalized() * rope_max_speed

	var offset := global_position - anchor
	var distance := offset.length()

	if distance <= 0.001:
		return

	var radial_dir := offset / distance

	# If we would move beyond the rope, keep only the tangential component.
	# This is the key part that creates swinging instead of straight-line flight.
	if distance >= rope_length:
		var outward_speed := velocity.dot(radial_dir)
		if outward_speed > 0.0:
			velocity -= radial_dir * outward_speed

		# Softly correct the rope length so CharacterBody3D remains stable.
		var excess := distance - rope_length
		if excess > 0.0:
			global_position -= radial_dir * minf(
				excess,
				rope_position_correction
			)


func _end_rope() -> void:
	rope_active = false
	# Gravity takes over normally on the next frame.
