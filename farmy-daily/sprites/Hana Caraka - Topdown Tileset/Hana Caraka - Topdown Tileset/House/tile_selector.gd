extends Sprite2D

@onready var ground_layer: TileMapLayer = $"../Backgrounds/NavRegion/Ground"

func _process(_delta):
	if not visible:
		return

	var target_global_pos = get_global_mouse_position()
	var is_locked_on_action = false
	
	var player = get_parent().player
	if player:
		if player.is_moving_to_interact or player.is_movement_locked:
			target_global_pos = player.pending_tool_action_pos
			is_locked_on_action = true

	var local_pos = ground_layer.to_local(target_global_pos)
	var grid_pos = ground_layer.local_to_map(local_pos)
	
	global_position = ground_layer.to_global(ground_layer.map_to_local(grid_pos))
	
	if is_locked_on_action:
		self.modulate = Color(0, 1, 0, 0.5)
		return

	if get_parent().has_method("is_tile_farmable"):
		if get_parent().is_tile_farmable(target_global_pos):
			self.modulate = Color(0, 1, 0, 0.5)
		else:
			self.modulate = Color(1, 0, 0, 0.5)
	else:
		var source_id = ground_layer.get_cell_source_id(grid_pos)
		var tile_data = ground_layer.get_cell_tile_data(grid_pos)
		
		if source_id == 1 and tile_data and tile_data.get_custom_data("can_farm"):
			self.modulate = Color(0, 1, 0, 0.5)
		else:
			self.modulate = Color(1, 0, 0, 0.5)
