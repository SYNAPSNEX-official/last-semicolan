extends Node3D

const PerformanceManager := preload("res://Scripts/performance_manager.gd")
const RopeGroundFix := preload("res://Scripts/rope_ground_fix.gd")


func _ready() -> void:
	var terrain := get_node_or_null("Terrain3D")
	if terrain != null:
		terrain.add_to_group("climbable")

	var performance_manager := PerformanceManager.new()
	performance_manager.name = "PerformanceManager"
	add_child(performance_manager)

	var rope_ground_fix := RopeGroundFix.new()
	rope_ground_fix.name = "RopeGroundFix"
	add_child(rope_ground_fix)

	_place_player_on_terrain()


## The Terrain3D collider can lag behind the first physics frames; a player
## that spawns inside a hill then falls through before depenetration. Wait a
## couple of frames, then settle the player just above the ground below it.
func _place_player_on_terrain() -> void:
	var player := get_node_or_null("Player") as Node3D
	if player == null:
		return

	await get_tree().physics_frame
	await get_tree().physics_frame

	var from := player.global_position + Vector3(0.0, 50.0, 0.0)
	var to := player.global_position - Vector3(0.0, 50.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [player]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var ground_y: float = hit.position.y
	if player.global_position.y < ground_y + 0.1:
		player.global_position.y = ground_y + 0.6
		(player as CharacterBody3D).velocity = Vector3.ZERO
