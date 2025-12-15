extends PanelContainer

signal hotbar_slot_selected(index: int)

@onready var h_box_container: HBoxContainer = $MarginContainer/HBoxContainer
const Slot = preload("res://Inventory/slot.tscn")

var active_slot_index: int = -1 
var inventory_data: InventoryData

func _ready() -> void:
	add_to_group("hotbar")

func set_inventory_data(new_inventory_data: InventoryData) -> void:
	inventory_data = new_inventory_data
	if not inventory_data.inventory_updated.is_connected(populate_hot_bar):
		inventory_data.inventory_updated.connect(populate_hot_bar)
	populate_hot_bar(inventory_data)

func populate_hot_bar(inv_data: InventoryData) -> void:
	for child in h_box_container.get_children():
		child.queue_free()
	
	var start_index = inv_data.slot_datas.size() - 6
	if start_index < 0:
		start_index = 0
	
	for i in range(6):
		var slot_data = null
		var real_index = start_index + i
		
		if real_index < inv_data.slot_datas.size():
			slot_data = inv_data.slot_datas[real_index]
			
		var slot = Slot.instantiate()
		h_box_container.add_child(slot)
		
		if slot_data:
			slot.set_slot_data(slot_data)
		
		if i == active_slot_index:
			slot.modulate = Color(1, 1, 1, 1)
		else:
			slot.modulate = Color(1, 1, 1, 0.5)
			
		slot.slot_clicked.connect(on_slot_clicked.bind(i))

func on_slot_clicked(index_in_hotbar: int, _slot_index: int, _button: int) -> void:
	if active_slot_index == index_in_hotbar:
		deselect_all()
		return

	active_slot_index = index_in_hotbar
	
	for i in h_box_container.get_child_count():
		var slot = h_box_container.get_child(i)
		if i == active_slot_index:
			slot.modulate = Color(1, 1, 1, 1)
		else:
			slot.modulate = Color(1, 1, 1, 0.5)
	
	var start_index = 0
	if inventory_data:
		start_index = inventory_data.slot_datas.size() - 6
		if start_index < 0:
			start_index = 0
			
	hotbar_slot_selected.emit(start_index + index_in_hotbar)

func deselect_all() -> void:
	active_slot_index = -1
	for child in h_box_container.get_children():
		child.modulate = Color(1, 1, 1, 0.5)
	hotbar_slot_selected.emit(-1)
