extends CharacterBody2D

@export var speed: float = 100.0
@export var stop_distance: float = 4.0
@export var inventory_data: Resource

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var cam: Camera2D = $Camera2D
@onready var interaction_area: Area2D = $InteractionComponent
@onready var hold_timer: Timer = $PlayerHoldTimer
@onready var time_manager: Node = get_node("/root/TimeManager")

var money: int = 100

signal money_updated(new_amount)
signal toggle_inventory()

const TREE_SCENES: Array[PackedScene] = [
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

var last_direction: Vector2 = Vector2.DOWN

const DOUBLE_TAP_DELAY_MS: int = 300
const LONG_PRESS_DURATION: float = 0.3
var last_tap_time: int = 0
var is_touching: bool = false
var touch_start_time: float = 0.0
var has_acted_this_touch: bool = false
var tap_count: int = 0

var click_timer: Timer
var pending_click_position: Vector2 = Vector2.ZERO

var is_holding: bool = false
var equipped_item: Resource = null
var equipped_slot_index: int = -1
var is_movement_locked: bool = false

var pending_tool_action_pos: Vector2 = Vector2.ZERO
var pending_tool_name: String = ""
var pending_target_body: Node2D = null
var pending_impact_sound: AudioStream = null
var is_moving_to_interact: bool = false
const TOOL_REACH_DISTANCE: float = 50.0

var stuck_timer: float = 0.0
var axe_hit_damage: int = 1

func _ready() -> void:
	z_index = 1
	agent.target_desired_distance = stop_distance
	agent.path_desired_distance = 4.0
	agent.path_max_distance = 20.0
	
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
	
	click_timer = Timer.new()
	click_timer.one_shot = true
	click_timer.timeout.connect(_on_click_timer_timeout)
	add_child(click_timer)
	
	load_sounds()
	emit_signal("money_updated", money)

func update_money(amount: int) -> void:
	money += amount
	emit_signal("money_updated", money)

func load_sounds() -> void:
	if FileAccess.file_exists("res://sounds/hit_tree.mp3"): sfx_hit_tree = load("res://sounds/hit_tree.mp3")
	if FileAccess.file_exists("res://sounds/hit_rock.mp3"): sfx_hit_rock = load("res://sounds/hit_rock.mp3")
	elif FileAccess.file_exists("res://sounds/pickaxe.mp3"): sfx_hit_rock = load("res://sounds/pickaxe.mp3")
	
	if FileAccess.file_exists("res://sounds/hoe.mp3"): sfx_hoe = load("res://sounds/hoe.mp3")
	if FileAccess.file_exists("res://sounds/swing.mp3"): sfx_swing = load("res://sounds/swing.mp3")
	if FileAccess.file_exists("res://sounds/seeds.mp3"): sfx_seeds = load("res://sounds/seeds.mp3")
	if FileAccess.file_exists("res://sounds/water.mp3"): sfx_water = load("res://sounds/water.mp3")

func reset_states() -> void:
	if click_timer: click_timer.stop()
	is_moving_to_interact = false
	is_holding = false
	is_touching = false
	tap_count = 0
	velocity = Vector2.ZERO
	stuck_timer = 0.0
	hold_timer.stop()
	update_idle_animation(last_direction)

func _unhandled_input(event: InputEvent) -> void:
	if is_movement_locked:
		return

	if Input.is_action_just_pressed("inventory"):
		reset_states()
		toggle_inventory.emit()
		get_viewport().set_input_as_handled()
		return
	
	if Input.is_action_just_pressed("use"):
		attempt_action_at(get_global_mouse_position())
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var current_time: int = Time.get_ticks_msec()
			if current_time - last_tap_time < DOUBLE_TAP_DELAY_MS:
				click_timer.stop()
				reset_states()
				toggle_inventory.emit()
				tap_count = 0
				last_tap_time = current_time
				return
			else:
				tap_count = 1
			last_tap_time = current_time

			if not is_movement_locked:
				is_touching = true
				touch_start_time = Time.get_ticks_msec() / 1000.0
				has_acted_this_touch = false
			
		else:
			var press_duration: float = (Time.get_ticks_msec() / 1000.0) - touch_start_time
			is_touching = false
			is_holding = false
			
			if press_duration < LONG_PRESS_DURATION and not has_acted_this_touch:
				if not is_movement_locked:
					pending_click_position = get_global_mouse_position()
					
					var time_since_press = Time.get_ticks_msec() - last_tap_time
					var remaining_wait_time = float(DOUBLE_TAP_DELAY_MS) - float(time_since_press)
					
					var wait_time = max(0.05, remaining_wait_time / 1000.0)
					click_timer.start(wait_time)

func _on_click_timer_timeout() -> void:
	if not is_movement_locked:
		is_moving_to_interact = false
		stuck_timer = 0.0
		agent.target_position = pending_click_position

func _process(_delta: float) -> void:
	if is_touching and not has_acted_this_touch and not is_movement_locked:
		var duration: float = (Time.get_ticks_msec() / 1000.0) - touch_start_time
		if duration >= LONG_PRESS_DURATION:
			has_acted_this_touch = true
			is_holding = true
			attempt_action_at(get_global_mouse_position())

func attempt_action_at(mouse_pos: Vector2) -> void:
	if not equipped_item:
		interact()
		return

	var item_name: String = equipped_item.get("name") if equipped_item else ""

	if item_name == "Hoe":
		if time_manager and time_manager.get("current_energy") <= 0: return
		if get_parent().has_method("is_tile_farmable") and not get_parent().call("is_tile_farmable", mouse_pos): return
		check_reach_and_act(mouse_pos, "hoe")
		
	elif item_name == "Watering Can":
		if time_manager and time_manager.get("current_energy") <= 0: return
		if get_parent().has_method("is_tile_waterable") and not get_parent().call("is_tile_waterable", mouse_pos): return
		check_reach_and_act(mouse_pos, "watering")

	elif item_name == "Scythe":
		if time_manager and time_manager.get("current_energy") <= 0: return
		check_reach_and_act(mouse_pos, "scythe")
	
	elif "Axe" in item_name or "axe" in item_name or item_name == "Pickaxe":
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.collision_mask = 4
		var results: Array[Dictionary] = space_state.intersect_point(query)
		
		if results.size() > 0:
			var collider: Node2D = results[0].collider
			if collider.has_method("hit"):
				var is_falling: bool = false
				if "is_falling" in collider and collider.is_falling:
					is_falling = true
				
				if not is_falling:
					var is_rock: bool = collider.is_in_group("rock") or "Rock" in collider.name or "Stone" in collider.name
					var is_stump: bool = false
					if "is_stump" in collider: is_stump = collider.is_stump
					
					var can_use: bool = false
					
					if item_name == "Pickaxe":
						if is_rock: can_use = true
					elif item_name == "Magical Axe" or item_name == "magical_axe":
						can_use = true
					elif item_name == "Sharpened Axe" or item_name == "sharpened_axe":
						if not is_rock: can_use = true
					else:
						if not is_rock and not is_stump: can_use = true
					
					if not can_use: return

					if time_manager and time_manager.get("current_energy") <= 0: return
					var tool_anim: String = "axe"
					var tool_sound: AudioStream = sfx_hit_tree
					
					if is_rock:
						tool_anim = "pickaxe"
						tool_sound = sfx_hit_rock
					
					if global_position.distance_to(collider.global_position) <= TOOL_REACH_DISTANCE:
						start_tool_loop(collider, tool_anim, tool_sound)
					else:
						start_move_interact(collider.global_position, tool_anim, collider, tool_sound)
		return

	elif "Tree Seed" in item_name:
		if get_parent().has_method("can_plant_seed") and not get_parent().call("can_plant_seed", mouse_pos): return
		check_reach_and_act(mouse_pos, "planting")
	
	elif "Seeds" in item_name:
		if get_parent().has_method("can_plant_seed") and not get_parent().call("can_plant_seed", mouse_pos): return
		check_reach_and_act(mouse_pos, "planting_crop")
	
	else:
		interact()

func check_reach_and_act(target_pos: Vector2, tool_name: String) -> void:
	if global_position.distance_to(target_pos) <= TOOL_REACH_DISTANCE:
		perform_tool_action(target_pos, tool_name)
	else:
		start_move_interact(target_pos, tool_name)

func _physics_process(delta: float) -> void:
	if is_movement_locked:
		return

	if not agent.is_navigation_finished():
		var next_pos: Vector2 = agent.get_next_path_position()
		var direction: Vector2 = (next_pos - global_position).normalized()
		velocity = direction * speed
		
		move_and_slide()
		
		if velocity.length() < 5.0:
			stuck_timer += delta
		else:
			stuck_timer = 0.0
			
		if stuck_timer > 0.25:
			agent.target_position = global_position
			velocity = Vector2.ZERO
			stuck_timer = 0.0
		
		update_walk_animation(direction)
		last_direction = direction
	else:
		velocity = Vector2.ZERO
		stuck_timer = 0.0
		move_and_slide()
		update_idle_animation(last_direction)
		
		if is_moving_to_interact:
			is_moving_to_interact = false
			execute_pending_action()

func update_walk_animation(direction: Vector2) -> void:
	sprite.flip_h = false
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			sprite.play("walk_right")
		else:
			sprite.flip_h = true
			sprite.play("walk_right")
	else:
		sprite.play("walk_down" if direction.y > 0 else "walk_up")

func update_idle_animation(direction: Vector2) -> void:
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
	var candidates: Array = []
	candidates.append_array(interaction_area.get_overlapping_bodies())
	candidates.append_array(interaction_area.get_overlapping_areas())
	
	if candidates.is_empty():
		return

	var closest_node: Node2D = null
	var min_dist: float = INF
	for node in candidates:
		if node is Node2D and node.has_method("interact") and node != self:
			var dist: float = global_position.distance_squared_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_node = node
				
	if closest_node:
		closest_node.call("interact", self)

func start_move_interact(pos: Vector2, tool_name: String, target: Node2D = null, impact_sound: AudioStream = null) -> void:
	if not is_movement_locked:
		is_moving_to_interact = true
		pending_tool_action_pos = pos
		pending_tool_name = tool_name
		pending_target_body = target
		pending_impact_sound = impact_sound
		stuck_timer = 0.0
		agent.target_position = pos

func execute_pending_action() -> void:
	if pending_tool_name == "axe" or pending_tool_name == "pickaxe":
		var is_target_valid: bool = is_instance_valid(pending_target_body)
		if is_target_valid and "is_falling" in pending_target_body and pending_target_body.is_falling:
			is_target_valid = false
			
		if is_target_valid:
			if global_position.distance_to(pending_target_body.global_position) <= TOOL_REACH_DISTANCE + 10.0:
				start_tool_loop(pending_target_body, pending_tool_name, pending_impact_sound)
	else:
		if global_position.distance_to(pending_tool_action_pos) <= TOOL_REACH_DISTANCE + 10.0:
			perform_tool_action(pending_tool_action_pos, pending_tool_name)

func start_tool_loop(target_node: Node2D, tool_anim_name: String, impact_sfx: AudioStream = null) -> void:
	if is_movement_locked:
		return
	if "is_falling" in target_node and target_node.is_falling:
		return

	is_movement_locked = true
	velocity = Vector2.ZERO
	last_direction = (target_node.global_position - global_position).normalized()

	while is_touching and is_instance_valid(target_node):
		if time_manager and time_manager.get("current_energy") <= 0:
			if time_manager.has_method("request_faint"):
				time_manager.call_deferred("request_faint")
			break

		if "is_falling" in target_node and target_node.is_falling:
			break

		sprite.flip_h = false
		var anim: String = tool_anim_name + "_"
		if abs(last_direction.x) > abs(last_direction.y):
			if last_direction.x > 0:
				anim += "right"
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

		if time_manager and time_manager.has_method("use_tool_energy"):
			time_manager.call("use_tool_energy")

		if time_manager and time_manager.get("current_energy") <= 0:
			if time_manager.has_method("request_faint"):
				time_manager.call_deferred("request_faint")
			break

		if not is_instance_valid(target_node):
			break
		if "is_falling" in target_node and target_node.is_falling:
			break

		if impact_sfx and impact_audio_player:
			impact_audio_player.stream = impact_sfx
			impact_audio_player.play()

		if is_instance_valid(target_node) and target_node.has_method("hit"):
			target_node.call("hit", axe_hit_damage)
			if "health" in target_node and target_node.health <= 0:
				break

	is_movement_locked = false
	update_idle_animation(last_direction)


func perform_tool_action(target_pos: Vector2, tool_name: String) -> void:
	if global_position.distance_to(target_pos) > TOOL_REACH_DISTANCE + 20.0:
		is_movement_locked = false
		is_moving_to_interact = false
		return

	if tool_name in ["hoe", "watering", "scythe"]:
		if time_manager and time_manager.get("current_energy") <= 0:
			if time_manager.has_method("request_faint"):
				time_manager.call_deferred("request_faint")
			is_movement_locked = false
			is_moving_to_interact = false
			return

	is_movement_locked = true
	pending_tool_action_pos = target_pos
	velocity = Vector2.ZERO
	last_direction = (target_pos - global_position).normalized()
	sprite.flip_h = false

	var anim_base: String = tool_name
	if tool_name == "planting_crop":
		anim_base = "planting"

	var anim_name: String = anim_base + "_"
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			anim_name += "right"
		else:
			sprite.flip_h = true
			anim_name += "right"
	else:
		anim_name += "down" if last_direction.y > 0 else "up"

	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.25).timeout

	if tool_name in ["hoe", "watering", "scythe"]:
		if time_manager and time_manager.has_method("use_tool_energy"):
			time_manager.call("use_tool_energy")
		if time_manager and time_manager.get("current_energy") <= 0:
			if time_manager.has_method("request_faint"):
				time_manager.call_deferred("request_faint")
			sprite.flip_h = false
			is_movement_locked = false
			update_idle_animation(last_direction)
			return

	if tool_name == "hoe" and get_parent().has_method("use_hoe"):
		if sfx_hoe and impact_audio_player:
			impact_audio_player.stream = sfx_hoe
			impact_audio_player.play()
		get_parent().call("use_hoe", target_pos)

	elif tool_name == "watering":
		if sfx_water and audio_player:
			audio_player.stream = sfx_water
			audio_player.play()

		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query.position = target_pos
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var results: Array[Dictionary] = space_state.intersect_point(query)
		for result in results:
			if result.collider.has_method("water"):
				result.collider.call("water")

		if get_parent().has_method("use_water"):
			get_parent().call("use_water", target_pos)

	elif tool_name == "scythe":
		if sfx_swing and audio_player:
			audio_player.stream = sfx_swing
			audio_player.play()

		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query.position = target_pos
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var results: Array[Dictionary] = space_state.intersect_point(query)
		for result in results:
			if result.collider.has_method("harvest"):
				if "current_stage" in result.collider and "max_stage" in result.collider:
					if result.collider.current_stage >= result.collider.max_stage:
						result.collider.call("harvest")

	elif tool_name == "planting":
		spawn_tree(target_pos)
		play_seed_sound()

	elif tool_name == "planting_crop":
		spawn_crop(target_pos)
		play_seed_sound()

	if tool_name == "watering" and audio_player:
		await get_tree().create_timer(0.1).timeout
		if audio_player.stream == sfx_water:
			audio_player.stop()

	sprite.flip_h = false
	is_movement_locked = false
	update_idle_animation(last_direction)

func play_seed_sound() -> void:
	if sfx_seeds and audio_player:
		audio_player.stream = sfx_seeds
		audio_player.play()

func find_tree_script(node: Node) -> Node:
	if node.has_method("setup_as_seed"):
		return node
	for child in node.get_children():
		var found: Node = find_tree_script(child)
		if found: return found
	return null

func find_crop_script(node: Node) -> Node:
	if node.has_method("_save_persistence") and node.has_method("water") and ("current_stage" in node):
		return node
	for child in node.get_children():
		var found: Node = find_crop_script(child)
		if found:
			return found
	return null

func spawn_tree(pos: Vector2) -> void:
	if equipped_slot_index == -1 or not inventory_data:
		return

	if get_parent().has_method("get_tile_center_position"):
		var snap_pos: Vector2 = get_parent().call("get_tile_center_position", pos)

		var tree_scene: PackedScene = null
		if equipped_item.get("crop_scene_path") != "":
			tree_scene = load(equipped_item.get("crop_scene_path"))

		if not tree_scene:
			tree_scene = TREE_SCENES.pick_random()

		if tree_scene:
			var tree: Node2D = tree_scene.instantiate()
			tree.global_position = snap_pos

			if "tree_sort_index" in get_parent():
				tree.z_index = get_parent().tree_sort_index
				get_parent().tree_sort_index += 1
			else:
				tree.z_index = 10

			get_parent().add_child(tree)

			var script_node: Node = find_tree_script(tree)
			if script_node:
				script_node.call("setup_as_seed")

			tree.modulate.a = 0.0
			var t: Tween = get_tree().create_tween()
			t.tween_property(tree, "modulate:a", 1.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

			consume_equipped_item()

func _get_level_root_for_runtime_objects() -> Node:
	var wrapper := get_tree().current_scene
	if wrapper and wrapper.has_method("get_level_root"):
		var lr = wrapper.call("get_level_root")
		if lr:
			return lr
	return get_parent()

func _request_level_state_save(level_root: Node) -> void:
	if level_root and level_root.has_method("save_level_state"):
		level_root.call("save_level_state")
	elif get_parent() and get_parent().has_method("save_level_state"):
		get_parent().call("save_level_state")
	elif has_node("/root/SaveManager") and get_node("/root/SaveManager").has_method("save_game"):
		get_node("/root/SaveManager").call("save_game")

func spawn_crop(pos: Vector2) -> void:
	if equipped_slot_index == -1 or not inventory_data:
		return

	if equipped_item.get("crop_scene_path") == "":
		print("No crop scene path assigned to this item!")
		return

	if get_parent().has_method("get_tile_center_position"):
		var snap_pos: Vector2 = get_parent().call("get_tile_center_position", pos)

		var crop_scene: PackedScene = load(equipped_item.get("crop_scene_path"))
		if crop_scene:
			var crop: Node2D = crop_scene.instantiate()
			crop.global_position = snap_pos
			crop.set_meta("crop_scene_path", equipped_item.get("crop_scene_path"))
			if get_parent().has_method("get_level_key"):
				var lk := str(get_parent().call("get_level_key"))
				if lk != "":
					crop.set_meta("level_key", lk)
			get_parent().add_child(crop)

			var crop_script: Node = find_crop_script(crop)
			if crop_script and crop_script.has_method("_save_persistence"):
				crop_script.call("_save_persistence")

			if get_parent().has_method("save_level_state"):
				get_parent().call("save_level_state")

			consume_equipped_item()



func consume_equipped_item() -> void:
	if not inventory_data.slot_datas[equipped_slot_index]:
		return
		
	var slot: Resource = inventory_data.slot_datas[equipped_slot_index]
	if slot and slot.item_data == equipped_item:
		slot.quantity -= 1
		if slot.quantity <= 0:
			inventory_data.slot_datas[equipped_slot_index] = null
			equipped_item = null
			
			if get_parent().has_method("refresh_tile_selector"):
				get_parent().call("refresh_tile_selector")
		
		if inventory_data.has_signal("inventory_updated"):
			inventory_data.emit_signal("inventory_updated", inventory_data)

func update_equipped_item(index: int) -> void:
	reset_states()
	equipped_slot_index = index
	is_movement_locked = false
	
	if index == -1:
		equipped_item = null
		return
	if index < inventory_data.slot_datas.size():
		var slot_data: Resource = inventory_data.slot_datas[index]
		if slot_data:
			equipped_item = slot_data.item_data
		else:
			equipped_item = null
	else:
		equipped_item = null

func add_item(item: Resource, amount: int) -> void:
	if not inventory_data:
		return
	
	var new_slot = SlotData.new()
	new_slot.item_data = item
	new_slot.quantity = amount
	
	if not inventory_data.pick_up_slot_data(new_slot):
		var drop_scene = load("res://Item/pick_up/pick_up.tscn")
		if not drop_scene:
			drop_scene = load("res://farmy-daily/Item/pick_up/pick_up.tscn")
			
		if drop_scene:
			var drop = drop_scene.instantiate()
			drop.slot_data = new_slot
			drop.global_position = global_position
			get_parent().add_child(drop)

func upgrade_axe_damage() -> void:
	axe_hit_damage = 2
