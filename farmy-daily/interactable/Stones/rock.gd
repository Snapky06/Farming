extends StaticBody2D

@export var item_drop: Resource
@export var health: int = 3
@export var min_drops: int = 1
@export var max_drops: int = 3

@onready var sprite_root = get_parent()
const PICK_UP_SCENE = preload("res://Item/pick_up/pick_up.tscn")

var is_destroyed: bool = false 

func _ready():
	add_to_group("rock")
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if not time_manager.season_changed.is_connected(_on_season_changed):
			time_manager.season_changed.connect(_on_season_changed)
	
	_load_persistence()
	update_visuals()

func _on_season_changed(_season):
	update_visuals()

func update_visuals():
	if is_destroyed:
		queue_free()
		return

	if not sprite_root: return
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.current_season == 3:
		if "frame" in sprite_root:
			sprite_root.frame = 1
	else:
		if "frame" in sprite_root:
			sprite_root.frame = 0

func hit(_arg):
	health -= 1
	_save_persistence() # Save damage
	
	if sprite_root:
		var t = create_tween()
		var original_pos = sprite_root.position
		t.tween_property(sprite_root, "position", original_pos + Vector2(2, 0), 0.05)
		t.tween_property(sprite_root, "position", original_pos - Vector2(2, 0), 0.05)
		t.tween_property(sprite_root, "position", original_pos, 0.05)
	
	if health <= 0:
		destroy_rock()

func destroy_rock():
	is_destroyed = true 
	_save_persistence() # Save destroyed
	
	collision_layer = 0
	collision_mask = 0
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	spawn_drops()
	
	if sprite_root:
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(sprite_root, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(sprite_root, "scale", sprite_root.scale * 0.9, 2.0)
		await t.finished
		sprite_root.queue_free()
	else:
		queue_free()

func spawn_drops():
	if not item_drop: return
	
	var drop_count = randi_range(min_drops, max_drops)
	
	for i in range(drop_count):
		var drop = PICK_UP_SCENE.instantiate()
		if drop:
			var slot = load("res://Inventory/slot_data.gd").new()
			slot.item_data = item_drop
			slot.quantity = 1
			drop.slot_data = slot
			
			var random_offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
			drop.global_position = global_position + random_offset
			
			get_tree().current_scene.call_deferred("add_child", drop)

func _save_persistence():
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").save_object_state(self, { "health": health, "destroyed": is_destroyed })

func _load_persistence():
	if has_node("/root/SaveManager"):
		var data = get_node("/root/SaveManager").get_object_state(self)
		health = data.get("health", health)
		is_destroyed = data.get("destroyed", false)
		if is_destroyed:
			queue_free()
