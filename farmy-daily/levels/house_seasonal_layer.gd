extends TileMapLayer

const CHANGEABLE_RECT: Rect2i = Rect2i(0, 0, 14, 10) 
const WINTER_OFFSET: Vector2i = Vector2i(0, 5)

var _original_tiles: Dictionary = {}
@onready var time_manager: Node = get_node("/root/TimeManager")

func _ready() -> void:
	for cell_pos in get_used_cells():
		_original_tiles[cell_pos] = {
			"source_id": get_cell_source_id(cell_pos),
			"atlas_coords": get_cell_atlas_coords(cell_pos),
			"alternative_tile": get_cell_alternative_tile(cell_pos)
		}

	if time_manager:
		if not time_manager.season_visual_changed.is_connected(_on_season_changed):
			time_manager.season_visual_changed.connect(_on_season_changed)
		
		var s: String = "spring"
		if time_manager.has_method("get_current_season_string"):
			s = time_manager.call("get_current_season_string")
		_on_season_changed(s)

func _on_season_changed(new_season_string: String) -> void:
	var is_winter: bool = (new_season_string == "winter" or new_season_string == "autumn_winter")
	
	for cell_pos in _original_tiles:
		var data: Dictionary = _original_tiles[cell_pos]
		var final_atlas_coords: Vector2i = data["atlas_coords"]
		var final_source_id: int = data["source_id"]
		var final_alt_tile: int = data["alternative_tile"]
		
		if is_winter:
			if CHANGEABLE_RECT.has_point(final_atlas_coords):
				final_atlas_coords += WINTER_OFFSET
		
		set_cell(cell_pos, final_source_id, final_atlas_coords, final_alt_tile)
