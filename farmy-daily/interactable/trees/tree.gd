extends StaticBody2D

# --- DYNAMIC EXPORTS ---
@export var item_to_drop: ItemData 
@export var quantity_to_drop: int = 3
@export var health: int = 3

# --- ANIMATION FRAME SETTINGS ---
@export var tree_frame: int = 0
@export var stump_frame: int = 7

var is_stump: bool = false
var is_falling: bool = false # This variable locks the tree interaction

var sfx_falling_leaves: AudioStream
var sfx_falling_tree: AudioStream
var active_leaves_player: AudioStreamPlayer2D 

@onready var sprite_root: AnimatedSprite2D = get_parent()

const PICK_UP_SCENE = preload("res://Item/pick_up/pick_up.tscn")

func _ready():
	# Load Audio
	if FileAccess.file_exists("res://sounds/falling_leaves.wav"):
		sfx_falling_leaves = load("res://sounds/falling_leaves.wav")
	elif FileAccess.file_exists("res://sounds/falling_leaves.mp3"):
		sfx_falling_leaves = load("res://sounds/falling_leaves.mp3")

	if FileAccess.file_exists("res://sounds/falling_tree.wav"):
		sfx_falling_tree = load("res://sounds/falling_tree.wav")
	elif FileAccess.file_exists("res://sounds/falling_tree.mp3"):
		sfx_falling_tree = load("res://sounds/falling_tree.mp3")

	if sprite_root:
		sprite_root.play("cycle")
		sprite_root.frame = tree_frame
		sprite_root.stop()

func hit(attacker_pos: Vector2 = Vector2.ZERO):
	# INTERACTION LOCK: 
	# If the tree is currently falling, ignore ALL hits.
	if is_falling:
		return

	play_falling_leaves_sound()

	health -= 1
	
	# Shake
	if sprite_root:
		var tween = create_tween()
		var original_pos = sprite_root.position
		tween.tween_property(sprite_root, "position", original_pos + Vector2(2, 0), 0.05)
		tween.tween_property(sprite_root, "position", original_pos - Vector2(2, 0), 0.05)
		tween.tween_property(sprite_root, "position", original_pos, 0.05)

	if health <= 0:
		if not is_stump:
			start_falling_sequence()
		else:
			remove_stump()

func start_falling_sequence():
	is_falling = true # LOCK: Player cannot hit anymore
	
	if active_leaves_player:
		active_leaves_player.stop()
		active_leaves_player.queue_free()
		active_leaves_player = null
	
	play_falling_tree_sound()
	
	# 1. Spawn items IMMEDIATELY (They hide under the falling tree sprite)
	spawn_drops_scattered(quantity_to_drop)
	
	# Calculate duration
	var fall_duration = 3.5
	if sfx_falling_tree:
		fall_duration = sfx_falling_tree.get_length()
	
	if sprite_root:
		var fall_visual = Sprite2D.new()
		var tex = sprite_root.sprite_frames.get_frame_texture(sprite_root.animation, sprite_root.frame)
		fall_visual.texture = tex
		
		# Match properties
		fall_visual.global_position = sprite_root.global_position
		fall_visual.offset = sprite_root.offset
		fall_visual.scale = sprite_root.scale
		fall_visual.flip_h = sprite_root.flip_h
		
		# Draw ON TOP of everything (Z=100 covers items and stump)
		fall_visual.z_as_relative = false
		fall_visual.z_index = 100
		
		get_tree().current_scene.add_child(fall_visual)
		
		# Transform real object to stump
		sprite_root.frame = stump_frame
		
		# Animate Fade
		var tween = create_tween()
		tween.tween_property(fall_visual, "modulate:a", 0.0, fall_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		await tween.finished
		
		fall_visual.queue_free()
		
	# UNLOCK: Only allow hitting the stump AFTER animation is totally done
	become_stump()

func play_falling_leaves_sound():
	if not sfx_falling_leaves or is_stump:
		return
		
	var temp_player = AudioStreamPlayer2D.new()
	get_tree().current_scene.add_child(temp_player)
	temp_player.global_position = global_position
	temp_player.stream = sfx_falling_leaves
	temp_player.play()
	temp_player.finished.connect(temp_player.queue_free)
	
	active_leaves_player = temp_player

func play_falling_tree_sound():
	if not sfx_falling_tree:
		return
	
	var temp_player = AudioStreamPlayer2D.new()
	get_tree().current_scene.add_child(temp_player)
	temp_player.global_position = global_position
	temp_player.stream = sfx_falling_tree
	temp_player.play()
	temp_player.finished.connect(temp_player.queue_free)

func become_stump():
	is_stump = true
	is_falling = false # RELEASE LOCK: Now you can hit the stump
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
		
		# Circular scattering around the tree
		var angle = (PI * 2.0 / amount_to_spawn) * i
		angle += randf_range(-0.5, 0.5)
		var distance = randf_range(10.0, 20.0)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		
		drop.global_position = global_position + offset
		
		get_tree().current_scene.call_deferred("add_child", drop)
