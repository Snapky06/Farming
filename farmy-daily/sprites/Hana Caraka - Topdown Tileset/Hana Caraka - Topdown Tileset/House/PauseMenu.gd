extends CanvasLayer

@onready var open_settings_button = $OpenSettingsButton
@onready var menu_overlay = $MenuOverlay
@onready var resume_button = $MenuOverlay/VBoxContainer/ResumeButton
@onready var quests_button = $MenuOverlay/VBoxContainer.get_node_or_null("QuestsButton")
@onready var options_button = $MenuOverlay/VBoxContainer/OptionsButton
@onready var save_exit_button = $MenuOverlay/VBoxContainer/SaveExitButton

var quest_manager: Node = null
var quests_ui: Control = null
var quests_list: VBoxContainer = null
var quests_close_button: Button = null
var dialog_font: Font = load("res://fonts/MineMouseRegular-BL3DB.ttf")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_overlay.visible = false
	open_settings_button.visible = true
	
	open_settings_button.pressed.connect(_on_open_settings_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	save_exit_button.pressed.connect(_on_save_exit_pressed)
	if quests_button:
		quests_button.pressed.connect(_on_quests_pressed)

	quest_manager = get_node_or_null("/root/QuestManager")
	if quest_manager:
		if quest_manager.quest_started.is_connected(_on_quest_changed) == false:
			quest_manager.quest_started.connect(_on_quest_changed)
		if quest_manager.quest_updated.is_connected(_on_quest_changed) == false:
			quest_manager.quest_updated.connect(_on_quest_changed)
		if quest_manager.quest_completed.is_connected(_on_quest_changed) == false:
			quest_manager.quest_completed.connect(_on_quest_changed)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if quests_ui and quests_ui.visible:
			_hide_quests()
			return
		if menu_overlay.visible:
			_on_resume_pressed()
		else:
			_on_open_settings_pressed()

func _on_open_settings_pressed():
	menu_overlay.visible = true
	open_settings_button.visible = false
	get_tree().paused = true

func _on_resume_pressed():
	_hide_quests()
	menu_overlay.visible = false
	open_settings_button.visible = true
	get_tree().paused = false

func _on_options_pressed():
	pass

func _on_save_exit_pressed():
	SaveManager.save_game()
	get_tree().paused = false
	menu_overlay.visible = false
	open_settings_button.visible = true
	_hide_quests()
	if ResourceLoader.exists("res://levels/main_menu.tscn"):
		get_tree().change_scene_to_file("res://levels/main_menu.tscn")
	elif ResourceLoader.exists("res://levels/intro.tscn"):
		get_tree().change_scene_to_file("res://levels/intro.tscn")
	else:
		get_tree().quit()

func _on_quests_pressed():
	if not quests_ui:
		_build_quests_ui()
	if quests_ui.visible:
		_hide_quests()
	else:
		quests_ui.visible = true
		_update_quests_view()

func _hide_quests():
	if quests_ui:
		quests_ui.visible = false

func _on_quest_changed(_id: String) -> void:
	if quests_ui and quests_ui.visible:
		_update_quests_view()

func _build_quests_ui():
	quests_ui = Control.new()
	quests_ui.anchor_left = 0.0
	quests_ui.anchor_top = 0.0
	quests_ui.anchor_right = 1.0
	quests_ui.anchor_bottom = 1.0
	quests_ui.visible = false
	quests_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	quests_ui.z_index = 1000
	add_child(quests_ui)

	var dim = ColorRect.new()
	dim.anchor_left = 0.0
	dim.anchor_top = 0.0
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.05)
	quests_ui.add_child(dim)

	var panel = Panel.new()
	panel.anchor_left = 0.10
	panel.anchor_right = 0.90
	panel.anchor_top = 0.10
	panel.anchor_bottom = 0.90
	panel.modulate = Color(0.96, 0.94, 0.90, 1.0)
	quests_ui.add_child(panel)

	var title = Label.new()
	title.anchor_left = 0.05
	title.anchor_right = 0.95
	title.anchor_top = 0.03
	title.anchor_bottom = 0.13
	title.text = "QUEST LOG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set("theme_override_fonts/font", dialog_font)
	title.set("theme_override_font_sizes/font_size", 34)
	title.set("theme_override_colors/font_color", Color(1, 1, 1, 1))
	panel.add_child(title)

	quests_close_button = Button.new()
	quests_close_button.text = "RETURN"
	quests_close_button.anchor_left = 0.35
	quests_close_button.anchor_right = 0.65
	quests_close_button.anchor_top = 0.88
	quests_close_button.anchor_bottom = 0.96
	quests_close_button.focus_mode = Control.FOCUS_NONE
	quests_close_button.set("theme_override_fonts/font", dialog_font)
	quests_close_button.set("theme_override_font_sizes/font_size", 22)
	quests_close_button.set("theme_override_colors/font_color", Color(0, 0, 0, 1))
	quests_close_button.modulate = Color(1.0, 0.9, 0.4, 1.0)
	quests_close_button.pressed.connect(_hide_quests)
	panel.add_child(quests_close_button)

	var scroll = ScrollContainer.new()
	scroll.anchor_left = 0.06
	scroll.anchor_right = 0.94
	scroll.anchor_top = 0.15
	scroll.anchor_bottom = 0.85
	panel.add_child(scroll)

	quests_list = VBoxContainer.new()
	quests_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quests_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(quests_list)

	_update_quests_view()

func _update_quests_view():
	if not quests_list:
		return

	for c in quests_list.get_children():
		c.queue_free()

	if not quest_manager:
		var l = Label.new()
		l.text = "QUEST SYSTEM NOT FOUND"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set("theme_override_fonts/font", dialog_font)
		l.set("theme_override_font_sizes/font_size", 22)
		l.set("theme_override_colors/font_color", Color(1, 1, 1, 1))
		quests_list.add_child(l)
		return

	var active = quest_manager.get_all_active_quests()

	if active.is_empty():
		var l2 = Label.new()
		l2.text = "NO ACTIVE QUESTS"
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.set("theme_override_fonts/font", dialog_font)
		l2.set("theme_override_font_sizes/font_size", 24)
		l2.set("theme_override_colors/font_color", Color(1, 1, 1, 1))
		quests_list.add_child(l2)
		return

	for quest_state in active:
		var quest = quest_state["resource"]
		var step_idx = int(quest_state["current_step_index"])
		var progress = int(quest_state["current_step_progress"])

		var title = Label.new()
		title.text = str(quest.title).to_upper()
		title.set("theme_override_fonts/font", dialog_font)
		title.set("theme_override_font_sizes/font_size", 26)
		title.set("theme_override_colors/font_color", Color(1, 1, 1, 1))
		quests_list.add_child(title)

		var desc = Label.new()
		desc.set("theme_override_fonts/font", dialog_font)
		desc.set("theme_override_font_sizes/font_size", 22)
		desc.set("theme_override_colors/font_color", Color(0.95, 0.95, 0.95, 1))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		if step_idx < quest.steps.size():
			var step = quest.steps[step_idx]
			desc.text = "- " + str(step.description) + " (" + str(progress) + "/" + str(step.required_count) + ")"
		else:
			desc.text = "COMPLETED"

		quests_list.add_child(desc)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 18)
		quests_list.add_child(spacer)
