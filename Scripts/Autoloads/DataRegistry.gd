extends Node

## Autoload singleton - Provides access to CharacterData and CardData resources
## For Slice 5, stores character data in memory from CharacterSelect
## Later can be extended to load from .tres files

var character_cache: Dictionary = {}  # Maps character_id -> CharacterData

# Upgrade definitions cache
var upgrade_definitions: Dictionary = {}  # Maps upgrade_id -> Dictionary with title, description, etc.
var card_upgrade_pools: Dictionary = {}  # Maps card_id -> Array[upgrade_id]

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

func _ready():
	## Initialize upgrade pools and definitions
	_initialize_upgrade_content()

func _initialize_upgrade_content():
	## Initialize hardcoded upgrade content for testing
	# Strike upgrades
	var strike_upgrades: Array[String] = [
		"strike_damage_plus",
		"strike_draw",
		"strike_energy",
		"strike_block"
	]
	card_upgrade_pools["strike_1"] = strike_upgrades
	card_upgrade_pools["strike"] = strike_upgrades  # Alias
	
	# Defend upgrades
	var defend_upgrades: Array[String] = [
		"defend_block_plus",
		"defend_retain",
		"defend_draw",
		"defend_exhaust_heal"
	]
	card_upgrade_pools["defend_1"] = defend_upgrades
	card_upgrade_pools["defend"] = defend_upgrades  # Alias
	
	# Upgrade definitions
	upgrade_definitions["strike_damage_plus"] = {
		"id": "strike_damage_plus",
		"title": "Damage+",
		"description": "Increase damage by 2"
	}
	upgrade_definitions["strike_draw"] = {
		"id": "strike_draw",
		"title": "Draw Card",
		"description": "Draw 1 card when played"
	}
	upgrade_definitions["strike_energy"] = {
		"id": "strike_energy",
		"title": "Energy+",
		"description": "Gain 1 energy when played"
	}
	upgrade_definitions["strike_block"] = {
		"id": "strike_block",
		"title": "Block+",
		"description": "Also gain 3 block"
	}
	upgrade_definitions["defend_block_plus"] = {
		"id": "defend_block_plus",
		"title": "Block+",
		"description": "Increase block by 2"
	}
	upgrade_definitions["defend_retain"] = {
		"id": "defend_retain",
		"title": "Retain",
		"description": "Card stays in hand if not played"
	}
	upgrade_definitions["defend_draw"] = {
		"id": "defend_draw",
		"title": "Draw Card",
		"description": "Draw 1 card when played"
	}
	upgrade_definitions["defend_exhaust_heal"] = {
		"id": "defend_exhaust_heal",
		"title": "Healing Block",
		"description": "Heal 2 HP when played"
	}

func get_upgrade_pool_for_card(card_id: String) -> Array[String]:
	## Get the upgrade pool for a card ID
	var pool = card_upgrade_pools.get(card_id, null)
	if pool == null:
		return [] as Array[String]
	# Ensure we return Array[String]
	if pool is Array[String]:
		return pool
	# Convert plain Array to Array[String] (fallback for safety)
	var typed_pool: Array[String] = []
	for item in pool:
		if item is String:
			typed_pool.append(item)
	return typed_pool

func get_upgrade_def(upgrade_id: String) -> Dictionary:
	## Get upgrade definition by ID
	return upgrade_definitions.get(upgrade_id, {})
