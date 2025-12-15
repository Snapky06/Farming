extends Control

@export var quest_list_container: VBoxContainer

@onready var quest_manager: Node = get_node_or_null("/root/QuestManager")

func _ready() -> void:
	if quest_manager:
		quest_manager.quest_started.connect(_on_quest_changed)
		quest_manager.quest_updated.connect(_on_quest_changed)
		quest_manager.quest_completed.connect(_on_quest_changed)
	
	update_view()

func _on_quest_changed(_id: String) -> void:
	update_view()

func update_view() -> void:
	if not quest_list_container:
		return
		
	for child in quest_list_container.get_children():
		child.queue_free()
		
	if not quest_manager:
		return
		
	var active = quest_manager.get_all_active_quests()
	
	if active.is_empty():
		var label = Label.new()
		label.text = "No active quests."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quest_list_container.add_child(label)
		return
		
	for quest_state in active:
		var quest = quest_state["resource"]
		var step_idx = quest_state["current_step_index"]
		var progress = quest_state["current_step_progress"]
		
		var title = Label.new()
		title.text = quest.title
		title.add_theme_font_size_override("font_size", 20)
		title.modulate = Color(1, 0.8, 0.4)
		quest_list_container.add_child(title)
		
		var desc = Label.new()
		if step_idx < quest.steps.size():
			var step = quest.steps[step_idx]
			desc.text = "- " + step.description + " (" + str(progress) + "/" + str(step.required_count) + ")"
		else:
			desc.text = "Completed"
			
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		quest_list_container.add_child(desc)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		quest_list_container.add_child(spacer)
