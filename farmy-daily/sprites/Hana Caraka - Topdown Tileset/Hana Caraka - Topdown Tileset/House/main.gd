extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var inventory_interface: Control = $UI/InventoryInterface
@onready var hot_bar_inventory: PanelContainer = $UI/HotBarInventory
@onready var tile_selector: Node2D = $TileSelector 

var ground_layer: TileMapLayer = null
var obstruction_layers: Array[TileMapLayer] = []

var tree_sort_index: int = 11

const HOED_SOURCE_ID: int = 1
const HOED_ATLAS_COORDS: Vector2i = Vector2i(11, 0)
const WATERED_SOURCE_ID: int = 1
const WATERED_ATLAS_COORDS: Vector2i = Vector2i(12, 0)

var watered_tiles: Dictionary = {}
var current_open_chest: StaticBody2D = null

var transition_layer: CanvasLayer = null
var transition_rect: ColorRect = null

var pause_menu_scene = preload("res://sprites/Hana Caraka - Topdown Tileset/Hana Caraka - Topdown Tileset/House/PauseMenu.tscn")

func _ready() -> void:
	_refresh_layer_references(self)
	_setup_transition_layer()
	_connect_all_chests(self)
	
	var menu = pause_menu_scene.instantiate()
	add_child(menu)

	var spawn_node: Node2D = null
	if TimeManager.player_spawn_tag != "":
		spawn_node = find_child(TimeManager.player_spawn_tag, true, false) as Node2D
	if spawn_node == null:
		spawn_node = find_child("SpawnPoint", true, false) as Node2D
	if spawn_node == null:
		var all_markers: Array = find_children("*", "Marker2D", true, false)
		if all_markers.size() > 0:
			spawn_node = all_markers[0] as Node2D
	
	if spawn_node and is_instance_valid(player):
		player.global_position = spawn_node.global_position
		player.agent.target_position = spawn_node.global_position
	
	TimeManager.player_spawn_tag = ""

	if is_instance_valid(player) and is_instance_valid(inventory_interface):
		player.toggle_inventory.connect(toggle_inventory_interface)
		inventory_interface.hide_inventory.connect(toggle_inventory_interface)
		hot_bar_inventory.set_inventory_data(player.inventory_data)
		inventory_interface.set_player_inventory_data(player.inventory_data)
		inventory_interface.player = player

	inventory_interface.visible = false
	hot_bar_inventory.show()

	hot_bar_inventory.hotbar_slot_selected.connect(player.update_equipped_item)
	hot_bar_inventory.hotbar_slot_selected.connect(_on_hotbar_slot_selected)

	if is_instance_valid(tile_selector):
		tile_selector.visible = false
	
	hot_bar_inventory.deselect_all()

	if TimeManager.has_signal("time_updated"):
		TimeManager.time_updated.connect(_on_time_updated)

	load_watered_tiles()

	await get_tree().process_frame
	set_camera_limits()

func _refresh_layer_references(root: Node) -> void:
	ground_layer = null
	obstruction_layers.clear()
	
	var all_layers: Array[Node] = root.find_children("*", "TileMapLayer", true, false)
	
	for layer in all_layers:
		if layer.name == "Ground":
			ground_layer = layer
			if is_instance_valid(tile_selector) and tile_selector.has_method("set_tile_size"):
				tile_selector.set_tile_size(ground_layer.tile_set.tile_size)
		else:
			obstruction_layers.append(layer)
			
	if ground_layer == null:
		push_error("CRITICAL: No TileMapLayer named 'Ground' found in this level!")

func _connect_all_chests(node: Node) -> void:
	if node.has_signal("chest_opened"):
		if not node.chest_opened.is_connected(on_chest_opened):
			node.chest_opened.connect(on_chest_opened.bind(node))
		if not node.chest_closed.is_connected(on_chest_closed):
			node.chest_closed.connect(on_chest_closed)
	
	for child in node.get_children():
		_connect_all_chests(child)

func _setup_transition_layer() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100 
	add_child(transition_layer)
	
	transition_rect = ColorRect.new()
	transition_rect.color = Color.BLACK
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.modulate.a = 0.0
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_rect)

func set_camera_limits() -> void:
	if not is_instance_valid(ground_layer) or not is_instance_valid(player):
		return
		
	var map_rect = ground_layer.get_used_rect()
	if map_rect.size == Vector2i.ZERO:
		return
	
	var tile_size = ground_layer.tile_set.tile_size
	var render_scale = ground_layer.global_scale
	var pos = ground_layer.global_position
	
	player.cam.limit_left = int(pos.x + map_rect.position.x * tile_size.x * render_scale.x)
	player.cam.limit_top = int(pos.y + map_rect.position.y * tile_size.y * render_scale.y)
	player.cam.limit_right = int(pos.x + map_rect.end.x * tile_size.x * render_scale.x)
	player.cam.limit_bottom = int(pos.y + map_rect.end.y * tile_size.y * render_scale.y)
	player.cam.position_smoothing_enabled = true
	player.cam.position_smoothing_speed = 8.0
	player.cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS

func _on_time_updated(_time_string: String) -> void:
	var day = TimeManager.current_day
	var month = TimeManager.current_month
	var time_sec = TimeManager.current_time_seconds
	update_watered_tiles(day, month, time_sec)

func update_watered_tiles(current_day: int, current_month: int, current_time: float) -> void:
	var tiles_to_dry: Array[Vector2i] = []
	for tile_pos in watered_tiles.keys():
		var data = watered_tiles[tile_pos]
		var w_day = int(data.get("day", current_day))
		var w_time = float(data.get("time", current_time))
		var w_month = int(data.get("month", current_month))
		
		var time_passed := 0.0
		if w_day == current_day and w_month == current_month:
			time_passed = current_time - w_time
		else:
			var day_diff = current_day - w_day
			if w_month != current_month:
				var days_in_prev_month = TimeManager.DAYS_IN_MONTH[w_month]
				day_diff = (days_in_prev_month - w_day) + current_day
			
			if day_diff < 0:
				tiles_to_dry.append(tile_pos)
				continue
				
			time_passed = day_diff * 86400.0 + (current_time - w_time)
		
		if time_passed >= 43200.0:
			tiles_to_dry.append(tile_pos)
			
	for tile_pos in tiles_to_dry:
		dry_tile(tile_pos)

func dry_tile(tile_pos: Vector2i) -> void:
	if not is_instance_valid(ground_layer): return
	if ground_layer.get_cell_atlas_coords(tile_pos) == WATERED_ATLAS_COORDS:
		ground_layer.set_cell(tile_pos, HOED_SOURCE_ID, HOED_ATLAS_COORDS)
	watered_tiles.erase(tile_pos)
	save_watered_tiles()

func _on_hotbar_slot_selected(_index: int) -> void:
	await get_tree().process_frame
	refresh_tile_selector()

func refresh_tile_selector() -> void:
	if not is_instance_valid(tile_selector): return
	
	if inventory_interface.visible:
		tile_selector.visible = false
		return
		
	if not is_instance_valid(player) or not player.equipped_item:
		tile_selector.visible = false
		return

	var item_name = str(player.equipped_item.name)
	var mouse_pos = get_global_mouse_position()
	
	var center_pos = get_tile_center_position(mouse_pos)
	if center_pos == Vector2.ZERO: 
		tile_selector.visible = false
		return

	tile_selector.global_position = center_pos
	
	var is_valid = false
	var show_selector = false

	if item_name == "Hoe":
		show_selector = true
		is_valid = is_tile_farmable(mouse_pos)

	elif item_name == "Watering Can":
		show_selector = true
		is_valid = is_tile_waterable(mouse_pos)

	elif "Seed" in item_name or "Seeds" in item_name:
		show_selector = true
		is_valid = can_plant_seed(mouse_pos)
	
	if show_selector:
		tile_selector.visible = true
		if tile_selector.has_method("set_status"):
			tile_selector.set_status(is_valid)
	else:
		tile_selector.visible = false

func _process(_delta: float) -> void:
	if is_instance_valid(player) and player.equipped_item:
		refresh_tile_selector()

func toggle_inventory_interface() -> void:
	if inventory_interface.visible:
		if current_open_chest and is_instance_valid(current_open_chest):
			current_open_chest.close_chest()
			return
		inventory_interface.visible = false
		hot_bar_inventory.show()
		if is_instance_valid(player):
			player.update_equipped_item(hot_bar_inventory.active_slot_index)
			player.is_movement_locked = false
		refresh_tile_selector()
	else:
		inventory_interface.visible = true
		hot_bar_inventory.hide()
		tile_selector.visible = false
		hot_bar_inventory.deselect_all()
		if is_instance_valid(player):
			player.is_movement_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func on_chest_opened(inventory_data, chest_instance) -> void:
	current_open_chest = chest_instance
	inventory_interface.set_external_inventory(inventory_data)
	inventory_interface.visible = true
	hot_bar_inventory.hide()
	tile_selector.visible = false
	hot_bar_inventory.deselect_all()
	
	if is_instance_valid(player):
		player.is_movement_locked = true
		if player.agent:
			player.agent.target_position = player.global_position
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func on_chest_closed() -> void:
	current_open_chest = null
	inventory_interface.clear_external_inventory()
	inventory_interface.visible = false
	hot_bar_inventory.show()
	
	if is_instance_valid(player):
		player.is_movement_locked = false
	
	refresh_tile_selector()

func get_tile_center_position(global_pos: Vector2) -> Vector2:
	if not is_instance_valid(ground_layer): return Vector2.ZERO
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	return ground_layer.to_global(ground_layer.map_to_local(tile_pos))

func is_tile_occupied(center: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = center
	query.collide_with_bodies = true
	query.collide_with_areas = false 
	query.collision_mask = 1 | 4 
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var collider = result.collider
		if collider == player or (player and player.is_ancestor_of(collider)):
			continue
		return true
	return false

func is_tile_farmable(global_pos: Vector2) -> bool:
	if not is_instance_valid(ground_layer): 
		return false
	
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	
	if ground_layer.get_cell_source_id(tile_pos) == -1:
		return false
		
	for layer in obstruction_layers:
		if is_instance_valid(layer):
			if layer.get_cell_source_id(tile_pos) != -1:
				return false
	
	var tile_data = ground_layer.get_cell_tile_data(tile_pos)
	if not tile_data:
		return false
		
	var can_farm = tile_data.get_custom_data("can_farm")
	if typeof(can_farm) == TYPE_BOOL and not can_farm:
		return false
		
	var atlas_coords = ground_layer.get_cell_atlas_coords(tile_pos)
	if atlas_coords == HOED_ATLAS_COORDS or atlas_coords == WATERED_ATLAS_COORDS:
		return false
		
	if is_tile_occupied(get_tile_center_position(global_pos)):
		return false
		
	return true

func is_tile_waterable(global_pos: Vector2) -> bool:
	if not is_instance_valid(ground_layer): 
		return false
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	var atlas_coords = ground_layer.get_cell_atlas_coords(tile_pos)
	
	if atlas_coords == HOED_ATLAS_COORDS:
		return true
	return false

func can_plant_seed(global_pos: Vector2) -> bool:
	if not is_instance_valid(ground_layer) or not is_instance_valid(player): 
		return false
	
	var item = player.equipped_item
	if not item: return false
	
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	var target_center = get_tile_center_position(global_pos)

	if "Tree Seed" in item.name:
		for x in range(-1, 2):
			for y in range(-1, 2):
				var neighbor_map_pos = tile_pos + Vector2i(x, y)
				var neighbor_center = ground_layer.to_global(ground_layer.map_to_local(neighbor_map_pos))
				if is_tile_occupied(neighbor_center):
					return false
		var source_id = ground_layer.get_cell_source_id(tile_pos)
		if source_id == -1: return false
		return true
	
	if is_tile_occupied(target_center):
		return false
		
	var atlas_coords = ground_layer.get_cell_atlas_coords(tile_pos)
	if atlas_coords == HOED_ATLAS_COORDS or atlas_coords == WATERED_ATLAS_COORDS:
		return true
		
	return false

func use_hoe(global_pos: Vector2) -> void:
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	
	spawn_till_effect(get_tile_center_position(global_pos))
	
	if is_instance_valid(ground_layer):
		ground_layer.set_cell(tile_pos, HOED_SOURCE_ID, HOED_ATLAS_COORDS)
	
	refresh_tile_selector()

func use_water(global_pos: Vector2) -> void:
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	var tile_center = ground_layer.to_global(ground_layer.map_to_local(tile_pos))
	
	spawn_water_effect(tile_center)
	
	await get_tree().create_timer(0.25).timeout

	if is_instance_valid(ground_layer):
		ground_layer.set_cell(tile_pos, WATERED_SOURCE_ID, WATERED_ATLAS_COORDS)
		
		watered_tiles[tile_pos] = {
			"day": TimeManager.current_day,
			"month": TimeManager.current_month,
			"time": TimeManager.current_time_seconds
		}
		save_watered_tiles()
	
	refresh_tile_selector()

func spawn_till_effect(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.amount = 6
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.direction = Vector2(0, -1)
	particles.spread = 40.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2(0, 400)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.4, 0.3, 0.2)
	particles.position = pos
	particles.z_index = 5
	
	get_tree().current_scene.add_child(particles)
	await get_tree().process_frame
	particles.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func spawn_water_effect(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.amount = 6
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT 
	particles.direction = Vector2(0, -1) 
	particles.spread = 25.0 
	particles.initial_velocity_min = 50.0 
	particles.initial_velocity_max = 70.0 
	particles.gravity = Vector2(0, 800) 
	
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 2.5
	particles.color = Color(0.2, 0.6, 1.0, 1.0)
	particles.position = pos
	particles.z_index = 20
	
	get_tree().current_scene.add_child(particles)
	await get_tree().process_frame
	particles.emitting = true
	
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func load_watered_tiles() -> void:
	watered_tiles.clear()
	if not TimeManager.has_method("load_watered_tiles"):
		return
	var saved_data = TimeManager.load_watered_tiles()
	if typeof(saved_data) != TYPE_DICTIONARY:
		return
	for key in saved_data.keys():
		var tile_pos_str = str(key)
		var parts = tile_pos_str.split(",")
		if parts.size() != 2:
			continue
		var x = int(parts[0])
		var y = int(parts[1])
		var tile_pos = Vector2i(x, y)
		var data = saved_data[key]
		if typeof(data) != TYPE_DICTIONARY:
			continue
		
		var day = int(data.get("day", TimeManager.current_day))
		var month = int(data.get("month", TimeManager.current_month))
		var time_val = float(data.get("time", TimeManager.current_time_seconds))
		
		watered_tiles[tile_pos] = {
			"day": day,
			"month": month,
			"time": time_val
		}
		if is_instance_valid(ground_layer):
			ground_layer.set_cell(tile_pos, WATERED_SOURCE_ID, WATERED_ATLAS_COORDS)

func save_watered_tiles() -> void:
	if not TimeManager.has_method("save_watered_tiles"):
		return
	var save_data: Dictionary = {}
	for tile_pos in watered_tiles.keys():
		var data = watered_tiles[tile_pos]
		var key = str(tile_pos.x) + "," + str(tile_pos.y)
		save_data[key] = data
	TimeManager.save_watered_tiles(save_data)

func change_level_to(target_scene_path: String, spawn_tag: String) -> void:
	var packed_scene: PackedScene = load(target_scene_path)
	if packed_scene == null:
		push_warning("Could not load level: " + target_scene_path)
		return
	if not is_instance_valid(ground_layer):
		push_warning("ground_layer is null; cannot determine current level root.")
		return
		
	if is_instance_valid(player):
		player.is_movement_locked = true
		player.velocity = Vector2.ZERO
		
	if is_instance_valid(transition_rect):
		var t = create_tween()
		t.tween_property(transition_rect, "modulate:a", 1.0, 0.5)
		await t.finished
		
	var old_level_root: Node = ground_layer
	while old_level_root.get_parent() != self and old_level_root.get_parent() != null:
		old_level_root = old_level_root.get_parent()
		
	TimeManager.player_spawn_tag = spawn_tag
	var parent: Node = old_level_root.get_parent()
	var index: int = old_level_root.get_index()
	var old_name: String = old_level_root.name
	
	old_level_root.queue_free()
	var new_level_root: Node = packed_scene.instantiate()
	new_level_root.name = old_name
	parent.add_child(new_level_root)
	parent.move_child(new_level_root, index)
	
	await get_tree().process_frame
	
	_refresh_layer_references(new_level_root)
				
	var spawn_node: Node2D = null
	if TimeManager.player_spawn_tag != "":
		spawn_node = find_child(TimeManager.player_spawn_tag, true, false) as Node2D
	if spawn_node == null:
		spawn_node = find_child("SpawnPoint", true, false) as Node2D
	if spawn_node == null:
		var all_markers: Array = find_children("*", "Marker2D", true, false)
		if all_markers.size() > 0:
			spawn_node = all_markers[0] as Node2D
	
	if spawn_node and is_instance_valid(player):
		player.global_position = spawn_node.global_position
		player.agent.target_position = spawn_node.global_position
		
	TimeManager.player_spawn_tag = ""
	set_camera_limits()
	refresh_tile_selector()
	
	_connect_all_chests(new_level_root)
	
	await get_tree().create_timer(0.5).timeout
	
	if is_instance_valid(transition_rect):
		var t2 = create_tween()
		t2.tween_property(transition_rect, "modulate:a", 0.0, 0.5)
		await t2.finished
		
	if is_instance_valid(player):
		player.is_movement_locked = false

func get_level_data() -> Dictionary:
	return {
		"watered_tiles": watered_tiles,
		"ground_modifications": _get_ground_modifications()
	}

func load_level_data(data: Dictionary) -> void:
	watered_tiles = data.get("watered_tiles", {})
	
	var mods = data.get("ground_modifications", {})
	if is_instance_valid(ground_layer):
		for key in mods:
			var coords = str_to_var("Vector2i" + key)
			var tile_info = mods[key]
			ground_layer.set_cell(coords, tile_info["source_id"], str_to_var("Vector2i" + tile_info["atlas_coords"]))

func _get_ground_modifications() -> Dictionary:
	var mods = {}
	if is_instance_valid(ground_layer):
		for tile_pos in ground_layer.get_used_cells():
			var atlas = ground_layer.get_cell_atlas_coords(tile_pos)
			if atlas == HOED_ATLAS_COORDS or atlas == WATERED_ATLAS_COORDS:
				mods[str(tile_pos)] = {
					"source_id": ground_layer.get_cell_source_id(tile_pos),
					"atlas_coords": str(atlas)
				}
	return mods
