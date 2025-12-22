extends Resource
class_name CardData

## Card data structure with targeting, effects, and upgrade support

enum CardType {
	ATTACK,
	SKILL,
	POWER
}

enum TargetingMode {
	NONE,
	ENEMY,
	ALL_ENEMIES,
	ALLY,
	SELF,
	ALL_ALLIES
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE
}

enum CostType {
	ENERGY,
	DISCARD  # Discard X cards from hand
}

@export var id: String = ""
@export var name: String = ""
@export var cost: int = 1
@export var cost_type: CostType = CostType.ENERGY  # Cost payment type
@export var discard_cost_amount: int = 1  # Number of cards to discard (for DISCARD cost type)
@export var card_type: CardType = CardType.ATTACK
@export var targeting_mode: TargetingMode = TargetingMode.NONE
@export var owner_character_id: String = ""  # For character-specific cards/animations
@export var rarity: Rarity = Rarity.COMMON
@export var keywords: Array[String] = []  # Keywords directly on card (e.g., "Slow", "Exhaust")
@export var base_effects: Array[EffectData] = []
@export var upgrade_pool: Array[UpgradeData] = []
@export var art_path: String = ""
@export var full_art_path: String = ""

func _init():
	keywords = []
	base_effects = []
	upgrade_pool = []
