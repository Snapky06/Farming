extends Control

var save_manager
var time_manager
var menu_container
var buttons_container
var slots_container
var name_panel
var name_input
var selected_slot_index = -1
var background_scene

var title_font = preload("res://fonts/MayfairNbpBold-gAA4.ttf")
var ui_font = preload("res://fonts/MineMouseRegular-BL3DB.ttf")

func _ready() -> void:
	save_manager = get_node("/root/SaveManager")
	time_manager = get_node("/root/TimeManager")
	
	if time_manager:
		time_manager.is_gameplay_active = false 
	
	setup_background()
	create_ui()

func _process(delta: float) -> void:
	if time_manager:
		time_manager.current_time_seconds += delta * 15000.0
		
		if time_manager.current_time_seconds >= time_manager.GAME_SECONDS_PER_DAY:
			time_manager.current_time_seconds -= time_manager.GAME_SECONDS_PER_DAY
			time_manager.advance_date()
		
		time_manager.recalculate_season()
		time_manager.emit_time_signal() 

func setup_background() -> void:
	if ResourceLoader.exists("res://levels/first.tscn"):
		var scene = load("res://levels/first.tscn")
		background_scene = scene.instantiate()
		add_child(background_scene)
		move_child(background_scene, 0)
		
		var existing_canvas = background_scene.find_child("CanvasLayer", true, false)
		if existing_canvas: existing_canvas.queue_free()
		var existing_ui = background_scene.find_child("UI", true, false)
		if existing_ui: existing_ui.queue_free()
		var player = background_scene.find_child("Player", true, false)
		if player: player.queue_free()

func create_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var center_control = CenterContainer.new()
	center_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_control.anchor_left = 0.0
	center_control.anchor_top = 0.0
	center_control.anchor_right = 1.0
	center_control.anchor_bottom = 1.0
	center_control.offset_left = 0
	center_control.offset_top = 0
	center_control.offset_right = 0
	center_control.offset_bottom = 0
	canvas.add_child(center_control)
	
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 40)
	menu_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center_control.add_child(menu_container)
	
	var title = Label.new()
	title.text = "Farmy Daily"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.05))
	title.add_theme_constant_override("outline_size", 16)
	menu_container.add_child(title)
	
	buttons_container = VBoxContainer.new()
	buttons_container.custom_minimum_size = Vector2(350, 0)
	buttons_container.add_theme_constant_override("separation", 20)
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_container.add_child(buttons_container)
	
	create_styled_button("Start", _on_start_pressed, buttons_container)
	create_styled_button("Options", _on_options_pressed, buttons_container)
	create_styled_button("Exit", _on_exit_pressed, buttons_container)
	
	slots_container = VBoxContainer.new()
	slots_container.custom_minimum_size = Vector2(500, 0)
	slots_container.add_theme_constant_override("separation", 15)
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_container.visible = false
	menu_container.add_child(slots_container)
	
	create_name_panel(canvas)

func create_styled_button(text: String, callback: Callable, parent: Node, min_size: Vector2 = Vector2(0, 60)) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_override("font", ui_font)
	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.35, 0.25, 0.15, 0.9)
	style_normal.border_width_bottom = 6
	style_normal.border_color = Color(0.2, 0.1, 0.05)
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_right = 10
	style_normal.corner_radius_bottom_left = 10
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.45, 0.35, 0.2, 1.0)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.25, 0.15, 0.05, 1.0)
	style_pressed.border_width_bottom = 2
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func create_name_panel(parent: Node) -> void:
	name_panel = Panel.new()
	name_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	name_panel.add_theme_stylebox_override("panel", style)
	name_panel.visible = false
	parent.add_child(name_panel)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	name_panel.add_child(center)
	
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 25)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	
	var prompt = Label.new()
	prompt.text = "Enter Name:"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_override("font", ui_font)
	prompt.add_theme_font_size_override("font_size", 48)
	box.add_child(prompt)
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "Farmer Name"
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.custom_minimum_size = Vector2(0, 60)
	name_input.add_theme_font_override("font", ui_font)
	name_input.add_theme_font_size_override("font_size", 32)
	box.add_child(name_input)
	
	var h_box = HBoxContainer.new()
	h_box.alignment = BoxContainer.ALIGNMENT_CENTER
	h_box.add_theme_constant_override("separation", 20)
	box.add_child(h_box)
	
	create_styled_button("Confirm", _on_confirm_name, h_box, Vector2(150, 60))
	create_styled_button("Cancel", func(): name_panel.visible = false, h_box, Vector2(150, 60))

func render_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
		
	for i in range(3):
		var meta = save_manager.slots_cache.get(i, {})
		var btn_text = ""
		
		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 10)
		slots_container.add_child(slot_hbox)
		
		if meta.is_empty():
			btn_text = "Slot " + str(i+1) + ": New Game"
			create_styled_button(btn_text, _on_slot_pressed.bind(i, true), slot_hbox)
		else:
			btn_text = meta.get("player_name", "Farmer") + " - " + meta.get("date", "Day 1")
			create_styled_button(btn_text, _on_slot_pressed.bind(i, false), slot_hbox)
			var del_btn = create_styled_button("X", _on_delete_pressed.bind(i), slot_hbox, Vector2(60, 60))
			del_btn.modulate = Color(1, 0.5, 0.5)

	create_styled_button("Back", _on_back_pressed, slots_container)

func _on_start_pressed() -> void:
	buttons_container.visible = false
	slots_container.visible = true
	render_slots()

func _on_options_pressed() -> void:
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	slots_container.visible = false
	buttons_container.visible = true

func _on_slot_pressed(index: int, is_new: bool) -> void:
	if is_new:
		selected_slot_index = index
		name_panel.visible = true
		name_input.text = ""
		name_input.grab_focus()
	else:
		save_manager.load_game(index)

func _on_delete_pressed(index: int) -> void:
	save_manager.delete_save(index)
	render_slots()

func _on_confirm_name() -> void:
	var pname = name_input.text.strip_edges()
	if pname == "": pname = "Farmer"
	save_manager.start_new_game(selected_slot_index, pname)
