extends Resource
class_name ItemData

@export var name: String = ""
@export_multiline var description: String = ""
@export var stackable: bool = false
@export var texture: Texture
@export_file("*.tscn") var crop_scene_path: String
@export var price: int = 10
@export var is_sellable: bool = true
