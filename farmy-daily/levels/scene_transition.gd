extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var target_spawn_tag: String = ""

func interact(_user = null) -> void:
	if target_scene_path == "":
		return
	call_deferred("change_scene_safe")

func change_scene_safe() -> void:
	var root = get_tree().current_scene
	if root != null and root.has_method("change_level_to"):
		root.change_level_to(target_scene_path, target_spawn_tag)
	else:
		TimeManager.player_spawn_tag = target_spawn_tag
		get_tree().change_scene_to_file(target_scene_path)
