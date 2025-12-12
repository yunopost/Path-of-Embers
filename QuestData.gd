extends Resource
class_name QuestData

## Quest data with progress tracking and completion conditions

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var progress_fields: Dictionary = {}  # Flexible progress tracking
@export var completion_condition: Dictionary = {}  # Data-driven completion check
@export var is_complete: bool = false

func _init():
	progress_fields = {}
	completion_condition = {}

