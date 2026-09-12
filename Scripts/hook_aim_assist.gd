class_name HookAimAssist
extends Node
## Forgiving arcade-style hook aim assist.
## Tracks nearby "hookable" bodies and exposes the best one for the hook.
## No precise crosshair placement required.


@export_category("References")
@export var player_body: CharacterBody3D
@export var camera: Camera3D

@export_category("Aim Assist")
@export var search_radius := 20.0
@export_range(1.0, 90.0, 1.0) var aim_cone_degrees := 20.0
@export_range(0.0, 1.0, 0.01) var closeness_bias := 0.5

var _best_target: Node3D = null
var _best_score := -INF


func _ready() -> void:
	if player_body == null:
		push_error("HookAimAssist: Player Body is not assigned.")

	if camera == null:
		push_error("HookAimAssist: Camera is not assigned.")


func _physics_process(_delta: float) -> void:
	_update_target()


## Refreshes the target list and current best target. Cheap, safe to call any time.
func update_target() -> void:
	_update_target()


## The best hookable body currently aimed at, or null if there is none.
func current_best_target() -> Node3D:
	return _best_target


func _update_target() -> void:
	_best_target = null
	_best_score = -INF

	if player_body == null or camera == null:
		return

	var player_forward := -player_body.global_transform.basis.z
	var cam_transform := camera.global_transform
	var cam_pos := cam_transform.origin
	var cam_forward := -cam_transform.basis.z

	var min_alignment := cos(deg_to_rad(aim_cone_degrees))

	for node in get_tree().get_nodes_in_group(&"hookable"):
		if not node is Node3D:
			continue

		var body := node as Node3D
		var to_body := body.global_position - cam_pos
		var distance := to_body.length()

		if distance > search_radius:
			continue

		if distance <= 0.001:
			continue

		var direction := to_body / distance

		# Outside the crosshair cone -> reject.
		var alignment := cam_forward.dot(direction)
		if alignment < min_alignment:
			continue

		# Never target something behind the player.
		if player_forward.dot(direction) < 0.0:
			continue

		var closeness := 1.0 - (distance / search_radius)
		var score := alignment + closeness * closeness_bias

		if score > _best_score:
			_best_score = score
			_best_target = body
