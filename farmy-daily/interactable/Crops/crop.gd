extends StaticBody2D

# --- Configuration ---
@export_group("Crop Settings")
@export var crop_name: String = "Generic Crop"
@export var days_to_grow: int = 4 
@export var seed_item: ItemData 
@export var harvest_item: ItemData 

enum GrowthStage { SPROUT, MEDIUM, MATURE }
var current_stage: GrowthStage = GrowthStage.SPROUT

var days_grown: int = 0
var is_watered: bool = false 
var days_unwatered: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
const PICK_UP_SCENE = preload("res://Item/pick_up/pick_up.tscn")

func _ready():
	add_to_group("crops")
	
	if TimeManager:
		TimeManager.date_updated.connect(_on_day_passed)
	
	update_visuals()

func setup(seed_data: ItemData):
	seed_item = seed_data

func _on_day_passed(_date_string):
	if current_stage == GrowthStage.MATURE:
		is_watered = false
		update_visuals()
		return

	if is_watered:
		days_grown += 1
		days_unwatered = 0 
		calculate_stage()
	else:
		days_unwatered += 1
		print(crop_name, " neglected for ", days_unwatered, " days.")
		
		if days_unwatered >= 3:
			wither_crop()
			return

	is_watered = false
	update_visuals()

func calculate_stage():
	var progress = float(days_grown) / float(days_to_grow)
	
	if progress >= 1.0:
		current_stage = GrowthStage.MATURE
	elif progress >= 0.5:
		current_stage = GrowthStage.MEDIUM
	else:
		current_stage = GrowthStage.SPROUT

func wither_crop():
	if seed_item:
		spawn_drop(seed_item, 1)
	

	var main_node = get_tree().current_scene
	if main_node.has_method("revert_tile_to_dirt"):
		main_node.revert_tile_to_dirt(global_position)
	
	# Destroy this crop object
	queue_free()

func update_visuals():
	if not sprite: return
	
	if sprite.sprite_frames.has_animation("default"):
		sprite.play("default")
		sprite.stop()
		
		match current_stage:
			GrowthStage.SPROUT: sprite.frame = 0
			GrowthStage.MEDIUM: sprite.frame = 1
			GrowthStage.MATURE: sprite.frame = 2
			
	if is_watered:
		modulate = Color(0.7, 0.7, 1.0) 
	else:
		modulate = Color(1.0, 1.0, 1.0) 

func interact(_player):
	if current_stage == GrowthStage.MATURE:
		harvest()

func harvest():
	if not harvest_item:
		print("Error: No harvest item set for ", crop_name)
		queue_free()
		return
		
	spawn_drop(harvest_item, 1)
	
	queue_free()

func spawn_drop(item, count):
	var drop = PICK_UP_SCENE.instantiate()
	var slot = SlotData.new()
	slot.item_data = item
	slot.quantity = count
	drop.slot_data = slot
	drop.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", drop)

func water():
	if current_stage != GrowthStage.MATURE:
		is_watered = true
		update_visuals()
