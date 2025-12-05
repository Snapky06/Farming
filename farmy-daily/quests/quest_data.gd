extends Resource
class_name QuestData

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var repeatable: bool = false
@export var steps: Array[QuestStepData] = []
