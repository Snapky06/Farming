extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var inventory_interface: Control = $UI/InventoryInterface
@onready var chest: StaticBody2D = $Chest
@onready var hot_bar_inventory: PanelContainer = $UI/HotBarInventory
@onready var tile_selector: Sprite2D = $TileSelector
@onready var ground_layer: TileMapLayer = $Backgrounds/NavRegion/Ground

var obstruction_layers: Array[TileMapLayer] = []
var hoe_cooldown: bool = false 

@export var HOED_SOURCE_ID: int = 1
@export var HOED_ATLAS_COORDS: Vector2i = Vector2i(11, 0)

# Watered tile configuration
@export var WATERED_SOURCE_ID: int = 1
@export var WATERED_ATLAS_COORDS: Vector2i = Vector2i(12, 0)

var watered_tiles: Dictionary = {} 
var current_open_chest: StaticBody2D = null

func _ready() -> void:
	var parent_node = ground_layer.get_parent()
	for child in parent_node.get_children():
		if child is TileMapLayer and child != ground_layer:
			obstruction_layers.append(child)

	player.toggle_inventory.connect(toggle_inventory_interface)
	inventory_interface.hide_inventory.connect(toggle_inventory_interface)
	
	hot_bar_inventory.set_inventory_data(player.inventory_data)
	inventory_interface.set_player_inventory_data(player.inventory_data)
	inventory_interface.player = player
	
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

func _on_time_updated(_time_string: String):
	var tiles_to_dry = []
	var current_day = TimeManager.current_day
	var current_time = TimeManager.current_time_seconds
	var current_month = TimeManager.current_month
	
	for tile_pos in watered_tiles.keys():
		var data = watered_tiles[tile_pos]
		var w_day = data["day"]
		var w_time = data["time"]
		var w_month = data.get("month", current_month)
		
		var time_passed = 0.0
		
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
				
			time_passed = (day_diff * 86400.0) + (current_time - w_time)
		
		if time_passed >= 43200.0: # 12 hours
			tiles_to_dry.append(tile_pos)
			
	for tile_pos in tiles_to_dry:
		dry_tile(tile_pos)

func dry_tile(tile_pos: Vector2i):
	if ground_layer.get_cell_atlas_coords(tile_pos) == WATERED_ATLAS_COORDS:
		ground_layer.set_cell(tile_pos, HOED_SOURCE_ID, HOED_ATLAS_COORDS)
	watered_tiles.erase(tile_pos)

func _on_hotbar_slot_selected(_index: int):
	await get_tree().process_frame
	refresh_tile_selector()

func refresh_tile_selector():
	if inventory_interface.visible or hoe_cooldown:
		tile_selector.visible = false
		return

	if player.equipped_item:
		var n = player.equipped_item.name
		if n == "Hoe" or n == "Tree Seed" or n == "Tree Seeds" or n == "Watering Can":
			tile_selector.visible = true
			return

	tile_selector.visible = false

func _unhandled_input(_event):
	if Input.is_action_just_pressed("inventory"):
		toggle_inventory_interface()
		get_viewport().set_input_as_handled()

func toggle_inventory_interface() -> void:
	if inventory_interface.visible:
		if not inventory_interface.can_close():
			return
		
		if current_open_chest:
			current_open_chest.close_chest()
			return
		
		inventory_interface.close()
		hot_bar_inventory.show()
		
		player.update_equipped_item(hot_bar_inventory.active_slot_index)
		refresh_tile_selector()
		player.is_movement_locked = false
	else:
		inventory_interface.clear_external_inventory()
		inventory_interface.open()
		hot_bar_inventory.hide()
		tile_selector.visible = false
		hot_bar_inventory.deselect_all()
		player.is_movement_locked = true
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func on_chest_opened(inventory_data):
	current_open_chest = chest
	inventory_interface.set_external_inventory(inventory_data)
	inventory_interface.open()
	hot_bar_inventory.hide()
	tile_selector.visible = false
	hot_bar_inventory.deselect_all()
	player.is_movement_locked = true
	player.agent.target_position = player.global_position

func on_chest_closed():
	current_open_chest = null
	inventory_interface.clear_external_inventory()
	inventory_interface.close()
	hot_bar_inventory.show()
	player.is_movement_locked = false
	refresh_tile_selector()

func get_tile_center_position(global_pos: Vector2) -> Vector2:
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	var center = ground_layer.map_to_local(tile_pos)
	
	# ALIGNMENT FIX: Add texture_origin offset from TileData
	var data = ground_layer.get_cell_tile_data(tile_pos)
	if data:
		center += Vector2(data.texture_origin)
		
	return ground_layer.to_global(center)

func can_plant_seed(global_pos: Vector2) -> bool:
	if hoe_cooldown: return false
	
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	var target_center = get_tile_center_position(global_pos)
	
	var all_trees = get_tree().get_nodes_in_group("trees")
	for t in all_trees:
		if t.global_position.distance_to(target_center) < 28.0:
			return false
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = target_center
	query.collide_with_bodies = true
	query.collision_mask = 4
	
	var results = space_state.intersect_point(query)
	for result in results:
		var collider = result.collider
		if collider == player or (player and player.is_ancestor_of(collider)):
			continue
		return false
	
	# FIXED: Removed strict check. Now allows planting on any valid tile.
	if ground_layer.get_cell_source_id(tile_pos) == -1:
		return false
		
	return true

func is_tile_farmable(global_pos: Vector2) -> bool:
	if hoe_cooldown: return false

	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	
	var tile_data = ground_layer.get_cell_tile_data(tile_pos)
	if not tile_data: return false
		
	var can_farm = tile_data.get_custom_data("can_farm")
	if typeof(can_farm) == TYPE_BOOL and not can_farm: return false

	var atlas_coords = ground_layer.get_cell_atlas_coords(tile_pos)
	if atlas_coords == HOED_ATLAS_COORDS or atlas_coords == WATERED_ATLAS_COORDS:
		return false

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_tile_center_position(global_pos)
	query.collide_with_bodies = true
	query.collision_mask = 4 
	
	var results = space_state.intersect_point(query)
	for result in results:
		var collider = result.collider
		if collider == player or (player and player.is_ancestor_of(collider)):
			continue
		return false

	return true

func is_tile_waterable(global_pos: Vector2) -> bool:
	if hoe_cooldown: return false
	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	var atlas_coords = ground_layer.get_cell_atlas_coords(tile_pos)
	if atlas_coords == HOED_ATLAS_COORDS: return true
	return false

func use_water(global_pos: Vector2) -> void:
	if is_tile_waterable(global_pos):
		var local_pos = ground_layer.to_local(global_pos)
		var tile_pos = ground_layer.local_to_map(local_pos)
		
		var source = ground_layer.tile_set.get_source(WATERED_SOURCE_ID) as TileSetAtlasSource
		
		# ALIGNMENT FIX: Retrieve texture_origin from the TARGET tile data
		var offset_vec = Vector2.ZERO
		if source.has_tile(WATERED_ATLAS_COORDS):
			var tile_data = source.get_tile_data(WATERED_ATLAS_COORDS, 0)
			if tile_data:
				offset_vec = Vector2(tile_data.texture_origin)

		if source:
			var temp_sprite = Sprite2D.new()
			temp_sprite.texture = source.texture
			temp_sprite.region_enabled = true
			temp_sprite.region_rect = source.get_tile_texture_region(WATERED_ATLAS_COORDS)
			
			ground_layer.add_child(temp_sprite)
			# Apply the calculated offset for perfect alignment
			temp_sprite.position = ground_layer.map_to_local(tile_pos) + offset_vec
			
			# Ensure it renders above the dry tile
			temp_sprite.z_index = 1 
			
			# Start small but visible
			temp_sprite.scale = Vector2(0.2, 0.2) 
			temp_sprite.modulate.a = 0.0
			
			var tween = create_tween()
			# Use TRANS_CUBIC for a more "liquid" spread feel
			tween.tween_property(temp_sprite, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(temp_sprite, "modulate:a", 1.0, 0.2)
			
			tween.tween_callback(func():
				ground_layer.set_cell(tile_pos, WATERED_SOURCE_ID, WATERED_ATLAS_COORDS)
				temp_sprite.queue_free()
				
				watered_tiles[tile_pos] = {
					"day": TimeManager.current_day,
					"month": TimeManager.current_month,
					"time": TimeManager.current_time_seconds
				}
			)
		else:
			ground_layer.set_cell(tile_pos, WATERED_SOURCE_ID, WATERED_ATLAS_COORDS)
			watered_tiles[tile_pos] = {
				"day": TimeManager.current_day,
				"month": TimeManager.current_month,
				"time": TimeManager.current_time_seconds
			}

func use_hoe(global_pos: Vector2) -> void:
	if is_tile_farmable(global_pos):
		hoe_cooldown = true 
		refresh_tile_selector() 
		
		var local_pos = ground_layer.to_local(global_pos)
		var tile_pos = ground_layer.local_to_map(local_pos)
		
		var source = ground_layer.tile_set.get_source(HOED_SOURCE_ID) as TileSetAtlasSource
		
		var offset_vec = Vector2.ZERO
		if source.has_tile(HOED_ATLAS_COORDS):
			var tile_data = source.get_tile_data(HOED_ATLAS_COORDS, 0)
			if tile_data: offset_vec = Vector2(tile_data.texture_origin)
		
		if source:
			var temp_sprite = Sprite2D.new()
			temp_sprite.texture = source.texture
			temp_sprite.region_enabled = true
			temp_sprite.region_rect = source.get_tile_texture_region(HOED_ATLAS_COORDS)
			
			ground_layer.add_child(temp_sprite)
			# Apply offset here too
			temp_sprite.position = ground_layer.map_to_local(tile_pos) + offset_vec
			temp_sprite.modulate.a = 0.0 
			temp_sprite.z_index = 1
			
			var tween = create_tween()
			tween.tween_property(temp_sprite, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
			
			tween.tween_callback(func():
				ground_layer.set_cell(tile_pos, HOED_SOURCE_ID, HOED_ATLAS_COORDS)
				temp_sprite.queue_free()
				
				hoe_cooldown = false
				refresh_tile_selector()
			)
		else:
			ground_layer.set_cell(tile_pos, HOED_SOURCE_ID, HOED_ATLAS_COORDS)
			hoe_cooldown = false
			refresh_tile_selector()
