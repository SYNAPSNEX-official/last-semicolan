extends CharacterBody3D

@export_category("Health")
@export var max_health := 80

@export_category("Movement")
@export var move_speed := 3.2
@export var detection_range := 12.0
@export var attack_range := 1.6
@export var gravity := 15.0

@export_category("Attack")
@export var attack_damage := 10.0
@export var attack_cooldown := 1.0

@export_category("Dash")
@export var dash_enabled := true
@export var dash_range := 10.0
@export var dash_speed := 16.0
@export var dash_damage := 20.0
@export var dash_cooldown := 5.0
@export var dash_charge_time := 0.8
@export var dash_duration := 0.6
@export var dash_min_distance := 3.0

@export_category("Shockwave")
@export var shockwave_enabled := true
@export var shockwave_range := 4.0
@export var shockwave_damage := 18.0
@export var shockwave_cooldown := 6.0
@export var shockwave_knockback := 8.0

@export_category("Enrage")
@export var enrage_enabled := true
@export var enrage_health_percent := 0.35
@export var enrage_speed_multiplier := 1.5
@export var enrage_damage_multiplier := 1.4

const _ANIM_IDLE := &"iddle"
const _ANIM_WALK := &"walking"
const _ANIM_ATTACK := &"attackwithhand"
const _ANIM_DASH := &"attackspin"

var health: float
var player: Node3D

var attack_timer := 0.0
var knockback_timer := 0.0

var dash_timer := 0.0
var dash_charge_timer := 0.0
var dash_time := 0.0
var is_dashing := false
var dash_direction := Vector3.ZERO

var shockwave_timer := 0.0

var is_enraged := false
var is_dead := false

var anim_player: AnimationPlayer
var _anim_locked := false
var _pulse_tween: Tween
var _ground_placed := false
var _ground_tries := 0


func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")

	_setup_animations()


func _physics_process(delta: float) -> void:
	if is_dead or not is_inside_tree():
		return

	if not _ground_placed:
		_place_on_ground()

	if not is_instance_valid(player):
		_find_player()

	if not is_instance_valid(player):
		_apply_gravity(delta)
		move_and_slide()
		return

	_apply_gravity(delta)
	_update_timers(delta)

	if knockback_timer > 0.0:
		_handle_knockback(delta)
		move_and_slide()
		return

	if is_dashing:
		_handle_dash(delta)
		move_and_slide()
		return

	if dash_charge_timer > 0.0:
		_handle_dash_charge(delta)
		move_and_slide()
		return

	var distance := global_position.distance_to(
		player.global_position
	)

	_update_enrage()

	# Close range attack
	if distance <= attack_range:
		_attack_player()

	# Shockwave
	elif (
		shockwave_enabled
		and distance <= shockwave_range
		and shockwave_timer <= 0.0
	):
		_shockwave()

	# Dash
	elif (
		dash_enabled
		and distance <= dash_range
		and distance > dash_min_distance
		and dash_timer <= 0.0
		and dash_charge_timer <= 0.0
	):
		_start_dash()

	# Chase
	elif distance <= detection_range:
		_chase_player()

	else:
		_stop_moving()

	move_and_slide()
	_play_state_anim()


func _update_timers(delta: float) -> void:
	attack_timer = max(
		attack_timer - delta,
		0.0
	)

	dash_timer = max(
		dash_timer - delta,
		0.0
	)

	shockwave_timer = max(
		shockwave_timer - delta,
		0.0
	)

	if knockback_timer > 0.0:
		knockback_timer -= delta


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")


func _place_on_ground() -> void:
	_ground_tries += 1

	var from := global_position + Vector3(0, 25, 0)
	var to := from + Vector3(0, -300, 0)

	var query := PhysicsRayQueryParameters3D.create(
		from,
		to
	)

	query.exclude = [get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(
		query
	)

	if hit.is_empty():
		if _ground_tries >= 30:
			_ground_placed = true

		return

	_ground_placed = true
	global_position.y = hit.position.y + 0.15


# =========================================================
# ANIMATION
# =========================================================

func _setup_animations() -> void:
	var robot_model := get_node_or_null("robot2") as Node3D

	if robot_model == null:
		return

	for child in robot_model.find_children(
		"*",
		"AnimationPlayer",
		true,
		false
	):
		anim_player = child as AnimationPlayer
		break

	if anim_player == null:
		return

	for anim in [_ANIM_IDLE, _ANIM_WALK]:
		if anim_player.has_animation(anim):
			anim_player.get_animation(
				anim
			).loop_mode = Animation.LOOP_LINEAR

	for anim in [_ANIM_ATTACK, _ANIM_DASH]:
		if anim_player.has_animation(anim):
			anim_player.get_animation(
				anim
			).loop_mode = Animation.LOOP_NONE

	anim_player.animation_finished.connect(
		_on_animation_finished
	)

	if anim_player.has_animation(_ANIM_IDLE):
		anim_player.play(_ANIM_IDLE)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name in [_ANIM_ATTACK, _ANIM_DASH]:
		_anim_locked = false
		_play_state_anim()


func _play_state_anim() -> void:
	if anim_player == null or _anim_locked:
		return

	var speed := Vector2(
		velocity.x,
		velocity.z
	).length()

	if speed > 0.3:
		_play_enemy_anim(_ANIM_WALK)
	else:
		_play_enemy_anim(_ANIM_IDLE)


func _play_enemy_anim(anim_name: StringName) -> void:
	if anim_player == null or not anim_player.has_animation(
		anim_name
	):
		return

	if (
		anim_player.current_animation == anim_name
		and anim_player.is_playing()
	):
		return

	if _anim_locked:
		_anim_locked = false

	anim_player.play(anim_name)


func _play_anim_once(anim_name: StringName) -> void:
	if anim_player == null or _anim_locked:
		return

	if not anim_player.has_animation(anim_name):
		return

	_anim_locked = true
	anim_player.play(anim_name)


# =========================================================
# MOVEMENT
# =========================================================

func _chase_player() -> void:
	var direction := global_position.direction_to(
		player.global_position
	)

	direction.y = 0.0

	if direction.length_squared() <= 0.01:
		return

	direction = direction.normalized()

	var speed := move_speed

	if is_enraged:
		speed *= enrage_speed_multiplier

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	_face_direction(direction)


func _stop_moving() -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		20.0 * get_physics_process_delta_time()
	)

	velocity.z = move_toward(
		velocity.z,
		0.0,
		20.0 * get_physics_process_delta_time()
	)


# =========================================================
# NORMAL ATTACK
# =========================================================

func _attack_player() -> void:
	_stop_moving()

	var direction := global_position.direction_to(
		player.global_position
	)

	direction.y = 0.0

	if direction.length_squared() > 0.01:
		_face_direction(direction.normalized())

	if attack_timer > 0.0:
		return

	attack_timer = attack_cooldown

	if player.get("is_dying") == true:
		return

	_play_anim_once(_ANIM_ATTACK)

	var damage := attack_damage

	if is_enraged:
		damage *= enrage_damage_multiplier

	if player.has_method("take_damage"):
		player.take_damage(damage)

	print("ROBOT ATTACK: ", damage)


# =========================================================
# DASH
# =========================================================

func _start_dash() -> void:
	if not is_instance_valid(player):
		return

	dash_direction = global_position.direction_to(
		player.global_position
	)

	dash_direction.y = 0.0

	if dash_direction.length_squared() <= 0.01:
		return

	dash_direction = dash_direction.normalized()

	dash_charge_timer = dash_charge_time

	_stop_moving()
	_face_direction(dash_direction)

	print("⚡ ROBOT CHARGING DASH!")


func _handle_dash_charge(delta: float) -> void:
	_stop_moving()

	_play_enemy_anim(_ANIM_IDLE)

	_face_direction(dash_direction)

	dash_charge_timer -= delta

	if dash_charge_timer <= 0.0:
		is_dashing = true
		dash_time = 0.0
		dash_timer = dash_cooldown

		_play_anim_once(_ANIM_DASH)

		print("⚡ ROBOT DASH!")


func _handle_dash(delta: float) -> void:
	dash_time += delta

	if dash_time >= dash_duration:
		is_dashing = false
		velocity.x = 0.0
		velocity.z = 0.0
		return

	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed

	var distance := global_position.distance_to(
		player.global_position
	)

	if distance <= 1.8:
		var damage := dash_damage

		if is_enraged:
			damage *= enrage_damage_multiplier

		if player.has_method("take_damage"):
			player.take_damage(damage)

		print("💥 DASH HIT!")

		is_dashing = false
		velocity.x = 0.0
		velocity.z = 0.0

	if is_on_wall():
		is_dashing = false
		velocity.x = 0.0
		velocity.z = 0.0


# =========================================================
# SHOCKWAVE
# =========================================================

func _shockwave() -> void:
	shockwave_timer = shockwave_cooldown

	_stop_moving()
	_pulse_model(0.12)

	var distance := global_position.distance_to(
		player.global_position
	)

	if distance > shockwave_range:
		return

	var direction := global_position.direction_to(
		player.global_position
	)

	direction.y = 0.0

	var damage := shockwave_damage

	if is_enraged:
		damage *= enrage_damage_multiplier

	if player.has_method("take_damage"):
		player.take_damage(damage)

	if player.has_method("launch"):
		player.launch(
			direction,
			shockwave_knockback,
			3.0
		)

	print("💥 ROBOT SHOCKWAVE!")


# =========================================================
# DAMAGE
# =========================================================

func take_damage(amount: float) -> void:
	if is_dead:
		return

	_pulse_model(0.1)

	health = maxf(
		health - amount,
		0.0
	)

	print(
		"Enemy HP: ",
		health,
		" / ",
		max_health
	)

	if health <= 0.0:
		die()


# =========================================================
# HOOK KNOCKBACK
# =========================================================

func launch(
	direction: Vector3,
	force: float,
	up_force: float
) -> void:
	if is_dead:
		return

	velocity = (
		direction.normalized() * force
		+ Vector3.UP * up_force
	)

	knockback_timer = 0.6

	take_damage(20)

	is_dashing = false
	dash_charge_timer = 0.0

	print("🪝 Enemy launched!")
	print("HP: ", health)


func _handle_knockback(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		5.0 * delta
	)

	velocity.z = move_toward(
		velocity.z,
		0.0,
		5.0 * delta
	)


# =========================================================
# ENRAGE
# =========================================================

func _update_enrage() -> void:
	if not enrage_enabled or is_enraged:
		return

	if health <= max_health * enrage_health_percent:
		is_enraged = true

		print("🔥 ROBOT ENRAGED!")


# =========================================================
# HELPERS
# =========================================================

func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.01:
		return

	look_at(
		global_position + direction,
		Vector3.UP
	)


func _pulse_model(amount: float) -> void:
	if is_dead:
		return

	var model := get_node_or_null("robot2") as Node3D

	if model == null:
		return

	if _pulse_tween:
		_pulse_tween.kill()

	var base_scale: Vector3 = model.scale

	_pulse_tween = create_tween()

	_pulse_tween.tween_property(
		model,
		"scale",
		base_scale * (1.0 + amount),
		0.08
	)

	_pulse_tween.tween_property(
		model,
		"scale",
		base_scale,
		0.18
	)


func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
		return

	velocity.y -= gravity * delta


func die() -> void:
	if is_dead:
		return

	is_dead = true

	print("🤖 ROBOT DESTROYED!")

	if anim_player:
		anim_player.stop()

	var model := get_node_or_null("robot2") as Node3D

	if _pulse_tween:
		_pulse_tween.kill()

	if model:
		var tween := create_tween()

		tween.set_parallel()

		tween.tween_property(
			model,
			"scale",
			Vector3.ZERO,
			0.3
		)

		tween.chain().tween_callback(
			queue_free
		)
	else:
		queue_free()
