extends Area2D

@export var slot_data: SlotData
@export var hover_speed: float = 4.0
@export var hover_height: float = 1.0
@export var magnet_speed: float = 100.0
@export var magnet_acceleration: float = 400.0

@onready var sprite_2d: Sprite2D = $Sprite2D

var pickup_sound: AudioStream
var time_passed: float = 0.0
var initial_y: float = 0.0
var magnet_target: Node2D = null
var current_speed: float = 0.0

var uuid: String = ""
var creation_time: float = 0.0
var is_collected: bool = false

func _ready() -> void:
	if slot_data:
		sprite_2d.texture = slot_data.item_data.texture
	
	initial_y = sprite_2d.position.y
	
	if FileAccess.file_exists("res://sounds/item_pick_up.wav"):
		pickup_sound = load("res://sounds/item_pick_up.wav")
	elif FileAccess.file_exists("res://sounds/item_pick_up.mp3"):
		pickup_sound = load("res://sounds/item_pick_up.mp3")
	
	if uuid == "":
		uuid = str(randi()) + str(Time.get_unix_time_from_system())
	if creation_time == 0.0:
		creation_time = Time.get_unix_time_from_system()
	
	add_to_group("drops")
	
	await get_tree().create_timer(0.5).timeout
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if Time.get_unix_time_from_system() - creation_time > 1200:
		_remove_from_persistence()
		queue_free()
		return

	if magnet_target:
		current_speed = move_toward(current_speed, magnet_speed * 4.0, magnet_acceleration * delta)
		global_position = global_position.move_toward(magnet_target.global_position, current_speed * delta)
	else:
		time_passed += delta
		var new_y = initial_y + (sin(time_passed * hover_speed) * hover_height)
		sprite_2d.position.y = new_y

func _on_area_entered(area: Area2D) -> void:
	if area.name == "InteractionComponent" and area.get_parent().name == "Player":
		magnet_target = area.get_parent()

func _on_body_entered(body: Node2D) -> void:
	if "inventory_data" in body:
		if body.inventory_data.pick_up_slot_data(slot_data):
			is_collected = true
			_remove_from_persistence()
			play_pickup_sound()
			queue_free()

func play_pickup_sound():
	if pickup_sound:
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = pickup_sound
		audio_player.global_position = global_position
		get_tree().current_scene.add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)

func _exit_tree():
	if not is_collected:
		_update_persistence()

func _update_persistence():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.get("is_slot_transitioning") == true:
		return
	if save_manager and slot_data and slot_data.item_data:
		var wrapper = get_tree().current_scene
		var level_path := ""
		if wrapper and wrapper.has_method("get_active_level_path"):
			level_path = str(wrapper.call("get_active_level_path"))
		if level_path == "":
			level_path = wrapper.scene_file_path if wrapper else ""
		if level_path != "":
			var data = {
				"x": global_position.x,
				"y": global_position.y,
				"item_path": slot_data.item_data.resource_path,
				"quantity": slot_data.quantity,
				"time": creation_time
			}
			save_manager.update_drop(level_path, uuid, data)

func _remove_from_persistence():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.get("is_slot_transitioning") == true:
		return
	if save_manager:
		var wrapper = get_tree().current_scene
		var level_path := ""
		if wrapper and wrapper.has_method("get_active_level_path"):
			level_path = str(wrapper.call("get_active_level_path"))
		if level_path == "":
			level_path = wrapper.scene_file_path if wrapper else ""
		if level_path != "":
			save_manager.remove_drop(level_path, uuid)
