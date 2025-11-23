extends CharacterBody2D

@export var speed := 100.0
@export var stop_distance := 4.0
@export var inventory_data: InventoryData
@onready var agent := $NavigationAgent2D
@onready var sprite := $AnimatedSprite2D
@onready var cam := $Camera2D
@onready var interaction_area: Area2D = $InteractionComponent
@onready var hold_timer: Timer = $PlayerHoldTimer

var last_direction := Vector2.DOWN
signal toggle_inventory()

const DOUBLE_TAP_DELAY = 0.3
var tap_count = 0
var double_tap_timer = 0.0
var last_tap_position = Vector2.ZERO

var is_holding: bool = false
var equipped_item: ItemData = null
var is_movement_locked: bool = false

var pending_tool_action_pos: Vector2 = Vector2.ZERO
var is_moving_to_interact: bool = false
const TOOL_REACH_DISTANCE = 40.0 

func _ready():
	agent.target_desired_distance = stop_distance
	agent.path_desired_distance = 2.0
	cam.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func reset_states():
	is_moving_to_interact = false
	is_holding = false
	tap_count = 0
	velocity = Vector2.ZERO
	hold_timer.stop()
	update_idle_animation(last_direction)

func _unhandled_input(event):
	if Input.is_action_just_pressed("use"):
		interact()
	
	if Input.is_action_just_pressed("inventory"):
		reset_states()
		toggle_inventory.emit()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			is_moving_to_interact = false 
			
			is_holding = true
			hold_timer.start()
			
			tap_count += 1
			last_tap_position = get_global_mouse_position() 
			
			if tap_count == 1:
				double_tap_timer = DOUBLE_TAP_DELAY
			elif tap_count == 2:
				reset_states()
				toggle_inventory.emit()
				tap_count = 0
				double_tap_timer = 0.0
		else:
			is_holding = false
			hold_timer.stop()

func _physics_process(_delta):
	if double_tap_timer > 0.0:
		double_tap_timer -= _delta
		if double_tap_timer <= 0.0:
			if not is_holding and tap_count > 0:
				if not is_movement_locked:
					agent.target_position = last_tap_position
					is_moving_to_interact = false
			tap_count = 0
	
	if is_movement_locked:
		return

	if not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		if get_slide_collision_count() > 0:
			agent.target_position = global_position
			velocity = Vector2.ZERO
		
		update_walk_animation(direction)
		last_direction = direction
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		update_idle_animation(last_direction)
		
		if is_moving_to_interact:
			is_moving_to_interact = false
			perform_tool_action(pending_tool_action_pos)

func update_walk_animation(direction: Vector2):
	sprite.flip_h = false
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			sprite.play("walk_right")
		else:
			sprite.flip_h = true
			sprite.play("walk_right")
	else:
		sprite.play("walk_down" if direction.y > 0 else "walk_up")

func update_idle_animation(direction: Vector2):
	sprite.flip_h = false
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			sprite.play("idle_right")
		else:
			sprite.flip_h = true
			sprite.play("idle_right")
	else:
		sprite.play("idle_down" if direction.y > 0 else "idle_up")

func interact() -> void:
	tap_count = 0
	double_tap_timer = 0.0
	
	var bodies = interaction_area.get_overlapping_bodies()
	if bodies.is_empty():
		return

	var closest_body = null
	var min_dist = INF

	for body in bodies:
		if body.has_method("interact") and body != self:
			var dist = global_position.distance_squared_to(body.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_body = body
	
	if closest_body:
		closest_body.interact()

func _on_PlayerHoldTimer_timeout():
	if is_holding:
		is_holding = false
		tap_count = 0
		double_tap_timer = 0.0
		
		var mouse_pos = get_global_mouse_position()
		
		if not is_movement_locked and equipped_item and equipped_item.name == "Hoe":
			if not get_parent().is_tile_farmable(mouse_pos):
				return
			
			var dist = global_position.distance_to(mouse_pos)
			
			pending_tool_action_pos = mouse_pos
			
			if dist <= TOOL_REACH_DISTANCE:
				perform_tool_action(mouse_pos)
			else:
				if not is_movement_locked:
					is_moving_to_interact = true
					agent.target_position = mouse_pos
			return
		
		interact()

func perform_tool_action(target_pos: Vector2) -> void:
	if global_position.distance_to(target_pos) > TOOL_REACH_DISTANCE + 10.0:
		is_movement_locked = false
		is_moving_to_interact = false
		return

	is_movement_locked = true
	velocity = Vector2.ZERO
	
	pending_tool_action_pos = target_pos
	
	var direction_to_target = (target_pos - global_position).normalized()
	last_direction = direction_to_target
	
	sprite.flip_h = false
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			sprite.play("hoe_right")
		else:
			sprite.flip_h = true
			sprite.play("hoe_right")
	else:
		if last_direction.y > 0:
			sprite.play("hoe_down")
		else:
			sprite.play("hoe_up")
	
	await sprite.animation_finished
	sprite.flip_h = false
	
	if get_parent().has_method("use_hoe"):
		get_parent().use_hoe(target_pos)
	
	is_movement_locked = false
	update_idle_animation(last_direction)

func update_equipped_item(index: int) -> void:
	reset_states()
	
	if index == -1:
		equipped_item = null
		return
	
	if index < inventory_data.slot_datas.size():
		var slot_data = inventory_data.slot_datas[index]
		if slot_data:
			equipped_item = slot_data.item_data
		else:
			equipped_item = null
	else:
		equipped_item = null
