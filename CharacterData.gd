extends Resource
class_name CharacterData

## Character data with starter cards, rewards, and quest references

@export var id: String = ""
@export var name: String = ""
@export var role: String = ""  # e.g., "Warrior", "Mage", etc.
@export var portrait_path: String = ""
@export var fullbody_path: String = ""
@export var generic_starter_cards: Array[String] = []  # Card IDs (3 cards)
@export var unique_starter_cards: Array[String] = []  # Card IDs (2 cards)
@export var reward_card_pool: Array[String] = []  # Card IDs available as rewards
@export var quest_data_id: String = ""  # Reference to QuestData

func _init():
	generic_starter_cards = []
	unique_starter_cards = []
	reward_card_pool = []

