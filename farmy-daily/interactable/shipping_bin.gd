extends StaticBody2D

signal bin_opened(bin_inventory)
signal bin_closed

@export var inventory_data: InventoryData
@onready var sprite = $AnimatedSprite2D

var is_open = false
var audio_player
var sfx_open

func _ready():
	sprite.play("idle")
	if not inventory_data:
		inventory_data = InventoryData.new()
		inventory_data.type = InventoryData.InventoryType.SELL_BIN
		inventory_data.slot_datas = []
		for i in 10:
			inventory_data.slot_datas.append(null)
	
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	if FileAccess.file_exists("res://sounds/chest_opening.mp3"):
		sfx_open = load("res://sounds/chest_opening.mp3")
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if not time_manager.date_updated.is_connected(_on_new_day):
			time_manager.date_updated.connect(_on_new_day)

func interact(_player = null):
	if is_open:
		close_bin()
	else:
		open_bin()

func open_bin():
	if is_open: return
	is_open = true
	if sfx_open:
		audio_player.stream = sfx_open
		audio_player.play()
	sprite.play("opening")
	
	var interface = get_tree().get_first_node_in_group("inventory_interface")
	if interface:
		interface.set_external_inventory(inventory_data)

func close_bin():
	if not is_open: return
	is_open = false
	if sfx_open:
		audio_player.stream = sfx_open
		audio_player.play()
	sprite.play("closing")
	
	var interface = get_tree().get_first_node_in_group("inventory_interface")
	if interface:
		interface.clear_external_inventory()

func player_interact():
	interact()

func _on_new_day(_date_string):
	var total_value = 0
	for i in range(inventory_data.slot_datas.size()):
		var slot = inventory_data.slot_datas[i]
		if slot and slot.item_data and slot.item_data.is_sellable:
			total_value += slot.item_data.price * slot.quantity
		inventory_data.slot_datas[i] = null
	
	if total_value > 0:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			players[0].update_money(total_value)
	
	if inventory_data:
		inventory_data.inventory_updated.emit(inventory_data)
