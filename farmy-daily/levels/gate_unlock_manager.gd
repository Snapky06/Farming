extends Node

func _ready() -> void:
	call_deferred("apply_investor_gates")

func apply_investor_gates() -> void:
	var sm: Node = get_tree().root.get_node_or_null("SaveManager")
	if sm == null:
		return

	var lvl := 0
	if sm.persistence_data.has("investor_gate_level"):
		lvl = int(sm.persistence_data["investor_gate_level"])

	for i in range(1, lvl + 1):
		var gate_name := "Gate%d" % i
		var gate := get_node_or_null(gate_name)
		if gate == null:
			continue

		if gate.has_method("clear"):
			gate.call("clear")

		if gate.has_method("update_internals"):
			gate.call("update_internals")
		elif gate.has_method("notify_runtime_tile_data_update"):
			gate.call("notify_runtime_tile_data_update")

		gate.set_deferred("visible", false)
		gate.call_deferred("queue_free")
