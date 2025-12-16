extends Node

const SAVE_DIR = "user://saves/"
const SAVE_TEMPLATE = "save_slot_%d.json"
const MAX_SLOTS = 3
const DEFAULT_LEVEL_PATH = "res://sprites/Hana Caraka - Topdown Tileset/Hana Caraka - Topdown Tileset/House/main.tscn"
const MAIN_MENU_PATH = "res://levels/main_menu.tscn"

var current_slot = 0
var current_player_name = "Farmer"
var slots_cache = {}
var persistence_data = {
	"levels": {},
	"objects": {}
}

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
	var current_scene = get_tree().current_scene
	var level_path = ""
	if current_scene:
		level_path = current_scene.scene_file_path
		
	var data = {
		"metadata": {
			"player_name": current_player_name,
			"money": 0,
			"date": Time.get_date_string_from_system(),
			"level_path": level_path 
		},
		"player": {},
		"inventory": [],
		"time": {},
		"persistence": persistence_data,
		"world": []
	}
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)
			
	if player:
		data["metadata"]["money"] = player.money
		data["player"] = {
			"pos_x": player.global_position.x,
			"pos_y": player.global_position.y,
			"money": player.money,
			"axe_damage": player.get("axe_hit_damage") if player.get("axe_hit_damage") != null else 10,
			"health": player.get("health") if player.get("health") != null else 100,
			"max_health": player.get("max_health") if player.get("max_health") != null else 100
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
	if time_manager and time_manager.has_method("get_save_data"):
		var t_data = time_manager.get_save_data()
		data["time"] = t_data
		if t_data.has("month") and t_data.has("day"):
			var month_idx = int(t_data["month"])
			var day_num = int(t_data["day"])
			data["metadata"]["date"] = "Month " + str(month_idx) + ", Day " + str(day_num)

	if current_scene and current_scene.has_method("save_level_state"):
		current_scene.call("save_level_state")

	var file = FileAccess.open(get_save_path(current_slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	
	_refresh_slots()

func save_and_exit_to_menu() -> void:
	save_game()
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.is_gameplay_active = false
		
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

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

func delete_save(slot_index: int) -> void:
	var path = get_save_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_refresh_slots()

func start_new_game(slot_index: int, player_name: String) -> void:
	current_slot = slot_index
	current_player_name = player_name
	persistence_data = { "levels": {}, "objects": {} }
	
	var path = get_save_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.is_gameplay_active = false
		time_manager.player_spawn_tag = "sleep" 
		if time_manager.has_method("load_save_data"):
			var default_data = {
				"time_seconds": 21600.0,
				"day": 1,
				"month": 4,
				"year": 2025,
				"season": 0,
				"penalty": false,
				"energy": 100.0
			}
			time_manager.load_save_data(default_data)
		
	if ResourceLoader.exists(DEFAULT_LEVEL_PATH):
		get_tree().change_scene_to_file(DEFAULT_LEVEL_PATH)
	else:
		get_tree().change_scene_to_file("res://sprites/Hana Caraka - Topdown Tileset/Hana Caraka - Topdown Tileset/House/main.tscn")
		
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)
		
	if player:
		var sleep_marker = get_tree().current_scene.find_child("sleep", true, false)
		if sleep_marker:
			player.global_position = sleep_marker.global_position
			
			player.set("is_movement_locked", true)
			var sprite = player.get_node_or_null("AnimatedSprite2D")
			if sprite and sprite.sprite_frames.has_animation("sleep_down"):
				sprite.play_backwards("sleep_down")
				await sprite.animation_finished
			else:
				await get_tree().create_timer(1.0).timeout
			
			if sprite:
				sprite.play("idle_down")
				
			player.set("is_movement_locked", false)
		
		player.money = 0
		player.emit_signal("money_updated", 0)
		if player.inventory_data:
			for i in range(player.inventory_data.slot_datas.size()):
				player.inventory_data.slot_datas[i] = null
			player.inventory_data.emit_signal("inventory_updated", player.inventory_data)

	if time_manager:
		time_manager.is_gameplay_active = true

	save_game()

func _apply_save_data(data: Dictionary) -> void:
	if data.has("persistence"):
		persistence_data = data["persistence"]
	else:
		persistence_data = { "levels": {}, "objects": {} }

	if data.has("metadata"):
		if data["metadata"].has("player_name"):
			current_player_name = data["metadata"]["player_name"]
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.is_gameplay_active = false
		
	var target_level = DEFAULT_LEVEL_PATH
	if data.has("metadata") and data["metadata"].has("level_path"):
		var saved_path = data["metadata"]["level_path"]
		if saved_path != "" and ResourceLoader.exists(saved_path):
			target_level = saved_path
			
	get_tree().change_scene_to_file(target_level)
		
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)
	
	if player and data.has("player"):
		var p = data["player"]
		player.global_position = Vector2(p.get("pos_x", 0), p.get("pos_y", 0))
		
		var money_val = p.get("money", 0)
		if money_val == null: money_val = 0
		player.money = int(money_val)
		
		var axe_dmg = p.get("axe_damage")
		if axe_dmg != null: 
			player.set("axe_hit_damage", int(axe_dmg))
			
		var hp = p.get("health")
		if hp != null: 
			player.set("health", int(hp))
			
		player.emit_signal("money_updated", player.money)
		
	if player and player.inventory_data and data.has("inventory"):
		var inv_list = data["inventory"]
		for i in range(inv_list.size()):
			if i < player.inventory_data.slot_datas.size():
				var slot_info = inv_list[i]
				if slot_info != null:
					if ResourceLoader.exists(slot_info["path"]):
						var res = load(slot_info["path"])
						if res:
							var new_slot = SlotData.new()
							new_slot.item_data = res
							new_slot.quantity = int(slot_info["amount"])
							player.inventory_data.slot_datas[i] = new_slot
				else:
					player.inventory_data.slot_datas[i] = null
		player.inventory_data.emit_signal("inventory_updated", player.inventory_data)

	if time_manager and data.has("time") and time_manager.has_method("load_save_data"):
		time_manager.load_save_data(data["time"])
		time_manager.is_gameplay_active = true

func save_level_data(level_path: String, data: Dictionary) -> void:
	if not persistence_data.has("levels"):
		persistence_data["levels"] = {}
	persistence_data["levels"][level_path] = data

func get_level_data_dynamic(level_path: String) -> Dictionary:
	if persistence_data.has("levels") and persistence_data["levels"].has(level_path):
		return persistence_data["levels"][level_path]
	return {}

func save_object_state(obj: Node, data: Dictionary) -> void:
	var level_path = ""
	if obj.owner:
		level_path = obj.owner.scene_file_path
	else:
		level_path = get_tree().current_scene.scene_file_path
		
	var obj_path = String(obj.get_path())
	
	if not persistence_data.has("objects"):
		persistence_data["objects"] = {}
	if not persistence_data["objects"].has(level_path):
		persistence_data["objects"][level_path] = {}
		
	persistence_data["objects"][level_path][obj_path] = data

func get_object_state(obj: Node) -> Dictionary:
	var level_path = ""
	if obj.owner:
		level_path = obj.owner.scene_file_path
	else:
		level_path = get_tree().current_scene.scene_file_path
		
	var obj_path = String(obj.get_path())
	
	if persistence_data.has("objects") and \
	   persistence_data["objects"].has(level_path) and \
	   persistence_data["objects"][level_path].has(obj_path):
		return persistence_data["objects"][level_path][obj_path]
	return {}
