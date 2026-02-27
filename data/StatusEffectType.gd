extends RefCounted
class_name StatusEffectType

## Enum-like class for status effect types - provides type safety and avoids string typos
## Usage: StatusEffectType.STRENGTH, StatusEffectType.VULNERABLE, etc.

# Stacking statuses (persist until combat ends, values accumulate)
const STRENGTH = "strength"
const DEXTERITY = "dexterity"
const FAITH = "faith"

# Duration-based statuses (decrease by 1 each turn, removed at 0)
const VULNERABLE = "vulnerable"
const WEAKNESS = "weakness"

# Special/one-time statuses
const PENDING_STRENGTH_IF_NO_DAMAGE = "pending_strength_if_no_damage"
const RETAIN_BLOCK_THIS_TURN = "retain_block_this_turn"
const BLOCK_ON_ENEMY_ACT = "block_on_enemy_act"
const RESONANT_FRAME_ACTIVE = "resonant_frame_active"

# Get all stacking status types
static func get_stacking_statuses() -> Array[String]:
	return [STRENGTH, DEXTERITY, FAITH]

# Get all pending status types (handled at specific times)
static func get_pending_statuses() -> Array[String]:
	return [PENDING_STRENGTH_IF_NO_DAMAGE]

# Check if a status is stacking (accumulates value)
static func is_stacking(status_type: String) -> bool:
	return status_type in get_stacking_statuses()

# Check if a status is pending (handled at specific times)
static func is_pending(status_type: String) -> bool:
	return status_type in get_pending_statuses()

# Get all valid status types
static func get_all_types() -> Array[String]:
	return [
		STRENGTH,
		DEXTERITY,
		FAITH,
		VULNERABLE,
		WEAKNESS,
		PENDING_STRENGTH_IF_NO_DAMAGE,
		RETAIN_BLOCK_THIS_TURN,
		BLOCK_ON_ENEMY_ACT,
		RESONANT_FRAME_ACTIVE
	]

# Validate if a string is a valid status type
static func is_valid(status_type: String) -> bool:
	return status_type in get_all_types()

