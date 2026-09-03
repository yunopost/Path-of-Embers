extends RefCounted
class_name StatusEffect

## Status effect data class - represents a single status effect on an entity
## Contains type, value, and metadata

var status_type: String = ""  # Use StatusEffectType constants
var value  # Value (int for stacking/duration, or other type for special statuses)

func _init(p_status_type: String = "", p_value = 0):
	status_type = p_status_type
	value = p_value
	_validate_status_type()

func _validate_status_type():
	## Validate status_type on creation (warns in debug builds)
	if not status_type.is_empty() and not StatusEffectType.is_valid(status_type):
		push_warning("StatusEffect: Unknown status_type '%s'. Use StatusEffectType constants for type safety." % status_type)

func get_value() -> int:
	## Get value as int (for stacking/duration statuses)
	if value is int:
		return value
	elif value is float:
		return int(value)
	return 0

func is_stacking() -> bool:
	## Check if this status type stacks (accumulates value)
	return StatusEffectType.is_stacking(status_type)

func is_pending() -> bool:
	## Check if this status type is pending (handled at specific times)
	return StatusEffectType.is_pending(status_type)

