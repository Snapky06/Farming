extends CharacterBody2D

@export var speed := 100.0
@export var stop_distance := 4.0
@export var inventory_data: InventoryData

@onready var agent := $NavigationAgent2D
@onready var sprite := $AnimatedSprite2D
@onready var cam := $Camera2D
@onready var interaction_area: Area2D = $InteractionComponent
@onready var hold_timer: Timer = $PlayerHoldTimer

var money: int = 100

signal money_updated(new_amount)
signal toggle_inventory()

const TREE_SCENES = [
	preload("res://interactable/trees/maple_tree.tscn"),
	preload("res://interactable/trees/pine_tree.tscn"),
	preload("res://interactable/trees/birch_tree.tscn"),
	preload("res://interactable/trees/spruce_tree.tscn")
]

var audio_player: AudioStreamPlayer2D
var impact_audio_player: AudioStreamPlayer2D

var sfx_hit_tree: AudioStream
var sfx_hit_rock: AudioStream
var sfx_hoe: AudioStream
var sfx_swing: AudioStream
var sfx_seeds: AudioStream
var sfx_water: AudioStream

var last_direction := Vector2.DOWN

const DOUBLE_TAP_DELAY_MS = 300
const LONG_PRESS_DURATION = 0.3
var last_tap_time = 0
var is_touching = false
var touch_start_time = 0.0
var has_acted_this_touch = false
var tap_count = 0

var is_holding: bool = false
var equipped_item: ItemData = null
var equipped_slot_index: int = -1
var is_movement_locked: bool = false

var pending_tool_action_pos: Vector2 = Vector2.ZERO
var pending_tool_name: String = ""
var pending_target_body: Node2D = null
var pending_impact_sound: AudioStream = null
var is_moving_to_interact: bool = false
const TOOL_REACH_DISTANCE = 50.0

func _ready() -> void:
	z_index = 1
	agent.target_desired_distance = stop_distance
	agent.path_desired_distance = 2.0
	
	if cam:
		cam.enabled = true
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 5.0
		cam.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	impact_audio_player = AudioStreamPlayer2D.new()
	add_child(impact_audio_player)
	
	load_sounds()
	emit_signal("money_updated", money)

func update_money(amount: int) -> void:
	money += amount
	emit_signal("money_updated", money)

func load_sounds():
	if FileAccess.file_exists("res://sounds/hit_tree.mp3"): sfx_hit_tree = load("res://sounds/hit_tree.mp3")
	if FileAccess.file_exists("res://sounds/hit_rock.mp3"): sfx_hit_rock = load("res://sounds/hit_rock.mp3")
	elif FileAccess.file_exists("res://sounds/pickaxe.mp3"): sfx_hit_rock = load("res://sounds/pickaxe.mp3")
	
	if FileAccess.file_exists("res://sounds/hoe.mp3"): sfx_hoe = load("res://sounds/hoe.mp3")
	if FileAccess.file_exists("res://sounds/swing.mp3"): sfx_swing = load("res://sounds/swing.mp3")
	if FileAccess.file_exists("res://sounds/seeds.mp3"): sfx_seeds = load("res://sounds/seeds.mp3")
	if FileAccess.file_exists("res://sounds/water.mp3"): sfx_water = load("res://sounds/water.mp3")

func reset_states():
	is_moving_to_interact = false
	is_holding = false
	is_touching = false
	tap_count = 0
	velocity = Vector2.ZERO
	hold_timer.stop()
	update_idle_animation(last_direction)

func _unhandled_input(event):
	if Input.is_action_just_pressed("use"):
		attempt_action_at(get_global_mouse_position())
	if Input.is_action_just_pressed("inventory"):
		reset_states()
		toggle_inventory.emit()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_touching = true
			touch_start_time = Time.get_ticks_msec() / 1000.0
			has_acted_this_touch = false
			
			var current_time = Time.get_ticks_msec()
			if current_time - last_tap_time < DOUBLE_TAP_DELAY_MS:
				reset_states()
				toggle_inventory.emit()
				tap_count = 0
			else:
				tap_count = 1
			last_tap_time = current_time
			
		else:
			var press_duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time
			is_touching = false
			is_holding = false
			
			if press_duration < LONG_PRESS_DURATION and not has_acted_this_touch:
				if not is_movement_locked:
					is_moving_to_interact = false
					agent.target_position = get_global_mouse_position()

func _process(_delta):
	if is_touching and not has_acted_this_touch and not is_movement_locked:
		var duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time
		if duration >= LONG_PRESS_DURATION:
			has_acted_this_touch = true
			is_holding = true
			attempt_action_at(get_global_mouse_position())

func attempt_action_at(mouse_pos: Vector2):
	if not equipped_item:
		interact()
		return

	if equipped_item.name == "Hoe":
		if get_parent().has_method("is_tile_farmable") and not get_parent().is_tile_farmable(mouse_pos): return
		check_reach_and_act(mouse_pos, "hoe")
		
	elif equipped_item.name == "Watering Can":
		if get_parent().has_method("is_tile_waterable") and not get_parent().is_tile_waterable(mouse_pos): return
		check_reach_and_act(mouse_pos, "watering")

	elif equipped_item.name == "Scythe":
		check_reach_and_act(mouse_pos, "scythe")
	
	elif equipped_item.name == "Axe" or equipped_item.name == "Pickaxe":
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.collision_mask = 4
		var results = space_state.intersect_point(query)
		
		if results.size() > 0:
			var collider = results[0].collider
			if collider.has_method("hit"):
				var is_falling = false
				if "is_falling" in collider and collider.is_falling:
					is_falling = true
				
				if not is_falling:
					var tool_anim = "axe"
					var tool_sound = sfx_hit_tree
					
					if collider.is_in_group("rock") or "Rock" in collider.name or "Stone" in collider.name:
						tool_anim = "pickaxe"
						tool_sound = sfx_hit_rock
					
					if global_position.distance_to(collider.global_position) <= TOOL_REACH_DISTANCE:
						start_tool_loop(collider, tool_anim, tool_sound)
					else:
						start_move_interact(collider.global_position, tool_anim, collider, tool_sound)
		return

	elif "Tree Seed" in equipped_item.name:
		if get_parent().has_method("can_plant_seed") and not get_parent().can_plant_seed(mouse_pos): return
		check_reach_and_act(mouse_pos, "planting")
	
	elif "Seeds" in equipped_item.name:
		if get_parent().has_method("can_plant_seed") and not get_parent().can_plant_seed(mouse_pos): return
		check_reach_and_act(mouse_pos, "planting_crop")
	
	else:
		interact()

func check_reach_and_act(target_pos: Vector2, tool_name: String):
	if global_position.distance_to(target_pos) <= TOOL_REACH_DISTANCE:
		perform_tool_action(target_pos, tool_name)
	else:
		start_move_interact(target_pos, tool_name)

func _physics_process(_delta):
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
	var candidates = []
	candidates.append_array(interaction_area.get_overlapping_bodies())
	candidates.append_array(interaction_area.get_overlapping_areas())
	
	if candidates.is_empty(): return

	var closest_node = null
	var min_dist = INF
	for node in candidates:
		if node.has_method("interact") and node != self:
			var dist = global_position.distance_squared_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_node = node
				
	if closest_node:
		closest_node.interact(self)

func start_move_interact(pos, tool_name, target=null, impact_sound=null):
	if not is_movement_locked:
		is_moving_to_interact = true
		pending_tool_action_pos = pos
		pending_tool_name = tool_name
		pending_target_body = target
		pending_impact_sound = impact_sound
		agent.target_position = pos

func execute_pending_action():
	if pending_tool_name == "axe" or pending_tool_name == "pickaxe":
		var is_target_valid = is_instance_valid(pending_target_body)
		if is_target_valid and "is_falling" in pending_target_body and pending_target_body.is_falling:
			is_target_valid = false
			
		if is_target_valid:
			if global_position.distance_to(pending_target_body.global_position) <= TOOL_REACH_DISTANCE + 10.0:
				start_tool_loop(pending_target_body, pending_tool_name, pending_impact_sound)
	else:
		if global_position.distance_to(pending_tool_action_pos) <= TOOL_REACH_DISTANCE + 10.0:
			perform_tool_action(pending_tool_action_pos, pending_tool_name)

func start_tool_loop(target_node, tool_anim_name, impact_sfx=null):
	if is_movement_locked: return
	if "is_falling" in target_node and target_node.is_falling: return
	
	is_movement_locked = true
	velocity = Vector2.ZERO
	last_direction = (target_node.global_position - global_position).normalized()
	
	while is_touching and is_instance_valid(target_node):
		if "is_falling" in target_node and target_node.is_falling: break
		
		sprite.flip_h = false
		var anim = tool_anim_name + "_"
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
		
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			await sprite.animation_finished
		else:
			await get_tree().create_timer(0.25).timeout
		
		if not is_instance_valid(target_node): break
		if "is_falling" in target_node and target_node.is_falling: break
		
		if impact_sfx and impact_audio_player:
			impact_audio_player.stream = impact_sfx
			impact_audio_player.play()
		
		if is_instance_valid(target_node) and target_node.has_method("hit"):
			target_node.hit(1)
			if "health" in target_node and target_node.health <= 0:
				break

	is_movement_locked = false
	update_idle_animation(last_direction)

func perform_tool_action(target_pos: Vector2, tool_name: String) -> void:
	if global_position.distance_to(target_pos) > TOOL_REACH_DISTANCE + 20.0:
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
	
	var has_anim = sprite.sprite_frames.has_animation(anim_name)
	if has_anim:
		sprite.play(anim_name)
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.25).timeout
	
	if tool_name == "hoe" and get_parent().has_method("use_hoe"):
		if sfx_hoe and impact_audio_player:
			impact_audio_player.stream = sfx_hoe
			impact_audio_player.play()
		get_parent().use_hoe(target_pos)
		
	elif tool_name == "watering":
		if sfx_water and audio_player:
			audio_player.stream = sfx_water
			audio_player.play()
			
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
	
	elif tool_name == "scythe":
		if sfx_swing and audio_player:
			audio_player.stream = sfx_swing
			audio_player.play()
			
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = target_pos
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var results = space_state.intersect_point(query)
		for result in results:
			if result.collider.has_method("harvest"):
				if "current_stage" in result.collider and "max_stage" in result.collider:
					if result.collider.current_stage >= result.collider.max_stage:
						result.collider.harvest()
		
	elif tool_name == "planting":
		spawn_tree(target_pos)
		play_seed_sound()
		
	elif tool_name == "planting_crop":
		spawn_crop(target_pos)
		play_seed_sound()
	
	if tool_name == "watering" and audio_player:
		await get_tree().create_timer(0.1).timeout
		if audio_player.stream == sfx_water: audio_player.stop()

	sprite.flip_h = false
	is_movement_locked = false
	update_idle_animation(last_direction)

func play_seed_sound():
	if sfx_seeds and audio_player:
		audio_player.stream = sfx_seeds
		audio_player.play()

func find_tree_script(node: Node):
	if node.has_method("setup_as_seed"):
		return node
	for child in node.get_children():
		var found = find_tree_script(child)
		if found: return found
	return null

func spawn_tree(pos: Vector2):
	if equipped_slot_index == -1 or not inventory_data: return

	if get_parent().has_method("get_tile_center_position"):
		var snap_pos = get_parent().get_tile_center_position(pos)
		
		var tree_scene = null
		if equipped_item.crop_scene_path != "":
			tree_scene = load(equipped_item.crop_scene_path)
		
		if not tree_scene:
			tree_scene = TREE_SCENES.pick_random()
			
		if tree_scene:
			var tree = tree_scene.instantiate()
			tree.global_position = snap_pos
			
			if "tree_sort_index" in get_parent():
				tree.z_index = get_parent().tree_sort_index
				get_parent().tree_sort_index += 1
			else:
				tree.z_index = 10

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
	
	if equipped_item.crop_scene_path == "":
		print("No crop scene path assigned to this item!")
		return
	
	if get_parent().has_method("get_tile_center_position"):
		var snap_pos = get_parent().get_tile_center_position(pos)
		
		var crop_scene = load(equipped_item.crop_scene_path)
		if crop_scene:
			var crop = crop_scene.instantiate()
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
