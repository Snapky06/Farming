extends Node

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)

var active_quests: Dictionary = {}
var completed_quests: Dictionary = {}

func start_quest(quest: QuestData) -> void:
	if active_quests.has(quest.id) or completed_quests.has(quest.id):
		return
	
	active_quests[quest.id] = {
		"resource": quest,
		"current_step_index": 0,
		"current_step_progress": 0
	}
	
	quest_started.emit(quest.id)

func notify_event(event_name: String, amount: int = 1, target_id: String = "") -> void:
	for quest_id in active_quests.keys():
		var quest_state = active_quests[quest_id]
		var quest_res = quest_state["resource"]
		var step_index = quest_state["current_step_index"]
		
		if step_index >= quest_res.steps.size():
			continue
			
		var step = quest_res.steps[step_index]
		
		if step.event_name == event_name:
			if target_id == "" or step.target_id == target_id:
				quest_state["current_step_progress"] += amount
				quest_updated.emit(quest_id)
				
				if quest_state["current_step_progress"] >= step.required_count:
					_advance_step(quest_id)

func _advance_step(quest_id: String) -> void:
	var quest_state = active_quests[quest_id]
	var quest_res = quest_state["resource"]
	
	quest_state["current_step_index"] += 1
	quest_state["current_step_progress"] = 0
	
	if quest_state["current_step_index"] >= quest_res.steps.size():
		complete_quest(quest_id)
	else:
		quest_updated.emit(quest_id)

func complete_quest(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return
		
	var quest_res = active_quests[quest_id]["resource"]
	completed_quests[quest_id] = active_quests[quest_id]
	active_quests.erase(quest_id)
	
	quest_completed.emit(quest_id)

func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id)

func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)

func get_step_progress(quest_id: String) -> Dictionary:
	if active_quests.has(quest_id):
		return {
			"current": active_quests[quest_id]["current_step_progress"],
			"current_step_index": active_quests[quest_id]["current_step_index"]
		}
	return {}

func get_all_active_quests() -> Array:
	return active_quests.values()

func get_save_data() -> Dictionary:
	var active_arr: Array = []
	for quest_id in active_quests.keys():
		var st: Dictionary = active_quests[quest_id]
		var q = st.get("resource", null)
		var rp := ""
		if q != null and q.resource_path != null:
			rp = str(q.resource_path)
		active_arr.append({
			"id": str(quest_id),
			"path": rp,
			"step": int(st.get("current_step_index", 0)),
			"progress": int(st.get("current_step_progress", 0))
		})
	var completed_arr: Array = []
	for quest_id in completed_quests.keys():
		completed_arr.append(str(quest_id))
	return {"active": active_arr, "completed": completed_arr}

func load_save_data(data: Dictionary) -> void:
	active_quests.clear()
	completed_quests.clear()

	if data.is_empty():
		return

	var completed_arr: Array = data.get("completed", [])
	for qid in completed_arr:
		completed_quests[str(qid)] = {"resource": null, "current_step_index": 0, "current_step_progress": 0}

	var active_arr: Array = data.get("active", [])
	for entry in active_arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var qid := str(entry.get("id", ""))
		var rp := str(entry.get("path", ""))
		if qid == "" or rp == "" or not ResourceLoader.exists(rp):
			continue
		var res = load(rp)
		if res == null:
			continue
		active_quests[qid] = {
			"resource": res,
			"current_step_index": int(entry.get("step", 0)),
			"current_step_progress": int(entry.get("progress", 0))
		}
