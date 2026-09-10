extends Node

## Autoload singleton - Manages party composition and character data
## Handles party-related state and signals

signal party_changed

var party: Array = []  # Legacy format (kept for backward compatibility)
var party_ids: Array[String] = []  # Array of 3 character IDs

func set_party(character_ids: Array[String]):
	## Set the party to the given character IDs (must be exactly 3)
	if character_ids.size() != 3:
		push_error("Party must contain exactly 3 characters, got %d" % character_ids.size())
		return
	party_ids = character_ids.duplicate()
	party = character_ids.duplicate()  # Keep legacy party for compatibility
	party_changed.emit()

func get_party_ids() -> Array[String]:
	## Get array of party character IDs
	return party_ids.duplicate()

func clear_party():
	## Clear the party
	party.clear()
	party_ids.clear()
	party_changed.emit()

func get_party_size() -> int:
	## Get current party size
	return party_ids.size()

