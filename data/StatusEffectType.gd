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

# Duration-based, symmetric with Vulnerable: while active, Block gained by the
# holder is increased 25% (rounded up). Applied to self (source), not an enemy.
const AGILITY = "agility"

# Special/one-time statuses
const PENDING_STRENGTH_IF_NO_DAMAGE = "pending_strength_if_no_damage"
const BLOCK_ON_ENEMY_ACT = "block_on_enemy_act"
const RESONANT_FRAME_ACTIVE = "resonant_frame_active"
const DRAW_PER_TURN = "draw_per_turn"

# Golemancer - Grand Assembly Power (stacking: each copy adds more HP bonus)
const GRAND_ASSEMBLY_ACTIVE = "grand_assembly_active"

# Get all stacking status types
static func get_stacking_statuses() -> Array[String]:
	return [STRENGTH, DEXTERITY, FAITH, GRAND_ASSEMBLY_ACTIVE, DRAW_PER_TURN]

# Get all pending status types (handled at specific times)
static func get_pending_statuses() -> Array[String]:
	return [PENDING_STRENGTH_IF_NO_DAMAGE]

# Check if a status is stacking (accumulates value)
static func is_stacking(status_type: String) -> bool:
	return status_type in get_stacking_statuses()

# Check if a status is pending (handled at specific times)
static func is_pending(status_type: String) -> bool:
	return status_type in get_pending_statuses()

# Get all statuses classified as debuffs (negative status applied to an enemy).
# Used by sequencing effects like Cheap Shot ("if the last card you played
# applied a debuff") so they read this list instead of hardcoding status names.
static func get_debuff_statuses() -> Array[String]:
	return [VULNERABLE, WEAKNESS]

# Check if a status is classified as a debuff
static func is_debuff(status_type: String) -> bool:
	return status_type in get_debuff_statuses()

# Get all valid status types
static func get_all_types() -> Array[String]:
	return [
		STRENGTH,
		DEXTERITY,
		FAITH,
		VULNERABLE,
		WEAKNESS,
		AGILITY,
		PENDING_STRENGTH_IF_NO_DAMAGE,
		BLOCK_ON_ENEMY_ACT,
		RESONANT_FRAME_ACTIVE,
		GRAND_ASSEMBLY_ACTIVE,
		DRAW_PER_TURN,
	]

# Validate if a string is a valid status type
static func is_valid(status_type: String) -> bool:
	return status_type in get_all_types()

