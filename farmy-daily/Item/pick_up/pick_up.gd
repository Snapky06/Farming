extends Area2D

@export var slot_data: SlotData
@export var hover_speed: float = 4.0
@export var hover_height: float = 1.0

@onready var sprite_2d: Sprite2D = $Sprite2D

var time_passed: float = 0.0
var initial_y: float = 0.0

func _ready() -> void:
	if slot_data:
		sprite_2d.texture = slot_data.item_data.texture
	
	initial_y = sprite_2d.position.y
	
	await get_tree().create_timer(0.5).timeout
	
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	time_passed += delta
	var new_y = initial_y + (sin(time_passed * hover_speed) * hover_height)
	sprite_2d.position.y = new_y

func _on_body_entered(body: Node2D) -> void:
	if "inventory_data" in body:
		if body.inventory_data.pick_up_slot_data(slot_data):
			queue_free()
