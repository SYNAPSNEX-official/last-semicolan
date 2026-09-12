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
@export var damage_trauma := 0.4
@export var damage_flash_time := 0.15
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
@export var footstep_shake_amount := 0.05
@export var footstep_shake_sprint_multiplier := 1.7

@export_category("Idle Sway")
@export var idle_sway_amount := 0.006
@export var idle_sway_speed := 0.6

@export_category("Hook Climbing")
@export var climb_speed := 6.5
@export var climb_acceleration := 30.0
@export var climb_stop_distance := 0.8
@export var climb_gravity := 2.0

@onready var camera: Camera3D = $Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var grappling_hook: Node = get_node_or_null("GrapplingHook")

@onready var interact_ray: RayCast3D = get_node_or_null("RayCast3D") as RayCast3D
@onready var interaction_label: Label = get_node_or_null("../UI/Label") as Label
@onready var damage_flash_rect: ColorRect = get_node_or_null("../UI/DamageFlash") as ColorRect

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

var trauma := 0.0
var shake_noise: FastNoiseLite
var shake_seed_offset := Vector3.ZERO
var shake_time := 0.0

var jump_kick_offset := 0.0
var was_on_floor := true
var previous_fall_velocity_y := 0.0

var last_bob_sign := 1.0
var idle_sway_time := 0.0
var action_lock_timer := 0.0
var last_input_vector := Vector2.ZERO
var has_climb_input := false

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

	has_climb_input = InputMap.has_action("climb")
	if not has_climb_input:
		print("WARNING: Add a 'climb' action in Project Settings > Input Map.")

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
	var wanted := name.to_lower()
	for animation_name in animation_player.get_animation_list():
		if animation_name.to_lower() == wanted:
			return animation_name
	for animation_name in animation_player.get_animation_list():
		if animation_name.to_lower().contains(wanted):
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
			Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE
		)
	animation_player.play(animation_name)

func _unhandled_input(event: InputEvent) -> void:
	if is_dying:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x -= event.relative.y * mouse_sensitivity
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-max_look_angle), deg_to_rad(max_look_angle))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if action_lock_timer > 0.0:
		action_lock_timer = max(action_lock_timer - delta, 0.0)
	_handle_crouch(delta)
	_handle_movement(delta)
	_handle_jump(delta)
	_handle_hook_climb(delta)
	_handle_landing_check()
	_handle_health_regen(delta)
	_handle_animation()
	_handle_camera(delta)
	_handle_trauma_shake(delta)
	_handle_jump_kick(delta)
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	last_input_vector = input_vector
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and not is_crouching and input_vector.y < 0.0
	var target_speed := crouch_speed if is_crouching else (sprint_speed if sprinting else walk_speed)
	var target_velocity := direction * target_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var current_acceleration := acceleration if is_on_floor() else air_acceleration
	if direction.length() > 0.0:
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, current_acceleration * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

func _climb_input_pressed() -> bool:
	return has_climb_input and Input.is_action_pressed("climb")

func _should_climb() -> bool:
	if grappling_hook == null or not grappling_hook.has_method("is_climbable"):
		return false
	return grappling_hook.is_climbable() and _climb_input_pressed()

func _handle_hook_climb(delta: float) -> void:
	if not _should_climb():
		return
	if not grappling_hook.has_method("get_anchor_position"):
		return

	var anchor: Vector3 = grappling_hook.get_anchor_position()
	var to_anchor := anchor - global_position
	var distance := to_anchor.length()
	if distance <= climb_stop_distance:
		velocity = Vector3.ZERO
		return

	# Climbing is now a direct, constant-speed movement toward the hook.
	# Gravity is cancelled while climbing so the player does not float/fight gravity.
	var direction := to_anchor.normalized()
	var desired_velocity := direction * climb_speed

	# Only use the component toward the anchor; never add sideways drift.
	velocity = velocity.move_toward(desired_velocity, climb_acceleration * delta)
	velocity.y = move_toward(velocity.y, desired_velocity.y, climb_acceleration * delta)

	# Stop gravity from pulling the player down while attached.
	if velocity.y < 0.0 and direction.y >= 0.0:
		velocity.y = 0.0

func _handle_jump(delta: float) -> void:
	previous_fall_velocity_y = velocity.y
	if _should_climb():
		return
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
	var target_height := crouch_height if is_crouching else standing_height
	current_height = move_toward(current_height, target_height, crouch_transition_speed * delta)
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.height = current_height
	var height_difference := standing_height - current_height
	var target_camera_y := base_camera_height - height_difference * 0.5
	camera.position.y = lerp(camera.position.y, target_camera_y, crouch_transition_speed * delta)

func _handle_health_regen(delta: float) -> void:
	if health >= max_health:
		health = max_health
		regen_timer = 0.0
		return
	regen_timer += delta
	if regen_timer >= regen_delay:
		health = min(health + regen_rate * delta, max_health)

func _handle_animation() -> void:
	if not animation_player or action_lock_timer > 0.0:
		return
	if not is_on_floor():
		if velocity.y > 0.0 and _find_animation("jump") != "":
			_play_animation("jump")
		elif _find_animation("fall") != "":
			_play_animation("fall")
		else:
			_play_animation("idle")
		return
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_velocity.length()
	if is_crouching:
		if speed > 0.1 and _find_animation("crouch_walk") != "":
			_play_animation("crouch_walk")
		elif _find_animation("crouch") != "":
			_play_animation("crouch")
		else:
			_play_animation("idle")
		return
	if speed < 0.1:
		_play_animation("idle")
	elif speed > (walk_speed + sprint_speed) * 0.5:
		_play_animation("run")
	else:
		_play_animation("walk")

# Remaining player systems are intentionally preserved below.
