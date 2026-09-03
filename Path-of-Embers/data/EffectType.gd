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

# Mechanist - Board Control
const DRAW_PER_TURN = "draw_per_turn"  # Power: draw N extra cards at start of each turn

# Mechanist - Legacy
const LEGACY_KILL_COUNTER = "legacy_kill_counter"  # Card permanently gains stats each time it lands a killing blow

# Legacy/placeholder
const APPLY_STATUS = "ApplyStatus"
const MODIFY_ENEMY_TIMER = "ModifyEnemyTimer"

# Revenant - Spite & Undying (stub)
const DAMAGE_SPITE = "damage_spite"  # Deals bonus damage scaled by missing HP: {base_amount, bonus_per_10_missing_hp}
const DRAW_IF_TOOK_DAMAGE = "draw_if_took_damage"  # Draw N cards if you took damage this combat: {amount}

# Tempest - Sequencing (stub)
const DAMAGE_SEQUENCING = "damage_sequencing"  # Bonus damage if last card played was an Attack: {base_amount, bonus_if_last_was_attack}

# Grove - Bloom & Regrowth (stub)
const BLOOM = "bloom"  # Add counters to a card; trigger effect when drawn at threshold: {counters, trigger_threshold, trigger_effect, trigger_amount}
const REGROWTH = "regrowth"  # Card returns to draw pile at end of turn instead of discarding: {}

# Sibyl - Foresight & Probability (stub)
const SCRY = "scry"  # Look at top N cards of draw pile and reorder them: {amount}
const DAMAGE_CONDITIONAL_TOP_CARD = "damage_conditional_top_card"  # More damage if top card is Attack, else less damage + block: {attack_amount, default_amount, default_block}

# Echo - Mirror & Resonance (stub)
const MIRROR = "mirror"  # Replay the last card played: {}
const RESONANCE_BLOCK = "resonance_block"  # Gain block; bonus block if last card was also a Skill: {base_amount, bonus_if_last_was_skill}

# Hollow - Conversion & Dominance (stub)
const BLOCK_TO_ENERGY = "block_to_energy"  # Convert all current Block into Energy at ratio: {block_per_energy}
const FORCE_END_TURN = "force_end_turn"  # End your turn immediately after this card resolves: {}

# Living Armor - Iron Tide
const DAMAGE_EQUAL_TO_BLOCK = "damage_equal_to_block"  # Deal damage equal to current Block value: {}

# ── Golemancer / Pet System ────────────────────────────────────────────────────
## Summon a pet defined in PetBoard's registry.
## params: { "pet_def_id": String, "hp_bonus": int (optional, default 0) }
const SUMMON_PET = "summon_pet"

## Give the oldest alive pet +max_hp and heal; optionally draw if it survives an enemy action.
## params: { "max_hp_bonus": int, "heal_amount": int, "draw_if_survives": int }
const REINFORCE_PET = "reinforce_pet"

## Power card: Whenever a Construct pet is summoned it gains +hp and heals.
## Also triggers an immediate assembly check.
## params: { "hp_bonus": int, "heal_amount": int }
const GRAND_ASSEMBLY_POWER = "grand_assembly_power"

## Deal damage to a random alive enemy at the START_OF_NEXT_PLAYER_TURN.
## params: { "amount": int }
const DELAYED_DAMAGE = "delayed_damage"

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
		DRAW_PER_TURN,
		LEGACY_KILL_COUNTER,
		APPLY_STATUS,
		MODIFY_ENEMY_TIMER,
		DAMAGE_SPITE,
		DRAW_IF_TOOK_DAMAGE,
		DAMAGE_SEQUENCING,
		BLOOM,
		REGROWTH,
		SCRY,
		DAMAGE_CONDITIONAL_TOP_CARD,
		MIRROR,
		RESONANCE_BLOCK,
		BLOCK_TO_ENERGY,
		FORCE_END_TURN,
		SUMMON_PET,
		REINFORCE_PET,
		GRAND_ASSEMBLY_POWER,
		DELAYED_DAMAGE,
		DAMAGE_EQUAL_TO_BLOCK,
	]

# Validate if a string is a valid effect type
static func is_valid(effect_type: String) -> bool:
	return effect_type in get_all_types()

