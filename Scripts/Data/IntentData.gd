extends Resource
class_name IntentData

## Data structure for enemy intents - telegraphing and execution parameters

@export var intent_type: String = ""  # e.g., "Attack", "Defend", "Debuff"
@export var values: Dictionary = {}  # e.g., { "damage": 6 }
@export var icon_path: String = ""  # Path to intent icon (placeholder for now)
@export var telegraph_text: String = ""  # Display text, e.g., "Attack 6"
@export var time_max_override: int = -1  # Optional; -1 means use enemy.time_max

func _init(p_intent_type: String = "", p_values: Dictionary = {}, p_telegraph_text: String = "", p_time_max_override: int = -1):
	intent_type = p_intent_type
	values = p_values
	telegraph_text = p_telegraph_text
	time_max_override = p_time_max_override
	
	# Auto-generate telegraph_text if not provided
	if telegraph_text.is_empty() and not values.is_empty():
		match intent_type:
			"Attack":
				var damage = values.get("damage", 0)
				telegraph_text = "Attack %d" % damage
			_:
				telegraph_text = intent_type

