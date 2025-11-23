extends CharacterBody2D

@export var walk_speed: float = 150.0
@export_range(0.0, 1.0, 0.01) var deceleration: float = 0.1

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var target_position: Vector2
var moving: bool = false
var last_facing: String = "down"

const STOP_EPS := 5.0

func _physics_process(delta: float) -> void:
	# Click para fijar destino
	if Input.is_action_just_pressed("click"):
		target_position = get_global_mouse_position()
		moving = true

	# Movimiento hacia el destino
	if moving:
		var dir := target_position - global_position
		var dist := dir.length()

		if dist > STOP_EPS:
			dir = dir.normalized()
			velocity = dir * walk_speed
		else:
			moving = false
			velocity = Vector2.ZERO
	else:
		# Frenado suave si no hay destino
		velocity = velocity.lerp(Vector2.ZERO, deceleration)

	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	var v := velocity

	if v.length() > STOP_EPS:
		var facing := last_facing

		# Escoge la componente dominante para la dirección
		if abs(v.x) > abs(v.y):
			facing = "right" if v.x > 0.0 else "left"
		else:
			facing = "down" if v.y > 0.0 else "up"

		anim.play("walk_%s" % facing)
		last_facing = facing
	else:
		anim.play("idle_%s" % last_facing)
