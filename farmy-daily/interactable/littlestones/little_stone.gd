
extends StaticBody2D

@export var stone_item: ItemData 

func interact(player) -> void:
	if player and player.inventory_data:
		var slot_data = SlotData.new()
		slot_data.item_data = stone_item
		slot_data.quantity = 1
		
		if player.inventory_data.pick_up_slot_data(slot_data):
			queue_free()
