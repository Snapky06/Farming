extends CanvasModulate

var daylight_gradient: Gradient = Gradient.new()

func _ready() -> void:
	daylight_gradient.set_color(0, Color("#0e0e24")) 
	
	if daylight_gradient.get_point_count() > 1:
		daylight_gradient.remove_point(1)
	
	daylight_gradient.add_point(0.15, Color("#1a1a3d"))
	daylight_gradient.add_point(0.25, Color("#6e5f8a"))
	daylight_gradient.add_point(0.3, Color("#ffb68f"))
	daylight_gradient.add_point(0.35, Color("#fff6d3"))
	daylight_gradient.add_point(0.65, Color("#ffffff"))
	daylight_gradient.add_point(0.75, Color("#ffc285"))
	daylight_gradient.add_point(0.8, Color("#5e4878"))
	daylight_gradient.add_point(0.9, Color("#12122e"))
	daylight_gradient.add_point(1.0, Color("#0e0e24"))

func _process(_delta: float) -> void:
	var day_progress = TimeManager.current_time_seconds / TimeManager.GAME_SECONDS_PER_DAY
	color = daylight_gradient.sample(day_progress)
