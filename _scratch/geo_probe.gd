extends SceneTree

var frames := 0
var world: Node = null

func _initialize() -> void:
	world = load("res://world.tscn").instantiate()
	root.add_child(world)

func _physics_process(_d: float) -> bool:
	frames += 1
	if frames < 4:
		return false

	print("=== OBJECTIVES ===")
	for i in range(1, 4):
		var area := world.get_node("objects/Objective%d" % i) as Area3D
		var col := area.get_node("CollisionShape3D") as CollisionShape3D
		print("Obj%d pos=" % i, area.global_position, " radius=", (col.shape as SphereShape3D).radius)

	print("=== STRUCTURES (pos, size, topY) ===")
	for child in (world.get_node("objects") as Node).get_children():
		if child is StaticBody3D:
			var mesh: MeshInstance3D = null
			for c in child.get_children():
				if c is MeshInstance3D:
					mesh = c as MeshInstance3D
					break
			var sz := Vector3.ZERO
			if mesh != null and mesh.mesh is BoxMesh:
				sz = (mesh.mesh as BoxMesh).size
			elif mesh != null and mesh.mesh is SphereMesh:
				var sm := mesh.mesh as SphereMesh
				sz = Vector3(sm.radius * 2, sm.height, sm.radius * 2)
			print(child.name, " pos=", child.global_position, " size=", sz, " topY=", child.global_position.y + sz.y / 2.0)

	print("player pos: ", world.get_node("Player").global_position)
	print("Server pos: ", world.get_node("Server").global_position)

	quit(0)
	return false