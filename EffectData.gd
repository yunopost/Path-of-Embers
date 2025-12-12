extends Resource
class_name EffectData

## Generic effect data structure for cards, relics, upgrades, and enemy intents
## Uses type string + params dict pattern for flexibility

@export var effect_type: String = ""  # e.g., "damage", "block", "draw", "heal", etc.
@export var params: Dictionary = {}  # Effect-specific parameters

func _init(p_effect_type: String = "", p_params: Dictionary = {}):
	effect_type = p_effect_type
	params = p_params

