extends Node2D

var current_color: Color = Color(1, 1, 1, 1)
var target_color: Color = Color(1, 1, 1, 1)
var tile_size: Vector2 = Vector2(16, 16) 
var time: float = 0.0

var bounce_speed: float = 8.0
var bounce_amount: float = 2.0 

func _ready() -> void:
	z_index = 15 
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	time += delta * bounce_speed
	
	current_color = current_color.lerp(target_color, delta * 20.0)
	
	queue_redraw()

func _draw() -> void:
	var offset_pulse = sin(time) * bounce_amount
	var current_size = tile_size + Vector2(offset_pulse, offset_pulse)
	var half_size = current_size / 2.0
	
	var corner_len = 5.0 
	var thickness = 2.0 
	
	draw_line(Vector2(-half_size.x, -half_size.y), Vector2(-half_size.x + corner_len, -half_size.y), current_color, thickness)
	draw_line(Vector2(-half_size.x, -half_size.y), Vector2(-half_size.x, -half_size.y + corner_len), current_color, thickness)
	
	draw_line(Vector2(half_size.x, -half_size.y), Vector2(half_size.x - corner_len, -half_size.y), current_color, thickness)
	draw_line(Vector2(half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y + corner_len), current_color, thickness)

	draw_line(Vector2(half_size.x, half_size.y), Vector2(half_size.x - corner_len, half_size.y), current_color, thickness)
	draw_line(Vector2(half_size.x, half_size.y), Vector2(half_size.x, half_size.y - corner_len), current_color, thickness)

	draw_line(Vector2(-half_size.x, half_size.y), Vector2(-half_size.x + corner_len, half_size.y), current_color, thickness)
	draw_line(Vector2(-half_size.x, half_size.y), Vector2(-half_size.x, half_size.y - corner_len), current_color, thickness)

func set_status(is_valid: bool) -> void:
	if is_valid:
		target_color = Color(0.2, 0.9, 0.3, 1.0) # Bright Retro Green
	else:
		target_color = Color(0.9, 0.2, 0.2, 1.0) # Bright Retro Red

func set_tile_size(new_size: Vector2) -> void:
	tile_size = new_size
