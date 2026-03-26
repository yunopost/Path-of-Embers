extends RefCounted
class_name PetDefinition

## Immutable blueprint for a pet type.
## Instantiated in code — no .tres resource file needed.
##
## intercept_mode values:
##   "NONE"         — utility pet, does not absorb damage
##   "SHARED_POOL"  — pet HP absorbs incoming damage before the player's HP
##   "SPLIT"        — (v2 stub) pet absorbs a % of damage
##
## Supported trigger hooks:
##   START_OF_PLAYER_TURN
##   END_OF_PLAYER_TURN
##   WHEN_ENEMY_ACTS      (fires per enemy action)
##   ON_PET_SUMMONED      (owner side, fires once on summon)
##   ON_PET_DAMAGED
##   ON_PET_DESTROYED
##   START_OF_NEXT_PLAYER_TURN
##
## Supported trigger actions (executed by PetBoard._execute_trigger):
##   gain_block                — player gains <amount> block
##   damage_acting_enemy       — deal <amount> damage to the currently-acting enemy
##   damage_attacker_or_random — prefer attacker; fall back to random alive enemy
##   damage_random_enemy       — deal <amount> damage to a random alive enemy

var pet_def_id: String = ""
var display_name: String = ""
var tags: Array[String] = []          ## e.g. ["Construct", "Core"]
var base_max_hp: int = 5
var intercept_mode: String = "NONE"
## triggers: Array of Dicts  { "hook": <String>, "action": <String>, "amount": <int>, ... }
var triggers: Array = []

func _init(
		p_id: String,
		p_name: String,
		p_tags: Array,
		p_max_hp: int,
		p_intercept: String = "NONE",
		p_triggers: Array = []
) -> void:
	pet_def_id = p_id
	display_name = p_name
	# Type-safe copy
	tags = []
	for t in p_tags:
		tags.append(str(t))
	base_max_hp = p_max_hp
	intercept_mode = p_intercept
	triggers = p_triggers.duplicate(true)
