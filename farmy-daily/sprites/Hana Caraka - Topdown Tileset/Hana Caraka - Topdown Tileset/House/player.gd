extends CharacterBody2D

@export var speed := 100.0
@export var stop_distance := 4.0
@export var inventory_data: InventoryData
@onready var agent := $NavigationAgent2D
@onready var sprite := $AnimatedSprite2D
@onready var cam := $Camera2D
@onready var interaction_area: Area2D = $InteractionComponent
@onready var hold_timer: Timer = $PlayerHoldTimer

const TREE_SCENES = [
	preload("res://interactable/trees/maple_tree.tscn"),
	preload("res://interactable/trees/pine_tree.tscn"),
	preload("res://interactable/trees/birch_tree.tscn"),
	preload("res://interactable/trees/spruce_tree.tscn")
]

const CROP_SCENE = preload("res://interactable/Crops/carrot.tscn")

var audio_player: AudioStreamPlayer2D
var impact_audio_player: AudioStreamPlayer2D 
var sfx_hit_tree: AudioStream
var sfx_hoe: AudioStream 
var sfx_swing: AudioStream 
var sfx_seeds: AudioStream 
var sfx_water: AudioStream 

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
	z_index = 1
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
	if FileAccess.file_exists("res://sounds/water.mp3"): sfx_water = load("res://sounds/water.mp3")

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
		pass 
		
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
			
			elif equipped_item.name == "Watering Can":
				if get_parent().has_method("is_tile_waterable"):
					if not get_parent().is_tile_waterable(mouse_pos): return
				
				if global_position.distance_to(mouse_pos) <= TOOL_REACH_DISTANCE:
					perform_tool_action(mouse_pos, "watering")
				else:
					start_move_interact(mouse_pos, "watering")
				return

			elif equipped_item.name == "Sickle" or equipped_item.name == "Scythe":
				var space_state = get_world_2d().direct_space_state
				var query = PhysicsPointQueryParameters2D.new()
				query.position = mouse_pos
				query.collide_with_bodies = true
				query.collide_with_areas = true
				var results = space_state.intersect_point(query)
				
				for result in results:
					var collider = result.collider
					if collider.has_method("harvest"):
						# Only harvest if fully grown
						if "current_stage" in collider and "max_stage" in collider:
							if collider.current_stage >= collider.max_stage:
								if global_position.distance_to(mouse_pos) <= TOOL_REACH_DISTANCE:
									perform_tool_action(mouse_pos, "sickle")
								else:
									start_move_interact(mouse_pos, "sickle")
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
			
			elif "Seeds" in equipped_item.name:
				if get_parent().has_method("can_plant_crop"):
					if not get_parent().can_plant_crop(mouse_pos):
						return
				
				if global_position.distance_to(mouse_pos) <= TOOL_REACH_DISTANCE:
					perform_tool_action(mouse_pos, "planting_crop")
				else:
					start_move_interact(mouse_pos, "planting_crop")
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
	pending_tool_action_pos = target_pos 
	velocity = Vector2.ZERO
	last_direction = (target_pos - global_position).normalized()
	sprite.flip_h = false
	
	var anim_base = tool_name
	if tool_name == "planting_crop":
		anim_base = "planting"
		
	var anim_name = anim_base + "_"
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0: anim_name += "right"
		else:
			sprite.flip_h = true
			anim_name += "right"
	else:
		anim_name += "down" if last_direction.y > 0 else "up"
	
	if tool_name == "watering":
		if sfx_water and audio_player:
			audio_player.stream = sfx_water
			audio_player.play()
	elif tool_name != "planting" and tool_name != "planting_crop" and sfx_swing and audio_player:
		audio_player.stream = sfx_swing
		audio_player.play()
	
	var has_anim = sprite.sprite_frames.has_animation(anim_name)
	if has_anim:
		sprite.play(anim_name)
		while sprite.is_playing() and sprite.frame < 1:
			await get_tree().process_frame
	else:
		await get_tree().create_timer(0.3).timeout
	
	if tool_name == "hoe" and get_parent().has_method("use_hoe"):
		if sfx_hoe and impact_audio_player:
			impact_audio_player.stream = sfx_hoe
			impact_audio_player.play()
		get_parent().use_hoe(target_pos)
		if impact_audio_player.playing: await impact_audio_player.finished
		
	elif tool_name == "watering":
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = target_pos
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var results = space_state.intersect_point(query)
		for result in results:
			if result.collider.has_method("water"):
				result.collider.water()

		if get_parent().has_method("use_water"):
			get_parent().use_water(target_pos)
	
	elif tool_name == "sickle":
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = target_pos
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var results = space_state.intersect_point(query)
		for result in results:
			if result.collider.has_method("harvest"):
				# Double check it is ready to harvest
				if "current_stage" in result.collider and "max_stage" in result.collider:
					if result.collider.current_stage >= result.collider.max_stage:
						result.collider.harvest()
		
	elif tool_name == "planting":
		spawn_tree(target_pos)
		play_seed_sound()
		
	elif tool_name == "planting_crop":
		spawn_crop(target_pos)
		play_seed_sound()
	
	if has_anim and sprite.is_playing():
		await sprite.animation_finished
	elif tool_name == "watering":
		await get_tree().create_timer(0.5).timeout

	if tool_name == "watering" and audio_player:
		audio_player.stop()

	sprite.flip_h = false
	is_movement_locked = false
	update_idle_animation(last_direction)

func play_seed_sound():
	if sfx_seeds and audio_player:
		audio_player.stream = sfx_seeds
		audio_player.play()
		get_tree().create_timer(0.5).timeout.connect(func(): if audio_player.stream == sfx_seeds: audio_player.stop())

func find_tree_script(node: Node):
	if node.has_method("setup_as_seed"):
		return node
	for child in node.get_children():
		if child.has_method("setup_as_seed"):
			return child
	return null

func spawn_tree(pos: Vector2):
	if equipped_slot_index == -1 or not inventory_data: return

	if get_parent().has_method("get_tile_center_position"):
		var snap_pos = get_parent().get_tile_center_position(pos)
		var random_tree_scene = TREE_SCENES.pick_random()
		var tree = random_tree_scene.instantiate()
		tree.global_position = snap_pos

		var script_node = find_tree_script(tree)
		if script_node:
			script_node.setup_as_seed()
		
		get_parent().add_child(tree)
		
		tree.modulate.a = 0.0
		var t = get_tree().create_tween()
		t.tween_property(tree, "modulate:a", 1.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		consume_equipped_item()

func spawn_crop(pos: Vector2):
	if equipped_slot_index == -1 or not inventory_data: return
	
	if get_parent().has_method("get_tile_center_position"):
		var snap_pos = get_parent().get_tile_center_position(pos)
		var crop = CROP_SCENE.instantiate()
		crop.global_position = snap_pos
		
		get_parent().add_child(crop)
		consume_equipped_item()

func consume_equipped_item():
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
