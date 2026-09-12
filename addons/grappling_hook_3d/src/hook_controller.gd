class_name HookController
extends Node
## Grappling hook controller.
## Fast, forgiving and arcade-like for the Level Zero jam.

signal hook_launched
signal hook_attached(body: Node3D)
signal hook_detached

@export_category("Required")
@export var hook_raycast: RayCast3D
@export var player_body: CharacterBody3D
@export var hook_source: Node3D
@export var hook_aim_assist: Node

@export_category("Input")
@export var launch_action_name: StringName = &"launch_grapple"
@export var retract_action_name: StringName = &"retract_grapple"

@export_category("Hook Feel")
@export_range(1.0, 50.0, 0.5)
var hook_range: float = 20.0

@export_range(0.0, 100.0, 0.5)
var pull_acceleration: float = 45.0

@export_range(0.0, 100.0, 0.5)
var max_pull_speed: float = 24.0

@export_range(0.1, 10.0, 0.1)
var stop_distance: float = 1.5

@export_category("Hook Visual")
@export var hook_scene: PackedScene = preload(
	"res://addons/grappling_hook_3d/src/hook.tscn"
)

var is_hook_launched := false

var _hook_model: Node3D
var _hook_target_node: Marker3D
var _hook_target_body: Node3D

var hook_target_normal := Vector3.ZERO


func _ready() -> void:
	if hook_raycast == null:
		push_error("HookController: Hook RayCast3D is not assigned.")

	if player_body == null:
		push_error("HookController: Player Body is not assigned.")

	if hook_scene == null:
		push_error("HookController: Hook scene is missing.")

	if not InputMap.has_action(launch_action_name):
		push_error(
			"HookController: Input action '%s' does not exist."
			% launch_action_name
		)

	if not InputMap.has_action(retract_action_name):
		push_warning(
			"HookController: Retract action '%s' does not exist."
			% retract_action_name
		)

	# Make sure the ray can reach our intended hook distance.
	if hook_raycast != null:
		hook_raycast.target_position = Vector3(0.0, 0.0, -hook_range)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(launch_action_name):
		toggle_hook()

	if (
		is_hook_launched
		and InputMap.has_action(retract_action_name)
		and Input.is_action_just_pressed(retract_action_name)
	):
		retract_hook()

	if is_hook_launched:
		_handle_hook(delta)


func toggle_hook() -> void:
	if is_hook_launched:
		retract_hook()
	else:
		launch_hook()


func launch_hook() -> void:
	if is_hook_launched:
		return

	var body: Node3D = null
	var hook_point := Vector3.ZERO
	var hook_normal := Vector3.ZERO

	# a) Prefer the precise hook ray. It must hit a hookable body.
	if hook_raycast != null and hook_raycast.is_colliding():
		var collider := hook_raycast.get_collider()

		if collider is Node3D and collider.is_in_group(&"hookable"):
			body = collider as Node3D
			hook_point = hook_raycast.get_collision_point()
			hook_normal = hook_raycast.get_collision_normal()

	# b) If the ray missed, let the aim assist pick the best hookable body.
	if (
		body == null
		and hook_aim_assist != null
		and hook_aim_assist.has_method(&"current_best_target")
	):
		hook_aim_assist.call(&"update_target")

		var assist_body: Variant = hook_aim_assist.call(&"current_best_target")

		if assist_body is Node3D:
			body = assist_body as Node3D
			hook_point = _aim_assist_hook_point(body)
			hook_normal = (hook_point - _hook_source_position()).normalized()

	# c) No valid hookable target, so do nothing.
	if body == null:
		return

	is_hook_launched = true
	_hook_target_body = body

	hook_target_normal = hook_normal

	# Create a target marker that follows the body, right where we aim to hook.
	_hook_target_node = Marker3D.new()
	_hook_target_node.name = "HookTarget"

	body.add_child(_hook_target_node)

	_hook_target_node.global_position = hook_point

	# Create the addon hook/rope model.
	if hook_scene:
		_hook_model = hook_scene.instantiate()
		add_child(_hook_model)

	hook_launched.emit()
	hook_attached.emit(body)


func _aim_assist_hook_point(body: Node3D) -> Vector3:
	# Anchor the rope a little short of the body center so the hook end rests
	# on the surface facing the player instead of floating at the exact center.
	var source := _hook_source_position()
	var to_body := body.global_position - source

	if to_body.length() < 0.001:
		return body.global_position

	return body.global_position - to_body.normalized() * _body_surface_offset(body)


func _body_surface_offset(body: Node3D) -> float:
	# Pull from the body's collision shape so large bodies still land the hook
	# near their surface. Fall back to a safe default for visual-only bodies.
	for child in body.get_children():
		if child is CollisionShape3D:
			var shape: Shape3D = (child as CollisionShape3D).shape

			if shape is BoxShape3D:
				return clampf((shape as BoxShape3D).size.length() * 0.5, 0.2, 2.0)

			if shape is SphereShape3D:
				return clampf((shape as SphereShape3D).radius, 0.2, 2.0)

			if shape is CapsuleShape3D:
				return clampf((shape as CapsuleShape3D).height * 0.5, 0.2, 2.0)

	return 0.6


func _hook_source_position() -> Vector3:
	if is_instance_valid(hook_source):
		return hook_source.global_position

	if player_body != null:
		return player_body.global_position

	return Vector3.ZERO


func retract_hook() -> void:
	if not is_hook_launched:
		return

	is_hook_launched = false

	if is_instance_valid(_hook_target_node):
		_hook_target_node.queue_free()

	if is_instance_valid(_hook_model):
		_hook_model.queue_free()

	_hook_target_node = null
	_hook_model = null
	_hook_target_body = null

	hook_target_normal = Vector3.ZERO

	hook_detached.emit()


func _handle_hook(delta: float) -> void:
	if not is_instance_valid(_hook_target_node):
		retract_hook()
		return

	if player_body == null:
		retract_hook()
		return

	var target_position := _hook_target_node.global_position
	var player_position := player_body.global_position

	var to_target := target_position - player_position
	var distance := to_target.length()

	# Close enough — don't keep slamming the player into the target.
	if distance <= stop_distance:
		_update_hook_visual()
		return

	var direction := to_target.normalized()

	# Strong arcade-style pull.
	player_body.velocity += (
		direction
		* pull_acceleration
		* delta
	)

	# Cap velocity so it stays controllable.
	var speed := player_body.velocity.length()

	if speed > max_pull_speed:
		player_body.velocity = (
			player_body.velocity.normalized()
			* max_pull_speed
		)

	_update_hook_visual()


func _update_hook_visual() -> void:
	if not is_instance_valid(_hook_model):
		return

	if not is_instance_valid(_hook_target_node):
		return

	var source_position := _hook_source_position()

	_hook_model.extend_from_to(
		source_position,
		_hook_target_node.global_position,
		hook_target_normal
	)
