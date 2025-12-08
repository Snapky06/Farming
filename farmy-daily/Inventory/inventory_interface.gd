extends Control

@export var money_icon: Texture

var grabbed_slot_data : SlotData
var external_inventory_owner
var player
const PICK_UP = preload("res://Item/pick_up/pick_up.tscn")

@onready var player_inventory: PanelContainer = $CenterContainer/HBoxContainer/PlayerInventory
@onready var grabbed_slot: PanelContainer = $GrabbedSlot
@onready var external_inventory: PanelContainer = $CenterContainer/HBoxContainer/ExternalInventory

var money_container: PanelContainer
var money_label: Label
var money_icon_rect: TextureRect

signal hide_inventory()

const DOUBLE_TAP_DELAY = 0.3
var tap_count = 0
var double_tap_timer = 0.0

func _ready() -> void:
	visible = false
	grabbed_slot.visible = false
	setup_money_display()
	find_player()

func setup_money_display() -> void:
	money_container = PanelContainer.new()
	add_child(money_container)
	
	money_container.layout_mode = 1
	money_container.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	money_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	money_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	money_container.position = Vector2(-20, -20)
	money_container.offset_left = -100
	money_container.offset_top = -50
	money_container.offset_right = -20
	money_container.offset_bottom = -20
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	money_container.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	
	money_icon_rect = TextureRect.new()
	money_icon_rect.texture = money_icon
	money_icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	money_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	money_icon_rect.custom_minimum_size = Vector2(32, 32)
	hbox.add_child(money_icon_rect)
	
	money_label = Label.new()
	money_label.text = "0"
	var font = load("res://fonts/MineMouseRegular-BL3DB.ttf")
	if font:
		money_label.add_theme_font_override("font", font)
	money_label.add_theme_font_size_override("font_size", 32)
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(money_label)

func find_player() -> void:
	if player: return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		player = get_tree().current_scene.find_child("Player", true, false)
		
	if player:
		if not player.money_updated.is_connected(update_money_text):
			player.money_updated.connect(update_money_text)
		update_money_text(player.money)

func update_money_text(amount: int) -> void:
	if money_label:
		money_label.text = str(amount)

func _process(delta: float) -> void:
	if not player:
		find_player()

	if double_tap_timer > 0.0:
		double_tap_timer -= delta
		if double_tap_timer <= 0.0:
			tap_count = 0

	if grabbed_slot.visible:
		grabbed_slot.global_position = get_global_mouse_position() + Vector2(5, 5)

func open() -> void:
	visible = true
	if player:
		update_money_text(player.money)

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
		
		if inventory_data.type == InventoryData.InventoryType.SELL_BIN:
			sell_contents(inventory_data)
	
		inventory_data.inventory_interact.disconnect(on_inventory_interact)
		external_inventory.clear_inventory_grid()
	
		external_inventory.hide()
		external_inventory_owner = null
		close()

func sell_contents(inventory_data: InventoryData):
	var total_price = 0
	for i in range(inventory_data.slot_datas.size()):
		var slot = inventory_data.slot_datas[i]
		if slot and slot.item_data:
			if slot.item_data.is_sellable:
				total_price += slot.item_data.price * slot.quantity
			inventory_data.slot_datas[i] = null
	
	if total_price > 0 and player:
		player.update_money(total_price)
	inventory_data.inventory_updated.emit(inventory_data)

func set_player_inventory_data(inventory_data: InventoryData) -> void:
	inventory_data.inventory_interact.connect(on_inventory_interact)
	player_inventory.set_inventory_data(inventory_data)

func on_inventory_interact(inventory_data: InventoryData, index: int, button: int) -> void:
	
	if inventory_data.type == InventoryData.InventoryType.SHOP and grabbed_slot_data == null:
		var slot = inventory_data.slot_datas[index]
		if slot and player:
			var buy_price = int(slot.item_data.price * 1.25)
			if player.money >= buy_price:
				player.update_money(-buy_price)
				grabbed_slot_data = slot.duplicate()
				grabbed_slot_data.quantity = 1
				update_grabbed_slot()
		return

	if grabbed_slot_data and inventory_data.type == InventoryData.InventoryType.SHOP:
		if grabbed_slot_data.item_data.is_sellable and player:
			var sell_price = grabbed_slot_data.item_data.price * grabbed_slot_data.quantity
			player.update_money(sell_price)
			grabbed_slot_data = null
			update_grabbed_slot()
		return

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
