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

func _on_hotbar_slot_selected(_index: int):
	await get_tree().process_frame
	refresh_tile_selector()

func refresh_tile_selector():
	# Hide selector if inventory is open OR hoe is on cooldown
	if inventory_interface.visible or hoe_cooldown:
		tile_selector.visible = false
		return

	if player.equipped_item and player.equipped_item.name == "Hoe":
		tile_selector.visible = true
	else:
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

func is_tile_farmable(global_pos: Vector2) -> bool:
	# Prevent interaction if cooldown is active
	if hoe_cooldown:
		return false

	var local_pos = ground_layer.to_local(global_pos)
	var tile_pos = ground_layer.local_to_map(local_pos)
	
	if ground_layer.get_cell_source_id(tile_pos) != HOED_SOURCE_ID:
		return false

	for layer in obstruction_layers:
		if layer.get_cell_source_id(tile_pos) != -1:
			return false
	
	var tile_data = ground_layer.get_cell_tile_data(tile_pos)
	if not tile_data:
		return false
		
	return tile_data.get_custom_data("can_farm")

func use_hoe(global_pos: Vector2) -> void:
	if is_tile_farmable(global_pos):
		hoe_cooldown = true 
		refresh_tile_selector() 
		
		var local_pos = ground_layer.to_local(global_pos)
		var tile_pos = ground_layer.local_to_map(local_pos)
		
		var source = ground_layer.tile_set.get_source(HOED_SOURCE_ID) as TileSetAtlasSource
		
		if source:
			var temp_sprite = Sprite2D.new()
			temp_sprite.texture = source.texture
			temp_sprite.region_enabled = true
			temp_sprite.region_rect = source.get_tile_texture_region(HOED_ATLAS_COORDS)
			
			ground_layer.add_child(temp_sprite)
			temp_sprite.position = ground_layer.map_to_local(tile_pos)
			temp_sprite.modulate.a = 0.0 
			
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
