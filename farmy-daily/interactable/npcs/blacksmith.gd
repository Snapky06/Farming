extends Node2D

@export var text_speed: float = 0.03
@export var interaction_range: float = 120.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var type_timer: Timer = $Timer
@onready var time_manager: Node = get_node("/root/TimeManager")

var axe_res: Resource = load("res://Item/items/tools/axe.tres")
var sharpened_axe_res: Resource = load("res://Item/items/tools/sharpened_axe.tres")
var magical_axe_res: Resource = load("res://Item/items/tools/magical_axe.tres")

var shame_day: int = -1

var dialog_active: bool = false
var is_typing: bool = false
var current_text: String = ""
var visible_characters: int = 0
var player_ref: CharacterBody2D = null

var dialog_canvas: CanvasLayer = null
var dialog_panel: Panel = null
var dialog_label: Label = null
var npc_portrait: AnimatedSprite2D = null
var player_portrait: AnimatedSprite2D = null
var yes_button: Button = null
var no_button: Button = null

var dialog_font: Font = load("res://fonts/MineMouseRegular-BL3DB.ttf")

var pending_cost: int = 0
var pending_upgrade_type: int = 0
var awaiting_choice: bool = false

func _ready() -> void:
	if not type_timer.timeout.is_connected(_on_type_timer_timeout):
		type_timer.timeout.connect(_on_type_timer_timeout)

func _process(_delta: float) -> void:
	if dialog_active and player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist > interaction_range:
			_end_dialog()

func on_interact(player: CharacterBody2D) -> void:
	if dialog_active:
		return
	
	player_ref = player
	if "is_movement_locked" in player_ref:
		player_ref.is_movement_locked = true
		
	_look_at_player()
	_ensure_dialog_ui()
	_update_portraits()
	
	_check_upgrade_availability()

func _check_upgrade_availability() -> void:
	var current_day = 0
	if time_manager and "day" in time_manager:
		current_day = time_manager.day
		
	if shame_day == current_day:
		_show_text("I told you to come back when you have money! Get out!", false)
		return

	var inv = player_ref.inventory_data
	var found_axe_index = -1
	var axe_type = 0 
	
	for i in range(inv.slot_datas.size()):
		if inv.slot_datas[i] and inv.slot_datas[i].item_data:
			var item = inv.slot_datas[i].item_data
			var i_name = item.get("name")
			if item == axe_res or i_name == "Axe":
				found_axe_index = i
				axe_type = 1
				break
			elif item == sharpened_axe_res or i_name == "Sharpened Axe":
				found_axe_index = i
				axe_type = 2
				break
			elif item == magical_axe_res or i_name == "Magical Axe":
				found_axe_index = i
				axe_type = 3
				break
	
	if found_axe_index == -1:
		_show_text("You don't have an axe I can work on.", false)
		return
		
	if axe_type == 1:
		pending_cost = 100
		pending_upgrade_type = 1
		_show_text("I can sharpen that axe for 100 gold. It will let you cut stumps. Interested?", true)
	elif axe_type == 2:
		pending_cost = 250
		pending_upgrade_type = 2
		_show_text("I can enchant that axe for 250 gold. It will crush rocks. Interested?", true)
	elif axe_type == 3:
		if player_ref.get("axe_hit_damage") >= 2:
			_show_text("Your axe is already a masterwork. I can do nothing more.", false)
		else:
			pending_cost = 625
			pending_upgrade_type = 3
			_show_text("I can hone the magic for 625 gold. It will destroy everything twice as fast.", true)

func _show_text(text: String, is_choice: bool) -> void:
	dialog_active = true
	awaiting_choice = is_choice
	current_text = text
	visible_characters = 0
	
	if dialog_label:
		dialog_label.text = ""
	if dialog_canvas:
		dialog_canvas.visible = true
	
	yes_button.visible = false
	no_button.visible = false
	
	is_typing = true
	type_timer.wait_time = text_speed
	type_timer.start()

func _on_type_timer_timeout() -> void:
	if not is_typing:
		return
		
	visible_characters += 1
	if visible_characters >= current_text.length():
		visible_characters = current_text.length()
		dialog_label.text = current_text
		is_typing = false
		type_timer.stop()
		_on_typing_finished()
	else:
		dialog_label.text = current_text.substr(0, visible_characters)

func _on_typing_finished() -> void:
	if awaiting_choice:
		yes_button.text = "Yes"
		yes_button.visible = true
		no_button.text = "No"
		no_button.visible = true
	else:
		no_button.text = "Close"
		no_button.visible = true
		yes_button.visible = false

func _on_yes_pressed() -> void:
	if is_typing:
		_skip_typing()
		return
		
	if not awaiting_choice:
		return

	if player_ref.money >= pending_cost:
		player_ref.update_money(-pending_cost)
		_perform_upgrade()
		_show_text("Pleasure doing business with you.", false)
	else:
		if time_manager and "day" in time_manager:
			shame_day = time_manager.day
		else:
			shame_day = 1
		_show_text("You don't have the coin? Don't waste my time!", false)

func _on_no_pressed() -> void:
	if is_typing:
		_skip_typing()
		return

	if awaiting_choice:
		_show_text("You're not prepared.", false)
	else:
		_end_dialog()

func _skip_typing() -> void:
	visible_characters = current_text.length()
	dialog_label.text = current_text
	is_typing = false
	type_timer.stop()
	_on_typing_finished()

func _perform_upgrade() -> void:
	var inv = player_ref.inventory_data
	
	if pending_upgrade_type == 1:
		_replace_item_in_inventory(inv, "Axe", sharpened_axe_res)
	elif pending_upgrade_type == 2:
		_replace_item_in_inventory(inv, "Sharpened Axe", magical_axe_res)
	elif pending_upgrade_type == 3:
		if player_ref.has_method("upgrade_axe_damage"):
			player_ref.call("upgrade_axe_damage")

func _replace_item_in_inventory(inv, old_name_check: String, new_item: Resource) -> void:
	for i in range(inv.slot_datas.size()):
		if inv.slot_datas[i] and inv.slot_datas[i].item_data:
			var i_name = inv.slot_datas[i].item_data.get("name")
			if i_name == old_name_check or inv.slot_datas[i].item_data == axe_res or (old_name_check == "Sharpened Axe" and inv.slot_datas[i].item_data == sharpened_axe_res):
				inv.slot_datas[i].item_data = new_item
				if inv.has_signal("inventory_updated"):
					inv.emit_signal("inventory_updated", inv)
				if player_ref.equipped_slot_index == i:
					player_ref.update_equipped_item(i)
				return

func _end_dialog() -> void:
	dialog_active = false
	is_typing = false
	type_timer.stop()
	if dialog_canvas:
		dialog_canvas.visible = false
	
	if player_ref and "is_movement_locked" in player_ref:
		player_ref.is_movement_locked = false
	player_ref = null

func _look_at_player() -> void:
	if not player_ref or not sprite:
		return
	var d := player_ref.global_position - global_position
	var anim := "idle_down"
	var flip := false
	if abs(d.x) > abs(d.y):
		anim = "idle_right"
		if d.x < 0.0:
			flip = true
	else:
		if d.y < 0.0:
			anim = "idle_up"
		else:
			anim = "idle_down"
	sprite.flip_h = flip
	sprite.play(anim)

func _update_portraits() -> void:
	if sprite and sprite.sprite_frames and npc_portrait:
		npc_portrait.sprite_frames = sprite.sprite_frames
		if sprite.sprite_frames.has_animation("idle_right"):
			npc_portrait.play("idle_right")

	if player_ref and player_portrait:
		var ps := player_ref.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ps and ps.sprite_frames:
			player_portrait.sprite_frames = ps.sprite_frames
			if ps.sprite_frames.has_animation("idle_right"):
				player_portrait.play("idle_right")

	if npc_portrait and player_portrait:
		var size := get_viewport().get_visible_rect().size
		var panel_top := size.y * 0.52
		var panel_bottom := size.y * 0.82
		var center_y := (panel_top + panel_bottom) * 0.5
		npc_portrait.position = Vector2(size.x * 0.16, center_y)
		player_portrait.position = Vector2(size.x * 0.86, center_y)

func _ensure_dialog_ui() -> void:
	if dialog_canvas != null:
		return

	dialog_canvas = CanvasLayer.new()
	dialog_canvas.layer = 30

	dialog_panel = Panel.new()
	dialog_panel.anchor_left = 0.10
	dialog_panel.anchor_right = 0.90
	dialog_panel.anchor_top = 0.52
	dialog_panel.anchor_bottom = 0.82
	dialog_panel.custom_minimum_size = Vector2(0, 120)
	dialog_panel.modulate = Color(0.912, 0.757, 0.459, 0.97)

	var border_color := Color(0.912, 0.757, 0.459, 0.97)
	var border_size := 5.0

	var top := ColorRect.new()
	top.color = border_color
	top.anchor_right = 1.0
	top.offset_top = -border_size
	top.offset_left = -border_size
	top.offset_right = border_size

	var bottom := ColorRect.new()
	bottom.color = border_color
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_bottom = border_size
	bottom.offset_left = -border_size
	bottom.offset_right = border_size

	var left := ColorRect.new()
	left.color = border_color
	left.anchor_bottom = 1.0
	left.offset_left = -border_size
	left.offset_top = -border_size
	left.offset_bottom = border_size

	var right := ColorRect.new()
	right.color = border_color
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_right = border_size
	right.offset_top = -border_size
	right.offset_bottom = border_size

	dialog_label = Label.new()
	dialog_label.anchor_left = 0.18
	dialog_label.anchor_right = 0.82
	dialog_label.anchor_top = 0.18
	dialog_label.anchor_bottom = 0.60
	dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialog_label.set("theme_override_font_sizes/font_size", 22)
	dialog_label.set("theme_override_fonts/font", dialog_font)
	dialog_label.set("theme_override_colors/font_color", Color(0.912, 0.757, 0.459, 0.97))

	yes_button = Button.new()
	yes_button.text = "Yes"
	yes_button.anchor_left = 0.24
	yes_button.anchor_right = 0.38
	yes_button.anchor_top = 0.65
	yes_button.anchor_bottom = 0.88
	yes_button.modulate = border_color
	yes_button.focus_mode = Control.FOCUS_NONE
	yes_button.set("theme_override_fonts/font", dialog_font)
	yes_button.set("theme_override_colors/font_color", Color(0.914, 0.753, 0.459, 0.969))
	yes_button.pressed.connect(_on_yes_pressed)

	no_button = Button.new()
	no_button.text = "No"
	no_button.anchor_left = 0.62
	no_button.anchor_right = 0.76
	no_button.anchor_top = 0.65
	no_button.anchor_bottom = 0.88
	no_button.modulate = border_color
	no_button.focus_mode = Control.FOCUS_NONE
	no_button.set("theme_override_fonts/font", dialog_font)
	no_button.set("theme_override_colors/font_color", Color(0.912, 0.757, 0.459, 0.97))
	no_button.pressed.connect(_on_no_pressed)

	dialog_panel.add_child(top)
	dialog_panel.add_child(bottom)
	dialog_panel.add_child(left)
	dialog_panel.add_child(right)
	dialog_panel.add_child(dialog_label)
	dialog_panel.add_child(yes_button)
	dialog_panel.add_child(no_button)
	dialog_canvas.add_child(dialog_panel)

	npc_portrait = AnimatedSprite2D.new()
	npc_portrait.scale = Vector2(8, 8)
	npc_portrait.z_index = 2

	player_portrait = AnimatedSprite2D.new()
	player_portrait.scale = Vector2(8, 8)
	player_portrait.z_index = 2
	player_portrait.flip_h = true

	dialog_canvas.add_child(npc_portrait)
	dialog_canvas.add_child(player_portrait)

	dialog_canvas.visible = false
	get_tree().root.add_child(dialog_canvas)
