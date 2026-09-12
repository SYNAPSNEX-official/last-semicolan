extends Node

## Lightweight runtime performance manager for the jam's low-end target.
## Keeps nearby enemies fully active and lets distant enemies stop simulating.
## Enemy meshes are also given a visibility range so distant robots stop rendering.

@export_category("Enemy Culling")
@export var full_simulation_distance := 35.0
@export var render_distance := 55.0
@export var check_interval := 0.5

var _timer := 0.0
var _player: Node3D
var _enemy_states: Dictionary = {}


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_apply_enemy_render_ranges()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return

	_timer = check_interval

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if not is_instance_valid(_player):
		return

	_update_enemy_simulation()


func _update_enemy_simulation() -> void:
	var enemy_root := get_node_or_null("../enemies")
	if enemy_root == null:
		return

	for enemy_node in enemy_root.get_children():
		var enemy := enemy_node as CharacterBody3D
		if enemy == null:
			continue

		var distance := enemy.global_position.distance_to(_player.global_position)
		var should_simulate := distance <= full_simulation_distance
		var instance_id := enemy.get_instance_id()

		if _enemy_states.get(instance_id, true) == should_simulate:
			continue

		_enemy_states[instance_id] = should_simulate
		enemy.set_physics_process(should_simulate)

		if not should_simulate:
			enemy.velocity = Vector3.ZERO


func _apply_enemy_render_ranges() -> void:
	var enemy_root := get_node_or_null("../enemies")
	if enemy_root == null:
		return

	for enemy in enemy_root.get_children():
		if not is_instance_valid(enemy):
			continue

		_set_geometry_visibility_range(enemy)


func _set_geometry_visibility_range(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = render_distance
		geometry.visibility_range_end_margin = 5.0
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	for child in node.get_children():
		_set_geometry_visibility_range(child)
