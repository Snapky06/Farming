extends Node

const SAVE_PATH = "user://save_game.dat"

func save_game():
	var save_data = {
		"time": {},
		"quests": {},
		"player": {},
		"inventory": [],
		"level": {}
	}

	if has_node("/root/TimeManager"):
		save_data["time"] = get_node("/root/TimeManager").get_save_data()
	
	if has_node("/root/QuestManager"):
		save_data["quests"] = get_node("/root/QuestManager").get_save_data()

	var root = get_tree().current_scene
	var player = root.find_child("Player", true, false)
	if player:
		save_data["player"] = {
			"position_x": player.global_position.x,
			"position_y": player.global_position.y,
			"scene_path": root.scene_file_path,
			"money": player.money
		}
		
		if player.inventory_data:
			save_data["inventory"] = player.inventory_data.serialize()

	if root.has_method("get_level_data"):
		save_data["level"] = root.get_level_data()

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_data = file.get_var()
	file.close()

	if save_data.has("time") and has_node("/root/TimeManager"):
		get_node("/root/TimeManager").load_save_data(save_data["time"])
	
	if save_data.has("quests") and has_node("/root/QuestManager"):
		get_node("/root/QuestManager").load_save_data(save_data["quests"])

	if save_data.has("player"):
		var player_data = save_data["player"]
		var scene_path = player_data.get("scene_path", "")
		
		if scene_path != "" and scene_path != get_tree().current_scene.scene_file_path:
			get_tree().change_scene_to_file(scene_path)
			await get_tree().process_frame
		
		var player = get_tree().current_scene.find_child("Player", true, false)
		if player:
			player.global_position = Vector2(player_data["position_x"], player_data["position_y"])
			if player_data.has("money"):
				player.money = player_data["money"]
				player.money_updated.emit(player.money)
			
			if save_data.has("inventory") and player.inventory_data:
				player.inventory_data.deserialize(save_data["inventory"])

	if save_data.has("level") and get_tree().current_scene.has_method("load_level_data"):
		get_tree().current_scene.load_level_data(save_data["level"])
