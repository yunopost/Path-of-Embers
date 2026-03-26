extends RefCounted
class_name RewardBundle

## Represents a bundle of rewards from an encounter/fight/shop
## Used to pass reward data between screens

var gold: int = 0
var card_choices: Array[String] = []  # Array of card IDs to choose from
var upgrade_count: int = 0  # Number of upgrade actions available from this reward
var upgrade_points: int = 0  # Upgrade currency granted by this reward (Phase 4)
var heal_amount: int = 0  # Amount of HP to heal
var skip_allowed: bool = true  # Whether player can skip rewards
var is_transcendence_upgrade: bool = false  # If true, upgrade options are transcendence instead of normal
# PLACEHOLDER FOR FUTURE WORK: Transcendence upgrade flow is not implemented.
# This flag is set for boss nodes but the upgrade flow does not check it.

func _init(p_gold: int = 0, p_card_choices: Array[String] = [], p_upgrade_count: int = 0, p_heal_amount: int = 0, p_skip_allowed: bool = true, p_is_transcendence: bool = false, p_upgrade_points: int = 0):
	gold = p_gold
	if p_card_choices:
		card_choices = p_card_choices.duplicate()
	else:
		card_choices = []
	upgrade_count = p_upgrade_count
	upgrade_points = p_upgrade_points
	heal_amount = p_heal_amount
	skip_allowed = p_skip_allowed
	is_transcendence_upgrade = p_is_transcendence

func has_any_rewards() -> bool:
	## Returns true if bundle contains any rewards
	return gold > 0 or card_choices.size() > 0 or upgrade_count > 0 or heal_amount > 0 or upgrade_points > 0

func to_dict() -> Dictionary:
	## Serialize to dictionary for save/load
	return {
		"gold": gold,
		"card_choices": card_choices,
		"upgrade_count": upgrade_count,
		"upgrade_points": upgrade_points,
		"heal_amount": heal_amount,
		"skip_allowed": skip_allowed,
		"is_transcendence_upgrade": is_transcendence_upgrade
	}

static func from_dict(data: Dictionary) -> RewardBundle:
	## Deserialize from dictionary
	var card_choices_data = data.get("card_choices", [])
	var card_choices_array: Array[String] = []
	for item in card_choices_data:
		card_choices_array.append(str(item))
	
	# Convert int fields (JSON may store as float)
	var p_gold := int(data.get("gold", 0))
	var p_upgrade_count := int(data.get("upgrade_count", 0))
	var p_heal_amount := int(data.get("heal_amount", 0))

	var p_upgrade_points := int(data.get("upgrade_points", 0))

	return RewardBundle.new(
		p_gold,
		card_choices_array,
		p_upgrade_count,
		p_heal_amount,
		data.get("skip_allowed", true),
		data.get("is_transcendence_upgrade", false),
		p_upgrade_points
	)
