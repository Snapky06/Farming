extends Node

const SAVE_DIR = "user://saves/"
const SAVE_TEMPLATE = "save_slot_%d.json"
const MAX_SLOTS = 3

const GAME_WRAPPER_PATH = "res://sprites/Hana Caraka - Topdown Tileset/Hana Caraka - Topdown Tileset/House/main.tscn"
const DEFAULT_LEVEL_SCENE_PATH = "res://levels/playerhouse.tscn"
const MAIN_MENU_PATH = "res://levels/main_menu.tscn"

var current_slot = 0
var current_player_name = "Farmer"
var slots_cache = {}

var persistence_data = {
	"levels": {},
	"objects": {},
	"watered_tiles_by_level": {}
}

var pending_level_path: String = ""
var pending_spawn_tag: String = ""
var pending_player_pos: Vector2 = Vector2.ZERO
var pending_has_player_pos: bool = false

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

func _find_player() -> Node:
	var p = get_tree().get_first_node_in_group("player")
	if p:
		return p
	var cs = get_tree().current_scene
	if cs:
		return cs.find_child("Player", true, false)
	return null

func save_game() -> void:
	var wrapper = get_tree().current_scene
	var wrapper_path := ""
	var active_level_path := ""
	if wrapper:
		wrapper_path = wrapper.scene_file_path
		if wrapper.has_method("get_active_level_path"):
			active_level_path = str(wrapper.call("get_active_level_path"))

	var data = {
		"metadata": {
			"player_name": current_player_name,
			"money": 0,
			"date": Time.get_date_string_from_system(),
			"wrapper_path": wrapper_path,
			"active_level_path": active_level_path
		},
		"player": {},
		"inventory": [],
		"time": {},
		"persistence": persistence_data,
		"world": []
	}

	var player = _find_player()
	if player:
		data["metadata"]["money"] = int(player.money) if ("money" in player and player.money != null) else 0
		data["player"] = {
			"pos_x": float(player.global_position.x),
			"pos_y": float(player.global_position.y),
			"money": int(player.money) if ("money" in player and player.money != null) else 0,
			"axe_damage": int(player.get("axe_hit_damage")) if player.get("axe_hit_damage") != null else 10,
			"health": int(player.get("health")) if player.get("health") != null else 100,
			"max_health": int(player.get("max_health")) if player.get("max_health") != null else 100
		}

		if "inventory_data" in player and player.inventory_data and "slot_datas" in player.inventory_data and player.inventory_data.slot_datas:
			for slot in player.inventory_data.slot_datas:
				if slot and slot.item_data:
					data["inventory"].append({
						"path": slot.item_data.resource_path,
						"amount": int(slot.quantity)
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

	if wrapper and wrapper.has_method("save_level_state"):
		wrapper.call("save_level_state")

	data["persistence"] = persistence_data

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

func start_new_game(slot_index: int, player_name: String) -> void:
	current_slot = slot_index
	current_player_name = player_name
	persistence_data = { "levels": {}, "objects": {}, "watered_tiles_by_level": {} }

	var path = get_save_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.is_gameplay_active = false
		time_manager.auto_sleep_penalty_applied = false
		time_manager.player_spawn_tag = "sleep"
		if time_manager.has_method("load_save_data"):
			time_manager.load_save_data({
				"time_seconds": 21600.0,
				"day": 1,
				"month": 4,
				"year": 2025,
				"season": 0,
				"penalty": false,
				"energy": 100.0
			})

	pending_level_path = DEFAULT_LEVEL_SCENE_PATH
	pending_spawn_tag = "sleep"
	pending_has_player_pos = false
	pending_player_pos = Vector2.ZERO

	get_tree().change_scene_to_file(GAME_WRAPPER_PATH)

func load_game(slot_index: int) -> void:
	var path = get_save_path(slot_index)
	if not FileAccess.file_exists(path):
		return

	current_slot = slot_index

	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(text) != OK:
		return

	var data: Dictionary = json.data

	if data.has("persistence"):
		persistence_data = data["persistence"]
	else:
		persistence_data = { "levels": {}, "objects": {}, "watered_tiles_by_level": {} }

	if not persistence_data.has("levels"):
		persistence_data["levels"] = {}
	if not persistence_data.has("objects"):
		persistence_data["objects"] = {}
	if not persistence_data.has("watered_tiles_by_level"):
		persistence_data["watered_tiles_by_level"] = {}

	if data.has("metadata") and data["metadata"].has("player_name"):
		current_player_name = str(data["metadata"]["player_name"])

	var active_level := DEFAULT_LEVEL_SCENE_PATH
	if data.has("metadata") and data["metadata"].has("active_level_path"):
		var ap = str(data["metadata"]["active_level_path"])
		if ap != "" and ResourceLoader.exists(ap):
			active_level = ap

	pending_level_path = active_level
	pending_spawn_tag = ""
	pending_has_player_pos = false
	pending_player_pos = Vector2.ZERO

	if data.has("player"):
		var p = data["player"]
		pending_player_pos = Vector2(float(p.get("pos_x", 0.0)), float(p.get("pos_y", 0.0)))
		pending_has_player_pos = true

	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.is_gameplay_active = false
		time_manager.player_spawn_tag = ""
		time_manager.auto_sleep_penalty_applied = false
		if data.has("time") and time_manager.has_method("load_save_data"):
			time_manager.load_save_data(data["time"])

	get_tree().change_scene_to_file(GAME_WRAPPER_PATH)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var player = _find_player()

	if player and data.has("player"):
		var pd = data["player"]

		var money_val = pd.get("money", 0)
		if money_val == null:
			money_val = 0
		if "money" in player:
			player.money = int(money_val)

		var axe_dmg = pd.get("axe_damage")
		if axe_dmg != null:
			player.set("axe_hit_damage", int(axe_dmg))

		var hp = pd.get("health")
		if hp != null:
			player.set("health", int(hp))

		if player.has_signal("money_updated"):
			player.emit_signal("money_updated", player.money)

	if player and "inventory_data" in player and player.inventory_data and data.has("inventory"):
		var inv_list = data["inventory"]
		for i in range(inv_list.size()):
			if i < player.inventory_data.slot_datas.size():
				var slot_info = inv_list[i]
				if slot_info != null and slot_info.has("path"):
					var rp = str(slot_info["path"])
					if rp != "" and ResourceLoader.exists(rp):
						var res = load(rp)
						if res:
							var new_slot = SlotData.new()
							new_slot.item_data = res
							new_slot.quantity = int(slot_info.get("amount", 1))
							player.inventory_data.slot_datas[i] = new_slot
						else:
							player.inventory_data.slot_datas[i] = null
					else:
						player.inventory_data.slot_datas[i] = null
				else:
					player.inventory_data.slot_datas[i] = null
		player.inventory_data.emit_signal("inventory_updated", player.inventory_data)

	var time_manager2 = get_node_or_null("/root/TimeManager")
	if time_manager2:
		time_manager2.is_gameplay_active = true

func delete_save(slot_index: int) -> void:
	var path = get_save_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_refresh_slots()

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
