extends Sprite2D

@onready var ground_layer: TileMapLayer = $"../Backgrounds/NavRegion/Ground"

func _process(_delta):
	if not visible:
		return

	var mouse_pos = get_global_mouse_position()
	var grid_pos = ground_layer.local_to_map(mouse_pos)
	
	global_position = ground_layer.map_to_local(grid_pos)
	
	var source_id = ground_layer.get_cell_source_id(grid_pos)
	
	if source_id != 1:
		self.modulate = Color(1, 0, 0, 0.5) 
		return
	
	var tile_data = ground_layer.get_cell_tile_data(grid_pos)
	
	if tile_data and tile_data.get_custom_data("can_farm"):
		self.modulate = Color(0, 1, 0, 0.5)
	else:
		self.modulate = Color(1, 0, 0, 0.5)
