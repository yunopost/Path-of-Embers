extends RefCounted
class_name EffectType

## Enum-like class for effect types - provides type safety and avoids string typos
## Usage: EffectType.DAMAGE, EffectType.BLOCK, etc.

# Core effects
const DAMAGE = "damage"
const BLOCK = "block"
const HEAL = "heal"
const DRAW = "draw"

# Status effects
const VULNERABLE = "vulnerable"
const VULNERABLE_ALL_ENEMIES = "vulnerable_all_enemies"
const STRENGTH = "strength"
const DEXTERITY = "dexterity"
const FAITH = "faith"
const WEAKNESS = "weakness"

# Card manipulation
const GRANT_HASTE_NEXT_CARD = "grant_haste_next_card"
const ADD_CURSE_TO_HAND = "add_curse_to_hand"
const ADD_TEMPORARY_UPGRADE_TO_RANDOM_HAND_CARD = "add_temporary_upgrade_to_random_hand_card"

# Conditional effects
const CONDITIONAL_STRENGTH_IF_NO_DAMAGE = "conditional_strength_if_no_damage"
const DAMAGE_PER_CURSE = "damage_per_curse"
const DAMAGE_CONDITIONAL_ELITE = "damage_conditional_elite"

# Special effects
const RETAIN_BLOCK_THIS_TURN = "retain_block_this_turn"
const BLOCK_ON_ENEMY_ACT = "block_on_enemy_act"
const DAMAGE_ON_BLOCK_GAIN = "damage_on_block_gain"

# Legacy/placeholder
const APPLY_STATUS = "ApplyStatus"
const MODIFY_ENEMY_TIMER = "ModifyEnemyTimer"

# Get all valid effect types (for validation)
static func get_all_types() -> Array[String]:
	return [
		DAMAGE,
		BLOCK,
		HEAL,
		DRAW,
		VULNERABLE,
		VULNERABLE_ALL_ENEMIES,
		STRENGTH,
		DEXTERITY,
		FAITH,
		WEAKNESS,
		GRANT_HASTE_NEXT_CARD,
		ADD_CURSE_TO_HAND,
		ADD_TEMPORARY_UPGRADE_TO_RANDOM_HAND_CARD,
		CONDITIONAL_STRENGTH_IF_NO_DAMAGE,
		DAMAGE_PER_CURSE,
		DAMAGE_CONDITIONAL_ELITE,
		RETAIN_BLOCK_THIS_TURN,
		BLOCK_ON_ENEMY_ACT,
		DAMAGE_ON_BLOCK_GAIN,
		APPLY_STATUS,
		MODIFY_ENEMY_TIMER
	]

# Validate if a string is a valid effect type
static func is_valid(effect_type: String) -> bool:
	return effect_type in get_all_types()

