extends Resource
class_name InventoryData

enum InventoryType { PLAYER, CHEST, SHOP, SELL_BIN }
@export var type: InventoryType = InventoryType.PLAYER

signal inventory_updated(inventory_data: InventoryData)
signal inventory_interact(inventory_data: InventoryData, index: int, button: int)

@export var slot_datas : Array[SlotData]

func grab_slot_data(index:int) -> SlotData:
	var slot_data = slot_datas[index]
	
	if slot_data:
		if type == InventoryType.SHOP:
			var new_slot = slot_data.duplicate()
			new_slot.quantity = 1
			return new_slot
		else:
			slot_datas[index] = null
			inventory_updated.emit(self)
			return slot_data
	else:
		return null

func grab_single_slot_data(index: int) -> SlotData:
	var slot_data = slot_datas[index]
	
	if not slot_data:
		return null
	
	if type == InventoryType.SHOP:
		var new_slot = slot_data.duplicate()
		new_slot.quantity = 1
		return new_slot

	if slot_data.quantity == 1:
		slot_datas[index] = null
		inventory_updated.emit(self)
		return slot_data
		
	var new_grabbed_slot = slot_data.duplicate()
	new_grabbed_slot.quantity = 1
	
	slot_data.quantity -= 1
	
	inventory_updated.emit(self)
	return new_grabbed_slot

func drop_slot_data(grabbed_slot_data: SlotData , index:int) -> SlotData:
	if type == InventoryType.SHOP:
		return grabbed_slot_data

	var slot_data = slot_datas[index]
	var return_slot_data: SlotData
	
	if slot_data and slot_data.can_fully_merge_with(grabbed_slot_data):
		slot_data.fully_merge_with(grabbed_slot_data)
		return_slot_data = null
	else:
		slot_datas[index] = grabbed_slot_data
		return_slot_data = slot_data
	
	inventory_updated.emit(self)
	return return_slot_data

func drop_single_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	if type == InventoryType.SHOP:
		return grabbed_slot_data

	var slot_data = slot_datas[index]
	
	if not slot_data:
		var new_slot = grabbed_slot_data.duplicate()
		new_slot.quantity = 1
		slot_datas[index] = new_slot
		grabbed_slot_data.quantity -= 1
		
	elif slot_data.item_data == grabbed_slot_data.item_data:
		slot_data.quantity += 1
		grabbed_slot_data.quantity -= 1

	else:
		var return_slot_data = slot_datas[index]
		slot_datas[index] = grabbed_slot_data
		inventory_updated.emit(self)
		return return_slot_data
	
	if grabbed_slot_data.quantity <= 0:
		inventory_updated.emit(self)
		return null
	
	inventory_updated.emit(self)
	return grabbed_slot_data

func pick_up_slot_data(slot_data: SlotData) -> bool:
	for index in slot_datas.size():
		var existing_slot = slot_datas[index]
		if existing_slot and existing_slot.can_fully_merge_with(slot_data):
			existing_slot.fully_merge_with(slot_data)
			inventory_updated.emit(self)
			return true
	
	for index in slot_datas.size():
		if not slot_datas[index]:
			slot_datas[index] = slot_data
			inventory_updated.emit(self)
			return true
	
	return false

func on_slot_clicked(index: int, button: int) -> void:
	inventory_interact.emit(self, index, button)

func serialize() -> Array:
	var serialized_slots = []
	for slot in slot_datas:
		if slot and slot.item_data:
			serialized_slots.append({
				"item_path": slot.item_data.resource_path,
				"quantity": slot.quantity
			})
		else:
			serialized_slots.append(null)
	return serialized_slots

func deserialize(data: Array) -> void:
	for i in range(data.size()):
		if i < slot_datas.size():
			if data[i] == null:
				slot_datas[i] = null
			else:
				var new_slot = SlotData.new()
				new_slot.item_data = load(data[i]["item_path"])
				new_slot.quantity = int(data[i]["quantity"])
				slot_datas[i] = new_slot
	inventory_updated.emit(self)
