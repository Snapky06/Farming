extends CanvasLayer

@onready var open_settings_button = $OpenSettingsButton
@onready var menu_overlay = $MenuOverlay
@onready var resume_button = $MenuOverlay/VBoxContainer/ResumeButton
@onready var options_button = $MenuOverlay/VBoxContainer/OptionsButton
@onready var save_exit_button = $MenuOverlay/VBoxContainer/SaveExitButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_overlay.visible = false
	open_settings_button.visible = true
	
	open_settings_button.pressed.connect(_on_open_settings_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	save_exit_button.pressed.connect(_on_save_exit_pressed)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"): 
		if menu_overlay.visible:
			_on_resume_pressed()
		else:
			_on_open_settings_pressed()

func _on_open_settings_pressed():
	menu_overlay.visible = true
	open_settings_button.visible = false
	get_tree().paused = true

func _on_resume_pressed():
	menu_overlay.visible = false
	open_settings_button.visible = true
	get_tree().paused = false

func _on_options_pressed():
	pass

func _on_save_exit_pressed():
	SaveManager.save_game()
	get_tree().quit()
