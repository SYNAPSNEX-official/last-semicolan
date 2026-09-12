extends Path3D

## Rope visual: connects HookOrigin to HookProjectile.
## Pure visuals — no RigidBody physics and no collisions. The rope bends
## around obstacles using physics raycasts and is drawn as a smooth tube
## along a Curve3D. It updates in the physics tick so it stays synchronized
## with the RigidBody3D hook.

@onready var hook_origin: Node3D = get_node_or_null("../HookOrigin")
@onready var hook_projectile: RigidBody3D = get_node_or_null("../HookProjectile")

@export var rope_radius := 0.022
@export var max_bends := 3
@export var corner_clearance := 0.12
@export var sag_amount := 0.35
@export var terrain_clearance := 0.05
@export var shade_steps_per_meter := 3.0
@export var smoothing := 12.0

var rope_mesh: ImmediateMesh
var rope_instance: MeshInstance3D
var _smoothed_points: PackedVector3Array = PackedVector3Array()

func _ready() -> void:
	curve = Curve3D.new()
	rope_mesh = ImmediateMesh.new()
	rope_instance = MeshInstance3D.new()
	rope_instance.mesh = rope_mesh
	rope_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope_instance)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(hook_origin) or not is_instance_valid(hook_projectile):
		visible = false
		return

	if not hook_projectile.visible:
		visible = false
		return

	var start := hook_origin.global_position
	var end := hook_projectile.global_position

	if start.distance_to(end) <= 0.05:
		visible = false
		return

	visible = true
	_build_rope(start, end, delta)

func _build_rope(start: Vector3, end: Vector3, delta: float) -> void:
	var raw_points := _compute_path_points(start, end)
	var segments: PackedVector3Array = PackedVector3Array()
	segments.append(raw_points[0])
	for i in range(raw_points.size() - 1):
		var a := raw_points[i]
		var b := raw_points[i + 1]
		var middle := (a + b) * 0.5
		middle.y -= sag_amount * minf(a.distance_to(b), 6.0)
		var ground := _ground_height_at(middle)
		if ground != -INF:
			middle.y = maxf(middle.y, ground + terrain_clearance)
		segments.append(middle)
		segments.append(b)

	segments = _apply_smoothing(segments, delta)
	curve.clear_points()
	for i in range(segments.size()):
		var local := to_local(segments[i])
		curve.add_point(local)
		var prev_local := to_local(segments[maxi(i - 1, 0)])
		var next_local := to_local(segments[mini(i + 1, segments.size() - 1)])
		var tangent := (next_local - prev_local) * 0.33
		curve.set_point_in(i, -tangent)
		curve.set_point_out(i, tangent)

	_build_mesh()

func _compute_path_points(start: Vector3, end: Vector3) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	points.append(start)
	var current := start
	var target := end

	for i in range(max_bends):
		if current.distance_to(target) <= 0.2:
			break
		var query := PhysicsRayQueryParameters3D.create(current, target)
		query.exclude = _ray_exclude_list()
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var hit_position: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		points.append(hit_position + normal * corner_clearance)
		current = points[points.size() - 1]

	points.append(end)
	return points

func _ground_height_at(point: Vector3) -> float:
	# Start well above the sample point. If the rope has already sagged
	# below Terrain3D, starting only 0.5m above it would miss the terrain.
	var from := point + Vector3.UP * 100.0
	var to := point + Vector3.DOWN * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _ray_exclude_list()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -INF
	return hit.position.y

func _ray_exclude_list() -> Array:
	var excluded: Array = []
	excluded.append(hook_origin)
	excluded.append(hook_projectile)
	if hook_origin != null:
		excluded.append(hook_origin.get_parent())
		var player := hook_origin.get_parent().get_parent()
		if is_instance_valid(player):
			excluded.append(player)
	return excluded

func _apply_smoothing(points: PackedVector3Array, delta: float) -> PackedVector3Array:
	if _smoothed_points.size() != points.size():
		_smoothed_points = points
		return points
	var smoothed: PackedVector3Array = PackedVector3Array()
	var blend := clampf(delta * smoothing, 0.0, 1.0)
	smoothed.resize(points.size())
	smoothed[0] = points[0]
	smoothed[points.size() - 1] = points[points.size() - 1]
	for i in range(1, points.size() - 1):
		smoothed[i] = _smoothed_points[i].lerp(points[i], blend)
	_smoothed_points = smoothed
	return smoothed

func _build_mesh() -> void:
	rope_mesh.clear_surfaces()
	var length := curve.get_baked_length()
	if length <= 0.001:
		return
	var steps := maxi(4, ceili(length * shade_steps_per_meter))
	var sides := 6
	rope_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := curve.sample_baked(0.0)

	for step in range(1, steps + 1):
		var point := curve.sample_baked(float(step) / float(steps) * length)
		var p1 := previous
		var p2 := point
		var direction := (p2 - p1).normalized()
		var right := direction.cross(Vector3.UP)
		if right.length_squared() < 0.001:
			right = direction.cross(Vector3.FORWARD)
		right = right.normalized()
		var up := right.cross(direction).normalized()

		for side in range(sides):
			var a1 := TAU * float(side) / sides
			var a2 := TAU * float(side + 1) / sides
			var offset1 := (right * cos(a1) + up * sin(a1)) * rope_radius
			var offset2 := (right * cos(a2) + up * sin(a2)) * rope_radius
			var v1 := p1 + offset1
			var v2 := p1 + offset2
			var v3 := p2 + offset2
			var v4 := p2 + offset1
			rope_mesh.surface_set_uv(Vector2(float(side) / sides, 0.0))
			rope_mesh.surface_add_vertex(v1)
			rope_mesh.surface_set_uv(Vector2(float(side + 1) / sides, 0.0))
			rope_mesh.surface_add_vertex(v2)
			rope_mesh.surface_set_uv(Vector2(float(side + 1) / sides, 1.0))
			rope_mesh.surface_add_vertex(v3)
			rope_mesh.surface_set_uv(Vector2(float(side) / sides, 1.0))
			rope_mesh.surface_add_vertex(v4)
			previous = p2

	rope_mesh.surface_end()
