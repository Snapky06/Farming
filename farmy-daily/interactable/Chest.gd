extends StaticBody2D

signal chest_opened(chest_inventory: InventoryData)
signal chest_closed

@export var chest_inventory: InventoryData
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_open: bool = false
var audio_player: AudioStreamPlayer2D
var sfx_chest_open: AudioStream

func _ready() -> void:
	sprite.play("idle")
	if not chest_inventory:
		_init_default_inventory()
	_load_persistence()

	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	if FileAccess.file_exists("res://sounds/chest_opening.mp3"):
		sfx_chest_open = load("res://sounds/chest_opening.mp3")

func _exit_tree() -> void:
	_save_persistence()

func _init_default_inventory() -> void:
	chest_inventory = InventoryData.new()
	chest_inventory.slot_datas = []
	for i in 5:
		chest_inventory.slot_datas.append(null)

func interact(_player_body = null) -> void:
	if is_open:
		close_chest()
	else:
		open_chest()

func open_chest() -> void:
	if is_open:
		return

	is_open = true
	if sfx_chest_open and audio_player:
		audio_player.stream = sfx_chest_open
		audio_player.play()

	sprite.play("opening")
	chest_opened.emit(chest_inventory)

func close_chest() -> void:
	if not is_open:
		return

	is_open = false
	if sfx_chest_open and audio_player:
		audio_player.stream = sfx_chest_open
		audio_player.play()

	sprite.play("closing")
	chest_closed.emit()

func _save_persistence() -> void:
	if not has_node("/root/SaveManager"):
		return

	var slots: Array = []
	for s in chest_inventory.slot_datas:
		if s and s.item_data:
			slots.append({
				"path": s.item_data.resource_path,
				"amount": int(s.quantity)
			})
		else:
			slots.append(null)

	get_node("/root/SaveManager").save_object_state(self, {
		"slots": slots
	})

func _load_persistence() -> void:
	if not has_node("/root/SaveManager"):
		return

	var data: Dictionary = get_node("/root/SaveManager").get_object_state(self)
	if data.is_empty():
		return

	if data.has("slots") and typeof(data["slots"]) == TYPE_ARRAY:
		var arr: Array = data["slots"]
		for i in range(min(arr.size(), chest_inventory.slot_datas.size())):
			var e = arr[i]
			if e == null:
				chest_inventory.slot_datas[i] = null
			else:
				var rp = str(e.get("path", ""))
				if rp != "" and ResourceLoader.exists(rp):
					var res = load(rp)
					if res:
						var sd := SlotData.new()
						sd.item_data = res
						sd.quantity = int(e.get("amount", 1))
						chest_inventory.slot_datas[i] = sd
					else:
						chest_inventory.slot_datas[i] = null
				else:
					chest_inventory.slot_datas[i] = null

	chest_inventory.inventory_updated.emit(chest_inventory)
