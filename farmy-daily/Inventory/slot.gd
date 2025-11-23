extends PanelContainer

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect
@onready var quantity_label: Label = $QuantityLabel
@onready var hold_timer: Timer = $HoldTimer

signal slot_clicked(index: int, button: int)

var is_mouse_down = false

func set_slot_data(slot_data : SlotData) -> void:
	var item_data = slot_data.item_data
	texture_rect.texture = item_data.texture
	tooltip_text = "%s\n%s" % [item_data.name, item_data.description]
	
	if slot_data.quantity > 1:
		quantity_label.text = "x%s" % slot_data.quantity
		quantity_label.show()
	else:
		quantity_label.hide()

func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	if event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		slot_clicked.emit(get_index(), MOUSE_BUTTON_RIGHT)
		get_viewport().set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			is_mouse_down = true
			hold_timer.start()
		elif event.is_released():
			if is_mouse_down:
				is_mouse_down = false
				if not hold_timer.is_stopped():
					hold_timer.stop()
					slot_clicked.emit(get_index(), MOUSE_BUTTON_LEFT)
		
		get_viewport().set_input_as_handled()

func _on_HoldTimer_timeout():
	if is_mouse_down:
		is_mouse_down = false
		slot_clicked.emit(get_index(), MOUSE_BUTTON_RIGHT)
