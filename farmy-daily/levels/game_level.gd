extends Node2D

@export var tilled_atlas_coord: Vector2i = Vector2i(11, 0)
@export var watered_atlas_coord: Vector2i = Vector2i(12, 0)
@export var ground_source_id: int = 1

@onready var save_manager: Node = get_node("/root/SaveManager")
@onready var time_manager: Node = get_node("/root/TimeManager")
@onready var ground_layer: TileMapLayer = find_child("Ground")

var tree_sort_index: int = 10

func _ready() -> void:
	add_to_group("persist_level")
	call_deferred("load_level_state")

func _exit_tree() -> void:
	save_level_state()

func use_hoe(pos: Vector2) -> void:
	if not ground_layer:
		return
	var map_pos: Vector2i = ground_layer.local_to_map(ground_layer.to_local(pos))
	ground_layer.set_cell(map_pos, ground_source_id, tilled_atlas_coord)
	save_level_state()

func use_water(pos: Vector2) -> void:
	if not ground_layer:
		return
	var map_pos: Vector2i = ground_layer.local_to_map(ground_layer.to_local(pos))
	var current_atlas: Vector2i = ground_layer.get_cell_atlas_coords(map_pos)
	if current_atlas == tilled_atlas_coord or current_atlas == watered_atlas_coord:
		ground_layer.set_cell(map_pos, ground_source_id, watered_atlas_coord)
		var crop_comp: Node = _find_crop_component_at(map_pos)
		if crop_comp and crop_comp.has_method("water"):
			crop_comp.call("water")
		save_level_state()

func can_plant_seed(pos: Vector2) -> bool:
	if not ground_layer:
		return false
	var map_pos: Vector2i = ground_layer.local_to_map(ground_layer.to_local(pos))
	var current_atlas: Vector2i = ground_layer.get_cell_atlas_coords(map_pos)
	if current_atlas != tilled_atlas_coord and current_atlas != watered_atlas_coord:
		return false
	if _find_crop_root_at(map_pos) != null:
		return false
	return true

func get_tile_center_position(pos: Vector2) -> Vector2:
	if not ground_layer:
		return pos
	var map_pos: Vector2i = ground_layer.local_to_map(ground_layer.to_local(pos))
	return ground_layer.map_to_local(map_pos)

func _crop_component_is(node: Node) -> bool:
	if node == null:
		return false
	if node.get_script() == null:
		return false
	var rp := str(node.get_script().resource_path)
	return rp.ends_with("interactable/Crops/crop.gd") or rp.find("/interactable/Crops/crop.gd") != -1

func _find_crop_component_in(node: Node) -> Node:
	if _crop_component_is(node):
		return node
	var kids: Array = node.find_children("*", "", true, false)
	for k in kids:
		if _crop_component_is(k):
			return k
	return null

func _is_crop_root(node: Node) -> bool:
	if not (node is Node2D):
		return false
	return _find_crop_component_in(node) != null

func _crop_tile_pos(world_pos: Vector2) -> Vector2i:
	if not ground_layer:
		return Vector2i.ZERO
	return ground_layer.local_to_map(ground_layer.to_local(world_pos))

func _make_crop_persist_id(scene_path: String, tile_pos: Vector2i) -> String:
	return "CROP|" + scene_path + "|" + str(tile_pos.x) + "," + str(tile_pos.y)

func _find_crop_root_at(tile_pos: Vector2i) -> Node2D:
	var nodes: Array = find_children("*", "", true, false)
	for n in nodes:
		if n is Node2D and _is_crop_root(n):
			var tp := _crop_tile_pos((n as Node2D).global_position)
			if tp == tile_pos:
				return n
	return null

func _find_crop_component_at(tile_pos: Vector2i) -> Node:
	var root := _find_crop_root_at(tile_pos)
	if root == null:
		return null
	return _find_crop_component_in(root)

func _free_all_runtime_crops() -> void:
	var nodes: Array = find_children("*", "", true, false)
	for n in nodes:
		if n is Node2D and _is_crop_root(n):
			var comp := _find_crop_component_in(n)
			if comp != null and comp.owner == null:
				(n as Node2D).queue_free()

func save_level_state() -> void:
	if not save_manager or not ground_layer:
		return
	if save_manager.get("is_slot_transitioning") == true:
		return

	var tiles_data: Array = []
	var used_cells: Array[Vector2i] = ground_layer.get_used_cells()
	for cell in used_cells:
		var atlas: Vector2i = ground_layer.get_cell_atlas_coords(cell)
		var source: int = ground_layer.get_cell_source_id(cell)
		if atlas == tilled_atlas_coord or atlas == watered_atlas_coord:
			tiles_data.append({"x": cell.x, "y": cell.y, "s": source, "ax": atlas.x, "ay": atlas.y})

	var crops_data: Array = []
	var nodes: Array = find_children("*", "", true, false)
	for n in nodes:
		if not (n is Node2D):
			continue
		if not _is_crop_root(n):
			continue
		var root2d := n as Node2D
		var comp := _find_crop_component_in(root2d)
		if comp == null or comp.owner != null:
			continue

		var sp := root2d.scene_file_path
		if sp == "":
			sp = ""
			var p := root2d.get_parent()
			while p:
				if p is Node and (p as Node).scene_file_path != "":
					sp = (p as Node).scene_file_path
					break
				p = p.get_parent()
		if sp == "":
			continue

		var tp := _crop_tile_pos(root2d.global_position)
		var pid := _make_crop_persist_id(sp, tp)
		comp.set_meta("persist_id", pid)
		if comp.has_method("_save_persistence"):
			comp.call("_save_persistence")

		crops_data.append({
			"scene_path": sp,
			"tile_x": tp.x,
			"tile_y": tp.y,
			"world_x": root2d.global_position.x,
			"world_y": root2d.global_position.y
		})

	var day_index: int = 0
	if time_manager:
		day_index = int(time_manager.current_day + (time_manager.current_month * 31) + (time_manager.current_year * 400))

	var level_data: Dictionary = {"tiles": tiles_data, "crops": crops_data, "last_day_index": day_index}
	if save_manager.has_method("save_level_data"):
		save_manager.save_level_data(scene_file_path, level_data)

func load_level_state() -> void:
	if not save_manager:
		return
	var data: Dictionary = {}
	if save_manager.has_method("get_level_data_dynamic"):
		data = save_manager.get_level_data_dynamic(scene_file_path)
	if data.is_empty():
		return

	if ground_layer and data.has("tiles"):
		for t in data["tiles"]:
			ground_layer.set_cell(Vector2i(t["x"], t["y"]), int(t["s"]), Vector2i(t["ax"], t["ay"]))

	var last_save_day: int = int(data.get("last_day_index", 0))
	_free_all_runtime_crops()

	if not data.has("crops"):
		return

	await get_tree().process_frame

	for c in data["crops"]:
		var sp := str(c.get("scene_path", ""))
		if sp == "" or not ResourceLoader.exists(sp):
			continue
		var scene: PackedScene = load(sp)
		if scene == null:
			continue

		var tile_x := int(c.get("tile_x", 0))
		var tile_y := int(c.get("tile_y", 0))
		var tp := Vector2i(tile_x, tile_y)
		var pid := _make_crop_persist_id(sp, tp)

		var inst: Node2D = scene.instantiate()
		var comp := _find_crop_component_in(inst)
		if comp != null:
			comp.set_meta("persist_id", pid)

		add_child(inst)

		if ground_layer:
			var local_center := ground_layer.map_to_local(tp)
			inst.global_position = ground_layer.to_global(local_center)
		else:
			inst.global_position = Vector2(float(c.get("world_x", 0.0)), float(c.get("world_y", 0.0)))

		if inst.has_method("simulate_catch_up"):
			inst.call_deferred("simulate_catch_up", last_save_day)
		elif comp != null and comp.has_method("simulate_catch_up"):
			comp.call_deferred("simulate_catch_up", last_save_day)
