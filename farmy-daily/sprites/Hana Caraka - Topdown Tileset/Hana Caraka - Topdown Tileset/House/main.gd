extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var inventory_interface: Control = $UI/InventoryInterface
@onready var hot_bar_inventory: PanelContainer = $UI/HotBarInventory
@onready var tile_selector: Node2D = $TileSelector
@onready var start: Node = $Start

const DEFAULT_LEVEL_SCENE_PATH: String = "res://levels/playerhouse.tscn"

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
var drop_scene = preload("res://Item/pick_up/pick_up.tscn")

var current_level_key: String = ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var sm = get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("save_game"):
			sm.save_game()
		if not sm or not sm.has_method("is_returning_to_menu") or not sm.is_returning_to_menu:
			get_tree().quit()

func get_active_level_path() -> String:
	if current_level_key != "" and current_level_key.begins_with("res://") and ResourceLoader.exists(current_level_key):
		return current_level_key
	var lr := _get_level_root()
	if lr and lr.scene_file_path != "" and ResourceLoader.exists(lr.scene_file_path):
		return lr.scene_file_path
	var lr2 := _get_level_root_from_ground()
	if lr2 and lr2.scene_file_path != "" and ResourceLoader.exists(lr2.scene_file_path):
		return lr2.scene_file_path
	return ""

func _ready() -> void:
	_setup_transition_layer()

	await _ensure_level_loaded_before_refs()

	var lvl_root0 := _get_level_root()
	_refresh_layer_references(lvl_root0 if lvl_root0 != null else get_tree().current_scene)
	_connect_all_chests(lvl_root0 if lvl_root0 != null else get_tree().current_scene)
	_update_current_level_key(lvl_root0)

	await _boot_apply_pending_level_if_needed()

	var lvl_root := _get_level_root()
	_refresh_layer_references(lvl_root if lvl_root != null else get_tree().current_scene)
	_connect_all_chests(lvl_root if lvl_root != null else get_tree().current_scene)
	_update_current_level_key(lvl_root)

	var menu = pause_menu_scene.instantiate()
	add_child(menu)

	var save_manager = get_node_or_null("/root/SaveManager")

	if save_manager and ("pending_has_player_pos" in save_manager) and bool(save_manager.pending_has_player_pos):
		var ppos = save_manager.pending_player_pos
		if typeof(ppos) == TYPE_VECTOR2:
			player.global_position = ppos
			player.agent.target_position = ppos
		save_manager.pending_has_player_pos = false
		save_manager.pending_level_path = ""
		save_manager.pending_spawn_tag = ""
	else:
		var spawn_search_root: Node = _get_level_root_from_ground()
		if spawn_search_root == null:
			spawn_search_root = _get_level_root()
		if spawn_search_root == null:
			spawn_search_root = get_tree().current_scene

		var spawn_node: Node2D = null
		if TimeManager.player_spawn_tag != "":
			spawn_node = spawn_search_root.find_child(TimeManager.player_spawn_tag, true, false) as Node2D
		if spawn_node == null:
			spawn_node = spawn_search_root.find_child("SpawnPoint", true, false) as Node2D
		if spawn_node == null:
			var all_markers: Array = spawn_search_root.find_children("*", "Marker2D", true, false)
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
	_restore_saved_drops()

	var sm2 = get_node_or_null("/root/SaveManager")
	if sm2 and sm2.has_method("end_slot_transition"):
		sm2.end_slot_transition()

	var time_manager2 = get_node_or_null("/root/TimeManager")
	if time_manager2:
		time_manager2.is_gameplay_active = true

	await get_tree().process_frame
	set_camera_limits()

func save_level_state() -> void:
	save_watered_tiles()
	_save_current_level_state()


func _get_level_root() -> Node:
	if not is_instance_valid(start):
		return null
	if start.get_child_count() <= 0:
		return null
	return start.get_child(0)

func get_level_root() -> Node:
	return _get_level_root()

func _ensure_level_loaded_before_refs() -> void:
	if not is_instance_valid(start):
		return
	if start.get_child_count() > 0:
		return

	var save_manager = get_node_or_null("/root/SaveManager")
	var path := ""
	if save_manager and ("pending_level_path" in save_manager):
		path = str(save_manager.pending_level_path)

	if path == "" or not ResourceLoader.exists(path):
		path = DEFAULT_LEVEL_SCENE_PATH

	await _replace_level_under_start(path)

func _replace_level_under_start(scene_path: String) -> void:
	if not is_instance_valid(start):
		return
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return

	current_level_key = scene_path
	if TimeManager.has_method("set_water_level_key"):
		TimeManager.set_water_level_key(current_level_key)

	for c in start.get_children():
		c.queue_free()

	await get_tree().process_frame

	var packed: PackedScene = load(scene_path)
	if packed == null:
		return

	var inst: Node = packed.instantiate()
	start.add_child(inst)
	_update_current_level_key(inst)

	await get_tree().process_frame

func _boot_apply_pending_level_if_needed() -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return

	var pending_level: String = ""
	if "pending_level_path" in save_manager:
		pending_level = str(save_manager.pending_level_path)

	if pending_level == "" or not ResourceLoader.exists(pending_level):
		return

	var current_path := get_active_level_path()
	if current_path != "" and current_path == pending_level:
		return

	await _boot_change_level_to(pending_level)

func _boot_change_level_to(target_scene_path: String) -> void:
	if is_instance_valid(start):
		await _replace_level_under_start(target_scene_path)
		var lr := _get_level_root()
		_refresh_layer_references(lr if lr != null else get_tree().current_scene)
		_update_current_level_key(lr)
		load_watered_tiles()
		_restore_saved_drops()
		_connect_all_chests(lr if lr != null else get_tree().current_scene)
		return

	var packed_scene: PackedScene = load(target_scene_path)
	if packed_scene == null:
		return

	if not is_instance_valid(ground_layer):
		_refresh_layer_references(get_tree().current_scene)
		if not is_instance_valid(ground_layer):
			return

	var old_level_root: Node = ground_layer
	while old_level_root.get_parent() != self and old_level_root.get_parent() != null:
		old_level_root = old_level_root.get_parent()

	var parent: Node = old_level_root.get_parent()
	if parent == null:
		return

	var index: int = old_level_root.get_index()
	var old_name: String = old_level_root.name

	old_level_root.queue_free()
	var new_level_root: Node = packed_scene.instantiate()
	new_level_root.name = old_name
	parent.add_child(new_level_root)
	parent.move_child(new_level_root, index)

	await get_tree().process_frame

	_refresh_layer_references(get_tree().current_scene)
	_update_current_level_key(new_level_root)
	load_watered_tiles()
	_restore_saved_drops()
	_connect_all_chests(new_level_root)

func _get_level_root_from_ground() -> Node:
	if not is_instance_valid(ground_layer):
		return null
	var n: Node = ground_layer
	var stop_node: Node = self
	if is_instance_valid(start):
		stop_node = start
	while n != null and n.get_parent() != stop_node and n.get_parent() != null:
		n = n.get_parent()
	return n

func _update_current_level_key(level_root: Node) -> void:
	if level_root == null:
		current_level_key = "unknown_level"
	else:
		if level_root.scene_file_path != "":
			current_level_key = level_root.scene_file_path
		else:
			current_level_key = level_root.name
	if TimeManager.has_method("set_water_level_key"):
		TimeManager.set_water_level_key(current_level_key)

func _update_current_level_key_from_ground() -> void:
	var level_root := _get_level_root_from_ground()
	_update_current_level_key(level_root)

func _refresh_layer_references(root: Node) -> void:
	ground_layer = null
	obstruction_layers.clear()

	var search_root: Node = root
	if search_root == null:
		search_root = get_tree().current_scene
	if search_root == null:
		return

	var direct_ground = search_root.find_child("Ground", true, false)
	if direct_ground and direct_ground is TileMapLayer:
		ground_layer = direct_ground
	else:
		var all_layers: Array[Node] = search_root.find_children("*", "TileMapLayer", true, false)
		for layer in all_layers:
			if layer.name == "Ground":
				ground_layer = layer
				break

	if ground_layer == null and get_tree().current_scene != null and get_tree().current_scene != search_root:
		var scene_root: Node = get_tree().current_scene
		var dg2 = scene_root.find_child("Ground", true, false)
		if dg2 and dg2 is TileMapLayer:
			ground_layer = dg2
		else:
			var all_layers2a: Array[Node] = scene_root.find_children("*", "TileMapLayer", true, false)
			for layera in all_layers2a:
				if layera.name == "Ground":
					ground_layer = layera
					break

	if ground_layer == null:
		push_error("CRITICAL: No TileMapLayer named 'Ground' found in this level!")
		return

	var scene_for_obs: Node = get_tree().current_scene
	if scene_for_obs == null:
		scene_for_obs = search_root

	var all_layers2: Array[Node] = scene_for_obs.find_children("*", "TileMapLayer", true, false)
	for layer2 in all_layers2:
		if layer2 == ground_layer:
			continue
		obstruction_layers.append(layer2)

	if is_instance_valid(tile_selector) and tile_selector.has_method("set_tile_size"):
		tile_selector.set_tile_size(ground_layer.tile_set.tile_size)

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
	if not is_instance_valid(ground_layer):
		return Vector2.ZERO
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

		if collider.get("is_destroyed"):
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
	if not item:
		return false

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
		if source_id == -1:
			return false
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
	_update_current_level_key_from_ground()
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
	_update_current_level_key_from_ground()
	if not TimeManager.has_method("save_watered_tiles"):
		return
	var save_data: Dictionary = {}
	for tile_pos in watered_tiles.keys():
		var data = watered_tiles[tile_pos]
		var key = str(tile_pos.x) + "," + str(tile_pos.y)
		save_data[key] = data
	TimeManager.save_watered_tiles(save_data)
	

func _save_current_level_state() -> void:
	var lr := _get_level_root()
	if lr == null:
		lr = _get_level_root_from_ground()
	if lr == null:
		return
	if lr.has_method("save_level_state"):
		lr.call("save_level_state")
	return

func change_level_to(target_scene_path: String, spawn_tag: String = "") -> void:
	if target_scene_path == "" or not ResourceLoader.exists(target_scene_path):
		push_warning("Could not load level: " + target_scene_path)
		return

	save_watered_tiles()
	_save_current_level_state()

	if is_instance_valid(player):
		player.is_movement_locked = true
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		if "agent" in player and player.agent:
			player.agent.target_position = player.global_position

	if is_instance_valid(transition_rect):
		var t = create_tween()
		t.tween_property(transition_rect, "modulate:a", 1.0, 0.5)
		await t.finished

	TimeManager.player_spawn_tag = spawn_tag

	await _replace_level_under_start(target_scene_path)

	var lr := _get_level_root()
	_refresh_layer_references(lr if lr != null else get_tree().current_scene)
	_connect_all_chests(lr if lr != null else get_tree().current_scene)
	_update_current_level_key(lr)

	load_watered_tiles()
	_restore_saved_drops()

	_spawn_player_in_current_level(spawn_tag)

	await get_tree().process_frame
	set_camera_limits()
	refresh_tile_selector()

	if is_instance_valid(transition_rect):
		var t2 = create_tween()
		t2.tween_property(transition_rect, "modulate:a", 0.0, 0.5)
		await t2.finished

	if is_instance_valid(player):
		player.is_movement_locked = false

func _clear_existing_drops() -> void:
	var nodes = get_tree().get_nodes_in_group("drops")
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()

func _restore_saved_drops() -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager == null or not save_manager.has_method("get_drops"):
		return

	var level_path := get_active_level_path()
	if level_path == "":
		return

	_clear_existing_drops()

	var drops: Dictionary = save_manager.get_drops(level_path)
	if typeof(drops) != TYPE_DICTIONARY or drops.is_empty():
		return

	var now = Time.get_unix_time_from_system()

	for id in drops.keys():
		var d = drops[id]
		if typeof(d) != TYPE_DICTIONARY:
			continue

		var t = float(d.get("time", now))
		if now - t > 1200.0:
			save_manager.remove_drop(level_path, str(id))
			continue

		var item_path = str(d.get("item_path", ""))
		if item_path == "" or not ResourceLoader.exists(item_path):
			save_manager.remove_drop(level_path, str(id))
			continue

		var res = load(item_path)
		if res == null:
			save_manager.remove_drop(level_path, str(id))
			continue

		var slot := SlotData.new()
		slot.item_data = res
		slot.quantity = int(d.get("quantity", 1))

		var inst = drop_scene.instantiate()
		inst.global_position = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))

		if "slot_data" in inst:
			inst.slot_data = slot
		if "uuid" in inst:
			inst.uuid = str(id)
		if "creation_time" in inst:
			inst.creation_time = t

		get_tree().current_scene.add_child(inst)


func _spawn_player_in_current_level(spawn_tag: String) -> void:
	var level_root: Node = _get_level_root()
	if level_root == null:
		level_root = _get_level_root_from_ground()
	if level_root == null:
		level_root = get_tree().current_scene

	var tag := spawn_tag
	if tag == "":
		tag = TimeManager.player_spawn_tag

	var spawn_node: Node2D = null
	if tag != "":
		spawn_node = level_root.find_child(tag, true, false) as Node2D
	if spawn_node == null:
		spawn_node = level_root.find_child("SpawnPoint", true, false) as Node2D
	if spawn_node == null:
		var all_markers: Array = level_root.find_children("*", "Marker2D", true, false)
		if all_markers.size() > 0:
			spawn_node = all_markers[0] as Node2D

	if spawn_node and is_instance_valid(player):
		player.global_position = spawn_node.global_position
		if "agent" in player and player.agent:
			player.agent.target_position = spawn_node.global_position

	TimeManager.player_spawn_tag = ""


func transition_to_level(target_scene_path: String, spawn_tag: String = "") -> void:
	await change_level_to(target_scene_path, spawn_tag)
