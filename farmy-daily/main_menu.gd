extends Control

var save_manager
var slot_container
var name_panel
var name_input
var selected_slot_index = -1

func _ready() -> void:
	save_manager = get_node("/root/SaveManager")
	create_ui()

func create_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var title = Label.new()
	title.text = "Farming RPG"
	title.add_theme_font_size_override("font_size", 50)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 50
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	
	slot_container = VBoxContainer.new()
	slot_container.set_anchors_preset(Control.PRESET_CENTER)
	slot_container.custom_minimum_size = Vector2(300, 200)
	slot_container.add_theme_constant_override("separation", 15)
	add_child(slot_container)
	
	render_slots()
	
	name_panel = Panel.new()
	name_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_panel.modulate = Color(0, 0, 0, 0.9)
	name_panel.visible = false
	add_child(name_panel)
	
	var center_box = VBoxContainer.new()
	center_box.set_anchors_preset(Control.PRESET_CENTER)
	center_box.custom_minimum_size = Vector2(300, 100)
	name_panel.add_child(center_box)
	
	var prompt = Label.new()
	prompt.text = "Enter Name:"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(prompt)
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "Farmer Name"
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(name_input)
	
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	center_box.add_child(btn_box)
	
	var ok_btn = Button.new()
	ok_btn.text = "Start"
	ok_btn.custom_minimum_size = Vector2(80, 40)
	ok_btn.pressed.connect(_on_confirm_name)
	btn_box.add_child(ok_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 40)
	cancel_btn.pressed.connect(func(): name_panel.visible = false)
	btn_box.add_child(cancel_btn)

func render_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()
		
	for i in range(3):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		
		var meta = save_manager.slots_cache.get(i, {})
		
		if meta.is_empty():
			btn.text = "Slot " + str(i+1) + ": Empty"
			btn.pressed.connect(_on_slot_pressed.bind(i, true))
		else:
			var txt = "Slot " + str(i+1) + ": " + meta["player_name"]
			txt += " (Day " + str(meta.get("day", 1)) + ")"
			btn.text = txt
			btn.pressed.connect(_on_slot_pressed.bind(i, false))
			
		slot_container.add_child(btn)
		
	var exit = Button.new()
	exit.text = "Exit"
	exit.custom_minimum_size = Vector2(0, 50)
	exit.pressed.connect(func(): get_tree().quit())
	slot_container.add_child(exit)

func _on_slot_pressed(index: int, is_new: bool) -> void:
	if is_new:
		selected_slot_index = index
		name_panel.visible = true
		name_input.text = ""
		name_input.grab_focus()
	else:
		save_manager.load_game(index)

func _on_confirm_name() -> void:
	var pname = name_input.text.strip_edges()
	if pname == "":
		pname = "Farmer"
	
	save_manager.start_new_game(selected_slot_index, pname)
