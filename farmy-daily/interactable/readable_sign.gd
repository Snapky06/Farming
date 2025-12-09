extends Area2D

@export_multiline var sign_text: String = "..."

var ui_root: CanvasLayer = null
var active_player: Node2D = null

func _ready() -> void:
	monitoring = true
	monitorable = true
	
	_build_ui()

func _build_ui() -> void:
	ui_root = CanvasLayer.new()
	ui_root.layer = 101 
	ui_root.visible = false
	add_child(ui_root)
	
	var control_root = Control.new()
	control_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	control_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(control_root)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 150)
	
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -200)
	panel.set_anchor_and_offset(SIDE_TOP, 0.5, -75)
	panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, 200)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 75)
	
	control_root.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var label = Label.new()
	label.text = sign_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 24)
	
	margin.add_child(label)

func interact(user = null) -> void:
	if ui_root.visible:
		close()
	else:
		open(user)

func open(user) -> void:
	active_player = user
	
	var control = ui_root.get_child(0)
	var panel = control.get_child(0)
	var margin = panel.get_child(0)
	var label = margin.get_child(0) as Label
	if label:
		label.text = sign_text
	
	ui_root.visible = true
	
	if user and "is_movement_locked" in user:
		user.is_movement_locked = true

func close() -> void:
	if active_player and "is_movement_locked" in active_player:
		active_player.is_movement_locked = false
		
	active_player = null
	ui_root.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not ui_root.visible:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var control = ui_root.get_child(0)
		var panel = control.get_child(0) as PanelContainer
		if panel:
			var _local_mouse = panel.get_local_mouse_position() 
			if not panel.get_rect().has_point(panel.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()):
				close()
				get_viewport().set_input_as_handled()
