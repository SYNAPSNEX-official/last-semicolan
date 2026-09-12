extends CharacterBody3D

@export_category("Health")
@export var max_health := 100.0

@export_category("Movement")
@export var move_speed := 2.5
@export var detection_range := 12.0
@export var attack_range := 1.6
@export var gravity := 15.0

@export_category("Attack")
@export var attack_damage := 10.0
@export var attack_cooldown := 1.0

var health: float
var player: Node3D
var attack_timer := 0.0
var knockback_timer := 0.0
var is_dead := false


func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if is_dead or not is_inside_tree():
		return

	_apply_gravity(delta)

	if attack_timer > 0.0:
		attack_timer -= delta

	if knockback_timer > 0.0:
		knockback_timer -= delta

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

		move_and_slide()
		return

	if player == null:
		_find_player()
		move_and_slide()
		return

	var distance := global_position.distance_to(
		player.global_position
	)

	if distance <= attack_range:
		_attack_player()
	elif distance <= detection_range:
		_chase_player()
	else:
		_stop_moving()

	if not is_inside_tree():
		return

	move_and_slide()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")


func _chase_player() -> void:
	var direction := global_position.direction_to(
		player.global_position
	)

	direction.y = 0.0
	direction = direction.normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

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

	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

	print("Enemy attacked player for ", attack_damage, " damage!")


func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.01:
		return

	look_at(
		global_position + direction,
		Vector3.UP
	)


func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
		return

	velocity.y -= gravity * delta


func take_damage(amount: float) -> void:
	health -= amount
	print("Enemy HP: ", health)

	if health <= 0.0:
		die()


func launch(direction: Vector3, force: float, up_force: float) -> void:
	velocity = (
		direction.normalized() * force
		+ Vector3.UP * up_force
	)

	knockback_timer = 0.6
	take_damage(20)
	print("Enemy launched!")
	print(health)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	queue_free()
