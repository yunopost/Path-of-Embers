extends Resource
class_name EncounterData

## Encounter event data — defines a non-combat node with choices and rewards.
## Each choice is a Dictionary with keys:
##   "id": String              — unique choice identifier (used by quest system)
##   "label": String           — button text
##   "effects_text": String    — short description of the outcome
##   "reward_gold": int        — gold granted (0 = none)
##   "reward_heal": int        — HP restored (0 = none)
##   "reward_card_choices": int — number of card choices offered (0 = none)
##   "reward_upgrade_count": int — upgrade points granted (0 = none)

@export var id: String = ""
@export var title: String = ""
@export var body: String = ""
@export var choices: Array[Dictionary] = []
@export var min_act: int = 1  # Earliest act this encounter can appear
@export var max_act: int = 3  # Latest act this encounter can appear

func _init():
	choices = []
