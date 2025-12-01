extends StaticBody2D

@export_group("Crop Settings")
@export var hours_to_grow_per_stage: int = 5
@export var seed_data: Resource
@export var harvest_data: Resource
@export var wither_days_limit: int = 2
@export var min_drop_quantity: int = 1
@export var max_drop_quantity: int = 3

@onready var animated_sprite: AnimatedSprite2D = get_parent()
@onready var time_manager: Node = get_node("/root/TimeManager")

var current_stage = 0
var max_stage = 3

var total_hours_watered = 0
var hours_for_next_stage = 0
var days_unwatered = 0
var is_watered_today = false

var seed_positions: Array[Vector2] = []

func _ready():
	# 1. COLLISION SETUP:
	# Layer 3 (Value 4) is for Tools. We ENABLE this so tools hit the crop.
	# We DISABLE Layer 1 so it's not a generic wall.
	collision_layer = 4 
	collision_mask = 0
	
	# 2. PLAYER WALK-THROUGH FIX:
	# Even with layers set, the player might still collide if their mask is wide.
	# We explicitly tell the player to ignore this specific crop object.
	_make_player_ignore_me()
	
	# 3. VISUALS:
	# Relative Z-Index allows correct Y-sorting (walking behind/in-front of crop)
	z_index = 0
	z_as_relative = true
	
	hours_for_next_stage = hours_to_grow_per_stage
	
	_generate_seed_positions()
	
	if time_manager:
		if not time_manager.hour_passed.is_connected(_on_hour_passed):
			time_manager.hour_passed.connect(_on_hour_passed)
		if not time_manager.date_updated.is_connected(_on_day_passed):
			time_manager.date_updated.connect(_on_day_passed)
	
	update_visuals()
	check_ground_water_state()

func _make_player_ignore_me():
	# Attempt to find the player node in the scene tree
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and player is CharacterBody2D:
		player.add_collision_exception_with(self)

func _generate_seed_positions():
	seed_positions.clear()
	
	# Tightly centered offsets to ensure seeds look neat inside the tile
	var base_offsets = [
		Vector2(0, 0),
		Vector2(-2.5, -2.5),
		Vector2(2.5, -2.5),
		Vector2(-2.5, 2.5),
		Vector2(2.5, 2.5)
	]
	
	for base in base_offsets:
		# Small random jitter for variety
		var jitter_x = randf_range(-0.5, 0.5)
		var jitter_y = randf_range(-0.5, 0.5)
		seed_positions.append(base + Vector2(jitter_x, jitter_y))

func check_ground_water_state():
	await get_tree().process_frame
	var parent_node = get_parent()
	if not parent_node: return
	
	var main_node = parent_node.get_parent()
	if main_node and "ground_layer" in main_node:
		var ground = main_node.ground_layer
		if ground:
			var local_pos = ground.to_local(global_position)
			var cell_pos = ground.local_to_map(local_pos)
			var atlas_coords = ground.get_cell_atlas_coords(cell_pos)
			if atlas_coords == Vector2i(12, 0):
				water()

func water():
	is_watered_today = true
	days_unwatered = 0
	
	# Visual update only. Growth happens over time in _on_hour_passed.
	update_visuals()

func _on_hour_passed():
	if current_stage >= max_stage:
		return

	if is_watered_today:
		total_hours_watered += 1
		
		# If we have enough water hours, proceed to next stage
		if total_hours_watered >= hours_for_next_stage:
			grow_next_stage()

func grow_next_stage():
	current_stage += 1
	if current_stage > max_stage:
		current_stage = max_stage
	hours_for_next_stage += hours_to_grow_per_stage
	update_visuals()

func _on_day_passed(_date_string):
	if not is_watered_today:
		days_unwatered += 1
		if days_unwatered >= wither_days_limit:
			wither()
	else:
		is_watered_today = false
		update_visuals()

func update_visuals():
	var color_mod = Color(1, 1, 1)
	if is_watered_today:
		color_mod = Color(0.6, 0.6, 0.6)
	
	modulate = color_mod
	if animated_sprite:
		animated_sprite.modulate = color_mod
		
		# Stage 0: Show drawn seeds, hide plant sprite
		if current_stage == 0:
			animated_sprite.self_modulate.a = 0.0 
		else:
			# Stage 1+: Show plant sprite, seeds stop drawing
			animated_sprite.self_modulate.a = 1.0
			if "frame" in animated_sprite:
				animated_sprite.frame = current_stage - 1
	
	queue_redraw()

func _draw():
	# Only draw seeds in Stage 0
	if current_stage == 0:
		var base_color = Color(0.15, 0.1, 0.08) # Dark Brown
		var highlight_color = Color(0.5, 0.4, 0.3) # Light Brown
		
		if is_watered_today:
			base_color = Color(0.08, 0.05, 0.04) # Wet Dark
			highlight_color = Color(0.3, 0.25, 0.2) # Wet Light

		var seed_base_size = Vector2(2, 2)
		var pixel_size = Vector2(1, 1)

		for pos in seed_positions:
			# Draw centered pixels
			var draw_pos = pos - (seed_base_size / 2.0)
			draw_rect(Rect2(draw_pos, seed_base_size), base_color)
			draw_rect(Rect2(draw_pos, pixel_size), highlight_color)

func harvest():
	if harvest_data:
		spawn_pickup(harvest_data, min_drop_quantity, max_drop_quantity)
	_play_harvest_tween_and_free()

func wither():
	if seed_data:
		spawn_pickup(seed_data, 1, 1)
	get_parent().queue_free()

func spawn_pickup(item_data, min_q, max_q):
	var pickup_scene = load("res://Item/pick_up/pick_up.tscn")
	if not pickup_scene: return
	
	var slot_script = load("res://Inventory/slot_data.gd")
	
	var total_quantity = min_q
	if max_q > min_q:
		total_quantity = randi_range(min_q, max_q)
	
	for i in range(total_quantity):
		var pickup_instance = pickup_scene.instantiate()
		var new_slot_data = slot_script.new()
		new_slot_data.item_data = item_data
		new_slot_data.quantity = 1
		
		pickup_instance.slot_data = new_slot_data
		pickup_instance.global_position = global_position
		
		get_tree().current_scene.call_deferred("add_child", pickup_instance)
		_apply_scatter_tween(pickup_instance)

func _apply_scatter_tween(item):
	var random_offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
	var target_pos = global_position + random_offset
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(item, "global_position", target_pos, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	var start_scale = item.scale
	item.scale = Vector2.ZERO
	t.tween_property(item, "scale", start_scale, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _play_harvest_tween_and_free():
	var root := get_parent()
	if not root:
		queue_free()
		return
	
	var t = create_tween()
	t.tween_property(root, "scale", root.scale * 1.1, 0.1)
	t.tween_property(root, "scale", Vector2.ZERO, 0.15)
	t.finished.connect(root.queue_free)
