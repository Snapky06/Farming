extends StaticBody2D

@export_group("Crop Settings")
@export var hours_to_grow_per_stage: int = 5
@export var seed_data: Resource
@export var harvest_data: Resource
@export var wither_days_limit: int = 2
@export var min_drop_quantity: int = 1
@export var max_drop_quantity: int = 3

const SEED_TEXTURE := preload("res://sprites/seeds/seed3.png")

@onready var animated_sprite: AnimatedSprite2D = get_parent()
@onready var time_manager: Node = get_node("/root/TimeManager")

var seed_sprite: Sprite2D = null

var current_stage = 0
var total_hours_watered = 0
var hours_for_next_stage = 0
var days_unwatered = 0
var is_watered_today = false
var max_stage = 3

func _ready():
	_create_seed_sprite()
	
	if time_manager:
		if time_manager.has_signal("hour_passed"):
			time_manager.hour_passed.connect(_on_hour_passed)
		if time_manager.has_signal("date_updated"):
			time_manager.date_updated.connect(_on_day_passed)
	
	hours_for_next_stage = hours_to_grow_per_stage
	update_sprite_frame()

func _create_seed_sprite():
	seed_sprite = Sprite2D.new()
	if animated_sprite:
		animated_sprite.add_child(seed_sprite)
		seed_sprite.position = Vector2.ZERO
	else:
		add_child(seed_sprite)
		seed_sprite.position = Vector2.ZERO
	seed_sprite.texture = SEED_TEXTURE
	seed_sprite.z_index = 100
	seed_sprite.visible = true
	seed_sprite.modulate = Color(1, 1, 1, 1)

func water():
	if current_stage >= max_stage:
		return
		
	is_watered_today = true
	days_unwatered = 0
	
	if current_stage == 0:
		current_stage = 1
		total_hours_watered = 0
		hours_for_next_stage = hours_to_grow_per_stage
		update_sprite_frame()
	
	if seed_sprite:
		seed_sprite.modulate = Color(0.6, 0.6, 0.6)
	if animated_sprite:
		animated_sprite.modulate = Color(0.6, 0.6, 0.6)

func harvest():
	if harvest_data:
		spawn_harvest_pickup()
	_play_harvest_tween_and_free()

func _on_hour_passed():
	if current_stage >= max_stage:
		return

	if is_watered_today:
		if current_stage == 0:
			return
		
		total_hours_watered += 1
		
		if total_hours_watered >= hours_for_next_stage:
			_grow()

func _grow():
	current_stage += 1
	if current_stage > max_stage:
		current_stage = max_stage
	hours_for_next_stage += hours_to_grow_per_stage
	update_sprite_frame()

func _on_day_passed(_date_string):
	if not is_watered_today:
		days_unwatered += 1
		if days_unwatered >= wither_days_limit:
			wither()
	else:
		is_watered_today = false
		if seed_sprite:
			seed_sprite.modulate = Color(1, 1, 1)
		if animated_sprite:
			animated_sprite.modulate = Color(1, 1, 1)

func wither():
	if seed_data:
		spawn_seed_pickup()
	get_parent().queue_free()

func spawn_seed_pickup():
	var pickup_scene = load("res://Item/pick_up/pick_up.tscn")
	if pickup_scene:
		var pickup_instance = pickup_scene.instantiate()
		
		var slot_script = load("res://Inventory/slot_data.gd")
		var new_slot_data = slot_script.new()
		new_slot_data.item_data = seed_data
		new_slot_data.quantity = 1
		
		pickup_instance.slot_data = new_slot_data
		pickup_instance.global_position = global_position + Vector2(0, -10)
		
		get_tree().current_scene.add_child(pickup_instance)

func spawn_harvest_pickup():
	var pickup_scene = load("res://Item/pick_up/pick_up.tscn")
	if pickup_scene:
		var pickup_instance = pickup_scene.instantiate()
		
		var slot_script = load("res://Inventory/slot_data.gd")
		var new_slot_data = slot_script.new()
		new_slot_data.item_data = harvest_data
		
		var range_size = max_drop_quantity - min_drop_quantity + 1
		var extra = floor(abs(randf() - randf()) * range_size)
		new_slot_data.quantity = min_drop_quantity + extra
		
		pickup_instance.slot_data = new_slot_data
		var random_offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		pickup_instance.global_position = global_position + Vector2(0, -10) + random_offset
		
		get_tree().current_scene.add_child(pickup_instance)

func update_sprite_frame():
	if animated_sprite and "frame" in animated_sprite:
		animated_sprite.frame = current_stage
	
	if seed_sprite:
		seed_sprite.visible = current_stage == 0

func _play_harvest_tween_and_free():
	var root := get_parent()
	if not root:
		queue_free()
		return
	
	var t = create_tween()
	if not t:
		root.queue_free()
		return
	
	var start_scale = root.scale
	var start_pos = root.position
	t.tween_property(root, "scale", start_scale * 1.05, 0.08)
	t.parallel().tween_property(root, "position", start_pos + Vector2(0, -4), 0.12)
	t.tween_property(root, "scale", Vector2.ZERO, 0.15)
	t.finished.connect(root.queue_free)
