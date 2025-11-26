extends StaticBody2D

signal chest_opened(chest_inventory: InventoryData)
signal chest_closed

@export var chest_inventory: InventoryData
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_open: bool = false
var audio_player: AudioStreamPlayer2D
var sfx_chest_open: AudioStream

func _ready() -> void:
	sprite.play("idle")
	if not chest_inventory:
		_init_default_inventory()
	
	# Setup Audio
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	if FileAccess.file_exists("res://sounds/chest_opening.mp3"):
		sfx_chest_open = load("res://sounds/chest_opening.mp3")

func _init_default_inventory() -> void:
	print("Chest: No InventoryData assigned. Creating default 5-slot inventory.")
	chest_inventory = InventoryData.new()
	chest_inventory.slot_datas = []
	for i in 5:
		chest_inventory.slot_datas.append(null)

func interact(_player_body = null) -> void:
	if is_open:
		close_chest()
	else:
		open_chest()

func open_chest() -> void:
	if is_open:
		return
	
	is_open = true
	if sfx_chest_open and audio_player:
		audio_player.stream = sfx_chest_open
		audio_player.play()
		
	sprite.play("opening")
	chest_opened.emit(chest_inventory)

func close_chest() -> void:
	if not is_open:
		return
	
	is_open = false
	if sfx_chest_open and audio_player:
		audio_player.stream = sfx_chest_open
		audio_player.play()
		
	sprite.play("closing")
	chest_closed.emit()
