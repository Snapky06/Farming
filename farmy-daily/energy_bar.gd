extends TextureProgressBar

@onready var warning_label: Label = $WarningLabel

func _ready() -> void:
	var time_manager = get_node("/root/TimeManager")
	if time_manager:
		time_manager.energy_updated.connect(_on_energy_updated)
		_on_energy_updated(time_manager.current_energy, time_manager.max_energy)
	
	if warning_label:
		warning_label.visible = false
		if FileAccess.file_exists("res://fonts/MineMouseRegular-BL3DB.ttf"):
			var font = load("res://fonts/MineMouseRegular-BL3DB.ttf")
			if font:
				warning_label.add_theme_font_override("font", font)

func _on_energy_updated(current: float, max_val: float) -> void:
	if max_val > 0:
		value = (current / max_val) * 100
	else:
		value = 0
	
	if warning_label:
		if value <= 20 and value > 0:
			warning_label.visible = true
			warning_label.text = "Go to sleep!"
		elif value == 0:
			warning_label.visible = true
			warning_label.text = "Passed out!"
		else:
			warning_label.visible = false
