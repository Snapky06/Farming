extends CharacterBody2D

@export var speed := 100.0
@export var stop_distance := 4.0
@export var inventory_data: InventoryData
@onready var agent := $NavigationAgent2D
@onready var sprite := $AnimatedSprite2D
@onready var cam := $Camera2D
@onready var interaction_area: Area2D = $InteractionComponent
@onready var hold_timer: Timer = $PlayerHoldTimer

const TREE_SCENE = preload("res://interactable/trees/maple_tree.tscn")

var audio_player: AudioStreamPlayer2D
var impact_audio_player: AudioStreamPlayer2D 
var sfx_hit_tree: AudioStream
var sfx_hoe: AudioStream 
var sfx_swing: AudioStream 
var sfx_seeds: AudioStream 

var last_direction := Vector2.DOWN
signal toggle_inventory()

const DOUBLE_TAP_DELAY = 0.3
var tap_count = 0
var double_tap_timer = 0.0
var last_tap_position = Vector2.ZERO

var is_holding: bool = false
var equipped_item: ItemData = null
var equipped_slot_index: int = -1
var is_movement_locked: bool = false

var pending_tool_action_pos: Vector2 = Vector2.ZERO
var pending_tool_name: String = "" 
var pending_target_body: Node2D = null
var is_moving_to_interact: bool = false
const TOOL_REACH_DISTANCE = 40.0 

func _ready():
	agent.target_desired_distance = stop_distance
	agent.path_desired_distance = 2.0
	cam.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	impact_audio_player = AudioStreamPlayer2D.new()
	add_child(impact_audio_player)
	
	load_sounds()

func load_sounds():
	if FileAccess.file_exists("res://sounds/hit_tree.mp3"): sfx_hit_tree = load("res://sounds/hit_tree.mp3")
	if FileAccess.file_exists("res://sounds/hoe.mp3"): sfx_hoe = load("res://sounds/hoe.mp3")
	if FileAccess.file_exists("res://sounds/swing.mp3"): sfx_swing = load("res://sounds/swing.mp3")
	if FileAccess.file_exists("res://sounds/seeds.mp3"): sfx_seeds = load("res://sounds/seeds.mp3")

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
	if is_movement_locked and not sprite.is_playing():
		is_movement_locked = false
		
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
			execute_pending_action()

func update_walk_animation(direction: Vector2):
	sprite.flip_h = false
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0: sprite.play("walk_right")
		else:
			sprite.flip_h = true
			sprite.play("walk_right")
	else:
		sprite.play("walk_down" if direction.y > 0 else "walk_up")

func update_idle_animation(direction: Vector2):
	sprite.flip_h = false
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0: sprite.play("idle_right")
		else:
			sprite.flip_h = true
			sprite.play("idle_right")
	else:
		sprite.play("idle_down" if direction.y > 0 else "idle_up")

func interact() -> void:
	tap_count = 0
	double_tap_timer = 0.0
	var bodies = interaction_area.get_overlapping_bodies()
	if bodies.is_empty(): return

	var closest_body = null
	var min_dist = INF
	for body in bodies:
		if body.has_method("interact") and body != self:
			var dist = global_position.distance_squared_to(body.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_body = body
	if closest_body:
		closest_body.interact(self)

func _on_PlayerHoldTimer_timeout():
	if is_moving_to_interact: return
		
	if is_holding:
		tap_count = 0
		double_tap_timer = 0.0
		var mouse_pos = get_global_mouse_position()
		
		if not is_movement_locked and equipped_item:
			
			if equipped_item.name == "Hoe":
				if not get_parent().is_tile_farmable(mouse_pos): return
				if global_position.distance_to(mouse_pos) <= TOOL_REACH_DISTANCE:
					perform_tool_action(mouse_pos, "hoe")
				else:
					start_move_interact(mouse_pos, "hoe")
				return
			
			elif equipped_item.name == "Axe":
				var space_state = get_world_2d().direct_space_state
				var query = PhysicsPointQueryParameters2D.new()
				query.position = mouse_pos
				query.collide_with_bodies = true
				query.collide_with_areas = true
				query.collision_mask = 4 
				var results = space_state.intersect_point(query)
				
				if results.size() > 0:
					var collider = results[0].collider
					if collider.has_method("hit") and not collider.get("is_falling"):
						if global_position.distance_to(collider.global_position) <= TOOL_REACH_DISTANCE:
							start_axe_loop(collider)
						else:
							start_move_interact(collider.global_position, "axe", collider)
				return

			elif equipped_item.name == "Tree Seed" or equipped_item.name == "Tree Seeds":
				if get_parent().has_method("can_plant_seed"):
					if not get_parent().can_plant_seed(mouse_pos):
						return
				
				if global_position.distance_to(mouse_pos) <= TOOL_REACH_DISTANCE:
					perform_tool_action(mouse_pos, "planting")
				else:
					start_move_interact(mouse_pos, "planting")
				return

		interact()

func start_move_interact(pos, tool_name, target=null):
	if not is_movement_locked:
		is_moving_to_interact = true
		pending_tool_action_pos = pos
		pending_tool_name = tool_name
		pending_target_body = target
		agent.target_position = pos

func execute_pending_action():
	if pending_tool_name == "axe":
		if is_instance_valid(pending_target_body) and not pending_target_body.get("is_falling"):
			if global_position.distance_to(pending_target_body.global_position) <= TOOL_REACH_DISTANCE + 10.0:
				start_axe_loop(pending_target_body)
	else:
		if global_position.distance_to(pending_tool_action_pos) <= TOOL_REACH_DISTANCE + 10.0:
			perform_tool_action(pending_tool_action_pos, pending_tool_name)

func start_axe_loop(target_node):
	if is_movement_locked: return
	if target_node.get("is_falling"): return
	
	is_movement_locked = true
	velocity = Vector2.ZERO
	last_direction = (target_node.global_position - global_position).normalized()
	
	while is_holding and is_instance_valid(target_node):
		if target_node.get("is_falling"): break
			
		sprite.flip_h = false
		var anim = "axe_"
		if abs(last_direction.x) > abs(last_direction.y):
			if last_direction.x > 0: anim += "right"
			else:
				sprite.flip_h = true
				anim += "right"
		else:
			anim += "down" if last_direction.y > 0 else "up"
		
		if sfx_swing and audio_player:
			audio_player.stream = sfx_swing
			audio_player.play()
		
		sprite.play(anim)
		await sprite.animation_finished
		
		if not is_instance_valid(target_node) or target_node.get("is_falling"): break
		
		if sfx_hit_tree and impact_audio_player:
			impact_audio_player.stream = sfx_hit_tree
			impact_audio_player.play()
		
		if is_instance_valid(target_node) and target_node.has_method("hit"):
			target_node.hit(global_position)
			if target_node.get("health") <= 0: break

	is_movement_locked = false
	update_idle_animation(last_direction)

func perform_tool_action(target_pos: Vector2, tool_name: String) -> void:
	if global_position.distance_to(target_pos) > TOOL_REACH_DISTANCE + 10.0:
		is_movement_locked = false
		is_moving_to_interact = false
		return

	is_movement_locked = true
	velocity = Vector2.ZERO
	last_direction = (target_pos - global_position).normalized()
	sprite.flip_h = false
	
	var anim_name = tool_name + "_"
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0: anim_name += "right"
		else:
			sprite.flip_h = true
			anim_name += "right"
	else:
		anim_name += "down" if last_direction.y > 0 else "up"
	
	# Only play swing sound if NOT planting
	if tool_name != "planting":
		if sfx_swing and audio_player:
			audio_player.stream = sfx_swing
			audio_player.play()
	
	sprite.play(anim_name)
	
	# Wait for impact frame (usually frame 1)
	while sprite.is_playing() and sprite.frame < 1:
		await get_tree().process_frame
	
	if tool_name == "hoe" and get_parent().has_method("use_hoe"):
		if sfx_hoe and impact_audio_player:
			impact_audio_player.stream = sfx_hoe
			impact_audio_player.play()
		get_parent().use_hoe(target_pos)
		
		# Wait for the audio to finish before finishing action
		if impact_audio_player.playing:
			await impact_audio_player.finished
		
	elif tool_name == "planting":
		spawn_tree(target_pos)
	
	if sprite.is_playing():
		await sprite.animation_finished

	# Play seeds audio AFTER animation finishes for planting
	if tool_name == "planting":
		if sfx_seeds and audio_player:
			audio_player.stream = sfx_seeds
			audio_player.play()
			# Stop the sound after 0.5s to cut the tail
			get_tree().create_timer(0.5).timeout.connect(func(): if audio_player.stream == sfx_seeds: audio_player.stop())

	sprite.flip_h = false
	is_movement_locked = false
	update_idle_animation(last_direction)

func find_tree_script(node: Node):
	if node.has_method("setup_as_seed"):
		return node
	for child in node.get_children():
		if child.has_method("setup_as_seed"):
			return child
	return null

func spawn_tree(pos: Vector2):
	if equipped_slot_index == -1 or not inventory_data: return

	var snapped_pos = pos
	if get_parent().has_method("get_tile_center_position"):
		snapped_pos = get_parent().get_tile_center_position(pos)

	var tree = TREE_SCENE.instantiate()
	get_parent().add_child(tree)
	tree.global_position = snapped_pos
	
	tree.modulate.a = 0.0
	var t = get_tree().create_tween()
	# Increased fade duration from 2.0 to 4.0
	t.tween_property(tree, "modulate:a", 1.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var script_node = find_tree_script(tree)
	if script_node:
		script_node.setup_as_seed()
	else:
		print("Error: No tree script found on spawned object")

	var slot = inventory_data.slot_datas[equipped_slot_index]
	if slot and slot.item_data == equipped_item:
		slot.quantity -= 1
		if slot.quantity <= 0:
			inventory_data.slot_datas[equipped_slot_index] = null
			equipped_item = null
			
			if get_parent().has_method("refresh_tile_selector"):
				get_parent().refresh_tile_selector()
		
		if inventory_data.has_signal("inventory_updated"):
			inventory_data.inventory_updated.emit(inventory_data)

func update_equipped_item(index: int) -> void:
	reset_states()
	equipped_slot_index = index
	
	is_movement_locked = false
	
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
