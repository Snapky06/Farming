extends StaticBody2D

signal chest_opened(chest_inventory)
signal chest_closed

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
	
	inventory_data.type = InventoryData.InventoryType.SELL_BIN
	
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	if FileAccess.file_exists("res://sounds/chest_opening.mp3"):
		sfx_open = load("res://sounds/chest_opening.mp3")
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if not time_manager.date_updated.is_connected(_on_new_day):
			time_manager.date_updated.connect(_on_new_day)

func interact(_player_body = null):
	if is_open:
		close_chest()
	else:
		open_chest()

func open_chest():
	if is_open: return
	is_open = true
	
	if sfx_open:
		audio_player.stream = sfx_open
		audio_player.play()
	
	sprite.play("opening")
	chest_opened.emit(inventory_data)

func close_chest():
	if not is_open: return
	is_open = false
	
	if sfx_open:
		audio_player.stream = sfx_open
		audio_player.play()
	
	sprite.play("closing")
	chest_closed.emit()

func player_interact():
	interact()

func _on_new_day(_date_string):
	var total_value = 0
	
	for i in range(inventory_data.slot_datas.size()):
		var slot = inventory_data.slot_datas[i]
		if slot and slot.item_data and slot.item_data.is_sellable:
			total_value += int(slot.item_data.price * 0.9) * slot.quantity
	
	if total_value > 0:
		var player_node = null
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]
		else:
			player_node = get_tree().current_scene.find_child("Player", true, false)
			
		if player_node and player_node.has_method("update_money"):
			player_node.update_money(total_value)
		else:
			print("CRITICAL: Shipping Bin could not find Player to give money!")
			
	for i in range(inventory_data.slot_datas.size()):
		inventory_data.slot_datas[i] = null
	
	if inventory_data:
		inventory_data.inventory_updated.emit(inventory_data)
