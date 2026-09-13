@tool
class_name MixaBridgeImportConfigurator
extends RefCounted

const SKELETON_NAME := "GeneralSkeleton"

const RETARGET_PARAMS: Dictionary = {
	"retarget/bone_renamer/rename_bones": true,
	"retarget/bone_renamer/unique_node/make_unique": true,
	"retarget/bone_renamer/unique_node/skeleton_name": SKELETON_NAME,
	"retarget/rest_fixer/apply_node_transforms": true,
	"retarget/rest_fixer/normalize_position_tracks": true,
	"retarget/rest_fixer/reset_all_bone_poses_after_import": true,
	"retarget/rest_fixer/retarget_method": 1,
	"retarget/rest_fixer/keep_global_rest_on_leftovers": true,
	"retarget/rest_fixer/use_global_pose": true,
	"retarget/remove_tracks/except_bone_transform": false,
	"retarget/remove_tracks/unimportant_positions": true,
	"retarget/remove_tracks/unmapped_bones": 1,
}


func configure_model(
	model_path: String, bone_map_path: String
) -> Error:
	return _apply_retarget_settings(model_path, bone_map_path)


func configure_animations(
	anim_paths: PackedStringArray, bone_map_path: String
) -> Error:
	for anim_path: String in anim_paths:
		var err := _apply_retarget_settings(anim_path, bone_map_path)
		if err != OK:
			push_error(
				"MixaBridge: failed to configure import for " + anim_path
			)
			return err
	return OK


func reimport_model(model_path: String) -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.reimport_files(PackedStringArray([model_path]))


func reimport_animations(anim_paths: PackedStringArray) -> void:
	if anim_paths.is_empty():
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.reimport_files(anim_paths)


func _apply_retarget_settings(
	file_path: String, bone_map_path: String
) -> Error:
	var import_path := file_path + ".import"
	var global_import_path := ProjectSettings.globalize_path(import_path)

	if not FileAccess.file_exists(import_path):
		push_error("MixaBridge: .import file not found at " + import_path)
		return ERR_FILE_NOT_FOUND

	var bone_map := load(bone_map_path) as BoneMap
	if not bone_map:
		push_error("MixaBridge: cannot load BoneMap at " + bone_map_path)
		return ERR_CANT_OPEN

	var config := ConfigFile.new()
	var err := config.load(global_import_path)
	if err != OK:
		push_error(
			"MixaBridge: cannot parse .import file at " + import_path
		)
		return err

	err = _store_node_retarget_options(config, bone_map)
	if err != OK:
		return err

	err = config.save(global_import_path)
	if err != OK:
		push_error(
			"MixaBridge: cannot save .import file at " + import_path
		)
	return err


# Godot 4.7 moved 3D scene retarget options from top-level [params] keys
# into per-node options stored under `params/_subresources` ->
# `nodes/<import_id>`. Top-level `retarget/*` keys are silently stripped
# on the next reimport, so they must live inside this structure instead.
func _store_node_retarget_options(config: ConfigFile, bone_map: BoneMap) -> Error:
	var sub: Dictionary = config.get_value("params", "_subresources", {})
	var nodes: Dictionary = sub.get("nodes", {})

	var skeleton_id := _resolve_skeleton_import_id(nodes)

	var node_options: Dictionary = nodes.get(skeleton_id, {})
	node_options["retarget/bone_map"] = bone_map
	for key: String in RETARGET_PARAMS:
		node_options[key] = RETARGET_PARAMS[key]

	nodes[skeleton_id] = node_options
	sub["nodes"] = nodes
	config.set_value("params", "_subresources", sub)
	return OK


func _resolve_skeleton_import_id(nodes: Dictionary) -> String:
	# Default import_id for a Skeleton3D directly under the scene root.
	for candidate: String in ["PATH:Skeleton3D", "PATH:GeneralSkeleton"]:
		if nodes.has(candidate):
			return candidate
	for key: Variant in nodes.keys():
		var suffix := String(key)
		if suffix.begins_with("PATH:"):
			return suffix
	return "PATH:Skeleton3D"
