extends TileMapLayer

const VISUAL_TRANSITION_WINDOW = 3

const ROW_MAPPING = {
	"spring": 3,
	"spring_summer": 4,
	"summer": 5,
	"summer_autumn": 6,
	"autumn": 7,
	"autumn_winter": 8,
	"winter_spring": 9,
	"winter": 10
}

var current_texture_state = ""
@onready var time_manager = get_node("/root/TimeManager")

func _ready():
	if time_manager:
		time_manager.season_changed.connect(_on_season_changed)
		time_manager.date_updated.connect(_on_date_updated)
		_update_visuals(true)

func _on_season_changed(_new_season):
	_update_visuals()

func _on_date_updated(_date_string):
	_update_visuals()

func _update_visuals(force_update = false):
	var new_state = get_target_season_state()
	
	if not force_update and new_state == current_texture_state:
		return
	
	current_texture_state = new_state
	var target_row = ROW_MAPPING.get(current_texture_state, 3)
	
	for cell in get_used_cells():
		var source = get_cell_source_id(cell)
		var atlas = get_cell_atlas_coords(cell)
		var alt = get_cell_alternative_tile(cell)
		
		if atlas.y != target_row:
			var new_atlas = Vector2i(atlas.x, target_row)
			set_cell(cell, source, new_atlas, alt)

func get_target_season_state() -> String:
	if not time_manager:
		return "spring"

	if time_manager.has_method("get_current_season_string"):
		return str(time_manager.call("get_current_season_string"))

	if "current_visual_season" in time_manager:
		return str(time_manager.current_visual_season)

	return "spring"
