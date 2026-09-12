extends CharacterBody3D

@export_category("Health")
@export var max_health := 100.0

@export_category("Movement")
@export var walk_speed := 5.5
@export var sprint_speed := 10
@export var acceleration := 32.0
@export var deceleration := 40.0
@export var air_acceleration := 12.0
@export var jump_velocity := 7
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

@export_category("Animation")
@export var walk_anim_threshold := 0.2
@export var run_anim_threshold := 4.0


@onready var camera: Camera3D = $Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var anim_player: AnimationPlayer = $"mesh/AnimationPlayer"


var health: float

var head_bob_time := 0.0
var base_camera_position := Vector3.ZERO
var base_camera_height := 0.0

var current_height := 1.8
var is_crouching := false

var is_attacking := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	health = max_health

	base_camera_position = camera.position
	base_camera_height = camera.position.y

	camera.fov = normal_fov

	if collision_shape.shape is CapsuleShape3D:
		current_height = collision_shape.shape.height

	anim_player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	anim_player.get_animation(&"Walk").loop_mode = Animation.LOOP_LINEAR
	anim_player.get_animation(&"Run").loop_mode = Animation.LOOP_LINEAR
	anim_player.animation_finished.connect(_on_animation_finished)
	anim_player.play(&"Idle")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Gun_Shoot":
		is_attacking = false


func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)

			camera.rotation.x -= event.relative.y * mouse_sensitivity

			camera.rotation.x = clamp(
				camera.rotation.x,
				deg_to_rad(-max_look_angle),
				deg_to_rad(max_look_angle)
			)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_handle_crouch(delta)
	_handle_movement(delta)
	_handle_jump(delta)
	_handle_camera(delta)
	_handle_animation()

	move_and_slide()


# ==================================================
# MOVEMENT
# ==================================================

func _handle_movement(delta: float) -> void:

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

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

	var horizontal_velocity := Vector3(
		velocity.x,
		0.0,
		velocity.z
	)

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


# ==================================================
# JUMP + GRAVITY
# ==================================================

func _handle_jump(delta: float) -> void:

	if not is_on_floor():
		velocity.y -= gravity * delta
		return

	# Hold Space = automatically jump whenever we land.
	if Input.is_action_pressed("jump") and not is_crouching:
		velocity.y = jump_velocity
	else:
		velocity.y = 0.0


# ==================================================
# CROUCH
# ==================================================

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

	var target_camera_y := (
		base_camera_height -
		height_difference * 0.5
	)

	camera.position.y = lerp(
		camera.position.y,
		target_camera_y,
		crouch_transition_speed * delta
	)


# ==================================================
# CAMERA
# ==================================================

func _handle_camera(delta: float) -> void:

	var horizontal_velocity := Vector3(
		velocity.x,
		0.0,
		velocity.z
	)

	var horizontal_speed := horizontal_velocity.length()

	var moving := horizontal_speed > 0.1

	var sprinting := (
		horizontal_speed > walk_speed + 0.5
		and not is_crouching
	)

	# ------------------------------
	# FOV
	# ------------------------------

	var target_fov := normal_fov

	if sprinting:
		target_fov = sprint_fov

	camera.fov = lerp(
		camera.fov,
		target_fov,
		fov_change_speed * delta
	)

	# ------------------------------
	# Head bob
	# ------------------------------

	if moving and is_on_floor():

		var bob_multiplier := 1.0

		if sprinting:
			bob_multiplier = sprint_bob_multiplier

		head_bob_time += (
			delta *
			head_bob_speed *
			bob_multiplier
		)

		var bob_x := (
			cos(head_bob_time * 0.5) *
			head_bob_amount
		)

		var bob_y := (
			sin(head_bob_time) *
			head_bob_amount
		)

		var bob_position := Vector3(
			bob_x,
			bob_y,
			0.0
		)

		camera.position = camera.position.lerp(
			base_camera_position + bob_position,
			12.0 * delta
		)

	else:

		camera.position = camera.position.lerp(
			Vector3(
				base_camera_position.x,
				camera.position.y,
				base_camera_position.z
			),
			12.0 * delta
		)

	# ------------------------------
	# Strafe tilt
	# ------------------------------

	var target_tilt := 0.0

	if not is_crouching:
		target_tilt = -Input.get_axis(
			"move_left",
			"move_right"
		) * strafe_tilt

	camera.rotation.z = lerp(
		camera.rotation.z,
		deg_to_rad(target_tilt),
		tilt_speed * delta
	)

# ==================================================
# ANIMATION
# ==================================================

func _handle_animation() -> void:
	if Input.is_action_just_pressed("attack"):
		_play_attack_animation()

	if is_attacking:
		return

	var speed := Vector2(velocity.x, velocity.z).length()

	var target_anim := &"Idle"

	if speed > run_anim_threshold:
		target_anim = &"Run"
	elif speed > walk_anim_threshold:
		target_anim = &"Walk"

	if anim_player.current_animation != target_anim:
		anim_player.play(target_anim)


func _play_attack_animation() -> void:
	anim_player.play(&"Gun_Shoot")
	is_attacking = true

# ==================================================
# HEALTH
# ==================================================

func take_damage(amount: float) -> void:
	health -= amount
	health = max(health, 0.0)
	print("Player HP: ", health)

	if health <= 0.0:
		die()

func die() -> void:
	print("Player died")
	get_tree().reload_current_scene()
