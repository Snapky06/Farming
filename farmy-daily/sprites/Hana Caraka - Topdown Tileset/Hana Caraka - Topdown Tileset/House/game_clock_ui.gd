extends CanvasLayer


@onready var time_label: Label = $Time/TimeAndMonth/ActualTime

@onready var date_label: Label = $Time/TimeAndMonth/NameMonthAndDate

func _ready() -> void:
	if TimeManager:
		TimeManager.time_updated.connect(_on_time_updated)
		TimeManager.date_updated.connect(_on_date_updated)
		
		TimeManager.emit_all_signals()

func _on_time_updated(time_string: String) -> void:
	if time_label:
		time_label.text = time_string

func _on_date_updated(date_string: String) -> void:
	if date_label:
		date_label.text = date_string
