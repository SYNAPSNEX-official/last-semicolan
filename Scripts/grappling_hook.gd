extends Node3D

@export_category("Hook")
@export var hook_range := 30.0
@export var hook_speed := 35.0
@export var launch_ease_time := 0.1
@export var hook_return_speed := 24.0
@export var return_ease_time := 0.08
@export var hit_tolerance := 2.5

@export_category("Projectile Physics")
@export var projectile_gravity := 15.0

@export_category("Enemy Launch")
@export var launch_force := 12.0
@export var launch_up_force := 4.0

@onready var camera: Camera3D = $"../Camera3D"
@onready var hook_origin: Marker3D = $HookOrigin
@onready var hook_projectile: MeshInstance3D = $HookProjectile
@onready var hook_ray: RayCast3D = $HookRay

enum HookState {
	READY,
	FLYING,
	ATTACHED,
	RETRACTING
}

var state := HookState.READY
var hooked_target: Node3D = null
var pending_collider: Object = null

var flight_start := Vector3.ZERO
var flight_direction := Vector3.ZERO
var flight_distance := 0.0
var flight_traveled := 0.0
var current_speed := 0.0
var flight_time := 0.0
var last_flight_position := Vector3.ZERO


func _ready() -> void:
	# The projectile lives in world space so it cannot be dragged off its
	# straight line by the player moving or rotating while it is in the air.
	hook_projectile.top_level = true
	hook_projectile.visible = false
	hook_ray.enabled = true
	hook_ray.add_exception(get_parent())


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		_handle_attack()

	match state:
		HookState.FLYING:
			_update_flight(delta)
		HookState.ATTACHED:
			_update_attached()
		HookState.RETRACTING:
			_update_return(delta)


func _handle_attack() -> void:
	match state:
		HookState.READY:
			_throw_hook()
		HookState.FLYING:
			_start_return()
		HookState.ATTACHED:
			_start_return()
		HookState.RETRACTING:
			pass


# ==================================================
# THROW
# ==================================================

func _throw_hook() -> void:
	state = HookState.FLYING
	hooked_target = null
	pending_collider = null

	# The CAMERA decides where the hook goes. HookOrigin is only the spawn point.
	var viewport_center := get_viewport().get_visible_rect().size / 2.0
	var aim_origin := camera.project_ray_origin(viewport_center)
	var aim_direction := camera.project_ray_normal(viewport_center)
	var aim_point := aim_origin + aim_direction * hook_range

	flight_start = hook_origin.global_position

	# Fixed direction, computed exactly once, from the hand to the aim point.
	var to_aim := flight_start.distance_to(aim_point)

	if to_aim < 0.001:
		flight_direction = Vector3.FORWARD
	else:
		flight_direction = (aim_point - flight_start) / to_aim

	# Collision is checked along THIS same line, so detection always matches the path.
	hook_ray.global_position = flight_start
	hook_ray.target_position = hook_ray.global_basis.inverse() * (flight_direction * to_aim)
	hook_ray.force_raycast_update()

	if hook_ray.is_colliding():
		flight_distance = flight_start.distance_to(hook_ray.get_collision_point())
		pending_collider = hook_ray.get_collider()
	else:
		flight_distance = to_aim

	flight_traveled = 0.0
	current_speed = 0.0
	flight_time = 0.0
	last_flight_position = flight_start

	hook_projectile.global_position = flight_start
	hook_projectile.visible = true


func _update_flight(delta: float) -> void:
	if current_speed < hook_speed:
		var ramp := hook_speed / maxf(launch_ease_time, 0.001)
		current_speed = minf(current_speed + ramp * delta, hook_speed)

	flight_time += delta
	flight_traveled += current_speed * delta

	var next_position := _projectile_position()
	var landing := _raycast_flight_landing(last_flight_position, next_position)

	if landing != null:
		hook_projectile.global_position = landing
		_hook_reached_target(landing)
		return

	if flight_traveled >= flight_distance:
		flight_traveled = flight_distance
		hook_projectile.global_position = _projectile_position()
		_hook_reached_target(hook_projectile.global_position)
		return

	hook_projectile.global_position = next_position
	last_flight_position = next_position


func _projectile_position() -> Vector3:
	var position := flight_start + flight_direction * flight_traveled
	position.y -= 0.5 * projectile_gravity * flight_time * flight_time
	return position


func _raycast_flight_landing(from: Vector3, to: Vector3):
	hook_ray.global_position = from
	hook_ray.target_position = hook_ray.global_basis.inverse() * (to - from)
	hook_ray.force_raycast_update()

	pending_collider = hook_ray.get_collider()

	if hook_ray.is_colliding():
		return hook_ray.get_collision_point()

	return null


func _hook_reached_target(landing: Vector3) -> void:
	var collider := pending_collider as Object
	if is_instance_valid(collider):
		var body := collider as Node3D

		if body.has_method("take_damage"):
			if body.global_position.distance_to(landing) <= hit_tolerance:
				hooked_target = body
				state = HookState.ATTACHED
				print("Hook attached to: ", body.name)
				pending_collider = null
				return

		# Solid surface: anchor the hook here.
		print("Hook hit surface")
		hooked_target = null
		pending_collider = null
		state = HookState.ATTACHED
		return

	# Nothing was hit, so reel the hook straight back in.
	print("Hook missed, retracting")
	hooked_target = null
	pending_collider = null
	state = HookState.RETRACTING
	current_speed = 0.0


func _update_attached() -> void:
	if is_instance_valid(hooked_target):
		hook_projectile.global_position = hooked_target.global_position
	else:
		hooked_target = null
		_start_return()


# ==================================================
# RETRACT
# ==================================================

func _start_return() -> void:
	if is_instance_valid(hooked_target):
		_launch_enemy()

	hooked_target = null
	state = HookState.RETRACTING
	current_speed = 0.0


func _update_return(delta: float) -> void:
	if current_speed < hook_return_speed:
		var ramp := hook_return_speed / maxf(return_ease_time, 0.001)
		current_speed = minf(current_speed + ramp * delta, hook_return_speed)

	var to_hand := hook_origin.global_position - hook_projectile.global_position
	var distance := to_hand.length()

	if distance <= 0.06:
		_finish_return()
		return

	hook_projectile.global_position += (to_hand / distance) * current_speed * delta

	if distance <= current_speed * delta:
		_finish_return()


func _finish_return() -> void:
	hook_projectile.global_position = hook_origin.global_position
	hook_projectile.visible = false
	state = HookState.READY
	print("Hook retracted")


# ==================================================
# ENEMY LAUNCH
# ==================================================

func _launch_enemy() -> void:
	var enemy := hooked_target
	if not (enemy is CharacterBody3D):
		return

	var direction := global_position.direction_to(enemy.global_position)
	direction.y = 0.0
	direction = direction.normalized()

	enemy.launch(direction, launch_force, launch_up_force)
