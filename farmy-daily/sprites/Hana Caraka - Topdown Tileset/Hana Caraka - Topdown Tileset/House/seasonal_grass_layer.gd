extends TileMapLayer

@export var spring_texture: Texture2D
@export var summer_texture: Texture2D
@export var autumn_texture: Texture2D
@export var winter_texture: Texture2D

@onready var time_manager: Node = get_node("/root/TimeManager")

var target_source_id: int = -1 

func _ready() -> void:
	target_source_id = _find_correct_source_id()
	
	if time_manager:
		if not time_manager.season_visual_changed.is_connected(_on_season_visual_changed):
			time_manager.season_visual_changed.connect(_on_season_visual_changed)
		
		var s: String = "spring"
		if time_manager.has_method("get_current_season_string"):
			s = time_manager.call("get_current_season_string")
		_on_season_visual_changed(s)

func _find_correct_source_id() -> int:
	if not tile_set:
		return -1
		
	for i in tile_set.get_source_count():
		var id: int = tile_set.get_source_id(i)
		var source: TileSetSource = tile_set.get_source(id)
		
		if source is TileSetAtlasSource:
			var current_tex: Texture2D = source.texture
			if current_tex == spring_texture or current_tex == summer_texture or current_tex == autumn_texture or current_tex == winter_texture:
				return id
				
	var used: Array[Vector2i] = get_used_cells()
	if used.size() > 0:
		return get_cell_source_id(used[0])
		
	return -1

func _on_season_visual_changed(visual_season: String) -> void:
	var new_texture: Texture2D = spring_texture
	
	match visual_season:
		"winter_spring": new_texture = winter_texture
		"spring": new_texture = spring_texture
		"spring_summer": new_texture = spring_texture
		"summer": new_texture = summer_texture
		"summer_autumn": new_texture = summer_texture
		"autumn": new_texture = autumn_texture
		"autumn_winter": new_texture = autumn_texture
		"winter": new_texture = winter_texture
	
	_swap_atlas_texture(new_texture)

func _swap_atlas_texture(texture: Texture2D) -> void:
	if texture == null or target_source_id == -1 or not tile_set:
		return
		
	var source: TileSetSource = tile_set.get_source(target_source_id)
	if source and source is TileSetAtlasSource:
		if source.texture != texture:
			source.texture = texture
