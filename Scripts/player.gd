extends CharacterBody3D

@export_category("Health")
@export var max_health := 100.0

@export_category("Health Regen")
@export var regen_delay := 4.0
@export var regen_rate := 10.0

@export_category("Movement")
@export var walk_speed := 5.5
@export var sprint_speed := 8.0
@export var acceleration := 32.0
@export var deceleration := 40.0
@export var air_acceleration := 12.0
@export var jump_velocity := 5.5
@export var gravity := 15.0

@export_category("Crouch")
@export var crouch_speed := 3.0
@export var crouch_height := 1.2
@export var standing_height := 1.8
@export var crouch_transition_speed := 10.0

@export_category("Mouse Look")
@export var mouse_sensitivity := 0.0025
@export var max_look_angle := 89.0

@export_category("Camera")
@export var normal_fov := 75.0
@export var sprint_fov := 82.0
@export var fov_change_speed := 8.0

@export_category("Head Bob")
@export var head_bob_amount := 0.035
@export var head_bob_speed := 10.0
@export var sprint_bob_multiplier := 1.35

@export_category("Camera Tilt")
@export var strafe_tilt := 2.0
@export var tilt_speed := 8.0

@export_category("Damage Feedback")
@export var damage_flash_time := 0.15
@export var damage_trauma := 0.4
@export var damage_flash_color := Color(1.0, 0.0, 0.0, 0.35)
@export var hit_react_lock_time := 0.35

@export_category("Camera Shake / Trauma")
@export var trauma_decay := 1.6
@export var max_shake_offset := 0.25
@export var max_shake_rotation := 4.0
@export var shake_noise_speed := 20.0
@export var landing_trauma_per_speed := 0.045
@export var min_fall_speed_for_shake := 4.0
@export var jump_kick_amount := 0.05

@export_category("Footstep Shake")
@export var footstep_shake_amount := 0.05      # trauma per footfall while walking
@export var footstep_shake_sprint_multiplier := 1.7

@export_category("Idle Sway")
@export var idle_sway_amount := 0.006           # radians, very subtle
@export var idle_sway_speed := 0.6

@export_category("Roll / Dodge")
@export var roll_speed := 12.0
@export var roll_duration := 0.35
@export var roll_cooldown := 1.0

@export_category("Hook Climbing")
@export var climb_speed := 6.5
@export var climb_acceleration := 30.0


var health: float
var regen_timer := 0.0
var is_dying := false

var head_bob_time := 0.0
var base_camera_position := Vector3.ZERO
var base_camera_height := 0.0
var current_height := 1.8
var is_crouching := false

var animation_player: AnimationPlayer
var current_animation := ""

# --- Trauma-based shake state ---
var trauma := 0.0
var shake_noise: FastNoiseLite
var shake_seed_offset := Vector3.ZERO
var shake_time := 0.0

# --- Jump kick state ---
var jump_kick_offset := 0.0
var was_on_floor := true
var previous_fall_velocity_y := 0.0

# --- Footstep shake state ---
var last_bob_sign := 1.0

# --- Idle sway state ---
var idle_sway_time := 0.0

# --- Animation lock (hit reactions, etc.) ---
var action_lock_timer := 0.0
var last_input_vector := Vector2.ZERO

# --- Roll / dodge state ---
var has_roll_input := false
var is_rolling := false
var roll_timer := 0.0
var roll_cooldown_timer := 0.0
var roll_direction := Vector3.ZERO

# --- Hook climbing state ---
var has_climb_input := false

# --- Damage flash (optional node, see earlier notes) ---
@onready var damage_flash_rect: ColorRect = get_node_or_null("../UI/DamageFlash") as ColorRect

@onready var camera: Camera3D = $Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var grappling_hook: Node = get_node_or_null("GrapplingHook")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	health = max_health

	base_camera_position = camera.position
	base_camera_height = camera.position.y

	camera.fov = normal_fov

	if collision_shape.shape is CapsuleShape3D:
		current_height = collision_shape.shape.height

	shake_noise = FastNoiseLite.new()
	shake_noise.seed = randi()
	shake_noise.frequency = 1.0
	shake_seed_offset = Vector3(
		randf_range(0.0, 1000.0),
		randf_range(0.0, 1000.0),
		randf_range(0.0, 1000.0)
	)

	has_roll_input = InputMap.has_action("roll")

	if not has_roll_input:
		print("NOTE: no 'roll' input action found — add one in Project > Project Settings > Input Map to enable dodging.")

	has_climb_input = InputMap.has_action("climb")

	if not has_climb_input:
		print("NOTE: no 'climb' input action found — defaulting to the E key for hook climbing.")

	_find_animation_player()
	_play_animation("idle")


func _find_animation_player() -> void:
	animation_player = _find_animation_player_recursive(self)

	if animation_player:
		print("AnimationPlayer found: ", animation_player.get_path())
		var animations := animation_player.get_animation_list()
		print("Available animations:")
		for animation_name in animations:
			print("  - ", animation_name)
	else:
		print("WARNING: No AnimationPlayer found on Player.")


func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var result := _find_animation_player_recursive(child)
		if result:
			return result
	return null


func _find_animation(name: String) -> String:
	if not animation_player:
		return ""

	var animations := animation_player.get_animation_list()
	var wanted := name.to_lower()

	for animation_name in animations:
		if animation_name.to_lower() == wanted:
			return animation_name

	for animation_name in animations:
		var lower_name := animation_name.to_lower()
		if lower_name.contains(wanted):
			return animation_name

	return ""


func _play_animation(name: String, force := false) -> void:
	if not animation_player:
		return

	var animation_name := _find_animation(name)

	if animation_name == "":
		return

	if not force and current_animation == animation_name:
		return

	current_animation = animation_name

	var name_lower := animation_name.to_lower()
	var should_loop := (
		name_lower.contains("idle")
		or name_lower.contains("walk")
		or name_lower.contains("run")
		or name_lower.contains("crouch")
		or name_lower == "fall"
		or name_lower == "jump"
	)

	if animation_player.has_animation(animation_name):
		animation_player.get_animation(animation_name).loop_mode = (
			Animation.LOOP_LINEAR
			if should_loop
			else Animation.LOOP_NONE
		)

	animation_player.play(animation_name)


func _unhandled_input(event: InputEvent) -> void:
	if is_dying:
		return

	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)

			camera.rotation.x -= (
				event.relative.y *
				mouse_sensitivity
			)

			camera.rotation.x = clamp(
				camera.rotation.x,
				deg_to_rad(-max_look_angle),
				deg_to_rad(max_look_angle)
			)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if action_lock_timer > 0.0:
		action_lock_timer = max(action_lock_timer - delta, 0.0)

	if roll_cooldown_timer > 0.0:
		roll_cooldown_timer = max(roll_cooldown_timer - delta, 0.0)

	_handle_roll_input(delta)

	if not is_rolling:
		_handle_crouch(delta)
		_handle_movement(delta)
		_handle_jump(delta)
		_handle_hook_climb(delta)
	else:
		_handle_roll_motion(delta)

	_handle_landing_check()
	_handle_health_regen(delta)
	_handle_animation()
	_handle_camera(delta)
	_handle_trauma_shake(delta)
	_handle_jump_kick(delta)

	move_and_slide()


func _handle_movement(delta: float) -> void:
	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	last_input_vector = input_vector

	var direction := (
		transform.basis *
		Vector3(input_vector.x, 0.0, input_vector.y)
	).normalized()

	var sprinting := (
		Input.is_action_pressed("sprint")
		and not is_crouching
		and input_vector.y < 0.0
	)

	var target_speed := walk_speed

	if is_crouching:
		target_speed = crouch_speed
	elif sprinting:
		target_speed = sprint_speed

	var target_velocity := direction * target_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	var current_acceleration := acceleration

	if not is_on_floor():
		current_acceleration = air_acceleration

	if direction.length() > 0.0:
		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			current_acceleration * delta
		)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(
			Vector3.ZERO,
			deceleration * delta
		)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _climb_input_pressed() -> bool:
	if has_climb_input:
		return Input.is_action_pressed("climb")

	return Input.is_physical_key_pressed(KEY_E)


func _should_climb() -> bool:
	if grappling_hook == null:
		return false
	if not grappling_hook.is_climbable():
		return false
	return _climb_input_pressed()


## Full-3D climb toward the hooked anchor. Called after jump/gravity so it
## can overcome gravity when the anchor is above. Wall-aware: the pull is
## projected onto the surface plane when a wall blocks it, so the player
## slides up/along geometry instead of clipping into it.
func _handle_hook_climb(delta: float) -> void:
	if not _should_climb():
		return

	var anchor: Vector3 = grappling_hook.get_anchor_position()
	var to_anchor: Vector3 = anchor - global_position
	var distance := to_anchor.length()

	if distance < 0.35:
		return  # reached the hook point: stop pulling

	var direction: Vector3 = to_anchor / distance
	var target_velocity := direction * climb_speed

	var from := global_position + Vector3.UP * 0.9
	var to := from + direction * (climb_speed * delta + 0.25)
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.exclude = [self]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		# Remove the component pushing into the wall; the rest is a slide
		# along the surface. When flush against the wall under the anchor, the
		# remaining pull collapses and the climb ends.
		target_velocity -= normal * target_velocity.dot(normal)
		if target_velocity.length() < 0.5:
			return

	# Horizontal pull toward the anchor slides the player to/along the
	# surface. The vertical pull is gated below so gravity is never erased:
	# pulling toward a level or lower anchor keeps the player falling instead
	# of floating in mid-air.
	var horizontal_target := Vector3(target_velocity.x, 0.0, target_velocity.z)
	velocity.x = move_toward(velocity.x, horizontal_target.x, climb_acceleration * delta)
	velocity.z = move_toward(velocity.z, horizontal_target.z, climb_acceleration * delta)

	# Vertical: only truly upward climbs get lift. The pull is measured by its
	# steepness — a shallow zipline toward an eye-level hook pulls the player
	# horizontally and keeps gravity intact, so they can never float up a
	# near-level rope. Steeper pulls ramp the assist up to full.
	if target_velocity.y > 0.0:
		# Lift is only granted when the player is actually climbing a surface:
		# pressed against a climbable body, standing on the floor, or riding
		# within ~1 m of the ground. In open air an upward pull would float the
		# player off the terrain.
		var steep: float = clampf((direction.y - 0.35) / 0.25, 0.0, 1.0)
		var pressed_climbable := false
		for i in get_slide_collision_count():
			var coll: KinematicCollision3D = get_slide_collision(i)
			if coll == null:
				continue
			var body := coll.get_collider()
			if body is Node and (body as Node).is_in_group("climbable"):
				pressed_climbable = true
				break
		var grounded := is_on_floor()
		if not grounded:
			var ground_from := global_position - Vector3(0.0, 0.35, 0.0)
			var ground_query := PhysicsRayQueryParameters3D.create(
				ground_from, ground_from - Vector3(0.0, 12.0, 0.0), collision_mask)
			ground_query.exclude = [self]
			var ground_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground_query)
			if not ground_hit.is_empty():
				grounded = global_position.y - (ground_hit.position as Vector3).y < 1.0
		if steep > 0.0 and (pressed_climbable or grounded):
			velocity.y = move_toward(velocity.y, target_velocity.y * steep, climb_acceleration * delta * 0.75)


func _handle_jump(delta: float) -> void:
	previous_fall_velocity_y = velocity.y

	if not is_on_floor():
		velocity.y -= gravity * delta
		return

	if Input.is_action_pressed("jump") and not is_crouching:
		velocity.y = jump_velocity
		jump_kick_offset = -jump_kick_amount
	else:
		velocity.y = 0.0


func _handle_landing_check() -> void:
	if is_on_floor() and not was_on_floor:
		var impact_speed := absf(previous_fall_velocity_y)

		if impact_speed >= min_fall_speed_for_shake:
			add_trauma(clamp(impact_speed * landing_trauma_per_speed, 0.0, 1.0))
			jump_kick_offset = -jump_kick_amount * clamp(impact_speed / 10.0, 0.5, 1.5)

	was_on_floor = is_on_floor()


func _handle_crouch(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch")

	var target_height := standing_height

	if is_crouching:
		target_height = crouch_height

	current_height = move_toward(
		current_height,
		target_height,
		crouch_transition_speed * delta
	)

	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.height = current_height

	var height_difference := standing_height - current_height
	var target_camera_y := base_camera_height - height_difference * 0.5

	camera.position.y = lerp(
		camera.position.y,
		target_camera_y,
		crouch_transition_speed * delta
	)


func _handle_health_regen(delta: float) -> void:
	if health >= max_health:
		health = max_health
		regen_timer = 0.0
		return

	regen_timer += delta

	if regen_timer >= regen_delay:
		health = min(health + regen_rate * delta, max_health)


func _handle_animation() -> void:
	if not animation_player:
		return

	# Don't let locomotion override a hit-reaction / roll / death animation mid-play.
	if action_lock_timer > 0.0 or is_rolling:
		return

	if not is_on_floor():
		if velocity.y > 0.0:
			if _find_animation("jump") != "":
				_play_animation("jump")
			else:
				_play_animation("idle")
		else:
			if _find_animation("fall") != "":
				_play_animation("fall")
			else:
				_play_animation("idle")
		return

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_velocity.length()

	if is_crouching:
		if speed > 0.1:
			if _find_animation("crouch_walk") != "":
				_play_animation("crouch_walk")
			else:
				_play_animation("walk")
		else:
			if _find_animation("crouch") != "":
				_play_animation("crouch")
			else:
				_play_animation("idle")
		return

	if speed < 0.1:
		_play_animation("idle")
		return

	var sprinting := speed > walk_speed + 0.5

	if sprinting:
		# Pick a directional run clip based on input intent.
		if absf(last_input_vector.x) > absf(last_input_vector.y):
			if last_input_vector.x < 0.0:
				_play_animation("run_left")
			else:
				_play_animation("run_right")
		elif last_input_vector.y > 0.0:
			_play_animation("run_back")
		else:
			_play_animation("run")
	else:
		_play_animation("walk")


func _handle_camera(delta: float) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	var moving := horizontal_speed > 0.1

	var sprinting := (
		horizontal_speed > walk_speed + 0.5
		and not is_crouching
	)

	var target_fov := normal_fov

	if sprinting:
		target_fov = sprint_fov

	camera.fov = lerp(camera.fov, target_fov, fov_change_speed * delta)

	if moving and is_on_floor():
		var bob_multiplier := 1.0

		if sprinting:
			bob_multiplier = sprint_bob_multiplier

		head_bob_time += delta * head_bob_speed * bob_multiplier

		var bob_x := cos(head_bob_time * 0.5) * head_bob_amount
		var bob_y := sin(head_bob_time) * head_bob_amount
		var bob_position := Vector3(bob_x, bob_y, 0.0)

		camera.position = camera.position.lerp(
			base_camera_position + bob_position,
			12.0 * delta
		)

		# Footstep shake: fire a tiny trauma pulse each time the bob cycle
		# hits its low point (foot "plants"), for a real handheld-camera feel.
		var current_bob_sign := signf(bob_y)

		if current_bob_sign < 0.0 and last_bob_sign >= 0.0:
			var footstep_intensity := footstep_shake_amount

			if sprinting:
				footstep_intensity *= footstep_shake_sprint_multiplier

			add_trauma(footstep_intensity)

		last_bob_sign = current_bob_sign
	else:
		camera.position = camera.position.lerp(
			Vector3(base_camera_position.x, camera.position.y, camera.position.z),
			12.0 * delta
		)

		if not moving and is_on_floor():
			# Idle breathing sway — subtle, keeps the camera from feeling static.
			idle_sway_time += delta * idle_sway_speed
			camera.rotation.x += sin(idle_sway_time) * idle_sway_amount * delta
			camera.rotation.z += cos(idle_sway_time * 0.7) * idle_sway_amount * delta

	var target_tilt := 0.0

	if not is_crouching:
		target_tilt = -Input.get_axis("move_left", "move_right") * strafe_tilt

	camera.rotation.z = lerp(
		camera.rotation.z,
		deg_to_rad(target_tilt),
		tilt_speed * delta
	)


# --- Trauma-based camera shake (position + rotation, smooth via noise) ---
func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)


func _handle_trauma_shake(delta: float) -> void:
	if trauma <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return

	shake_time += delta * shake_noise_speed

	var shake_power := trauma * trauma

	var offset_x := max_shake_offset * shake_power * shake_noise.get_noise_2d(
		shake_time, shake_seed_offset.x
	)
	var offset_y := max_shake_offset * shake_power * shake_noise.get_noise_2d(
		shake_time, shake_seed_offset.y
	)
	var rot_z := deg_to_rad(max_shake_rotation) * shake_power * shake_noise.get_noise_2d(
		shake_time, shake_seed_offset.z
	)

	camera.h_offset = offset_x
	camera.v_offset = offset_y
	camera.rotation.z += rot_z

	trauma = max(trauma - trauma_decay * delta, 0.0)


func _handle_jump_kick(delta: float) -> void:
	jump_kick_offset = move_toward(jump_kick_offset, 0.0, 4.0 * delta)
	camera.position.y += jump_kick_offset * delta * 10.0


# --- Roll / dodge ---
func _handle_roll_input(delta: float) -> void:
	if not has_roll_input or is_dying:
		return

	if (
		not is_rolling
		and roll_cooldown_timer <= 0.0
		and is_on_floor()
		and Input.is_action_just_pressed("roll")
	):
		_start_roll()


func _start_roll() -> void:
	var input_vector := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)

	var dir := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()

	if dir.length() < 0.1:
		dir = -transform.basis.z.normalized()  # default: roll forward if no input

	roll_direction = dir
	is_rolling = true
	roll_timer = roll_duration
	roll_cooldown_timer = roll_cooldown

	add_trauma(0.15)
	_play_animation("roll", true)
	action_lock_timer = roll_duration


func _handle_roll_motion(delta: float) -> void:
	roll_timer -= delta

	velocity.x = roll_direction.x * roll_speed
	velocity.z = roll_direction.z * roll_speed

	if not is_on_floor():
		velocity.y -= gravity * delta

	if roll_timer <= 0.0:
		is_rolling = false
		add_trauma(0.1)


func take_damage(amount: float) -> void:
	if is_dying:
		return

	health -= amount
	health = max(health, 0.0)

	regen_timer = 0.0

	add_trauma(damage_trauma)
	_flash_damage()
	_play_hit_reaction()

	print("Player HP: %.1f" % health)

	if health <= 0.0:
		die()


func _play_hit_reaction() -> void:
	var anim_name := "hitrecieve_2" if randf() < 0.5 else "hitrecieve"
	_play_animation(anim_name, true)
	action_lock_timer = hit_react_lock_time


func _flash_damage() -> void:
	if not damage_flash_rect:
		return

	damage_flash_rect.color = damage_flash_color
	damage_flash_rect.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(
		damage_flash_rect,
		"modulate:a",
		0.0,
		damage_flash_time
	)


func launch(direction: Vector3, force: float, up_force: float) -> void:
	if is_dying:
		return

	var knockback_direction := direction.normalized()

	velocity.x = knockback_direction.x * force
	velocity.z = knockback_direction.z * force
	velocity.y = up_force

	regen_timer = 0.0
	add_trauma(0.3)

	print("Player launched!")


func die() -> void:
	if is_dying:
		return

	is_dying = true
	is_rolling = false
	velocity = Vector3.ZERO
	add_trauma(1.0)

	_play_animation("death", true)

	print("PLAYER DIED")

	await get_tree().create_timer(1.0).timeout

	get_tree().reload_current_scene()
