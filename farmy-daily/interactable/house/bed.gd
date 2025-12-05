extends Area2D

@onready var time_manager: Node = get_node("/root/TimeManager")
@onready var sleep_marker: Node2D = get_parent().get_node_or_null("sleep")

var is_sleeping: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true

func interact(user = null) -> void:
	if time_manager == null:
		return

	var player = user
	if player == null:
		player = _find_player()
	if player == null:
		return

	var current_hour := int(time_manager.current_time_seconds / 3600.0) % 24

	if current_hour >= 2 and current_hour < 19:
		return

	var target_hour := 6
	var is_next_day := current_hour >= 19

	_start_sleep(player, target_hour, is_next_day)

func _find_player():
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("Player", true, false)

func _start_sleep(player, target_hour: int, is_next_day: bool) -> void:
	if is_sleeping:
		return

	is_sleeping = true

	if "is_movement_locked" in player:
		player.is_movement_locked = true
	if "velocity" in player:
		player.velocity = Vector2.ZERO

	var bed_position: Vector2 = get_parent().global_position

	var direction: Vector2 = (bed_position - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	var anim_name := "sleep_down"
	var flip_h := false

	if abs(direction.x) > abs(direction.y):
		anim_name = "sleep_right"
		if direction.x < 0:
			flip_h = true
	else:
		if direction.y > 0:
			anim_name = "sleep_down"
		else:
			anim_name = "sleep_up"

	var transition_rect = _get_transition_rect()

	if sprite:
		sprite.flip_h = flip_h
		sprite.play(anim_name)
		await sprite.animation_finished

	if transition_rect:
		var t = create_tween()
		t.tween_property(transition_rect, "modulate:a", 1.0, 0.5)
		await t.finished

	_advance_time_to(target_hour, is_next_day)

	player.global_position = bed_position
	if player.has_method("update_idle_animation"):
		player.update_idle_animation(Vector2.DOWN)
	if "is_movement_locked" in player:
		player.is_movement_locked = false

	if transition_rect:
		var t2 = create_tween()
		t2.tween_property(transition_rect, "modulate:a", 0.0, 1.0)
		await t2.finished

	is_sleeping = false

func _advance_time_to(target_hour: int, is_next_day: bool) -> void:
	if time_manager == null:
		return

	var current_hour := int(time_manager.current_time_seconds / 3600.0) % 24
	var hours_to_advance := 0

	if is_next_day:
		hours_to_advance = (24 - current_hour) + target_hour
	else:
		if target_hour > current_hour:
			hours_to_advance = target_hour - current_hour

	for i in range(hours_to_advance):
		current_hour = (current_hour + 1) % 24
		if current_hour == 0:
			time_manager.advance_date()
		time_manager.current_time_seconds = float(current_hour) * 3600.0
		time_manager.last_hour = current_hour
		time_manager.hour_passed.emit()

	if time_manager.has_method("emit_all_signals"):
		time_manager.emit_all_signals()

func _get_transition_rect():
	var scene := get_tree().current_scene
	if scene == null:
		return null

	for child in scene.get_children():
		if child is CanvasLayer and child.layer == 100:
			for grand in child.get_children():
				if grand is ColorRect:
					return grand

	return null
