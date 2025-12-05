extends Area2D

@onready var time_manager = get_node_or_null("/root/TimeManager")

var is_sleeping = false
var skip_hour_logic = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	if time_manager:
		if not time_manager.hour_passed.is_connected(_on_hour_passed):
			time_manager.hour_passed.connect(_on_hour_passed)

func interact(user = null) -> void:
	if not time_manager:
		return

	var player = user
	if player == null:
		player = _find_player()
	if player == null:
		return

	var total_minutes = int(time_manager.current_time_seconds / 60)
	var current_hour = int(total_minutes / 60) % 24

	if current_hour >= 2 and current_hour < 19:
		return

	var target_hour = 6
	var is_next_day = current_hour >= 19

	_start_sleep(player, target_hour, is_next_day)

func _on_hour_passed() -> void:
	if not time_manager:
		return
	if skip_hour_logic:
		return

	var total_minutes = int(time_manager.current_time_seconds / 60)
	var current_hour = int(total_minutes / 60) % 24

	if current_hour == 2:
		var player = _find_player()
		if player:
			_start_sleep(player, 15, false)

func _find_player():
	var scene = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("Player", true, false)

func _start_sleep(player, target_hour, is_next_day) -> void:
	if is_sleeping:
		return

	is_sleeping = true
	skip_hour_logic = true

	if "is_movement_locked" in player:
		player.is_movement_locked = true
	if "velocity" in player:
		player.velocity = Vector2.ZERO

	var bed_node = get_parent()
	var bed_position = global_position
	if bed_node:
		bed_position = bed_node.global_position

	var direction = (bed_position - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	var sprite = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	var anim_name = "sleep_down"
	var flip_h = false

	if abs(direction.x) > abs(direction.y):
		anim_name = "sleep_right"
		if direction.x < 0:
			flip_h = true
	else:
		if direction.y > 0:
			anim_name = "sleep_down"
		else:
			anim_name = "sleep_up"

	if sprite:
		sprite.flip_h = flip_h
		sprite.play(anim_name)
		await sprite.animation_finished

	_advance_time_to(target_hour, is_next_day)

	player.global_position = bed_position
	if player.has_method("update_idle_animation"):
		player.update_idle_animation(Vector2.DOWN)
	if "is_movement_locked" in player:
		player.is_movement_locked = false

	is_sleeping = false
	skip_hour_logic = false

func _advance_time_to(target_hour, is_next_day) -> void:
	if not time_manager:
		return

	var total_minutes = int(time_manager.current_time_seconds / 60)
	var current_hour = int(total_minutes / 60) % 24
	var hours_to_advance = 0

	if is_next_day:
		hours_to_advance = (24 - current_hour) + target_hour
	else:
		if target_hour > current_hour:
			hours_to_advance = target_hour - current_hour

	for i in range(hours_to_advance):
		current_hour = (current_hour + 1) % 24
		if current_hour == 0:
			time_manager.advance_date()
		time_manager.current_time_seconds = float(current_hour * 3600)
		time_manager.last_hour = current_hour
		time_manager.hour_passed.emit()

	if TimeManager:
		TimeManager.emit_all_signals()
