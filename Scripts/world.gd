extends Node3D

const PerformanceManager := preload("res://Scripts/performance_manager.gd")

const OBJECTIVE_NAMES := {
	1: "RELAY TOWER",
	2: "BRIDGE GAP",
	3: "POWER CELL",
}

const OBJECTIVE_TIPS := {
	1: "Grapple to the top of the relay tower",
	2: "Swing across the gap to the far platform",
	3: "Hook the power cell and reel it in",
}

# Tower (objective 1)
const TOWER_COLUMN := Vector3(16, 10.5, -16)
const TOWER_COLUMN_SIZE := Vector3(5, 14, 5)
const TOWER_PLATFORM := Vector3(16, 18.1, -16)
const TOWER_PLATFORM_SIZE := Vector3(9, 1.2, 9)
const TOWER_TARGET := Vector3(16, 20.0, -16)

# Bridge gap platforms (objective 2)
const BRIDGE_A := Vector3(25, 4.2, -27)
const BRIDGE_A_SIZE := Vector3(8, 1.2, 8)
const BRIDGE_B := Vector3(42, 10.9, -36)
const BRIDGE_B_SIZE := Vector3(9, 1.4, 9)
const BRIDGE_TARGET := Vector3(43, 12.9, -37)

# Power cell chamber (objective 3)
const CELL_FLOOR := Vector3(12, 2, -40)
const CELL_FLOOR_SIZE := Vector3(14, 1, 10)
const CELL_PEDESTAL := Vector3(8, 4.25, -40)
const CELL_PEDESTAL_SIZE := Vector3(2, 3.5, 2)
const CELL_ORB := Vector3(8, 7.5, -40)
const CELL_TARGET := Vector3(8, 7.5, -40)

# Final server pad
const SERVER_PAD := Vector3(0, 6.2, -54)
const SERVER_PAD_SIZE := Vector3(10, 1.4, 10)

var objectives_done: Dictionary = {}
var objectives_done_all := false

var _objective_areas: Dictionary = {}


func _ready() -> void:
	var terrain := get_node_or_null("Terrain3D")
	if terrain != null:
		terrain.add_to_group("climbable")

	var performance_manager := PerformanceManager.new()
	performance_manager.name = "PerformanceManager"
	add_child(performance_manager)

	_wire_objectives()
	_mark_climbable()
	_place_enemy_guards()
	_place_player_on_terrain()


## Structures are baked into the scene now, so re-tag every level body as
## climbable at runtime (pack() does not preserve groups on generated nodes).
func _mark_climbable() -> void:
	var host := get_node_or_null("objects")
	if host == null:
		return
	for node in host.find_children("*", "StaticBody3D", true, false):
		node.add_to_group("climbable")


## The objective Area3D nodes live in the scene; wire up their completion
## signals at runtime so logic stays in code.
func _wire_objectives() -> void:
	var host := get_node_or_null("objects")
	if host == null:
		return
	_objective_areas.clear()
	for i in range(1, 4):
		var area := host.get_node_or_null("Objective%d" % i) as Area3D
		if area == null:
			continue
		_objective_areas[i] = area
		var callable := _on_objective_body_entered.bind(area, i)
		if not area.body_entered.is_connected(callable):
			area.body_entered.connect(callable)


func is_server_unlocked() -> bool:
	return objectives_done_all


func get_objectives_completed() -> int:
	return objectives_done.size()


# =========================================================
# LEVEL CONSTRUCTION
# =========================================================

func _build_level() -> void:
	var host := get_node_or_null("objects")
	if host == null:
		return

	# --- Objective 1: Relay Tower --------------------------------------
	_make_box(host, "TowerColumn", TOWER_COLUMN, TOWER_COLUMN_SIZE, Color(0.30, 0.32, 0.38), false)
	_make_box(host, "TowerPlatform", TOWER_PLATFORM, TOWER_PLATFORM_SIZE, Color(0.40, 0.42, 0.50), false)
	_make_beacon(host, "TowerBeacon", "RELAY TOWER\nGrapple to the top", TOWER_TARGET + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.2))
	_make_area_sphere(host, "TowerAreaDeco", TOWER_TARGET, Color(1.0, 0.85, 0.2))

	# --- Objective 2: Bridge gap -----------------------------------------
	_make_box(host, "BridgePlatformA", BRIDGE_A, BRIDGE_A_SIZE, Color(0.34, 0.36, 0.42), false)
	_make_box(host, "BridgePlatformB", BRIDGE_B, BRIDGE_B_SIZE, Color(0.42, 0.44, 0.52), false)
	_make_beacon(host, "BridgeBeacon", "BRIDGE GAP\nSwing across", BRIDGE_TARGET + Vector3(0, 1.6, 0), Color(0.3, 0.9, 1.0))
	_make_area_sphere(host, "BridgeAreaDeco", BRIDGE_TARGET, Color(0.3, 0.9, 1.0))

	# --- Objective 3: Power cell chamber ----------------------------------
	_make_box(host, "CellFloor", CELL_FLOOR, CELL_FLOOR_SIZE, Color(0.28, 0.30, 0.35), false)
	_make_box(host, "CellWallLeft", Vector3(5.5, 5, -40), Vector3(1, 6, 8), Color(0.28, 0.30, 0.35), false)
	_make_box(host, "CellWallRight", Vector3(18.5, 5, -40), Vector3(1, 6, 8), Color(0.28, 0.30, 0.35), false)
	_make_box(host, "CellWallBack", Vector3(12, 5, -45.5), Vector3(14, 6, 1), Color(0.28, 0.30, 0.35), false)
	_make_box(host, "CellPedestal", CELL_PEDESTAL, CELL_PEDESTAL_SIZE, Color(0.34, 0.36, 0.42), false)
	_make_pull_orb(host, "PowerCell", CELL_ORB)
	_make_beacon(host, "CellBeacon", "POWER CELL\nHook and reel it in", CELL_ORB + Vector3(0, 3.0, 0), Color(0.9, 0.4, 1.0))
	_make_area_sphere(host, "CellAreaDeco", CELL_TARGET, Color(0.9, 0.4, 1.0))

	# --- Final server pad ---------------------------------------------------
	_make_box(host, "ServerPad", SERVER_PAD, SERVER_PAD_SIZE, Color(0.10, 0.45, 0.25), false)
	_make_beacon(host, "ServerBeacon", "DATA CENTER\nRepair the server (E)", Vector3(0, 12.5, -54), Color(0.2, 1.0, 0.35))


func _make_box(host: Node, node_name: String, box_pos: Vector3, box_size: Vector3, color: Color, emissive: bool, climbable := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = box_pos
	body.add_to_group("_generated")
	if climbable:
		body.add_to_group("climbable")
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = box_size
	mesh.material_override = _make_material(color, emissive, 0.5)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = box_size
	body.add_child(shape)
	host.add_child(body)
	return body


## The power cell: a climbable sphere the player must hook and reel to.
func _make_pull_orb(host: Node, node_name: String, orb_pos: Vector3) -> void:
	var orb := StaticBody3D.new()
	orb.name = node_name
	orb.position = orb_pos
	orb.add_to_group("_generated")
	orb.add_to_group("climbable")
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	var sphere := mesh.mesh as SphereMesh
	sphere.radius = 0.7
	sphere.height = 1.4
	mesh.material_override = _make_material(Color(0.9, 0.4, 1.0), true, 1.6)
	orb.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = 0.7
	orb.add_child(shape)
	host.add_child(orb)


func _make_beacon(host: Node, node_name: String, text: String, beacon_pos: Vector3, color: Color) -> void:
	var beacon := Node3D.new()
	beacon.name = node_name
	beacon.position = beacon_pos
	beacon.add_to_group("_generated")
	host.add_child(beacon)

	var sphere := MeshInstance3D.new()
	sphere.name = "Glow"
	sphere.mesh = SphereMesh.new()
	(sphere.mesh as SphereMesh).radius = 0.45
	(sphere.mesh as SphereMesh).height = 0.9
	sphere.material_override = _make_material(color, true, 2.0)
	beacon.add_child(sphere)

	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.position = Vector3(0, -0.6, 0)
	label.font_size = 64
	label.pixel_size = 0.02
	label.outline_size = 20
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	beacon.add_child(label)


func _make_area_sphere(host: Node, node_name: String, center: Vector3, color: Color) -> void:
	var deco := MeshInstance3D.new()
	deco.name = node_name
	deco.mesh = SphereMesh.new()
	var sphere := deco.mesh as SphereMesh
	sphere.radius = 0.22
	sphere.height = 0.44
	deco.position = center
	deco.add_to_group("_generated")
	deco.material_override = _make_material(color, true, 3.0)
	host.add_child(deco)


func _make_material(color: Color, emissive: bool, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.metallic = 0.2
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
	return mat


# =========================================================
# OBJECTIVES
# =========================================================

func _spawn_objectives() -> void:
	var host := get_node_or_null("objects")
	if host == null:
		return
	_spawn_objective(host, 1, TOWER_TARGET, 2.5)
	_spawn_objective(host, 2, BRIDGE_TARGET, 3.0)
	_spawn_objective(host, 3, CELL_TARGET, 2.5)


func _spawn_objective(host: Node, id: int, center: Vector3, radius: float) -> void:
	var area := Area3D.new()
	area.name = "Objective%d" % id
	area.position = center
	area.collision_layer = 1
	area.collision_mask = 1
	area.add_to_group("_generated")
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = radius
	area.add_child(shape)
	area.body_entered.connect(_on_objective_body_entered.bind(area, id))
	host.add_child(area)
	_objective_areas[id] = area


func _on_objective_body_entered(body: Node, area: Area3D, id: int) -> void:
	if objectives_done.has(id):
		return
	if not body.is_in_group("player"):
		return
	_area_completed(id, area)


func _area_completed(id: int, area: Area3D) -> void:
	objectives_done[id] = true
	area.set_deferred("monitoring", false)
	print("[OBJECTIVE] %s complete" % OBJECTIVE_NAMES[id])

	var ui := get_node_or_null("UI")
	if ui != null and ui.has_method("set_objectives"):
		ui.set_objectives(objectives_done.size())

	if objectives_done.size() >= 3:
		objectives_done_all = true
		print("[OBJECTIVE] ALL OBJECTIVES COMPLETE - SERVER UNLOCKED")
		if ui != null and ui.has_method("show_server_unlocked"):
			ui.show_server_unlocked()


# =========================================================
# ENEMIES
# =========================================================

func _place_enemy_guards() -> void:
	# World scene holds the enemy instances; we just nudge their spawn spots
	# onto our structures so they do not fall through the terrain.
	_set_enemy_position("Enemy", Vector3(16, 12, -16))
	_set_enemy_position("Enemy2", Vector3(25, 7, -27))
	_set_enemy_position("Enemy3", Vector3(14, 8, -33))
	_set_enemy_position("Enemy4", Vector3(2, 10, -54))


func _set_enemy_position(node_name: String, pos: Vector3) -> void:
	var enemy := get_node_or_null("enemies/" + node_name) as Node3D
	if enemy != null:
		enemy.global_position = pos


# =========================================================
# PLAYER START
# =========================================================

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