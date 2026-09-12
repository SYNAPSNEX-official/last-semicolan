extends Node3D

const HULL_MATERIAL := preload("res://assests/robots/scout_hull_m.tres")
const TRIM_MATERIAL := preload("res://assests/robots/scout_trim_e.tres")

func _ready() -> void:
	for child in find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh:
			var surface: Material = mi.mesh.surface_get_material(0)
			if surface is StandardMaterial3D:
				var name := (surface as StandardMaterial3D).resource_name
				if name.ends_with("_M"):
					mi.material_override = HULL_MATERIAL
				elif name.ends_with("_E"):
					mi.material_override = TRIM_MATERIAL