extends Control

func _ready() -> void:
	var logo = $TextureRect
	logo.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(logo, "modulate:a", 1.0, 1.5)
	tween.tween_interval(1.5)
	tween.tween_property(logo, "modulate:a", 0.0, 1.0)
	tween.tween_callback(change_scene)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		change_scene()
	elif event.is_action_pressed("ui_accept"):
		change_scene()

func change_scene() -> void:
	get_tree().change_scene_to_file("res://levels/main_menu.tscn")
