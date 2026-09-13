extends Node3D

const IDLE_SCN := "res://assests/14-girl-obj/Idle.fbx"
const GIRL_SCN := "res://assests/14-girl-obj/girl OBJ.fbx"
const MAT_DIR := "res://assests/14-girl-obj/materials/"

const RIGID_PARTS := {
	"Head_Hair001_baked_005": ["Head", "girl_head.tres"],
	"hair_Hair001_baked_001": ["Head", "girl_hair.tres"],
	"eyes_Hair001_baked_009": ["Head", "girl_face.tres"],
	"boca_Hair001_baked_010": ["Head", "girl_face.tres"],
	"ceja_Hair001_baked_003": ["Head", "girl_face.tres"],
	"scarf_Cube": ["Neck", "girl_scarf.tres"],
}

const SEGMENTED_PARTS := {
	"body_pERSONAJE_002": "girl_skin.tres",
	"Top_pERSONAJE_004": "girl_top.tres",
	"bot_pERSONAJE_005": "girl_bot.tres",
}

const BONES := [
	"Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
]

const BOT_PART := "bot_pERSONAJE_005"
const BOT_HEM_Y := 0.72

const HAIR_PART := "hair_Hair001_baked_001"
const HAIR_HEM_Y := 1.05

var _sk: Skeleton3D
var _rest := {}

func _ready() -> void:
	_build()

func _build() -> void:
	var idle: Node = (load(IDLE_SCN) as PackedScene).instantiate()
	_sk = idle.get_node("GeneralSkeleton")
	_sk.owner = null
	var arm := Node3D.new()
	arm.name = "CharacterArmature"
	add_child(arm)
	idle.remove_child(_sk)
	_sk.name = "Skeleton3D"
	arm.add_child(_sk)
	idle.free()

	for b in BONES:
		var idx := _sk.find_bone(b)
		if idx != -1:
			_rest[idx] = _sk.get_bone_global_rest(idx).origin

	var girl: Node = (load(GIRL_SCN) as PackedScene).instantiate()
	for part_name: String in RIGID_PARTS:
		_build_rigid(girl, part_name, RIGID_PARTS[part_name][0], MAT_DIR + RIGID_PARTS[part_name][1])
	for part_name: String in SEGMENTED_PARTS:
		_build_segmented(girl, part_name, MAT_DIR + SEGMENTED_PARTS[part_name])
	girl.free()

func _build_rigid(girl: Node, part_name: String, bone: String, mat_path: String) -> void:
	var src: MeshInstance3D = girl.get_node(part_name)
	var bone_idx := _sk.find_bone(bone)
	if bone_idx == -1:
		push_warning("missing bone for " + part_name + ": " + bone)
		return
	var mi := _rig(
		src, bone_idx,
		HAIR_HEM_Y if part_name == HAIR_PART else INF)
	mi.set_surface_override_material(0, load(mat_path))
	_sk.add_child(mi)

func _clip_y(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idxs: PackedInt32Array, hem_y: float) -> Array:
	var remap := {}
	var new_verts := PackedVector3Array()
	var new_norms := PackedVector3Array()
	var new_uvs := PackedVector2Array()
	var new_idxs := PackedInt32Array()
	var has_norms := norms.size() == verts.size()
	var has_uvs := uvs.size() == verts.size()
	for i in range(0, idxs.size(), 3):
		var keep := true
		for j in 3:
			if verts[idxs[i + j]].y < hem_y:
				keep = false
				break
		if not keep:
			continue
		for j in 3:
			var v := idxs[i + j]
			if not remap.has(v):
				remap[v] = new_verts.size()
				new_verts.append(verts[v])
				if has_norms:
					new_norms.append(norms[v])
				if has_uvs:
					new_uvs.append(uvs[v])
			new_idxs.append(remap[v])
	return [new_verts, new_norms, new_uvs, new_idxs]

func _clip_bot(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idxs: PackedInt32Array) -> Array:
	return _clip_y(verts, norms, uvs, idxs, BOT_HEM_Y)

func _rig(src: MeshInstance3D, bone_idx: int, hem_y: float = INF) -> MeshInstance3D:
	var src_mesh: ArrayMesh = src.mesh
	var out := ArrayMesh.new()
	for s in src_mesh.get_surface_count():
		var arr: Array = src_mesh.surface_get_arrays(s)
		if hem_y != INF:
			var filtered := _clip_y(
				arr[ArrayMesh.ARRAY_VERTEX] as PackedVector3Array,
				arr[ArrayMesh.ARRAY_NORMAL] as PackedVector3Array,
				arr[ArrayMesh.ARRAY_TEX_UV] as PackedVector2Array,
				arr[ArrayMesh.ARRAY_INDEX] as PackedInt32Array,
				hem_y)
			arr[ArrayMesh.ARRAY_VERTEX] = filtered[0]
			arr[ArrayMesh.ARRAY_NORMAL] = filtered[1]
			arr[ArrayMesh.ARRAY_TEX_UV] = filtered[2]
			arr[ArrayMesh.ARRAY_INDEX] = filtered[3]
		var vc: int = (arr[ArrayMesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		for _v in vc:
			bones.append(bone_idx)
			bones.append(0)
			bones.append(0)
			bones.append(0)
			weights.append(1.0)
			weights.append(0.0)
			weights.append(0.0)
			weights.append(0.0)
		arr[ArrayMesh.ARRAY_BONES] = bones
		arr[ArrayMesh.ARRAY_WEIGHTS] = weights
		out.add_surface_from_arrays(src_mesh.surface_get_primitive_type(s), arr)
	var mi := MeshInstance3D.new()
	mi.name = src.name
	mi.mesh = out
	mi.skeleton = NodePath("..")
	return mi

func _build_segmented(girl: Node, part_name: String, mat_path: String) -> void:
	var src: MeshInstance3D = girl.get_node(part_name)
	var src_mesh: ArrayMesh = src.mesh
	var mat := load(mat_path)
	for s in src_mesh.get_surface_count():
		var arr := src_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[ArrayMesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[ArrayMesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arr[ArrayMesh.ARRAY_TEX_UV]
		var idxs: PackedInt32Array = arr[ArrayMesh.ARRAY_INDEX]
		if idxs.size() == 0:
			idxs = PackedInt32Array()
			idxs.resize(verts.size() * 3)
			for v in verts.size():
				idxs[v * 3] = v
				idxs[v * 3 + 1] = v + 1
				idxs[v * 3 + 2] = v + 2
		if part_name == BOT_PART:
			var clipped := _clip_bot(verts, norms, uvs, idxs)
			verts = clipped[0]
			norms = clipped[1]
			uvs = clipped[2]
			idxs = clipped[3]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(verts.size() * 4)
		weights.resize(verts.size() * 4)
		for v in verts.size():
			var skin := _skin_weights(verts[v])
			for j in 4:
				bones[v * 4 + j] = skin[0][j]
				weights[v * 4 + j] = skin[1][j]
		var out := ArrayMesh.new()
		var out_arr := []
		out_arr.resize(ArrayMesh.ARRAY_MAX)
		out_arr[ArrayMesh.ARRAY_VERTEX] = verts
		out_arr[ArrayMesh.ARRAY_NORMAL] = norms
		out_arr[ArrayMesh.ARRAY_TEX_UV] = uvs
		out_arr[ArrayMesh.ARRAY_INDEX] = idxs
		out_arr[ArrayMesh.ARRAY_BONES] = bones
		out_arr[ArrayMesh.ARRAY_WEIGHTS] = weights
		var src_tan: Variant = arr[ArrayMesh.ARRAY_TANGENT]
		if typeof(src_tan) == TYPE_PACKED_FLOAT32_ARRAY and (src_tan as PackedFloat32Array).size() == verts.size() * 4:
			out_arr[ArrayMesh.ARRAY_TANGENT] = src_tan
		out.add_surface_from_arrays(src_mesh.surface_get_primitive_type(s), out_arr)
		var mi := MeshInstance3D.new()
		mi.name = part_name
		mi.mesh = out
		mi.skeleton = NodePath("..")
		mi.set_surface_override_material(0, mat)
		_sk.add_child(mi)

const BW := 0.12

func _skin_weights(p: Vector3) -> Array:
	var cand: Array = []
	for idx: int in _rest:
		cand.append([_rest[idx].distance_to(p), idx])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	bones.resize(4)
	wts.resize(4)
	var sum := 0.0
	var n := mini(4, cand.size())
	for i in n:
		var d: float = cand[i][0]
		var w := exp(-(d * d) / (BW * BW))
		bones[i] = cand[i][1]
		wts[i] = w
		sum += w
	if sum > 0.0:
		for i in n:
			wts[i] /= sum
	return [bones, wts]