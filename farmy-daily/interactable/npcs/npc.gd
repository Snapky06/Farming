extends Node2D

@export var dialog_lines: Array[String] = []
@export var text_speed: float = 0.03
@export var offered_quest: QuestData
@export var start_event_name: String = ""
@export var finish_event_name: String = ""
@export var finish_on_last_line: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var type_timer: Timer = $Timer
@onready var quest_manager: Node = get_node_or_null("/root/QuestManager")

var dialog_active: bool = false
var is_typing: bool = false
var current_line_index: int = 0
var current_text: String = ""
var visible_characters: int = 0
var player_ref: Node2D = null

var dialog_canvas: CanvasLayer = null
var dialog_panel: Panel = null
var dialog_label: Label = null
var npc_portrait: AnimatedSprite2D = null
var player_portrait: AnimatedSprite2D = null
var next_button: Button = null
var close_button: Button = null

var dialog_font: Font = load("res://fonts/MineMouseRegular-BL3DB.ttf")

func _ready() -> void:
	if not type_timer.timeout.is_connected(_on_type_timer_timeout):
		type_timer.timeout.connect(_on_type_timer_timeout)

func on_interact(player) -> void:
	if dialog_lines.is_empty():
		return
	if dialog_active:
		return
	if quest_manager:
		if offered_quest and not quest_manager.is_quest_active(offered_quest.id) and not quest_manager.is_quest_completed(offered_quest.id):
			quest_manager.start_quest(offered_quest)
		if start_event_name != "":
			quest_manager.notify_event(start_event_name, 1, name)
	_start_dialog(player)

func _start_dialog(player) -> void:
	player_ref = player
	dialog_active = true
	if "is_movement_locked" in player_ref:
		player_ref.is_movement_locked = true
	_look_at_player()
	_ensure_dialog_ui()
	_update_portraits()
	_show_line(0)

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
	dialog_panel.offset_left = 0.0
	dialog_panel.offset_right = 0.0
	dialog_panel.offset_top = 0.0
	dialog_panel.offset_bottom = 0.0
	dialog_panel.custom_minimum_size = Vector2(0, 120)
	dialog_panel.modulate = Color(0.912, 0.757, 0.459, 0.97)

	var border_color := Color(0.912, 0.757, 0.459, 0.97)
	var border_size := 5.0

	var top := ColorRect.new()
	top.color = border_color
	top.anchor_left = 0.0
	top.anchor_right = 1.0
	top.anchor_top = 0.0
	top.anchor_bottom = 0.0
	top.offset_top = -border_size
	top.offset_bottom = 0.0
	top.offset_left = -border_size
	top.offset_right = border_size

	var bottom := ColorRect.new()
	bottom.color = border_color
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = 0.0
	bottom.offset_bottom = border_size
	bottom.offset_left = -border_size
	bottom.offset_right = border_size

	var left := ColorRect.new()
	left.color = border_color
	left.anchor_left = 0.0
	left.anchor_right = 0.0
	left.anchor_top = 0.0
	left.anchor_bottom = 1.0
	left.offset_left = -border_size
	left.offset_right = 0.0
	left.offset_top = -border_size
	left.offset_bottom = border_size

	var right := ColorRect.new()
	right.color = border_color
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.0
	right.anchor_bottom = 1.0
	right.offset_left = 0.0
	right.offset_right = border_size
	right.offset_top = -border_size
	right.offset_bottom = border_size

	dialog_label = Label.new()
	dialog_label.anchor_left = 0.18
	dialog_label.anchor_right = 0.82
	dialog_label.anchor_top = 0.18
	dialog_label.anchor_bottom = 0.60
	dialog_label.offset_left = 8.0
	dialog_label.offset_right = -8.0
	dialog_label.offset_top = 0.0
	dialog_label.offset_bottom = 0.0
	dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialog_label.set("theme_override_font_sizes/font_size", 22)
	dialog_label.set("theme_override_fonts/font", dialog_font)
	dialog_label.set("theme_override_colors/font_color", Color(0.912, 0.757, 0.459, 0.97))

	next_button = Button.new()
	next_button.text = "Next"
	next_button.anchor_left = 0.62
	next_button.anchor_right = 0.76
	next_button.anchor_top = 0.65
	next_button.anchor_bottom = 0.88
	next_button.offset_left = 0.0
	next_button.offset_right = 0.0
	next_button.offset_top = 0.0
	next_button.offset_bottom = 0.0
	next_button.modulate = border_color
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.set("theme_override_fonts/font", dialog_font)
	next_button.set("theme_override_colors/font_color", Color(0.912, 0.757, 0.459, 0.97))
	next_button.pressed.connect(_on_next_button_pressed)

	close_button = Button.new()
	close_button.text = "Return"
	close_button.anchor_left = 0.24
	close_button.anchor_right = 0.38
	close_button.anchor_top = 0.65
	close_button.anchor_bottom = 0.88
	close_button.offset_left = 0.0
	close_button.offset_right = 0.0
	close_button.offset_top = 0.0
	close_button.offset_bottom = 0.0
	close_button.modulate = border_color
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.set("theme_override_fonts/font", dialog_font)
	close_button.set("theme_override_colors/font_color", Color(0.912, 0.757, 0.459, 0.97))
	close_button.pressed.connect(_on_close_button_pressed)

	dialog_panel.add_child(top)
	dialog_panel.add_child(bottom)
	dialog_panel.add_child(left)
	dialog_panel.add_child(right)
	dialog_panel.add_child(dialog_label)
	dialog_panel.add_child(next_button)
	dialog_panel.add_child(close_button)
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

func _update_portraits() -> void:
	if sprite and sprite.sprite_frames:
		npc_portrait.sprite_frames = sprite.sprite_frames
		if sprite.sprite_frames.has_animation("idle_right"):
			npc_portrait.play("idle_right")

	if player_ref:
		var ps := player_ref.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ps and ps.sprite_frames:
			player_portrait.sprite_frames = ps.sprite_frames
			if ps.sprite_frames.has_animation("idle_right"):
				player_portrait.play("idle_right")

	var size := get_viewport().get_visible_rect().size
	var panel_top := size.y * 0.52
	var panel_bottom := size.y * 0.82
	var center_y := (panel_top + panel_bottom) * 0.5

	npc_portrait.position = Vector2(size.x * 0.16, center_y)
	player_portrait.position = Vector2(size.x * 0.84, center_y)

func _show_line(index: int) -> void:
	current_line_index = index
	current_text = dialog_lines[index]
	visible_characters = 0
	is_typing = true
	dialog_label.text = ""
	dialog_canvas.visible = true
	type_timer.wait_time = text_speed
	type_timer.start()

func _on_next_button_pressed() -> void:
	if not dialog_active:
		return
	if is_typing:
		visible_characters = current_text.length()
		dialog_label.text = current_text
		is_typing = false
		type_timer.stop()
	else:
		_advance_or_close()

func _on_close_button_pressed() -> void:
	if not dialog_active:
		return
	_end_dialog()

func _advance_or_close() -> void:
	var next_index := current_line_index + 1
	if next_index < dialog_lines.size():
		_show_line(next_index)
	else:
		if quest_manager and finish_on_last_line and finish_event_name != "":
			quest_manager.notify_event(finish_event_name, 1, name)
		_end_dialog()

func _end_dialog() -> void:
	dialog_active = false
	is_typing = false
	type_timer.stop()
	if dialog_canvas:
		dialog_canvas.visible = false
	if player_ref and "is_movement_locked" in player_ref:
		player_ref.is_movement_locked = false
	player_ref = null

func _on_type_timer_timeout() -> void:
	if not is_typing:
		return
	visible_characters += 1
	if visible_characters >= current_text.length():
		visible_characters = current_text.length()
		dialog_label.text = current_text
		is_typing = false
		type_timer.stop()
	else:
		dialog_label.text = current_text.substr(0, visible_characters)

func _look_at_player() -> void:
	if player_ref == null:
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
