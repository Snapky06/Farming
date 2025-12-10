extends StaticBody2D

@export var item_to_pick_up: ItemData 
@export var quantity_to_pick_up: int = 1 
@export var pickup_sound: AudioStream 

@onready var sprite_root: Sprite2D = get_parent() as Sprite2D 

var is_picked_up: bool = false
var is_destroyed: bool = false 

func _ready():
	_load_persistence()

func interact(player) -> void:
	if is_picked_up:
		return
	
	if player and player.inventory_data and item_to_pick_up:
		var slot_data = SlotData.new()
		slot_data.item_data = item_to_pick_up
		slot_data.quantity = quantity_to_pick_up
		
		if player.inventory_data.pick_up_slot_data(slot_data):
			is_picked_up = true
			is_destroyed = true 
			_save_persistence() # Save state
			
			collision_layer = 0
			collision_mask = 0
			if has_node("CollisionShape2D"):
				$CollisionShape2D.set_deferred("disabled", true)
			
			play_sound() 
			await play_pickup_animation()
			
			sprite_root.queue_free()

func play_sound() -> void:
	if pickup_sound:
		var temp_player = AudioStreamPlayer2D.new()
		get_tree().current_scene.add_child(temp_player)
		temp_player.global_position = global_position
		temp_player.stream = pickup_sound
		temp_player.play()
		temp_player.finished.connect(temp_player.queue_free)

func play_pickup_animation() -> void:
	if not sprite_root:
		return

	var duration = 0.3
	var timer = 0.0
	var start_scale = sprite_root.scale
	var start_alpha = sprite_root.modulate.a
	
	var original_pos_x = sprite_root.position.x
	var original_pos_y = sprite_root.position.y
	
	var end_scale = Vector2(0.1, 0.1)
	var end_alpha = 0.0
	
	var shake_x_magnitude = 3.0
	var shake_frequency = 30.0
	var lift_height = 5.0

	while timer < duration:
		var delta = get_process_delta_time() 
		timer += delta
		
		var t = min(timer / duration, 1.0) 
		
		var shake_x = sin(timer * shake_frequency) * shake_x_magnitude * (1.0 - t)
		
		sprite_root.position.x = original_pos_x + shake_x
		sprite_root.position.y = original_pos_y - (t * lift_height)
		
		sprite_root.scale = start_scale.lerp(end_scale, t)
		
		var color = sprite_root.modulate
		color.a = lerp(start_alpha, end_alpha, t)
		sprite_root.modulate = color

		await get_tree().process_frame

func _save_persistence():
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").save_object_state(self, { "picked_up": is_picked_up })

func _load_persistence():
	if has_node("/root/SaveManager"):
		var data = get_node("/root/SaveManager").get_object_state(self)
		if data.get("picked_up", false):
			is_picked_up = true
			is_destroyed = true
			if sprite_root: sprite_root.queue_free()
			queue_free()
