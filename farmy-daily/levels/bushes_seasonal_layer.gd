extends TileMapLayer

const ROW_MAPPING = {
	"spring": 0,
	"summer": 1,
	"autumn": 2,
	"winter": 3
}

var current_texture_state = ""
@onready var time_manager = get_node("/root/TimeManager")

func _ready():
	if time_manager:
		time_manager.season_changed.connect(_on_season_changed)
		_update_visuals(true)

func _on_season_changed(_new_season):
	_update_visuals()

func _update_visuals(force_update = false):
	var new_state = get_target_season_state()
	
	if not force_update and new_state == current_texture_state:
		return
	
	current_texture_state = new_state
	var target_row = ROW_MAPPING.get(current_texture_state, 0)
	
	for cell in get_used_cells():
		var source = get_cell_source_id(cell)
		var atlas = get_cell_atlas_coords(cell)
		var alt = get_cell_alternative_tile(cell)
		
		if atlas.y != target_row:
			var new_atlas = Vector2i(atlas.x, target_row)
			set_cell(cell, source, new_atlas, alt)

func get_target_season_state() -> String:
	if not time_manager: return "spring"

	match time_manager.current_season:
		0: return "spring"
		1: return "summer"
		2: return "autumn"
		3: return "winter"
	
	return "spring"
