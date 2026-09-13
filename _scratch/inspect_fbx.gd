extends Node3D

func _ready() -> void:
	var scene: PackedScene = load("res://assests/models/buildin1.fbx") as PackedScene
	var node := scene.instantiate()
	add_child(node)
	_dump(node, 0)
	print("== buildin1 done ==")
	_print_groups(node)
	node.free()

	var scene2: PackedScene = load("res://assests/models/hallway.fbx") as PackedScene
	var node2 := scene2.instantiate()
	add_child(node2)
	_dump(node2, 0)
	print("== hallway done ==")
	node2.free()
	get_tree().quit(0)

func _dump(node: Node, depth: int) -> void:
	var t := ""
	if node is Node3D:
		var n := node as Node3D
		t = " [%s] pos=%s" % [node.get_class(), n.global_position.round()]
	print("  ".repeat(depth) + node.name + t)
	for child in node.get_children():
		_dump(child, depth + 1)

func _print_groups(node: Node) -> void:
	for g in node.get_groups():
		print("  group: ", g)