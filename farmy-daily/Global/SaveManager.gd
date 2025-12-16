extends Node

const SAVE_DIR = "user://saves/"
const SAVE_TEMPLATE = "save_slot_%d.json"
const MAX_SLOTS = 3

var current_slot = 0
var current_player_name = "Farmer"
var slots_cache = {}

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
	_refresh_slots()

func get_save_path(index: int) -> String:
	return SAVE_DIR + (SAVE_TEMPLATE % index)

func _refresh_slots() -> void:
	slots_cache.clear()
	for i in range(MAX_SLOTS):
		var path = get_save_path(i)
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var text = file.get_as_text()
				file.close()
				var json = JSON.new()
				if json.parse(text) == OK:
					var data = json.data
					if data.has("metadata"):
						slots_cache[i] = data["metadata"]

func save_game() -> void:
	var data = {
		"metadata": {
			"player_name": current_player_name,
			"day": 1,
			"money": 0,
			"date": Time.get_date_string_from_system()
		},
		"player": {},
		"inventory": [],
		"time": {},
		"world": []
	}
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		var root = get_tree().current_scene
		if root.name == "Player":
			player = root
		else:
			player = root.find_child("Player", true, false)
			
	if player:
		data["metadata"]["money"] = player.money
		data["player"] = {
			"pos_x": player.global_position.x,
			"pos_y": player.global_position.y,
			"money": player.money,
			"axe_damage": player.get("axe_hit_damage"),
			"health": player.get("health"),
			"max_health": player.get("max_health")
		}
		
		if player.inventory_data and player.inventory_data.slot_datas:
			for slot in player.inventory_data.slot_datas:
				if slot and slot.item_data:
					data["inventory"].append({
						"path": slot.item_data.resource_path,
						"amount": slot.quantity
					})
				else:
					data["inventory"].append(null)

	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		data["metadata"]["day"] = time_manager.day
		data["time"] = {
			"day": time_manager.day,
			"minutes": time_manager.current_time_minutes
		}

	var root_node = get_tree().current_scene
	var saveable_objects = root_node.get_children()
	
	for node in saveable_objects:
		if node == player:
			continue
			
		if node.scene_file_path.is_empty():
			continue
			
		if "TileMap" in node.name:
			continue

		var should_save = false
		var object_props = {}
		
		if "current_stage" in node:
			should_save = true
			object_props["current_stage"] = node.current_stage
		
		if "health" in node:
			should_save = true
			object_props["health"] = node.health
			
		if "is_watered" in node:
			should_save = true
			object_props["is_watered"] = node.is_watered
			
		if node.is_in_group("persist"):
			should_save = true

		if should_save:
			data["world"].append({
				"file": node.scene_file_path,
				"x": node.global_position.x,
				"y": node.global_position.y,
				"z": node.z_index,
				"props": object_props
			})

	var file = FileAccess.open(get_save_path(current_slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	
	_refresh_slots()

func load_game(slot_index: int) -> void:
	var path = get_save_path(slot_index)
	if not FileAccess.file_exists(path):
		return
		
	current_slot = slot_index
	
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(text) == OK:
		var data = json.data
		_apply_save_data(data)

func start_new_game(slot_index: int, player_name: String) -> void:
	current_slot = slot_index
	current_player_name = player_name
	
	var path = get_save_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		
	get_tree().change_scene_to_file("res://farmy-daily/levels/playerhouse.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)
		
	if player:
		player.money = 0
		player.emit_signal("money_updated", 0)
		if player.inventory_data:
			for i in range(player.inventory_data.slot_datas.size()):
				player.inventory_data.slot_datas[i] = null
			player.inventory_data.emit_signal("inventory_updated", player.inventory_data)

	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.day = 1
		time_manager.current_time_minutes = 360

	save_game()

func _apply_save_data(data: Dictionary) -> void:
	if data.has("metadata"):
		current_player_name = data["metadata"]["player_name"]
		
	get_tree().change_scene_to_file("res://farmy-daily/levels/playerhouse.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)
		
	if player and data.has("player"):
		var p = data["player"]
		player.global_position = Vector2(p["pos_x"], p["pos_y"])
		player.money = int(p["money"])
		if p.has("axe_damage"): player.set("axe_hit_damage", int(p["axe_damage"]))
		if p.has("health"): player.set("health", int(p["health"]))
		player.emit_signal("money_updated", player.money)
		
	if player and player.inventory_data and data.has("inventory"):
		var inv_list = data["inventory"]
		for i in range(inv_list.size()):
			if i < player.inventory_data.slot_datas.size():
				var slot_info = inv_list[i]
				if slot_info != null:
					var res = load(slot_info["path"])
					if res:
						var new_slot = SlotData.new()
						new_slot.item_data = res
						new_slot.quantity = int(slot_info["amount"])
						player.inventory_data.slot_datas[i] = new_slot
				else:
					player.inventory_data.slot_datas[i] = null
		player.inventory_data.emit_signal("inventory_updated", player.inventory_data)

	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and data.has("time"):
		time_manager.day = int(data["time"]["day"])
		time_manager.current_time_minutes = int(data["time"]["minutes"])

	var root = get_tree().current_scene
	for child in root.get_children():
		if child == player: continue
		if "TileMap" in child.name: continue
		if "health" in child or "current_stage" in child or child.is_in_group("persist"):
			child.queue_free()
			
	await get_tree().process_frame
	
	if data.has("world"):
		for obj in data["world"]:
			if ResourceLoader.exists(obj["file"]):
				var scene = load(obj["file"])
				var instance = scene.instantiate()
				instance.global_position = Vector2(obj["x"], obj["y"])
				instance.z_index = int(obj["z"])
				if obj.has("props"):
					for key in obj["props"]:
						instance.set(key, obj["props"][key])
				instance.add_to_group("persist")
				root.add_child(instance)
