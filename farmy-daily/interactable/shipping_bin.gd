extends Node2D

@export var inventory_data: InventoryData

func player_interact() -> void:
	var inventory_interface = get_tree().get_first_node_in_group("inventory_interface")
	if inventory_interface:
		inventory_interface.set_external_inventory(inventory_data)
