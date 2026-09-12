extends Node3D

## Physical grappling hook (TOOL / WEAPON).
##
## Fires a real RigidBody3D projectile with momentum and gravity. The hook
## attaches to surfaces or targets on impact and never pulls the player by
## itself. Optional climbing is steered from the Player script via
## is_attached()/get_anchor_position().
##
## States: READY -> FIRED -> ATTACHED -> RETRACTING -> READY
## Left click (action "attack"): fire / retrieve.

@export_category("Hook")
@export var hook_speed := 34.0
@export var hook_range := 30.0
@export var hook_retract_speed := 20.0
@export var flight_timeout := 2.5
@export var impact_stop_threshold := 0.9

@export_category("Enemy Launch")
@export var launch_force := 12.0
@export var launch_up_force := 4.0

enum HookState {
	READY,
	FIRED,
	ATTACHED,
	RETRACTING,
}

var state := HookState.READY
var surface_anchor := false
var hooked_target: Node3D = null
var surface_body: Node3D = null

## Group name that marks a surface as climbable via the Player's climb input.
## Level designers add this group to StaticBody3D (or other) colliders.
const CLIMBABLE_GROUP := "climbable"

var _player: Node3D = null
var _camera: Camera3D = null
var _hook_origin: Marker3D = null
var _projectile: RigidBody3D = null
var _rope: Node3D = null

var _fire_origin := Vector3.ZERO
var _fired_timer := 0.0
var _fired_distance := 0.0
var _rest_check_timer := 0.0
var _retract_timer := 0.0
var _last_target_position := Vector3.INF


func _ready() -> void:
	_player = get_parent() as Node3D
	_camera = get_node_or_null("../Camera3D") as Camera3D
	_hook_origin = get_node_or_null("HookOrigin") as Marker3D
	_projectile = get_node_or_null("HookProjectile") as RigidBody3D
	_rope = get_node_or_null("Path3D")

	if _projectile == null:
		push_error("[Hook] Missing HookProjectile (RigidBody3D) child.")
		return

	_projectile.contact_monitor = true
	_projectile.max_contacts_reported = 8
	_projectile.can_sleep = false
	_projectile.freeze = true
	_projectile.top_level = true  # WORLD-SPACE body: never inherits camera/player motion
	_projectile.visible = false

	if _player is CollisionObject3D:
		_projectile.add_collision_exception_with(_player)

	if _rope == null:
		push_warning("[Hook] No 'Path3D' rope node attached; rope visuals disabled.")

	_projectile.body_entered.connect(_on_projectile_body_entered)


func _physics_process(delta: float) -> void:
	if _projectile == null:
		return

	match state:
		HookState.FIRED:
			_update_fired(delta)
		HookState.ATTACHED:
			_update_attached()
		HookState.RETRACTING:
			_update_retract(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack"):
		return

	match state:
		HookState.READY:
			fire()
		HookState.FIRED, HookState.ATTACHED:
			_start_retract()
		HookState.RETRACTING:
			pass  # ignore duplicate inputs while retracting


# ================================================================
# PUBLIC API (Player / future systems)
# ================================================================

func is_attached() -> bool:
	return state == HookState.ATTACHED


func is_climbable() -> bool:
	## True when the hook is embedded in a surface marked with the
	## "climbable" group. Only then does the player's climb input pull.
	return (
		state == HookState.ATTACHED
		and surface_anchor
		and is_instance_valid(surface_body)
		and surface_body.is_in_group(CLIMBABLE_GROUP)
	)


func is_busy() -> bool:
	return state != HookState.READY


func get_anchor_position() -> Vector3:
	if is_instance_valid(hooked_target):
		return hooked_target.global_position
	if _projectile != null:
		return _projectile.global_position
	return Vector3.ZERO


# ================================================================
# FIRING
# ================================================================

func fire() -> void:
	if state != HookState.READY or _projectile == null:
		return

	var direction := _aim_direction()

	_fire_origin = _origin_position()
	_projectile.global_position = _fire_origin
	_projectile.rotation = Vector3(0.0, atan2(direction.x, direction.z), 0.0)
	_projectile.freeze = false
	_projectile.visible = true
	_projectile.linear_velocity = direction * hook_speed
	_projectile.angular_velocity = Vector3.ZERO

	hooked_target = null
	surface_body = null
	surface_anchor = false
	_last_target_position = Vector3.INF
	_fired_timer = 0.0
	_fired_distance = 0.0
	_rest_check_timer = 0.0

	state = HookState.FIRED
	print("[HOOK] Fired: ", direction)

func _aim_direction() -> Vector3:
	var from := _origin_position()
	var direction := Vector3.FORWARD

	if _camera != null:
		var center := get_viewport().get_visible_rect().size * 0.5
		var aim_origin := _camera.project_ray_origin(center)
		var aim_normal := _camera.project_ray_normal(center)
		var aim_point := aim_origin + aim_normal * 100.0
		var shot := aim_point - from

		if shot.length_squared() > 0.001:
			direction = shot.normalized()
	elif _player != null:
		direction = -_player.global_transform.basis.z

	return direction


func _update_fired(delta: float) -> void:
	_fired_timer += delta
	_fired_distance = maxf(
		_fired_distance,
		_fire_origin.distance_to(_projectile.global_position)
	)
	_rest_check_timer += delta

	# Timed out or flew past the effective range: reel straight back in.
	if _fired_timer >= flight_timeout or _fired_distance > hook_range:
		_start_retract()
		return

	# The projectile lost its momentum (impact without an event, stuck, or
	# rolled to a stop) after leaving the hand: treat it as a surface hit.
	# A gentle gravity arc never drops below the threshold mid-flight.
	if (
		_rest_check_timer >= 0.12
		and _projectile.linear_velocity.length() < impact_stop_threshold
		and _fired_distance > 0.8
	):
		_rest_check_timer = 0.0
		_attach_surface(_projectile.global_position)


func _on_projectile_body_entered(body: Node) -> void:
	if state != HookState.FIRED or not is_instance_valid(body):
		return
	if body == _player:
		return

	var node := body as Node3D
	if node == null:
		return

	if _is_hook_target(node):
		_hook_target_response(node)
		_attach_target(node)
	else:
		print("[HOOK] hit body: ", node.name, " at ", _projectile.global_position)
		_attach_surface(_projectile.global_position, node)


# ================================================================
# TARGETS (modular: robots, levers, switches, cables, generators, ...)
# ================================================================

func _is_hook_target(node: Node3D) -> bool:
	if node.is_in_group("hookable"):
		return true
	if node.has_method("take_damage"):
		return true

	# Future target types should be added as groups (robots, levers,
	# switches, cables, generators, movable objects, ...).
	return false


func _hook_target_response(node: Node3D) -> void:
	# Extension point: targets may react immediately when hooked.
	if node.has_method("on_hooked_by_hook"):
		node.on_hooked_by_hook()


func _attach_target(target: Node3D) -> void:
	_projectile.freeze = true
	_projectile.linear_velocity = Vector3.ZERO
	_projectile.angular_velocity = Vector3.ZERO
	_projectile.global_position = target.global_position
	hooked_target = target
	surface_body = null
	surface_anchor = false
	_last_target_position = target.global_position
	state = HookState.ATTACHED
	print("[HOOK] Attached to target: ", target.name)


func _attach_surface(point: Vector3, body: Node3D = null) -> void:
	_projectile.freeze = true
	_projectile.linear_velocity = Vector3.ZERO
	_projectile.angular_velocity = Vector3.ZERO
	_projectile.global_position = point
	hooked_target = null
	surface_body = body
	surface_anchor = true
	state = HookState.ATTACHED
	print("[HOOK] Attached to surface at ", point)


func _update_attached() -> void:
	if is_instance_valid(hooked_target):
		var dead_state: Variant = hooked_target.get("is_dead")
		if dead_state is bool and dead_state:
			_start_retract()
			return

		# Only follow a moving target (robots, launched bodies); the parked
		# body never churns every frame otherwise. The rope reads the projectile
		# position directly, so the visual stays attached to the hook point.
		var position_now: Vector3 = hooked_target.global_position
		if position_now.distance_to(_last_target_position) > 0.004:
			_projectile.global_position = position_now
			_last_target_position = position_now
	elif surface_anchor:
		pass  # frozen WORLD-SPACE projectile parked at the anchor point
	else:
		_start_retract()


# ================================================================
# RETRACTING
# ================================================================

func _start_retract() -> void:
	if state == HookState.RETRACTING:
		return

	# Enemies are knocked back when the hook is pulled out (combat behavior).
	if is_instance_valid(hooked_target) and hooked_target is CharacterBody3D:
		_launch_enemy(hooked_target as CharacterBody3D)

	# Modular: targets may clean up when the hook detaches.
	if (
		is_instance_valid(hooked_target)
		and hooked_target.has_method("on_hook_released")
	):
		hooked_target.on_hook_released()

	hooked_target = null
	surface_body = null
	surface_anchor = false
	state = HookState.RETRACTING
	_retract_timer = 0.0

	if _projectile != null:
		_projectile.freeze = true
		_projectile.linear_velocity = Vector3.ZERO
		_projectile.angular_velocity = Vector3.ZERO

	print("[HOOK] Retracting")


func _update_retract(delta: float) -> void:
	var target := _origin_position()
	var to_hand := target - _projectile.global_position
	var distance := to_hand.length()

	if distance <= 0.08:
		_finish_return()
		return

	_retract_timer += delta
	var speed := hook_retract_speed * clampf(_retract_timer / 0.12, 0.0, 1.0)
	var step := speed * delta

	if step >= distance:
		_projectile.global_position = target
		_finish_return()
	else:
		_projectile.global_position += (to_hand / distance) * step


func _finish_return() -> void:
	_projectile.global_position = _origin_position()
	_projectile.visible = false
	hooked_target = null
	surface_body = null
	surface_anchor = false
	state = HookState.READY
	print("[HOOK] Ready")


func _origin_position() -> Vector3:
	if _hook_origin != null:
		return _hook_origin.global_position
	return global_position


# ================================================================
# ENEMY LAUNCH (preserved from the previous hook)
# ================================================================

func _launch_enemy(enemy: CharacterBody3D) -> void:
	var direction := global_position.direction_to(enemy.global_position)
	direction.y = 0.0
	direction = direction.normalized()
	enemy.launch(direction, launch_force, launch_up_force)
