extends Node

const SAVE_PATH: String = "user://save_game.dat"

var world_state: Dictionary = {}
var level_drops: Dictionary = {}
var level_dynamic_data: Dictionary = {}

var _current_scene_path: String = ""

func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene and scene.scene_file_path != _current_scene_path:
		_current_scene_path = scene.scene_file_path
		_spawn_drops_for_level(_current_scene_path)

func save_game() -> void:
	var root: Node = get_tree().current_scene
	if root.has_method("save_level_state"):
		root.call("save_level_state")

	var save_data: Dictionary = {
		"time": {},
		"quests": {},
		"player": {},
		"inventory": [],
		"level": {},
		"world_state": world_state,
		"level_drops": level_drops,
		"level_dynamic_data": level_dynamic_data
	}

	if has_node("/root/TimeManager"):
		save_data["time"] = get_node("/root/TimeManager").call("get_save_data")
	
	if has_node("/root/QuestManager"):
		save_data["quests"] = get_node("/root/QuestManager").call("get_save_data")

	var player: Node2D = root.find_child("Player", true, false)
	if player:
		save_data["player"] = {
			"position_x": player.global_position.x,
			"position_y": player.global_position.y,
			"scene_path": root.scene_file_path,
			"money": player.get("money")
		}
		
		var inv_data = player.get("inventory_data")
		if inv_data and inv_data.has_method("serialize"):
			save_data["inventory"] = inv_data.call("serialize")

	if root.has_method("get_level_data"):
		save_data["level"] = root.call("get_level_data")

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_data: Variant = file.get_var()
	file.close()
	
	if not save_data is Dictionary:
		return

	if save_data.has("world_state"): world_state = save_data["world_state"]
	if save_data.has("level_drops"): level_drops = save_data["level_drops"]
	if save_data.has("level_dynamic_data"): level_dynamic_data = save_data["level_dynamic_data"]

	if save_data.has("time") and has_node("/root/TimeManager"):
		get_node("/root/TimeManager").call("load_save_data", save_data["time"])
	
	if save_data.has("quests") and has_node("/root/QuestManager"):
		get_node("/root/QuestManager").call("load_save_data", save_data["quests"])

	if save_data.has("player"):
		var player_data: Dictionary = save_data["player"]
		var scene_path: String = player_data.get("scene_path", "")
		
		if scene_path != "" and scene_path != get_tree().current_scene.scene_file_path:
			get_tree().change_scene_to_file(scene_path)
			await get_tree().process_frame
		
		var player: Node2D = get_tree().current_scene.find_child("Player", true, false)
		if player:
			player.global_position = Vector2(player_data["position_x"], player_data["position_y"])
			if player_data.has("money"):
				player.set("money", player_data["money"])
				if player.has_signal("money_updated"):
					player.emit_signal("money_updated", player_data["money"])
			
			var inv_data = player.get("inventory_data")
			if save_data.has("inventory") and inv_data and inv_data.has_method("deserialize"):
				inv_data.call("deserialize", save_data["inventory"])

	if save_data.has("level") and get_tree().current_scene.has_method("load_level_data"):
		get_tree().current_scene.call("load_level_data", save_data["level"])
		
	var current_level: Node = get_tree().current_scene
	if current_level.has_method("load_level_state"):
		current_level.call("load_level_state")
	
	_current_scene_path = get_tree().current_scene.scene_file_path
	_spawn_drops_for_level(_current_scene_path)

func get_object_state(node: Node2D) -> Dictionary:
	var level_id: String = _get_level_id(node)
	var object_id: String = _get_object_id(node)
	if world_state.has(level_id) and world_state[level_id].has(object_id):
		return world_state[level_id][object_id]
	return {}

func save_object_state(node: Node2D, data: Dictionary) -> void:
	var level_id: String = _get_level_id(node)
	var object_id: String = _get_object_id(node)
	if not world_state.has(level_id): world_state[level_id] = {}
	if not world_state[level_id].has(object_id): world_state[level_id][object_id] = {}
	for key in data:
		world_state[level_id][object_id][key] = data[key]

func save_level_data(level_id: String, data: Dictionary) -> void:
	if has_node("/root/TimeManager"):
		var tm: Node = get_node("/root/TimeManager")
		data["last_day_index"] = tm.get("current_day") + (tm.get("current_month") * 30) + (tm.get("current_year") * 365)
	level_dynamic_data[level_id] = data

func get_level_data_dynamic(level_id: String) -> Dictionary:
	if not level_dynamic_data.has(level_id):
		return {}
	return level_dynamic_data[level_id]

func _get_level_id(node: Node) -> String:
	if node.owner and node.owner.scene_file_path: return node.owner.scene_file_path
	if get_tree().current_scene: return get_tree().current_scene.scene_file_path
	return "unknown_level"

func _get_object_id(node: Node2D) -> String:
	return str(Vector2i(node.global_position))

func update_drop(level_id: String, uuid: String, data: Dictionary) -> void:
	if not level_drops.has(level_id): level_drops[level_id] = {}
	level_drops[level_id][uuid] = data

func remove_drop(level_id: String, uuid: String) -> void:
	if level_drops.has(level_id) and level_drops[level_id].has(uuid): level_drops[level_id].erase(uuid)

func _spawn_drops_for_level(level_id: String) -> void:
	if not level_drops.has(level_id): return
	var drops_data: Dictionary = level_drops[level_id]
	var current_time: int = int(Time.get_unix_time_from_system())
	var pick_up_scene: PackedScene = load("res://Item/pick_up/pick_up.tscn")
	var slot_script: Script = load("res://Inventory/slot_data.gd")
	var to_remove: Array = []

	for uuid in drops_data:
		var data: Dictionary = drops_data[uuid]
		if current_time - data.get("time", 0) > 1200:
			to_remove.append(uuid)
			continue
		var instance: Node2D = pick_up_scene.instantiate()
		instance.set("uuid", uuid)
		instance.set("creation_time", data.get("time", current_time))
		instance.position = Vector2(data["x"], data["y"])
		var slot: Resource = slot_script.new()
		if data.has("item_path") and ResourceLoader.exists(data["item_path"]):
			slot.item_data = load(data["item_path"])
			slot.quantity = data.get("quantity", 1)
			instance.set("slot_data", slot)
			get_tree().current_scene.add_child(instance)
		else:
			to_remove.append(uuid)
	for uuid in to_remove:
		level_drops[level_id].erase(uuid)
