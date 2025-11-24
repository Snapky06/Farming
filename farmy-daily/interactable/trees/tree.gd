extends StaticBody2D

# --- DYNAMIC EXPORTS ---
@export var item_to_drop: ItemData 
@export var quantity_to_drop: int = 3
@export var health: int = 3

# --- ANIMATION FRAME SETTINGS ---
@export var tree_frame: int = 0
@export var stump_frame: int = 7

var is_stump: bool = false
var sfx_falling_leaves: AudioStream
var active_leaves_player: AudioStreamPlayer2D # Track the sound player

@onready var sprite_root: AnimatedSprite2D = get_parent()

const PICK_UP_SCENE = preload("res://Item/pick_up/pick_up.tscn")

func _ready():
	# Load audio dynamically
	if FileAccess.file_exists("res://sounds/falling_leaves.wav"):
		sfx_falling_leaves = load("res://sounds/falling_leaves.wav")
	elif FileAccess.file_exists("res://sounds/falling_leaves.mp3"):
		sfx_falling_leaves = load("res://sounds/falling_leaves.mp3")

	if sprite_root:
		sprite_root.play("cycle")
		sprite_root.frame = tree_frame
		sprite_root.stop()

func hit():
	# 1. PLAY SOUND (Only if we are not already a stump)
	play_falling_leaves_sound()

	# 2. APPLY DAMAGE
	health -= 1
	
	# 3. VISUAL SHAKE
	if sprite_root:
		var tween = create_tween()
		var original_pos = sprite_root.position
		tween.tween_property(sprite_root, "position", original_pos + Vector2(2, 0), 0.05)
		tween.tween_property(sprite_root, "position", original_pos - Vector2(2, 0), 0.05)
		tween.tween_property(sprite_root, "position", original_pos, 0.05)

	# 4. CHECK DEATH
	if health <= 0:
		if not is_stump:
			become_stump()
		else:
			remove_stump()

func play_falling_leaves_sound():
	# Logic: Only play sound if file exists AND we are not hitting a stump
	if not sfx_falling_leaves or is_stump:
		return
		
	var temp_player = AudioStreamPlayer2D.new()
	get_tree().current_scene.add_child(temp_player)
	
	temp_player.global_position = global_position
	temp_player.stream = sfx_falling_leaves
	temp_player.play()
	
	temp_player.finished.connect(temp_player.queue_free)
	
	# Store reference so we can kill it if the tree dies this frame
	active_leaves_player = temp_player

func become_stump():
	# --- STOP LEAVES SOUND ---
	# Because the tree is gone, we cut the sound immediately
	if active_leaves_player:
		active_leaves_player.stop()
		active_leaves_player.queue_free()
		active_leaves_player = null

	spawn_drops_scattered(quantity_to_drop)
	
	is_stump = true
	health = 2 
	
	if sprite_root:
		sprite_root.stop() 
		sprite_root.frame = stump_frame 

func remove_stump():
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
