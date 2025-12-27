extends Resource
class_name EffectData

## Generic effect data structure for cards, relics, upgrades, and enemy intents
## Uses type string + params dict pattern for flexibility
## Use EffectType constants for type safety (e.g., EffectType.DAMAGE)

@export var effect_type: String = ""  # Use EffectType constants (e.g., EffectType.DAMAGE)
@export var params: Dictionary = {}  # Effect-specific parameters

func _init(p_effect_type: String = "", p_params: Dictionary = {}):
	effect_type = p_effect_type
	params = p_params
	_validate_effect_type()

func _validate_effect_type():
	## Validate effect_type on creation (warns in debug builds)
	if not effect_type.is_empty() and not EffectType.is_valid(effect_type):
		push_warning("EffectData: Unknown effect_type '%s'. Use EffectType constants for type safety." % effect_type)

func get_effect_type() -> String:
	## Get the effect type string
	return effect_type

