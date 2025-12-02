extends TileMapLayer

# Drag and drop your 4 season PNGs here in the Inspector
@export var spring_texture: Texture2D
@export var summer_texture: Texture2D
@export var autumn_texture: Texture2D
@export var winter_texture: Texture2D

@onready var time_manager: Node = get_node("/root/TimeManager")

# We will find this automatically
var target_source_id: int = -1 

func _ready():
	# 1. AUTO-DETECT: Find out what tile ID you used to paint the map
	var used_cells = get_used_cells()
	if used_cells.size() > 0:
		# We just look at the very first tile you painted to find the ID
		target_source_id = get_cell_source_id(used_cells[0])
	else:
		print("SeasonalGrass: No tiles found on this layer to update!")
		return

	# 2. Connect to TimeManager
	if time_manager:
		time_manager.season_changed.connect(_on_season_changed)
		# Apply the correct season immediately
		_on_season_changed(time_manager.current_season)

func _on_season_changed(new_season):
	var new_texture: Texture2D = null
	
	match new_season:
		0: new_texture = spring_texture
		1: new_texture = summer_texture
		2: new_texture = autumn_texture
		3: new_texture = winter_texture
	
	_swap_atlas_texture(new_texture)

func _swap_atlas_texture(texture: Texture2D):
	if texture == null or target_source_id == -1:
		return
		
	var source = tile_set.get_source(target_source_id)
	if source and source is TileSetAtlasSource:
		source.texture = texture
