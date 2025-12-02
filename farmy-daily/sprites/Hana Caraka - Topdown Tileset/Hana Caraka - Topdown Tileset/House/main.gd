extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var inventory_interface: Control = $UI/InventoryInterface
@onready var chest: StaticBody2D = null
@onready var hot_bar_inventory: PanelContainer = $UI/HotBarInventory
@onready var tile_selector: Sprite2D = $TileSelector
@onready var ground_layer: TileMapLayer = $Start/NavRegion/Ground

var obstruction_layers: Array[TileMapLayer] = []
var hoe_cooldown: bool = false

const HOED_SOURCE_ID: int = 1
const HOED_ATLAS_COORDS: Vector2i = Vector2i(11, 0)
const WATERED_SOURCE_ID: int = 1
const WATERED_ATLAS_COORDS: Vector2i = Vector2i(12, 0)

var watered_tiles: Dictionary = {}
var current_open_chest: StaticBody2D = null

func _ready() -> void:
	if has_node("Chest"):
		chest = $Chest

	var parent_node = ground_layer.get_parent()
	for child in parent_node.get_children():
		if child is TileMapLayer and child != ground_layer:
			obstruction_layers.append(child)

	var spawn_node: Node2D = null
	if TimeManager.player_spawn_tag != "":
		spawn_node = find_child(TimeManager.player_spawn_tag, true, false) as Node2D
	if spawn_node == null:
		spawn_node = find_child("SpawnPoint", true, false) as Node2D
	if spawn_node == null:
		var all_markers: Array = find_children("*", "Marker2D", true, false)
		if all_markers.size() > 0:
			spawn_node = all_markers[0] as Node2D
	if spawn_node:
		player.global_position = spawn_node.global_position
		player.agent.target_position = spawn_node.global_position
	TimeManager.player_spawn_tag = ""

	player.toggle_inventory.connect(toggle_inventory_interface)
	inventory_interface.hide_inventory.connect(toggle_inventory_interface)

	hot_bar_inventory.set_inventory_data(player.inventory_data)
	inventory_interface.set_player_inventory_data(player.inventory_data)
	inventory_interface.player = player

	if chest:
		chest.chest_opened.connect(on_chest_opened)
		chest.chest_closed.connect(on_chest_closed)

	inventory_interface.visible = false
	hot_bar_inventory.show()

	hot_bar_inventory.hotbar_slot_selected.connect(player.update_equipped_item)
	hot_bar_inventory.hotbar_slot_selected.connect(_on_hotbar_slot_selected)

	tile_selector.visible = false
	hot_bar_inventory.deselect_all()

	if TimeManager.has_signal("time_updated"):
		TimeManager.time_updated.connect(_on_time_updated)

	load_watered_tiles()

	await get_tree().process_frame
	set_camera_limits()

func set_camera_limits() -> void:
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
	if ground_layer.get_cell_atlas_coords(tile_pos) == WATERED_ATLAS_COORDS:
		ground_layer.set_cell(tile_pos, HOED_SOURCE_ID, HOED_ATLAS_COORDS)
	watered_tiles.erase(tile_pos)
	save_watered_tiles()

func _on_hotbar_slot_selected(_index: int) -> void:
	await get_tree().process_frame
	refresh_tile_selector()

func refresh_tile_selector() -> void:
	if inventory_interface.visible or hoe_cooldown:
		tile_selector.visible = false
		return
	if not player.equipped_item:
		tile_selector.visible = false
		return

	var n = str(player.equipped_item.name)
	var mouse_pos = get_global_mouse_position()

	if n == "Hoe":
		if is_tile_farmable(mouse_pos):
			tile_selector.visible = true
			tile_selector.global_position = get_tile_center_position(mouse_pos)
		else:
			tile_selector.visible = false
		return

	if n == "Watering Can":
		if is_tile_waterable(mouse_pos):
			tile_selector.visible = true
			tile_selector.global_position = get_tile_center_position(mouse_pos)
		else:
			tile_selector.visible = false
		return

	if "Seeds" in n:
		if can_plant_seed(mouse_pos):
			tile_selector.visible = true
			tile_selector.global_position = get_tile_center_position(mouse_pos)
		else:
			tile_selector.visible = false
		return

	tile_selector.visible = false

func _process(_delta: float) -> void:
	if player.equipped_item:
		refresh_tile_selector()

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("inventory"):
		toggle_inventory_interface()
		get_viewport().set_input_as_handled()

func toggle_inventory_interface() -> void:
	if inventory_interface.visible:
		if current_open_chest:
			current_open_chest.close_chest()
			return
		inventory_interface.visible = false
		hot_bar_inventory.show()
		player.update_equipped_item(hot_bar_inventory.active_slot_index)
		refresh_tile_selector()
		player.is_movement_locked = false
	else:
		inventory_interface.visible = true
		hot_bar_inventory.hide()
		tile_selector.visible = false
		hot_bar_inventory.deselect_all()
		player.is_movement_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func on_chest_opened(inventory_data) -> void:
	current_open_chest = chest
	inventory_interface.set_external_inventory(inventory_data)
	inventory_interface.visible = true
	hot_bar_inventory.hide()
	tile_selector.visible = false
	hot_bar_inventory.deselect_all()
	player.is_movement_locked = true
	player.agent.target_position = player.global_position
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func on_chest_closed() -> void:
	current_open_chest = null
	inventory_interface.clear_external_inventory()
	inventory_interface.visible = false
	hot_bar_inventory.show()
	player.is_movement_locked = false
	refresh_tile_selector()

func get_tile_center_position(global_pos: Vector2) -> Vector2:
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	return ground_layer.to_global(ground_layer.map_to_local(tile_pos))

func is_tile_occupied(center: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = center
	query.collide_with_bodies = true
	query.collision_mask = 4
	var results = space_state.intersect_point(query)
	for result in results:
		var collider = result.collider
		if collider == player or (player and player.is_ancestor_of(collider)):
			continue
		return true
	return false

func is_tile_farmable(global_pos: Vector2) -> bool:
	if hoe_cooldown:
		return false
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
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
	if hoe_cooldown:
		return false
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	var atlas_coords = ground_layer.get_cell_atlas_coords(tile_pos)
	if atlas_coords != HOED_ATLAS_COORDS:
		return false
	return true

func can_plant_seed(global_pos: Vector2) -> bool:
	if hoe_cooldown:
		return false
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	var target_center = get_tile_center_position(global_pos)
	var all_trees = get_tree().get_nodes_in_group("trees")
	for t in all_trees:
		if t.global_position.distance_to(target_center) < 28.0:
			return false
	var tile_data = ground_layer.get_cell_tile_data(tile_pos)
	if not tile_data:
		return false
	var can_farm = tile_data.get_custom_data("can_farm")
	if typeof(can_farm) == TYPE_BOOL and not can_farm:
		return false
	var atlas_coords = ground_layer.get_cell_atlas_coords(tile_pos)
	if atlas_coords != WATERED_ATLAS_COORDS:
		return false
	if is_tile_occupied(target_center):
		return false
	return true

func plant_crop(global_pos: Vector2, crop_scene: PackedScene) -> void:
	if not can_plant_seed(global_pos):
		return
	var tile_center = get_tile_center_position(global_pos)
	if tile_center == Vector2.ZERO:
		return
	var crop = crop_scene.instantiate()
	get_tree().current_scene.add_child(crop)
	crop.global_position = tile_center

func use_hoe(global_pos: Vector2) -> void:
	if not is_tile_farmable(global_pos):
		return
	hoe_cooldown = true
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	ground_layer.set_cell(tile_pos, HOED_SOURCE_ID, HOED_ATLAS_COORDS)
	await get_tree().create_timer(0.15).timeout
	hoe_cooldown = false
	refresh_tile_selector()

func water_tile(global_pos: Vector2) -> void:
	if not is_tile_waterable(global_pos):
		return
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	ground_layer.set_cell(tile_pos, WATERED_SOURCE_ID, WATERED_ATLAS_COORDS)
	var tile_center = ground_layer.to_global(ground_layer.map_to_local(tile_pos))
	watered_tiles[tile_pos] = {
		"day": TimeManager.current_day,
		"month": TimeManager.current_month,
		"time": TimeManager.current_time_seconds
	}
	save_watered_tiles()

	var particles = CPUParticles2D.new()
	particles.amount = 25
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.emitting = true
	particles.gravity = Vector2(0, 500)
	particles.speed_scale = 1.5
	particles.position = tile_center
	add_child(particles)

func use_water(global_pos: Vector2) -> void:
	water_tile(global_pos)

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
	if ground_layer == null:
		push_warning("ground_layer is null; cannot determine current level root.")
		return
	var old_level_root: Node = ground_layer
	while old_level_root.get_parent() != self and old_level_root.get_parent() != null:
		old_level_root = old_level_root.get_parent()
	if old_level_root.get_parent() == null:
		push_warning("Could not determine level root from ground_layer.")
		return
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
	var new_ground_layer: TileMapLayer = _find_ground_layer(new_level_root)
	if new_ground_layer == null:
		push_warning("No Ground TileMapLayer found under new level root.")
		return
	ground_layer = new_ground_layer
	obstruction_layers.clear()
	var parent_node2: Node = ground_layer.get_parent()
	for child in parent_node2.get_children():
		if child is TileMapLayer and child != ground_layer:
			obstruction_layers.append(child)
	var spawn_node: Node2D = null
	if TimeManager.player_spawn_tag != "":
		spawn_node = find_child(TimeManager.player_spawn_tag, true, false) as Node2D
	if spawn_node == null:
		spawn_node = find_child("SpawnPoint", true, false) as Node2D
	if spawn_node == null:
		var all_markers: Array = find_children("*", "Marker2D", true, false)
		if all_markers.size() > 0:
			spawn_node = all_markers[0] as Node2D
	if spawn_node:
		player.global_position = spawn_node.global_position
		player.agent.target_position = spawn_node.global_position
	TimeManager.player_spawn_tag = ""
	set_camera_limits()
	refresh_tile_selector()

func _find_ground_layer(root: Node) -> TileMapLayer:
	var node = root.get_node_or_null("NavRegion/Ground")
	if node is TileMapLayer:
		return node
	node = root.get_node_or_null("Backgrounds/NavRegion/Ground")
	if node is TileMapLayer:
		return node
	var queue: Array = [root]
	while queue.size() > 0:
		var current: Node = queue[0]
		queue.remove_at(0)
		if current is TileMapLayer and current.name == "Ground":
			return current
		for child in current.get_children():
			queue.append(child)
	return null
