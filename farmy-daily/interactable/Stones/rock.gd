extends StaticBody2D

@export_group("Settings")
@export var health: int = 5
@export var min_drops: int = 1
@export var max_drops: int = 3

@export_group("Items")
@export var stone_item: Resource

var default_layer: int = 1
var sfx_hit: AudioStream
var sfx_break: AudioStream

@onready var sprite_root: AnimatedSprite2D = get_parent()
const PICK_UP_SCENE = preload("res://Item/pick_up/pick_up.tscn")

func _ready():
	add_to_group("rocks")
	z_as_relative = false
	
	if collision_layer > 0:
		default_layer = collision_layer
	else:
		default_layer = 1
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if not time_manager.season_changed.is_connected(_on_update_visuals):
			time_manager.season_changed.connect(_on_update_visuals)
	
	load_audio()
	_refresh_visuals_immediate()

func _on_update_visuals(_arg=null):
	update_visuals()

func _refresh_visuals_immediate():
	update_visuals()

func update_visuals():
	if not sprite_root: return
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.current_season == 3:
		sprite_root.frame = 1
	else:
		sprite_root.frame = 0

func hit(_pos):
	play_sound(sfx_hit)
	health -= 1
	
	var t = create_tween()
	t.tween_property(sprite_root, "position", sprite_root.position + Vector2(2,0), 0.05)
	t.tween_property(sprite_root, "position", sprite_root.position, 0.05)
	
	if health <= 0:
		break_rock()

func break_rock():
	play_sound(sfx_break)
	
	var amount = randi_range(min_drops, max_drops)
	spawn_drops(stone_item, amount)
	
	if sprite_root:
		var fade_visual = Sprite2D.new()
		if sprite_root.sprite_frames.has_animation(sprite_root.animation):
			fade_visual.texture = sprite_root.sprite_frames.get_frame_texture(sprite_root.animation, sprite_root.frame)
		
		fade_visual.global_position = sprite_root.global_position
		fade_visual.offset = sprite_root.offset
		fade_visual.z_index = sprite_root.z_index
		get_tree().current_scene.add_child(fade_visual)
		
		var t = create_tween()
		t.tween_property(fade_visual, "modulate:a", 0.0, 1.0)
		t.tween_callback(fade_visual.queue_free)
	
	queue_free()
	if sprite_root: sprite_root.queue_free()

func spawn_drops(item, count):
	if not item or count <= 0: return
	for i in range(count):
		var drop = PICK_UP_SCENE.instantiate()
		if drop:
			var slot = load("res://Inventory/slot_data.gd").new()
			slot.item_data = item
			slot.quantity = 1
			drop.slot_data = slot
			drop.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			get_tree().current_scene.call_deferred("add_child", drop)

func load_audio():
	if FileAccess.file_exists("res://sounds/pickaxe.mp3"): 
		sfx_hit = load("res://sounds/pickaxe.mp3")
	elif FileAccess.file_exists("res://sounds/hit_tree.mp3"): 
		sfx_hit = load("res://sounds/hit_tree.mp3")
		
	if FileAccess.file_exists("res://sounds/grab_stone.mp3"): 
		sfx_break = load("res://sounds/grab_stone.mp3")

func play_sound(stream):
	if stream:
		var p = AudioStreamPlayer2D.new()
		p.stream = stream
		p.global_position = global_position
		get_tree().current_scene.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
