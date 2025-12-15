extends Resource
class_name QuestData

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var repeatable: bool = false
@export var steps: Array[QuestStepData] = []

@export_group("Dialogs")
@export_multiline var start_dialog: Array[String] = []
@export_multiline var active_dialog: Array[String] = []
@export_multiline var complete_dialog: Array[String] = []

@export_group("Rewards")
@export var reward_items: Array[Resource] = []
@export var reward_amount: int = 1
