extends StaticBody2D

# --- ITEM & HEALTH SETTINGS ---
@export var item_to_drop: ItemData 
@export var quantity_to_drop: int = 3
@export var health: int = 3

# --- ANIMATION FRAME SETTINGS ---
# Now you can change these numbers in the Inspector for different tree types!
@export var tree_frame: int = 0
@export var stump_frame: int = 7

var is_stump: bool = false

@onready var sprite_root: AnimatedSprite2D = get_parent()

const PICK_UP_SCENE = preload("res://Item/pick_up/pick_up.tscn")

func _ready():
	if sprite_root:
		# Start with the "cycle" animation loaded
		sprite_root.play("cycle")
		# Set to the specific tree frame defined in Inspector
		sprite_root.frame = tree_frame
		# Stop playing so it doesn't animate through seasons automatically
		sprite_root.stop()

func hit():
	# 1. APPLY DAMAGE IMMEDIATELY
	health -= 1
	
	# 2. Visual Shake
	if sprite_root:
		var tween = create_tween()
		var original_pos = sprite_root.position
		tween.tween_property(sprite_root, "position", original_pos + Vector2(2, 0), 0.05)
		tween.tween_property(sprite_root, "position", original_pos - Vector2(2, 0), 0.05)
		tween.tween_property(sprite_root, "position", original_pos, 0.05)
		# We do not await here so logic proceeds immediately
	
	# 3. Check Health State
	if health <= 0:
		if not is_stump:
			become_stump()
		else:
			remove_stump()

func become_stump():
	# Drop the wood for the tree
	spawn_drops_scattered(quantity_to_drop)
	
	# Update state
	is_stump = true
	health = 2 
	
	if sprite_root:
		# Ensure animation is stopped and set to the dynamic stump frame
		sprite_root.stop() 
		sprite_root.frame = stump_frame 

func remove_stump():
	# Drop wood for the stump
	spawn_drops_scattered(1)
	
	if sprite_root:
		sprite_root.queue_free()
	else:
		queue_free()

func spawn_drops_scattered(amount_to_spawn: int):
	if not item_to_drop or not PICK_UP_SCENE:
		return

	for i in range(amount_to_spawn):
		var drop = PICK_UP_SCENE.instantiate()
		var slot_data = SlotData.new()
		slot_data.item_data = item_to_drop
		slot_data.quantity = 1 
		drop.slot_data = slot_data
		
		var random_offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		drop.global_position = global_position + random_offset
		
		get_tree().current_scene.call_deferred("add_child", drop)
