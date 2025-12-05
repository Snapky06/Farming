extends Node

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal quests_changed

var active_quests: Dictionary = {}
var completed_quests: Dictionary = {}

func start_quest(quest: QuestData) -> void:
	if quest == null:
		return
	if quest.id == "":
		return
	if quest.id in active_quests:
		return
	if quest.id in completed_quests and not quest.repeatable:
		return
	var state: Dictionary = {}
	state["data"] = quest
	state["current_step"] = 0
	state["progress"] = 0
	state["times_completed"] = 0
	active_quests[quest.id] = state
	quest_started.emit(quest.id)
	quests_changed.emit()

func abandon_quest(quest_id: String) -> void:
	if not quest_id in active_quests:
		return
	active_quests.erase(quest_id)
	quests_changed.emit()

func is_quest_active(quest_id: String) -> bool:
	return quest_id in active_quests

func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quests

func get_active_quest_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in active_quests.keys():
		ids.append(id)
	return ids

func get_quest_data(quest_id: String) -> QuestData:
	if quest_id in active_quests:
		var state: Dictionary = active_quests[quest_id]
		return state["data"]
	if quest_id in completed_quests:
		var c_state: Dictionary = completed_quests[quest_id]
		return c_state["data"]
	return null

func get_step_progress(quest_id: String) -> Dictionary:
	var result: Dictionary = {}
	result["has_data"] = false
	if quest_id in active_quests:
		var state: Dictionary = active_quests[quest_id]
		var data: QuestData = state["data"]
		var index: int = state["current_step"]
		if index >= 0 and index < data.steps.size():
			var step: QuestStepData = data.steps[index]
			var required := step.required_count
			if required <= 0:
				required = 1
			result["has_data"] = true
			result["current_step_index"] = index
			result["current"] = state["progress"]
			result["required"] = required
			result["description"] = step.description
	return result

func notify_event(event_name: String, amount: int = 1, target_id: String = "") -> void:
	if event_name == "":
		return
	if amount <= 0:
		return
	var quests_to_complete: Array[String] = []
	for quest_id in active_quests.keys():
		var state: Dictionary = active_quests[quest_id]
		var data: QuestData = state["data"]
		var index: int = state["current_step"]
		if index < 0 or index >= data.steps.size():
			continue
		var step: QuestStepData = data.steps[index]
		if step.event_name != event_name:
			continue
		if step.target_id != "" and step.target_id != target_id:
			continue
		var required := step.required_count
		if required <= 0:
			required = 1
		var progress: int = state["progress"]
		progress += amount
		if progress >= required:
			progress = required
			index += 1
			if index >= data.steps.size():
				state["times_completed"] = int(state.get("times_completed", 0)) + 1
				completed_quests[quest_id] = state.duplicate()
				quests_to_complete.append(quest_id)
			else:
				state["current_step"] = index
				state["progress"] = 0
				active_quests[quest_id] = state
				quest_updated.emit(quest_id)
		else:
			state["progress"] = progress
			active_quests[quest_id] = state
			quest_updated.emit(quest_id)
	for id in quests_to_complete:
		active_quests.erase(id)
		quest_completed.emit(id)
	if quests_to_complete.size() > 0:
		quests_changed.emit()

func reset_all() -> void:
	active_quests.clear()
	completed_quests.clear()
	quests_changed.emit()

func get_save_data() -> Dictionary:
	return {
		"active": active_quests,
		"completed": completed_quests
	}

func load_save_data(data: Dictionary) -> void:
	active_quests = data.get("active", {})
	completed_quests = data.get("completed", {})
	quests_changed.emit()
