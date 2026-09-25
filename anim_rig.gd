extends RefCounted
class_name AnimRig

const ANIMS := {
	"idle":        "res://models/avatars/animations/idle.fbx",
	"walk":        "res://models/avatars/animations/walk.fbx",
	"run":         "res://models/avatars/animations/run.fbx",
	"walk_back":   "res://models/avatars/animations/walk_back.fbx",
	"crouch_walk": "res://models/avatars/animations/crouch_walk.fbx",
	"rifle_idle":  "res://models/avatars/animations/rifle_idle.fbx",
}

static func attach(anim_player: AnimationPlayer, skeleton: Skeleton3D) -> bool:
	if anim_player == null or skeleton == null:
		return false
	var model_root: Node = anim_player.get_parent()
	if model_root == null:
		return false
	anim_player.root_node = anim_player.get_path_to(model_root)
	var skel_rel: String = String(model_root.get_path_to(skeleton))
	print("[rig] skeleton rel path: ", skel_rel)
	var lib := AnimationLibrary.new()
	var loaded_count := 0
	for key in ANIMS.keys():
		var path: String = ANIMS[key]
		var scn: PackedScene = load(path)
		if scn == null:
			print("[rig] failed to load: ", path)
			continue
		var inst: Node = scn.instantiate()
		var src_ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if src_ap == null:
			print("[rig] no AnimationPlayer in ", path)
			inst.queue_free()
			continue
		var src_lib: AnimationLibrary = src_ap.get_animation_library("")
		if src_lib == null:
			print("[rig] no default library in ", path)
			inst.queue_free()
			continue
		var src_names: PackedStringArray = src_lib.get_animation_list()
		if src_names.size() == 0:
			inst.queue_free()
			continue
		var anim: Animation = src_lib.get_animation(src_names[0]).duplicate(true)
		_retarget_tracks(anim, skel_rel)
		_strip_root_motion(anim)
		lib.add_animation(String(key), anim)
		loaded_count += 1
		inst.queue_free()
	if loaded_count == 0:
		return false
	if anim_player.has_animation_library("mixamo"):
		anim_player.remove_animation_library("mixamo")
	anim_player.add_animation_library("mixamo", lib)
	print("[rig] attached ", loaded_count, " animations")
	return true

static func _retarget_tracks(anim: Animation, skel_rel: String) -> void:
	var count := anim.get_track_count()
	for i in range(count):
		var p: String = String(anim.track_get_path(i))
		var colon: int = p.find(":")
		if colon < 0:
			continue
		var bone_part: String = p.substr(colon)
		var new_path: NodePath = NodePath(skel_rel + bone_part)
		anim.track_set_path(i, new_path)

static func _strip_root_motion(anim: Animation) -> void:
	var remove_idxs: Array = []
	for i in range(anim.get_track_count()):
		var p: String = String(anim.track_get_path(i))
		if not p.to_lower().ends_with("hips"):
			continue
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			remove_idxs.append(i)
	for i in range(remove_idxs.size() - 1, -1, -1):
		anim.remove_track(remove_idxs[i])
