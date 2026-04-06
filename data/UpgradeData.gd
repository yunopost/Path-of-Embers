extends Resource
class_name UpgradeData

## Upgrade data for cards - can modify cards or transcend into other cards

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""  # Description text for the upgrade
@export var rarity: String = "common"  # common, uncommon, rare
@export var weight: float = 1.0  # For random selection weighting
@export var modifications: Array[EffectData] = []  # Effects that modify the card
@export var effects_dict: Dictionary = {}  # Dictionary-based effects (for legacy compatibility during migration)
@export var applies_to_cards: Array[String] = []  # Card IDs this upgrade applies to (for pool configuration)
@export var is_keyword: bool = false  # Whether this is a keyword definition
@export var can_transcend: bool = false
@export var transcend_target_card_id: String = ""  # Card to transform into

func _init():
	modifications = []
	effects_dict = {}
	applies_to_cards = []

