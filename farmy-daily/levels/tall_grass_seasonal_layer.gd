extends TileMapLayer

# The vertical offset for each season relative to the Spring (base) position
const SEASON_OFFSETS = {
	"spring": 0,
	"summer": 3,
	"autumn": 6
}

var current_season_state = "spring" 
var stored_grass_cells = {}
var is_hidden = false

@onready var time_manager = get_node("/root/TimeManager")

func _ready():
	_save_cells_state() # Capture the initial map state
	if time_manager:
		time_manager.season_changed.connect(_on_season_changed)
		_update_visuals(true)

func _on_season_changed(_new_season):
	_update_visuals()

func _save_cells_state():
	var cells = get_used_cells()
	if cells.size() > 0:
		stored_grass_cells.clear()
		for cell in cells:
			stored_grass_cells[cell] = {
				"source": get_cell_source_id(cell),
				"atlas_coords": get_cell_atlas_coords(cell),
				"alt": get_cell_alternative_tile(cell)
			}

func _update_visuals(force_update = false):
	var new_season = _get_season_string()
	
	if new_season == "winter":
		if not is_hidden:
			_save_cells_state()
			clear()
			is_hidden = true
		return

	# Calculate how many rows we need to shift based on the difference between the old and new season
	var offset_diff = SEASON_OFFSETS[new_season] - SEASON_OFFSETS[current_season_state]
	
	if is_hidden:
		for cell in stored_grass_cells:
			var data = stored_grass_cells[cell]
			# Apply the shift to the saved coordinates
			var new_atlas = Vector2i(data.atlas_coords.x, data.atlas_coords.y + offset_diff)
			set_cell(cell, data.source, new_atlas, data.alt)
			
		is_hidden = false
		current_season_state = new_season
		return

	if not force_update and new_season == current_season_state:
		return
		
	# Apply the shift to currently visible cells
	for cell in get_used_cells():
		var source = get_cell_source_id(cell)
		var atlas = get_cell_atlas_coords(cell)
		var alt = get_cell_alternative_tile(cell)
		
		var new_atlas = Vector2i(atlas.x, atlas.y + offset_diff)
		set_cell(cell, source, new_atlas, alt)
		
	current_season_state = new_season

func _get_season_string():
	if not time_manager: return "spring"
	match time_manager.current_season:
		0: return "spring"
		1: return "summer"
		2: return "autumn"
		3: return "winter"
	return "spring"
