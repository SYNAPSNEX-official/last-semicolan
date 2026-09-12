extends MeshInstance3D

@onready var hook_origin: Node3D = $".."
@onready var hook_projectile: MeshInstance3D = $"../HookProjectile"

@export var rope_radius := 0.025

func _process(_delta: float) -> void:
	if not is_instance_valid(hook_origin) or not is_instance_valid(hook_projectile):
		visible = false
		return

	var start := hook_origin.global_position
	var end := hook_projectile.global_position

	var direction := end - start
	var length := direction.length()

	if length <= 0.01:
		visible = false
		return

	visible = true

	# Put rope halfway between origin and projectile.
	global_position = start + direction * 0.5

	# Point local Y axis toward the projectile.
	var dir := direction.normalized()

	# Build a basis where Y follows the rope direction.
	var right := dir.cross(Vector3.UP)

	if right.length_squared() < 0.001:
		right = dir.cross(Vector3.FORWARD)

	right = right.normalized()

	var up := right.cross(dir).normalized()

	global_basis = Basis(
		right,
		dir,
		up
	)

	# CylinderMesh is 2 units tall by default.
	# Scale Y to exactly match the distance.
	scale = Vector3(
		rope_radius,
		length * 0.5,
		rope_radius
	)
