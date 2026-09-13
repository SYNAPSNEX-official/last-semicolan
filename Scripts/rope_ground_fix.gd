extends Node

## Stabilizes the rope -> ground transition without overriding normal movement.

@export var floor_snap_distance := 0.8
@export var release_drop_velocity := 0.5

var player: CharacterBody3D
var grappling_hook: Node
var was_climbing := false

func _ready() -> void:
	player = get_node_or_null("../Player") as CharacterBody3D
	if player == null:
		return
	grappling_hook = player.get_node_or_null("GrapplingHook")
	player.floor_snap_length = floor_snap_distance
	process_priority = 100

func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var climbing := _is_climbing()

	if was_climbing and not climbing:
		if not player.is_on_floor():
			player.velocity.y = minf(player.velocity.y, -release_drop_velocity)
		player.apply_floor_snap()

	was_climbing = climbing

func _is_climbing() -> bool:
	if grappling_hook == null or not is_instance_valid(grappling_hook):
		return false
	if not grappling_hook.has_method("is_climbable"):
		return false
	return grappling_hook.is_climbable() and Input.is_action_pressed("climb")
