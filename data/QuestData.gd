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

## Reward granted immediately on quest completion.
## Keys (all optional): "gold": int, "upgrade_count": int, "heal_amount": int, "relic_id": String
@export var reward: Dictionary = {}

func _init():
	params = {}
	reward = {}
