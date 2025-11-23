extends Button

@onready var inventory_panel: Panel = $"../Panel"

func _ready() -> void:
	pressed.connect(_on_inventory_button_pressed)

func _on_inventory_button_pressed() -> void:
	inventory_panel.visible = not inventory_panel.visible
