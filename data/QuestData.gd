extends Resource
class_name QuestData

## Quest data with progress tracking and completion conditions

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var progress_max: int = 0
@export var tracking_type: String = ""  # e.g., "kill_count", "damage_dealt", etc.
@export var params: Dictionary = {}  # Additional parameters for quest logic
@export var is_complete: bool = false

func _init():
	params = {}

