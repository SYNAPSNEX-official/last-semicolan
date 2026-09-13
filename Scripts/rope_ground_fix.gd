extends Node

## Keeps the player from hovering slightly above the floor after rope climbing.
## This runs after the player physics step and only affects the rope -> ground transition.

@export var floor_snap_distance := 0.9
@export var release_drop_velocity := 0.35

var player: CharacterBody3D
var grappling_hook: Node
var was_climbing := false


func _ready() -> void:
	player = get_node_or_null("../Player") as CharacterBody3D
	if player == null:
		return

	grappling_hook = player.get_node_or_null("GrapplingHook")
	player.floor_snap_length = floor_snap_distance

	# Run after the player's own _physics_process/move_and_slide().
	process_priority = 100


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var climbing := _is_climbing()

	# A rope climb can finish with zero vertical velocity at the anchor.
	# Give the player a tiny downward velocity so CharacterBody3D can settle.
	if was_climbing and not climbing and not player.is_on_floor():
		if player.velocity.y >= 0.0:
			player.velocity.y = -release_drop_velocity
		player.apply_floor_snap()

	# Also catch the common case where the player reaches a climb endpoint
	# just above a floor and releases the climb on that same frame.
	if not climbing and not player.is_on_floor() and player.velocity.y <= 0.0:
		player.apply_floor_snap()

	was_climbing = climbing


func _is_climbing() -> bool:
	if grappling_hook == null or not is_instance_valid(grappling_hook):
		return false
	if not grappling_hook.has_method("is_climbable"):
		return false
	if not grappling_hook.is_climbable():
		return false
	return Input.is_action_pressed("climb")
