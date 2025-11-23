extends Control

var grabbed_slot_data : SlotData
var external_inventory_owner
var player
const PICK_UP = preload("res://Item/pick_up/pick_up.tscn")

@onready var player_inventory: PanelContainer = $PlayerInventory
@onready var grabbed_slot: PanelContainer = $GrabbedSlot
@onready var external_inventory: PanelContainer = $ExternalInventory

signal hide_inventory()

const DOUBLE_TAP_DELAY = 0.3
var tap_count = 0
var double_tap_timer = 0.0

func _ready() -> void:
	visible = false
	grabbed_slot.visible = false

func _process(delta: float) -> void:
	if double_tap_timer > 0.0:
		double_tap_timer -= delta
		if double_tap_timer <= 0.0:
			tap_count = 0

	if grabbed_slot.visible:
		grabbed_slot.global_position = get_global_mouse_position() + Vector2(5, 5)

func open() -> void:
	visible = true

func close() -> void:
	visible = false

func set_external_inventory(external_inventory_data: InventoryData):
	external_inventory_owner = external_inventory_data
	var inventory_data = external_inventory_data
	inventory_data.inventory_interact.connect(on_inventory_interact)

	external_inventory.set_inventory_data(inventory_data)
	external_inventory.show()
	
	open()

func clear_external_inventory():
	if external_inventory_owner:
		var inventory_data = external_inventory_owner
	
		inventory_data.inventory_interact.disconnect(on_inventory_interact)
		external_inventory.clear_inventory_grid()
	
		external_inventory.hide()
		external_inventory_owner = null
		close()

func set_player_inventory_data(inventory_data: InventoryData) -> void:
	inventory_data.inventory_interact.connect(on_inventory_interact)
	player_inventory.set_inventory_data(inventory_data)

func on_inventory_interact(inventory_data: InventoryData,
	index: int, button: int) -> void:
	
	match [grabbed_slot_data, button] :
		[null, MOUSE_BUTTON_LEFT]:
			grabbed_slot_data = inventory_data.grab_single_slot_data(index)
		[null, MOUSE_BUTTON_RIGHT]:
			grabbed_slot_data = inventory_data.grab_slot_data(index)
		
		[_, MOUSE_BUTTON_LEFT]:
			grabbed_slot_data = inventory_data.drop_single_slot_data(grabbed_slot_data, index)
		[_, MOUSE_BUTTON_RIGHT]:
			grabbed_slot_data = inventory_data.drop_slot_data(grabbed_slot_data, index)
	
	update_grabbed_slot()

func update_grabbed_slot() -> void:
	if grabbed_slot_data:
		grabbed_slot.show()
		grabbed_slot.set_slot_data(grabbed_slot_data)
	else:
		grabbed_slot.hide()

func drop_grabbed_item() -> void:
	var pick_up = PICK_UP.instantiate()
	pick_up.slot_data = grabbed_slot_data
	
	if player:
		pick_up.global_position = player.global_position + Vector2(0, 10)
	
	get_tree().current_scene.add_child(pick_up)
	
	grabbed_slot_data = null
	update_grabbed_slot()

func can_close() -> bool:
	return grabbed_slot_data == null

func _unhandled_input(event: InputEvent) -> void:
	if grabbed_slot_data:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			drop_grabbed_item()
			get_viewport().set_input_as_handled()
