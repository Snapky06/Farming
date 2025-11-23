extends StaticBody2D

signal chest_opened(chest_inventory: InventoryData)
signal chest_closed

@export var chest_inventory: InventoryData
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_open: bool = false

func _ready() -> void:
	sprite.play("idle")
	if not chest_inventory:
		_init_default_inventory()

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
	sprite.play("opening")
	chest_opened.emit(chest_inventory)

func close_chest() -> void:
	if not is_open:
		return
	
	is_open = false
	sprite.play("closing")
	chest_closed.emit()
