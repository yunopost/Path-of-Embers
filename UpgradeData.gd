extends Resource
class_name UpgradeData

## Upgrade data for cards - can modify cards or transcend into other cards

@export var id: String = ""
@export var name: String = ""
@export var rarity: String = "common"  # common, uncommon, rare
@export var weight: float = 1.0  # For random selection weighting
@export var modifications: Array[EffectData] = []  # Effects that modify the card
@export var can_transcend: bool = false
@export var transcend_target_card_id: String = ""  # Card to transform into

func _init():
	modifications = []

