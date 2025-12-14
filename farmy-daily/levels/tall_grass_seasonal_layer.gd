extends TileMapLayer

const SEASON_OFFSETS: Dictionary = {
	"spring": 0,
	"summer": 3,
	"autumn": 6
}

var current_season_state: String = "spring" 
var stored_grass_cells: Dictionary = {}
var is_hidden: bool = false

@onready var time_manager: Node = get_node("/root/TimeManager")

func _ready() -> void:
	_save_cells_state()
	if time_manager:
		if not time_manager.season_visual_changed.is_connected(_on_season_changed):
			time_manager.season_visual_changed.connect(_on_season_changed)
		
		# Force an immediate update to ensure sync on level load
		var initial_season: String = _get_season_string()
		if initial_season != "":
			_on_season_changed(initial_season)

func _on_season_changed(_new_season_string: String) -> void:
	_update_visuals()

func _save_cells_state() -> void:
	var cells: Array[Vector2i] = get_used_cells()
	if cells.size() > 0:
		stored_grass_cells.clear()
		for cell in cells:
			stored_grass_cells[cell] = {
				"source": get_cell_source_id(cell),
				"atlas_coords": get_cell_atlas_coords(cell),
				"alt": get_cell_alternative_tile(cell)
			}

func _update_visuals(force_update: bool = false) -> void:
	var raw_season: String = _get_season_string()
	var mapped_season: String = _map_season(raw_season)
	
	if mapped_season == "winter":
		if not is_hidden:
			_save_cells_state()
			clear()
			is_hidden = true
		return

	var offset_diff: int = SEASON_OFFSETS.get(mapped_season, 0) - SEASON_OFFSETS.get(current_season_state, 0)
	
	if is_hidden:
		for cell in stored_grass_cells:
			var data: Dictionary = stored_grass_cells[cell]
			var new_atlas: Vector2i = Vector2i(data.atlas_coords.x, data.atlas_coords.y + offset_diff)
			set_cell(cell, data.source, new_atlas, data.alt)
			
		is_hidden = false
		current_season_state = mapped_season
		return

	if not force_update and mapped_season == current_season_state:
		return
		
	for cell in get_used_cells():
		var source: int = get_cell_source_id(cell)
		var atlas: Vector2i = get_cell_atlas_coords(cell)
		var alt: int = get_cell_alternative_tile(cell)
		
		var new_atlas: Vector2i = Vector2i(atlas.x, atlas.y + offset_diff)
		set_cell(cell, source, new_atlas, alt)
		
	current_season_state = mapped_season

func _get_season_string() -> String:
	if not time_manager:
		return "spring"
	if time_manager.has_method("get_current_season_string"):
		return time_manager.call("get_current_season_string")
	return "spring"

func _map_season(val: String) -> String:
	match val:
		"winter_spring": return "winter" 
		"spring": return "spring"
		"spring_summer": return "spring" 
		"summer": return "summer"
		"summer_autumn": return "summer" 
		"autumn": return "autumn"
		"autumn_winter": return "autumn" 
		"winter": return "winter"
	return "spring"
