extends TileMapLayer

const CHANGEABLE_RECT = Rect2i(0, 0, 14, 10) 
const WINTER_OFFSET = Vector2i(0, 5)

var _original_tiles: Dictionary = {}

func _ready() -> void:
	for cell_pos in get_used_cells():
		_original_tiles[cell_pos] = {
			"source_id": get_cell_source_id(cell_pos),
			"atlas_coords": get_cell_atlas_coords(cell_pos),
			"alternative_tile": get_cell_alternative_tile(cell_pos)
		}

	if TimeManager:
		if not TimeManager.season_changed.is_connected(_on_season_changed):
			TimeManager.season_changed.connect(_on_season_changed)
		
		_on_season_changed(TimeManager.current_season)

func _on_season_changed(new_season: int) -> void:
	var is_winter = (new_season == TimeManager.Seasons.WINTER)
	
	for cell_pos in _original_tiles:
		var data = _original_tiles[cell_pos]
		var final_atlas_coords = data["atlas_coords"]
		var final_source_id = data["source_id"]
		var final_alt_tile = data["alternative_tile"]
		
		if is_winter:
			if CHANGEABLE_RECT.has_point(final_atlas_coords):
				final_atlas_coords += WINTER_OFFSET
		
		set_cell(cell_pos, final_source_id, final_atlas_coords, final_alt_tile)
