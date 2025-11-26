extends StaticBody2D

var TREE_VARIANTS = [
	{
		"name": "Pine Tree",
		"seed_frame": 7,
		"stump_frame": 7,
		
		"little_spring": 0, "little_spring_summer": 1, "little_summer": 2,
		"little_summer_autumn": 3, "little_autumn": 4, "little_autumn_winter": 5,
		"little_winter": 6, "little_winter_spring": 6,
		
		"big_spring": 0, "big_spring_summer": 1, "big_summer": 2,
		"big_summer_autumn": 3, "big_autumn": 4, "big_autumn_winter": 5,
		"big_winter": 6, "big_winter_spring": 6,
		
		"seed_chance": 0.5,
		"min_health": 3, "max_health": 6,
		"min_wood": 2, "max_wood": 5
	},
	{
		"name": "Maple Tree",
		"seed_frame": 7,
		"stump_frame": 7,
		
		"little_spring": 0, "little_spring_summer": 1, "little_summer": 2,
		"little_summer_autumn": 3, "little_autumn": 4, "little_autumn_winter": 5,
		"little_winter": 6, "little_winter_spring": 6,
		
		"big_spring": 0, "big_spring_summer": 1, "big_summer": 2,
		"big_summer_autumn": 3, "big_autumn": 4, "big_autumn_winter": 5,
		"big_winter": 6, "big_winter_spring": 6,
		
		"seed_chance": 0.5,
		"min_health": 4, "max_health": 6,
		"min_wood": 3, "max_wood": 6
	},
	{
		"name": "Birch Tree",
		"seed_frame": 7,
		"stump_frame": 7,
		
		"little_spring": 0, "little_spring_summer": 1, "little_summer": 2,
		"little_summer_autumn": 3, "little_autumn": 4, "little_autumn_winter": 5,
		"little_winter": 6, "little_winter_spring": 6,
		
		"big_spring": 0, "big_spring_summer": 1, "big_summer": 2,
		"big_summer_autumn": 3, "big_autumn": 4, "big_autumn_winter": 5,
		"big_winter": 6, "big_winter_spring": 6,
		
		"seed_chance": 0.2,
		"min_health": 1, "max_health": 3,
		"min_wood": 1, "max_wood": 3
	},
	{
		"name": "Spruce Tree",
		"seed_frame": 3,
		"stump_frame": 3,
		
		"little_spring": 0, "little_spring_summer": 1, "little_summer": 1,
		"little_summer_autumn": 1, "little_autumn": 1, "little_autumn_winter": 1,
		"little_winter": 2, "little_winter_spring": 2,
		
		"big_spring": 0, "big_spring_summer": 1, "big_summer": 1,
		"big_summer_autumn": 1, "big_autumn": 1, "big_autumn_winter": 1,
		"big_winter": 2, "big_winter_spring": 2,
		
		"seed_chance": 0.1,
		"min_health": 1, "max_health": 2,
		"min_wood": 1, "max_wood": 2
	}
]

@export_group("Items")
@export var wood_item: ItemData 
@export var seed_item: ItemData 

enum GrowthStage { SEED, SAPLING, MATURE }
var current_stage: GrowthStage = GrowthStage.MATURE
var active_variant: Dictionary = {} 
var days_until_next_stage: int = 0
var health: int = 3

var is_stump: bool = false
var is_falling: bool = false 
var default_layer: int = 1 
var visual_transition_window: int = 2 

var sfx_leaves: AudioStream
var sfx_fall: AudioStream

@onready var sprite_root: AnimatedSprite2D = get_parent()
const PICK_UP_SCENE = preload("res://Item/pick_up/pick_up.tscn")

func _ready():
	default_layer = collision_layer 
	visual_transition_window = randi_range(2, 4)
	
	if TimeManager:
		TimeManager.season_changed.connect(_on_update_visuals)
		TimeManager.date_updated.connect(_on_day_passed)
	
	load_audio()
	
	if active_variant.is_empty():
		active_variant = TREE_VARIANTS.pick_random()
		randomize_stats()
		
	update_visuals()

func setup_as_seed():
	current_stage = GrowthStage.SEED
	active_variant = TREE_VARIANTS.pick_random()
	days_until_next_stage = randi_range(1, 3) 
	randomize_stats()
	update_visuals()

func randomize_stats():
	if active_variant.has("min_health"):
		health = randi_range(active_variant["min_health"], active_variant["max_health"])
	else:
		health = 3

func _on_day_passed(_date_string):
	if is_falling: return
	
	update_visuals()
	if current_stage == GrowthStage.MATURE or is_stump: return
	
	days_until_next_stage -= 1
	if days_until_next_stage <= 0:
		advance_growth()

func advance_growth():
	if current_stage == GrowthStage.SEED:
		current_stage = GrowthStage.SAPLING
		days_until_next_stage = randi_range(1, 3)
	elif current_stage == GrowthStage.SAPLING:
		current_stage = GrowthStage.MATURE
		randomize_stats()
	
	update_visuals()

func _on_update_visuals(_arg=null):
	update_visuals()

func update_visuals():
	if not sprite_root: return
	sprite_root.visible = true
	
	if is_stump:
		sprite_root.play("big_cycle")
		sprite_root.stop()
		sprite_root.frame = active_variant.get("stump_frame", 20)
		collision_layer = default_layer
		z_index = 3
		return

	if current_stage == GrowthStage.SEED:
		sprite_root.play("little_cycle")
		sprite_root.stop()
		
		if active_variant.has("seed_frame"):
			sprite_root.frame = active_variant["seed_frame"]
		else:
			sprite_root.frame = 7
		
		collision_layer = 0 
		z_index = 0
		return

	collision_layer = default_layer 
	z_index = 3
	
	var prefix = "big_"
	var anim_name = "big_cycle"
	
	if current_stage == GrowthStage.SAPLING:
		prefix = "little_"
		anim_name = "little_cycle"
	
	if sprite_root.sprite_frames.has_animation(anim_name):
		sprite_root.play(anim_name)
		sprite_root.stop() 
	
	var suffix = get_season_suffix()
	var frame_key = prefix + suffix
	
	if active_variant.has(frame_key):
		sprite_root.frame = active_variant[frame_key]
	else:
		var fallback = prefix + get_fallback_suffix()
		if active_variant.has(fallback):
			sprite_root.frame = active_variant[fallback]

func get_season_suffix() -> String:
	var m = TimeManager.current_month
	var d = TimeManager.current_day
	
	if m == 6 and abs(d - 20) <= visual_transition_window: 
		return "spring_summer"
	elif m == 9 and abs(d - 21) <= visual_transition_window: 
		return "summer_autumn"
	elif m == 12 and abs(d - 20) <= visual_transition_window:
		return "autumn_winter"
	elif m == 3 and abs(d - 20) <= visual_transition_window:
		return "winter_spring"
	
	return get_fallback_suffix()

func get_fallback_suffix() -> String:
	match TimeManager.current_season:
		TimeManager.Seasons.SPRING: return "spring"
		TimeManager.Seasons.SUMMER: return "summer"
		TimeManager.Seasons.AUTUMN: return "autumn"
		TimeManager.Seasons.WINTER: return "winter"
	return "spring"

func hit(_pos):
	if is_falling or current_stage == GrowthStage.SEED: return
	
	play_sound(sfx_leaves)
	health -= 1
	
	var t = create_tween()
	t.tween_property(sprite_root, "position", sprite_root.position + Vector2(2,0), 0.05)
	t.tween_property(sprite_root, "position", sprite_root.position, 0.05)

	if health <= 0:
		if current_stage == GrowthStage.SAPLING:
			destroy_sapling()
		elif is_stump:
			destroy_stump()
		else:
			fall_tree()

func destroy_sapling():
	spawn_drops(wood_item, 1)
	if randf() < 0.3: spawn_drops(seed_item, 1)
	queue_free()
	if sprite_root: sprite_root.queue_free()

func destroy_stump():
	spawn_drops(wood_item, 1)
	if sprite_root: sprite_root.queue_free()
	else: queue_free()

func fall_tree():
	if is_falling: return
	is_falling = true
	collision_layer = 0
	play_sound(sfx_fall)
	
	var wood_count = 3
	if active_variant.has("min_wood"):
		wood_count = randi_range(active_variant["min_wood"], active_variant["max_wood"])
	spawn_drops(wood_item, wood_count)
	
	if randf() < active_variant.get("seed_chance", 0.5):
		spawn_drops(seed_item, 1)

	if sprite_root:
		var fall_visual = Sprite2D.new()
		fall_visual.texture = sprite_root.sprite_frames.get_frame_texture(sprite_root.animation, sprite_root.frame)
		fall_visual.global_position = sprite_root.global_position
		fall_visual.offset = sprite_root.offset
		fall_visual.z_index = 100
		get_tree().current_scene.add_child(fall_visual)
		
		sprite_root.play("big_cycle")
		sprite_root.stop()
		sprite_root.frame = active_variant.get("stump_frame", 20)
		
		var t = create_tween()
		t.tween_property(fall_visual, "modulate:a", 0.0, 3.0)
		await t.finished
		fall_visual.queue_free()
		
		is_stump = true
		is_falling = false
		health = 2
		collision_layer = default_layer
		z_index = 3

func spawn_drops(item, count):
	if not item or count <= 0: return
	for i in range(count):
		var drop = PICK_UP_SCENE.instantiate()
		var slot = SlotData.new()
		slot.item_data = item
		slot.quantity = 1
		drop.slot_data = slot
		drop.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		get_tree().current_scene.call_deferred("add_child", drop)

func load_audio():
	if FileAccess.file_exists("res://sounds/falling_leaves.mp3"): sfx_leaves = load("res://sounds/falling_leaves.mp3")
	if FileAccess.file_exists("res://sounds/falling_tree.mp3"): sfx_fall = load("res://sounds/falling_tree.mp3")

func play_sound(stream):
	if stream:
		var p = AudioStreamPlayer2D.new()
		p.stream = stream
		p.global_position = global_position
		get_tree().current_scene.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
