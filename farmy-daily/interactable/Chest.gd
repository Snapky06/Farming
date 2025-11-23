extends StaticBody2D

signal chest_opened(chest_inventory_data)
signal chest_closed

@export var chest_inventory: InventoryData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_open := false
var is_animating := false

func _ready():
	sprite.play("idle")
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

func interact():
	if is_animating:
		return

	is_animating = true
	
	if is_open:
		sprite.play("closing")
		is_open = false
		chest_closed.emit()
	else:
		sprite.play("opening")
		is_open = true
		chest_opened.emit(chest_inventory)

func close_chest():
	if not is_open or is_animating:
		return
	
	is_animating = true
	is_open = false
	sprite.play("closing")
	chest_closed.emit()

func _on_animation_finished():
	is_animating = false
