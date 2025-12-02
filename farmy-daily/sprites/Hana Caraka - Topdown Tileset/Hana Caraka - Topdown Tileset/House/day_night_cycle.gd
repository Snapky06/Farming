extends CanvasModulate

var daylight_gradient: Gradient = Gradient.new()

func _ready() -> void:
	if TimeManager.season_changed.is_connected(_on_season_changed) == false:
		TimeManager.season_changed.connect(_on_season_changed)
	
	_on_season_changed(TimeManager.current_season)

func _process(_delta: float) -> void:
	var day_progress = TimeManager.current_time_seconds / TimeManager.GAME_SECONDS_PER_DAY
	color = daylight_gradient.sample(day_progress)

func _on_season_changed(season: int) -> void:
	daylight_gradient = Gradient.new()
	
	match season:
		0:
			_set_gradient_points(
				Color("#0e0e24"),
				Color("#2a2a4a"),
				Color("#ffc0cb"),
				Color("#ffffff"),
				Color("#ffc0cb"),
				Color("#2a2a4a")
			)
		1:
			_set_gradient_points(
				Color("#08081c"),
				Color("#3d3d5c"),
				Color("#ffdfba"),
				Color("#fffde6"),
				Color("#ffae00"),
				Color("#3d3d5c")
			)
		2:
			_set_gradient_points(
				Color("#140a0a"),
				Color("#422424"),
				Color("#d48c68"),
				Color("#ffe8d6"),
				Color("#c95d5d"),
				Color("#422424")
			)
		3:
			_set_gradient_points(
				Color("#050510"),
				Color("#151530"),
				Color("#a3b1ff"),
				Color("#e3eaff"),
				Color("#7579bd"),
				Color("#151530")
			)

func _set_gradient_points(midnight, night_end, dawn, noon, dusk, night_start):
	daylight_gradient.set_color(0, midnight)
	
	while daylight_gradient.get_point_count() > 1:
		daylight_gradient.remove_point(1)
	
	daylight_gradient.add_point(0.15, night_end)
	daylight_gradient.add_point(0.25, dawn.lerp(midnight, 0.5))
	daylight_gradient.add_point(0.30, dawn)
	daylight_gradient.add_point(0.35, dawn.lerp(noon, 0.5))
	
	daylight_gradient.add_point(0.65, noon)
	
	daylight_gradient.add_point(0.75, dusk)
	daylight_gradient.add_point(0.80, dusk.lerp(night_start, 0.5))
	daylight_gradient.add_point(0.90, night_start)
	daylight_gradient.add_point(1.00, midnight)
