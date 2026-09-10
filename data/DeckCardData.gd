extends RefCounted
class_name DeckCardData

## Represents a card in the deck with upgrades and transcend state
## Used for save/load and deck management

var instance_id: String = ""  # Unique identifier for this card instance
var card_id: String = ""
var owner_character_id: String = ""  # Character who owns this card instance
var applied_upgrades: Array[String] = []  # Upgrade IDs applied to this card
var is_transcended: bool = false
var transcendent_card_id: String = ""  # If transcended, the new card ID
var is_temporary: bool = false  # Temporary cards removed at end of combat

func _init(p_card_id: String = "", p_owner_id: String = "", p_upgrades: Array[String] = [], p_transcended: bool = false, p_transcendent_id: String = "", p_instance_id: String = "", p_is_temporary: bool = false):
	card_id = p_card_id
	owner_character_id = p_owner_id
	if p_upgrades:
		applied_upgrades = p_upgrades.duplicate()
	else:
		applied_upgrades = []
	is_transcended = p_transcended
	transcendent_card_id = p_transcendent_id
	is_temporary = p_is_temporary
	
	# Generate instance_id if not provided (UUID-style random string)
	if p_instance_id.is_empty():
		instance_id = _generate_instance_id()
	else:
		instance_id = p_instance_id

static func _generate_instance_id() -> String:
	## Generate a UUID-style unique identifier
	## Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
	var chars = "0123456789abcdef"
	var result = ""
	var pattern = [8, 4, 4, 4, 12]
	for group_size in pattern:
		if result != "":
			result += "-"
		for i in range(group_size):
			result += chars[randi() % chars.length()]
	return result

func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"card_id": card_id,
		"owner_character_id": owner_character_id,
		"applied_upgrades": applied_upgrades,
		"is_transcended": is_transcended,
		"transcendent_card_id": transcendent_card_id,
		"is_temporary": is_temporary
	}

static func from_dict(data: Dictionary) -> DeckCardData:
	var upgrades_data = data.get("applied_upgrades", [])
	var upgrades_array: Array[String] = []
	for item in upgrades_data:
		if item is String:
			upgrades_array.append(item)
	return DeckCardData.new(
		data.get("card_id", ""),
		data.get("owner_character_id", ""),
		upgrades_array,
		data.get("is_transcended", false),
		data.get("transcendent_card_id", ""),
		data.get("instance_id", ""),  # Restore instance_id exactly as saved
		data.get("is_temporary", false)
	)
