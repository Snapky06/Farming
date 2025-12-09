extends Node

signal time_updated(time_string)
signal date_updated(date_string)
signal season_changed(season)
signal hour_passed
signal energy_updated(current, max)

enum Seasons { SPRING, SUMMER, AUTUMN, WINTER }

const REAL_SECONDS_PER_GAME_DAY = 1200.0
const GAME_SECONDS_PER_DAY = 86400.0
const TIME_SCALE = GAME_SECONDS_PER_DAY / REAL_SECONDS_PER_GAME_DAY

const DAYS_IN_MONTH = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTH_NAMES = [
	"",
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December"
]

var current_time_seconds: float = 0.0
var current_day: int = 27
var current_month: int = 4
var current_year: int = 2025
var current_season: int = Seasons.SPRING
var last_hour: int = -1

var player_spawn_tag: String = ""
var auto_sleep_penalty_applied: bool = false

var max_energy: float = 100.0
var current_energy: float = 100.0
var last_half_hour_check: int = -1

func _ready() -> void:
	current_time_seconds = 8.0 * 3600.0
	last_hour = int(current_time_seconds / 3600.0) % 24
	last_half_hour_check = int(current_time_seconds / 1800.0)
	recalculate_season()
	emit_all_signals()

func _process(delta: float) -> void:
	current_time_seconds += delta * TIME_SCALE

	if current_time_seconds >= GAME_SECONDS_PER_DAY:
		current_time_seconds -= GAME_SECONDS_PER_DAY
		advance_date()

	var current_hour := int(current_time_seconds / 3600.0) % 24
	if current_hour != last_hour:
		last_hour = current_hour
		hour_passed.emit()
		_check_auto_sleep_penalty()

	var current_half_hour = int(current_time_seconds / 1800.0)
	if current_half_hour != last_half_hour_check:
		last_half_hour_check = current_half_hour
		_consume_energy(5.0)

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
	var prev_season := current_season

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
	energy_updated.emit(current_energy, max_energy)

func emit_time_signal() -> void:
	var total_minutes := int(current_time_seconds / 60.0)
	var hours := int(total_minutes / 60.0) % 24
	var minutes := total_minutes % 60

	var period := "AM"
	if hours >= 12:
		period = "PM"

	var display_hour := hours
	if hours == 0:
		display_hour = 12
	elif hours > 12:
		display_hour = hours - 12

	var time_str := "%02d:%02d %s" % [display_hour, minutes, period]
	time_updated.emit(time_str)

func emit_date_signal() -> void:
	var date_str := "%s %d" % [MONTH_NAMES[current_month], current_day]
	date_updated.emit(date_str)

func _check_auto_sleep_penalty() -> void:
	var current_hour := int(current_time_seconds / 3600.0) % 24

	if current_hour < 2:
		auto_sleep_penalty_applied = false
		return

	if (current_hour == 2 or current_energy <= 0) and not auto_sleep_penalty_applied:
		print("Fainting triggered from _check_auto_sleep_penalty")
		auto_sleep_penalty_applied = true
		_do_auto_sleep_penalty()

func _do_auto_sleep_penalty() -> void:
	print("Starting auto sleep penalty...")
	var root := get_tree().current_scene
	if root == null:
		return

	var player = root.find_child("Player", true, false)
	if player == null:
		return

	if "is_movement_locked" in player:
		player.is_movement_locked = true
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	if "reset_states" in player:
		player.reset_states()

	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	var transition_rect: ColorRect = null
	for child in root.get_children():
		if child is CanvasLayer and child.layer == 100:
			for grand in child.get_children():
				if grand is ColorRect:
					transition_rect = grand
					break

	if sprite:
		sprite.flip_h = false
		if sprite.sprite_frames.has_animation("sleep_down"):
			sprite.play("sleep_down")
			await sprite.animation_finished
		else:
			await get_tree().create_timer(1.0).timeout
	else:
		await get_tree().create_timer(1.0).timeout

	if transition_rect:
		var t = create_tween()
		t.tween_property(transition_rect, "modulate:a", 1.0, 0.5)
		await t.finished

	var target_hour := 15
	var current_hour := int(current_time_seconds / 3600.0) % 24
	var hours_to_advance := 0

	if target_hour > current_hour:
		hours_to_advance = target_hour - current_hour
	else:
		hours_to_advance = (24 - current_hour) + target_hour

	for i in range(hours_to_advance):
		current_hour = (current_hour + 1) % 24
		if current_hour == 0:
			advance_date()
		current_time_seconds = float(current_hour) * 3600.0
		last_hour = current_hour
		hour_passed.emit()

	restore_energy()
	last_half_hour_check = int(current_time_seconds / 1800.0)
	auto_sleep_penalty_applied = false 
	emit_all_signals()

	if root.has_method("change_level_to"):
		await root.change_level_to("res://levels/playerhouse.tscn", "sleep")
		if "is_movement_locked" in player:
			player.is_movement_locked = false
		return

	var target_pos: Vector2 = player.global_position
	var sleep_marker = root.find_child("sleep", true, false)
	if sleep_marker and sleep_marker is Node2D:
		target_pos = sleep_marker.global_position

	player.global_position = target_pos

	if player.has_node("NavigationAgent2D"):
		var agent = player.get_node("NavigationAgent2D")
		if agent:
			agent.target_position = target_pos

	if player.has_method("update_idle_animation"):
		player.update_idle_animation(Vector2.DOWN)
	if "is_movement_locked" in player:
		player.is_movement_locked = false

	if transition_rect:
		var t2 = create_tween()
		t2.tween_property(transition_rect, "modulate:a", 0.0, 1.0)
		await t2.finished

func get_save_data() -> Dictionary:
	return {
		"time_seconds": current_time_seconds,
		"day": current_day,
		"month": current_month,
		"year": current_year,
		"season": current_season,
		"penalty": auto_sleep_penalty_applied,
		"energy": current_energy
	}

func load_save_data(data: Dictionary) -> void:
	current_time_seconds = data.get("time_seconds", 8.0 * 3600.0)
	current_day = data.get("day", 1)
	current_month = data.get("month", 1)
	current_year = data.get("year", 2025)
	current_season = data.get("season", Seasons.SPRING)
	auto_sleep_penalty_applied = data.get("penalty", false)
	current_energy = data.get("energy", 100.0)
	last_hour = int(current_time_seconds / 3600.0) % 24
	last_half_hour_check = int(current_time_seconds / 1800.0)
	emit_all_signals()

func save_watered_tiles(_data: Dictionary) -> void:
	pass 

func load_watered_tiles() -> Dictionary:
	return {}

func use_tool_energy() -> void:
	_consume_energy(4.0)

func _consume_energy(amount: float) -> void:
	current_energy -= amount
	if current_energy <= 0:
		current_energy = 0
		if not auto_sleep_penalty_applied:
			print("Energy depleted. Triggering faint.")
			auto_sleep_penalty_applied = true
			_do_auto_sleep_penalty()
	
	energy_updated.emit(current_energy, max_energy)

func restore_energy() -> void:
	current_energy = max_energy
	energy_updated.emit(current_energy, max_energy)
