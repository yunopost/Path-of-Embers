extends Resource
class_name CharacterData

## Character data with starter cards, rewards, and quest references

@export var id: String = ""
@export var display_name: String = ""
@export var role: String = ""  # e.g., "Warrior", "Healer", "Defender"
@export var portrait_path: String = ""
@export var fullbody_path: String = ""
@export var starter_unique_cards: Array[CardData] = []  # Exactly 2 unique cards
@export var reward_card_pool: Array[CardData] = []  # Cards available as rewards
@export var quest: QuestData = null  # QuestData reference

func _init():
	starter_unique_cards = []
	reward_card_pool = []
