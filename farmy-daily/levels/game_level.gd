extends Node2D

@export var tilled_atlas_coord := Vector2i(11, 0)
@export var watered_atlas_coord := Vector2i(12, 0)
@export var ground_source_id: int = 1

@onready var save_manager = get_node("/root/SaveManager")
@onready var time_manager = get_node("/root/TimeManager")
@onready var ground_layer = find_child("Ground")

var tree_sort_index: int = 10

func _ready():
	add_to_group("persist_level")
	call_deferred("load_level_state")

func _exit_tree():
	save_level_state()

func use_hoe(pos: Vector2):
	if not ground_layer: return
	
	var map_pos = ground_layer.local_to_map(ground_layer.to_local(pos))
	ground_layer.set_cell(map_pos, ground_source_id, tilled_atlas_coord)
	save_level_state()

func use_water(pos: Vector2):
	if not ground_layer: return
	
	var map_pos = ground_layer.local_to_map(ground_layer.to_local(pos))
	var current_atlas = ground_layer.get_cell_atlas_coords(map_pos)
	
	if current_atlas == tilled_atlas_coord or current_atlas == watered_atlas_coord:
		ground_layer.set_cell(map_pos, ground_source_id, watered_atlas_coord)
		
		var crop = _get_crop_at(map_pos)
		if crop and crop.has_method("water"):
			crop.water()
		
		save_level_state()

func can_plant_seed(pos: Vector2) -> bool:
	if not ground_layer: return false
	
	var map_pos = ground_layer.local_to_map(ground_layer.to_local(pos))
	var current_atlas = ground_layer.get_cell_atlas_coords(map_pos)
	
	if current_atlas != tilled_atlas_coord and current_atlas != watered_atlas_coord:
		return false
		
	if _get_crop_at(map_pos):
		return false
		
	return true

func get_tile_center_position(pos: Vector2) -> Vector2:
	if not ground_layer: return pos
	var map_pos = ground_layer.local_to_map(ground_layer.to_local(pos))
	return ground_layer.map_to_local(map_pos)

func _get_crop_at(map_pos: Vector2i):
	for child in get_children():
		if child.has_method("setup_as_seed") or (child.get_script() and child.get_script().resource_path.contains("crop.gd")):
			var child_map_pos = ground_layer.local_to_map(ground_layer.to_local(child.global_position))
			if child_map_pos == map_pos:
				return child
	return null

func save_level_state():
	if not save_manager or not ground_layer: return
	
	var tiles_data = []
	var used_cells = ground_layer.get_used_cells()
	
	for cell in used_cells:
		var atlas = ground_layer.get_cell_atlas_coords(cell)
		var source = ground_layer.get_cell_source_id(cell)
		
		if atlas == tilled_atlas_coord or atlas == watered_atlas_coord:
			tiles_data.append({
				"x": cell.x,
				"y": cell.y,
				"s": source,
				"ax": atlas.x,
				"ay": atlas.y
			})

	var crops_data = []
	for child in get_children():
		var is_crop = child.has_method("grow_next_stage")
		var is_tree = child.has_method("setup_as_seed")
		
		if (is_crop or is_tree) and child.owner == null and child.scene_file_path != "":
			if child.has_method("_save_persistence"):
				child._save_persistence()
			
			crops_data.append({
				"scene_path": child.scene_file_path,
				"x": child.global_position.x,
				"y": child.global_position.y
			})

	var level_data = {
		"tiles": tiles_data,
		"crops": crops_data
	}
	
	save_manager.save_level_data(scene_file_path, level_data)

func load_level_state():
	if not save_manager: return
	
	var data = save_manager.get_level_data_dynamic(scene_file_path)
	if data.is_empty(): return
	
	if ground_layer and data.has("tiles"):
		for t in data["tiles"]:
			ground_layer.set_cell(Vector2i(t["x"], t["y"]), t["s"], Vector2i(t["ax"], t["ay"]))
	
	var last_save_day = data.get("last_day_index", 0)
	
	for child in get_children():
		var is_crop = child.has_method("grow_next_stage")
		var is_tree = child.has_method("setup_as_seed")
		if (is_crop or is_tree) and child.owner == null:
			child.queue_free()
	
	if data.has("crops"):
		for c_data in data["crops"]:
			if ResourceLoader.exists(c_data["scene_path"]):
				var scene = load(c_data["scene_path"])
				var inst = scene.instantiate()
				inst.global_position = Vector2(c_data["x"], c_data["y"])
				add_child(inst)
				
				if inst.has_method("simulate_catch_up"):
					inst.call_deferred("simulate_catch_up", last_save_day)
