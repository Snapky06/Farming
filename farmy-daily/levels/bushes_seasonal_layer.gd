extends TileMapLayer

const ROW_MAPPING: Dictionary = {
	"spring": 0,
	"summer": 1,
	"autumn": 2,
	"winter": 3
}

var current_texture_state: String = ""
@onready var time_manager: Node = get_node("/root/TimeManager")

func _ready() -> void:
	if time_manager:
		if not time_manager.season_visual_changed.is_connected(_on_season_changed):
			time_manager.season_visual_changed.connect(_on_season_changed)
		_update_visuals(true)

func _on_season_changed(_new_season_string: String) -> void:
	_update_visuals()

func _update_visuals(force_update: bool = false) -> void:
	var visual_state: String = get_target_season_state()
	var mapped_state: String = map_visual_to_row(visual_state)
	
	if not force_update and mapped_state == current_texture_state:
		return
	
	current_texture_state = mapped_state
	var target_row: int = ROW_MAPPING.get(current_texture_state, 0)
	
	for cell in get_used_cells():
		var source: int = get_cell_source_id(cell)
		var atlas: Vector2i = get_cell_atlas_coords(cell)
		var alt: int = get_cell_alternative_tile(cell)
		
		if atlas.y != target_row:
			var new_atlas: Vector2i = Vector2i(atlas.x, target_row)
			set_cell(cell, source, new_atlas, alt)

func get_target_season_state() -> String:
	if not time_manager:
		return "spring"
	if time_manager.has_method("get_current_season_string"):
		return time_manager.call("get_current_season_string")
	return "spring"

func map_visual_to_row(visual: String) -> String:
	match visual:
		"winter_spring": return "spring" 
		"spring": return "spring"
		"spring_summer": return "spring"
		"summer": return "summer"
		"summer_autumn": return "summer" 
		"autumn": return "autumn"
		"autumn_winter": return "autumn" 
		"winter": return "winter"
	return "spring"
