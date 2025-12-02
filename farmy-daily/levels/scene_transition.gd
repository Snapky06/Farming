extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var target_spawn_tag: String = ""

func interact(_user = null):
	if target_scene_path == "":
		return
		
	call_deferred("change_scene_safe")

func change_scene_safe():
	TimeManager.player_spawn_tag = target_spawn_tag
	get_tree().change_scene_to_file(target_scene_path)
