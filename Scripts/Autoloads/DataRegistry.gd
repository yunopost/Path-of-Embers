extends Node

## Autoload singleton - Provides access to CharacterData and CardData resources
## For Slice 5, stores character data in memory from CharacterSelect
## Later can be extended to load from .tres files

var character_cache: Dictionary = {}  # Maps character_id -> CharacterData

func register_character(char_data: CharacterData):
	## Register a CharacterData resource
	if char_data and char_data.id:
		character_cache[char_data.id] = char_data

func get_character(character_id: String) -> CharacterData:
	## Get CharacterData by ID, returns null if not found
	return character_cache.get(character_id, null)

func get_character_display_name(character_id: String) -> String:
	## Get character display name, returns ID as fallback
	var char_data = get_character(character_id)
	if char_data:
		return char_data.display_name
	return character_id

func clear_cache():
	## Clear the character cache (useful for new runs)
	character_cache.clear()

