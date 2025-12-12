extends RefCounted
class_name DeckCardData

## Represents a card in the deck with upgrades and transcend state
## Used for save/load and deck management

var card_id: String = ""
var applied_upgrades: Array = []  # Upgrade IDs applied to this card
var is_transcended: bool = false
var transcendent_card_id: String = ""  # If transcended, the new card ID

func _init(p_card_id: String = "", p_upgrades: Array = [], p_transcended: bool = false, p_transcendent_id: String = ""):
	card_id = p_card_id
	applied_upgrades = p_upgrades if p_upgrades else []
	is_transcended = p_transcended
	transcendent_card_id = p_transcendent_id

func to_dict() -> Dictionary:
	return {
		"card_id": card_id,
		"applied_upgrades": applied_upgrades,
		"is_transcended": is_transcended,
		"transcendent_card_id": transcendent_card_id
	}

static func from_dict(data: Dictionary) -> DeckCardData:
	return DeckCardData.new(
		data.get("card_id", ""),
		data.get("applied_upgrades", []),
		data.get("is_transcended", false),
		data.get("transcendent_card_id", "")
	)
