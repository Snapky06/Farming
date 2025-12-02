extends Node

signal time_updated(time_string)
signal date_updated(date_string)
signal season_changed(season)
signal hour_passed

enum Seasons { SPRING, SUMMER, AUTUMN, WINTER }

const REAL_SECONDS_PER_GAME_DAY = 1200.0 
const GAME_SECONDS_PER_DAY = 86400.0 

const TIME_SCALE = GAME_SECONDS_PER_DAY / REAL_SECONDS_PER_GAME_DAY 

var current_time_seconds = 0.0
var current_day = 1
var current_month = 10
var current_year = 2025
var current_season = Seasons.SPRING
var last_hour = -1

const DAYS_IN_MONTH = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTH_NAMES = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

func _ready():
	current_time_seconds = 8 * 3600 
	last_hour = int(current_time_seconds / 3600) % 24
	recalculate_season()
	emit_all_signals()
	print("TimeManager: Started. One day will take ", REAL_SECONDS_PER_GAME_DAY, " seconds.")

func _process(delta):
	current_time_seconds += delta * TIME_SCALE
	
	var current_hour = int(current_time_seconds / 3600) % 24
	if current_hour != last_hour:
		last_hour = current_hour
		hour_passed.emit()
		print("TimeManager: Hour Passed -> ", current_hour, ":00") # DEBUG PRINT
	
	if current_time_seconds >= GAME_SECONDS_PER_DAY:
		current_time_seconds -= GAME_SECONDS_PER_DAY
		advance_date()
	
	emit_time_signal()

func advance_date():
	current_day += 1
	
	if current_day > DAYS_IN_MONTH[current_month]:
		current_day = 1
		current_month += 1
		
		if current_month > 12:
			current_month = 1
			current_year += 1
	
	recalculate_season()
	emit_date_signal()
	print("TimeManager: New Day Started: ", current_day, "/", current_month)

func recalculate_season():
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

func emit_all_signals():
	emit_time_signal()
	emit_date_signal()
	season_changed.emit(current_season)

func emit_time_signal():
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

func emit_date_signal():
	var date_str = "%s %d" % [MONTH_NAMES[current_month], current_day]
	date_updated.emit(date_str)
