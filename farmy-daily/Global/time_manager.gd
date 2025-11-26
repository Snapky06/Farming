extends Node

signal time_updated(time_string: String)
signal date_updated(date_string: String)
signal season_changed(season: Seasons)

enum Seasons { SPRING, SUMMER, AUTUMN, WINTER }

const REAL_SECONDS_PER_GAME_DAY: float = 1200.0
const GAME_SECONDS_PER_DAY: float = 86400.0 

const TIME_SCALE: float = GAME_SECONDS_PER_DAY / REAL_SECONDS_PER_GAME_DAY 

var current_time_seconds: float = 0.0
var current_day: int = 25
var current_month: int = 12
var current_year: int = 1
var current_season: Seasons = Seasons.SPRING

const DAYS_IN_MONTH = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTH_NAMES = [
	"", "January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"
]

func _ready() -> void:
	current_time_seconds = 8 * 3600 
	recalculate_season()
	emit_all_signals()

func _process(delta: float) -> void:
	current_time_seconds += delta * TIME_SCALE
	
	if current_time_seconds >= GAME_SECONDS_PER_DAY:
		current_time_seconds -= GAME_SECONDS_PER_DAY
		advance_date()
	
	emit_time_signal()

func advance_date() -> void:
	current_day += 1
	
	if current_day > DAYS_IN_MONTH[current_month]:
		current_day = 1
		current_month += 1
		
		if current_month > 12:
			current_month = 1
			current_year += 1
	
	recalculate_season()
	emit_date_signal()

func recalculate_season() -> void:
	var prev_season = current_season
	
	if (current_month == 3 and current_day >= 20) or (current_month > 3 and current_month < 6) or (current_month == 6 and current_day <= 20):
		current_season = Seasons.SPRING
	elif (current_month == 6 and current_day >= 21) or (current_month > 6 and current_month < 9) or (current_month == 9 and current_day <= 21):
		current_season = Seasons.SUMMER
	elif (current_month == 9 and current_day >= 22) or (current_month > 9 and current_month < 12) or (current_month == 12 and current_day <= 20):
		current_season = Seasons.AUTUMN
	else:
		current_season = Seasons.WINTER
		
	if current_season != prev_season:
		season_changed.emit(current_season)

func emit_all_signals() -> void:
	emit_time_signal()
	emit_date_signal()
	season_changed.emit(current_season)

func emit_time_signal() -> void:
	var total_minutes = int(current_time_seconds / 60)
	var hours = (total_minutes / 60) % 24
	var minutes = total_minutes % 60
	
	var period = "AM"
	if hours >= 12:
		period = "PM"
	
	var display_hour = hours
	if hours == 0:
		display_hour = 12
	elif hours > 12:
		display_hour = hours - 12
	
	var time_str = "%02d:%02d %s" % [display_hour, minutes, period]
	time_updated.emit(time_str)

func emit_date_signal() -> void:
	var date_str = "%s %d" % [MONTH_NAMES[current_month], current_day]
	date_updated.emit(date_str)
