extends Sprite2D

@onready var ground_layer: TileMapLayer = $"../Backgrounds/NavRegion/Ground"

func _process(_delta):
	if not visible:
		return

	var target_global_pos = get_global_mouse_position()
	var is_locked_on_action = false
	
	var player = get_parent().player
	if player:
		if player.is_moving_to_interact or player.is_movement_locked:
			target_global_pos = player.pending_tool_action_pos
			is_locked_on_action = true

	var local_pos = ground_layer.to_local(target_global_pos)
	var grid_pos = ground_layer.local_to_map(local_pos)
	
	global_position = ground_layer.to_global(ground_layer.map_to_local(grid_pos))
	
	if is_locked_on_action:
		self.modulate = Color(0, 1, 0, 0.5)
		return

	var is_valid = false
	if get_parent().has_method("is_tile_farmable") and player and player.equipped_item:
		var n = player.equipped_item.name
		
		if n == "Hoe":
			is_valid = get_parent().is_tile_farmable(target_global_pos)
			
		elif n == "Watering Can":
			if get_parent().has_method("is_tile_waterable"):
				is_valid = get_parent().is_tile_waterable(target_global_pos)
		
		elif n == "Scythe":
			var space_state = ground_layer.get_world_2d().direct_space_state
			var query = PhysicsPointQueryParameters2D.new()
			query.position = target_global_pos
			query.collide_with_bodies = true
			query.collide_with_areas = true
			var results = space_state.intersect_point(query)
			for result in results:
				var c = result.collider
				if c.has_method("harvest") and "current_stage" in c and "max_stage" in c:
					if c.current_stage >= c.max_stage:
						is_valid = true
						break
				
		elif n == "Tree Seed" or n == "Tree Seeds":
			if get_parent().has_method("can_plant_seed"):
				is_valid = get_parent().can_plant_seed(target_global_pos)
				
		elif "Seeds" in n:
			if get_parent().has_method("can_plant_crop"):
				is_valid = get_parent().can_plant_crop(target_global_pos)

	if is_valid:
		self.modulate = Color(0, 1, 0, 0.5)
	else:
		self.modulate = Color(1, 0, 0, 0.5)
