extends Node

const SAVE_PATH = "user://save_game.dat"

var world_state = {}
var level_drops = {}

var _current_scene_path = ""

func _process(_delta):
	var scene = get_tree().current_scene
	if scene and scene.scene_file_path != _current_scene_path:
		_current_scene_path = scene.scene_file_path
		_spawn_drops_for_level(_current_scene_path)

func save_game():
	var save_data = {
		"time": {},
		"quests": {},
		"player": {},
		"inventory": [],
		"level": {},
		"world_state": world_state,
		"level_drops": level_drops
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

	if save_data.has("world_state"):
		world_state = save_data["world_state"]
	else:
		world_state = {}
		
	if save_data.has("level_drops"):
		level_drops = save_data["level_drops"]
	else:
		level_drops = {}

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
	
	_current_scene_path = get_tree().current_scene.scene_file_path
	_spawn_drops_for_level(_current_scene_path)

func get_object_state(node: Node2D) -> Dictionary:
	var level_id = _get_level_id(node)
	var object_id = _get_object_id(node)
	
	if world_state.has(level_id) and world_state[level_id].has(object_id):
		return world_state[level_id][object_id]
	return {}

func save_object_state(node: Node2D, data: Dictionary):
	var level_id = _get_level_id(node)
	var object_id = _get_object_id(node)
	
	if not world_state.has(level_id):
		world_state[level_id] = {}
	
	if not world_state[level_id].has(object_id):
		world_state[level_id][object_id] = {}
		
	for key in data:
		world_state[level_id][object_id][key] = data[key]

func _get_level_id(node: Node) -> String:
	if node.owner and node.owner.scene_file_path:
		return node.owner.scene_file_path
	var current = get_tree().current_scene
	if current:
		return current.scene_file_path
	return "unknown_level"

func _get_object_id(node: Node2D) -> String:
	return str(Vector2i(node.global_position))

func update_drop(level_id: String, uuid: String, data: Dictionary):
	if not level_drops.has(level_id):
		level_drops[level_id] = {}
	level_drops[level_id][uuid] = data

func remove_drop(level_id: String, uuid: String):
	if level_drops.has(level_id) and level_drops[level_id].has(uuid):
		level_drops[level_id].erase(uuid)

func _spawn_drops_for_level(level_id: String):
	if not level_drops.has(level_id): return
	
	var drops_data = level_drops[level_id]
	var current_time = Time.get_unix_time_from_system()
	var pick_up_scene = load("res://Item/pick_up/pick_up.tscn")
	var slot_script = load("res://Inventory/slot_data.gd")
	
	var to_remove = []

	for uuid in drops_data:
		var data = drops_data[uuid]
		
		if current_time - data.get("time", 0) > 1200:
			to_remove.append(uuid)
			continue
			
		var instance = pick_up_scene.instantiate()
		instance.uuid = uuid
		instance.creation_time = data.get("time", current_time)
		instance.position = Vector2(data["x"], data["y"])
		
		var slot = slot_script.new()
		if data.has("item_path") and ResourceLoader.exists(data["item_path"]):
			slot.item_data = load(data["item_path"])
			slot.quantity = data.get("quantity", 1)
			instance.slot_data = slot
			get_tree().current_scene.add_child(instance)
		else:
			to_remove.append(uuid)
	
	for uuid in to_remove:
		level_drops[level_id].erase(uuid)
