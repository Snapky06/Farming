extends Area2D

func interact(user = null) -> void:
	var npc = get_parent()
	if npc and npc.has_method("on_interact"):
		npc.on_interact(user)
