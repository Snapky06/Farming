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

func _ready() -> void:
	if slot_data:
		sprite_2d.texture = slot_data.item_data.texture
	
	initial_y = sprite_2d.position.y
	
	# Load GLOBAL Item Pickup Sound
	# Removed "grab_stone" fallback so it only plays the generic pop/pickup sound
	if FileAccess.file_exists("res://sounds/item_pick_up.wav"):
		pickup_sound = load("res://sounds/item_pick_up.wav")
	elif FileAccess.file_exists("res://sounds/item_pick_up.mp3"):
		pickup_sound = load("res://sounds/item_pick_up.mp3")
	
	await get_tree().create_timer(0.5).timeout
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if magnet_target:
		# Magnet Logic: Accelerate towards player
		current_speed = move_toward(current_speed, magnet_speed * 4.0, magnet_acceleration * delta)
		global_position = global_position.move_toward(magnet_target.global_position, current_speed * delta)
	else:
		# Hover Animation (only when not being magnetized)
		time_passed += delta
		var new_y = initial_y + (sin(time_passed * hover_speed) * hover_height)
		sprite_2d.position.y = new_y

func _on_area_entered(area: Area2D) -> void:
	if area.name == "InteractionComponent" and area.get_parent().name == "Player":
		magnet_target = area.get_parent()

func _on_body_entered(body: Node2D) -> void:
	if "inventory_data" in body:
		if body.inventory_data.pick_up_slot_data(slot_data):
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
