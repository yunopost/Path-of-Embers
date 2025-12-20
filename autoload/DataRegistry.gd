extends Node

## Autoload singleton - Provides access to CharacterData and CardData resources
## For Slice 5, stores character data in memory from CharacterSelect
## Later can be extended to load from .tres files

var character_cache: Dictionary = {}  # Maps character_id -> CharacterData

# Enemy cache
var enemy_cache: Dictionary = {}  # Maps enemy_id -> EnemyData

# Upgrade definitions cache
var upgrade_definitions: Dictionary = {}  # Maps upgrade_id -> Dictionary with title, description, etc.
var card_upgrade_pools: Dictionary = {}  # Maps card_id -> Array[upgrade_id]

# Transcendent placeholder cards cache
var transcendent_card_cache: Dictionary = {}  # Maps card_id -> CardData for transcendent placeholders

# Generic card cache (for cards like strike_1, defend_1, heal_1)
var generic_card_cache: Dictionary = {}  # Maps card_id -> CardData for generic cards

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

func register_enemy(enemy_data: EnemyData):
	## Register an EnemyData resource
	if enemy_data and enemy_data.id:
		enemy_cache[enemy_data.id] = enemy_data

func get_enemy(enemy_id: String) -> EnemyData:
	## Get EnemyData by ID, returns null if not found
	return enemy_cache.get(enemy_id, null)

func _ready():
	## Initialize upgrade pools and definitions
	_initialize_upgrade_content()
	_initialize_transcendent_cards()
	_initialize_generic_cards()
	_initialize_enemies()

func _initialize_upgrade_content():
	## Initialize hardcoded upgrade content for testing
	
	# Universal upgrades (available to all cards)
	var universal_upgrades: Array[String] = [
		"upgrade_cost_minus_1",
		"upgrade_haste"
	]
	
	# Upgrade definitions - Universal upgrades
	upgrade_definitions["upgrade_cost_minus_1"] = {
		"id": "upgrade_cost_minus_1",
		"title": "-1 Cost",
		"description": "Costs 1 less (minimum 0).",
		"effects": {
			"cost_delta": -1
		},
		"rules": {
			"max_stacks": 1,
			"group": "cost"
		}
	}
	upgrade_definitions["upgrade_haste"] = {
		"id": "upgrade_haste",
		"title": "Haste",
		"description": "Playing this card does not advance the enemy turn.",
		"keyword": "Haste",
		"effects": {
			"timer_tick_override": 0
		},
		"rules": {
			"max_stacks": 1,
			"group": "tempo"
		}
	}
	
	# Slow keyword definition (for tooltip support)
	upgrade_definitions["keyword_slow"] = {
		"id": "keyword_slow",
		"title": "Slow",
		"description": "A card with Slow ticks the enemy timer 2 times instead of 1.",
		"keyword": "Slow"
	}
	
	# Exhaust keyword definition (for tooltip support, future use)
	upgrade_definitions["keyword_exhaust"] = {
		"id": "keyword_exhaust",
		"title": "Exhaust",
		"description": "Card is removed from play for the rest of this combat instead of going to the discard pile.",
		"keyword": "Exhaust"
	}
	
	# Vulnerable keyword definition (for tooltip support)
	upgrade_definitions["keyword_vulnerable"] = {
		"id": "keyword_vulnerable",
		"title": "Vulnerable",
		"description": "A vulnerable character or enemy takes 1.5x damage.",
		"keyword": "Vulnerable"
	}
	
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
	
	# Upgrade definitions - Card-specific upgrades
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
	## Always includes universal upgrades (upgrade_cost_minus_1, upgrade_haste)
	var card_specific_pool = card_upgrade_pools.get(card_id, null)
	var result_pool: Array[String] = []
	
	# Add card-specific upgrades if they exist
	if card_specific_pool != null:
		for upgrade_id in card_specific_pool:
			if upgrade_id is String and not result_pool.has(upgrade_id):
				result_pool.append(upgrade_id)
	
	# Always add universal upgrades (if not already present)
	var universal_upgrades = ["upgrade_cost_minus_1", "upgrade_haste"]
	for upgrade_id in universal_upgrades:
		if not result_pool.has(upgrade_id):
			result_pool.append(upgrade_id)
	
	# If no card-specific pool exists, return just universal upgrades
	return result_pool

func get_upgrade_def(upgrade_id: String) -> Dictionary:
	## Get upgrade definition by ID
	return upgrade_definitions.get(upgrade_id, {})

func get_all_upgrade_definitions() -> Dictionary:
	## Get all upgrade definitions (for keyword tooltip lookup)
	return upgrade_definitions.duplicate()

func get_card_data(card_id: String) -> CardData:
	## Get CardData by card_id
	## Returns null if not found
	# Check generic card cache first (most common)
	if generic_card_cache.has(card_id):
		var card_data = generic_card_cache[card_id]
		if card_data and card_data is CardData:
			return card_data
	
	# Check transcendent card cache
	if transcendent_card_cache.has(card_id):
		var card_data = transcendent_card_cache[card_id]
		if card_data and card_data is CardData:
			return card_data
	
	# Search through registered characters' cards
	for character_id in character_cache:
		var char_data = character_cache[character_id]
		if not char_data:
			continue
		
		# Check starter cards
		for card_data in char_data.starter_unique_cards:
			if card_data and card_data.id == card_id:
				return card_data
		
		# Check reward card pool
		for card_data in char_data.reward_card_pool:
			if card_data and card_data.id == card_id:
				return card_data
	
	return null

func get_card_display_name(card_id: String) -> String:
	## Get card display name from registered characters' cards
	## Returns formatted card_id as fallback
	var card_data = get_card_data(card_id)
	if card_data:
		return card_data.name
	
	# Fallback: format card_id nicely
	# e.g., "strike_1" -> "Strike", "defend" -> "Defend"
	var formatted = card_id.replace("_", " ")
	# Capitalize first letter of each word
	var parts = formatted.split(" ")
	for i in range(parts.size()):
		if parts[i].length() > 0:
			parts[i] = parts[i][0].to_upper() + parts[i].substr(1)
	return " ".join(parts)

func _initialize_transcendent_cards():
	## Initialize 4 placeholder transcendent cards
	## PLACEHOLDER FOR FUTURE WORK: These cards exist for testing game loop,
	## but transcendence upgrade logic is not implemented. The upgrade flow
	## does not use these cards even when is_transcendence_upgrade flag is set.
	for i in range(1, 5):
		var card_id = "transcend_placeholder_%d" % i
		var card_data = CardData.new()
		card_data.id = card_id
		card_data.name = "Transcendent Card %d" % i
		card_data.cost = 0
		# Note: CardData doesn't have a description property, effects are in base_effects
		# For placeholders, we leave base_effects empty
		transcendent_card_cache[card_id] = card_data

func get_transcendent_card_ids() -> Array[String]:
	## Get all available transcendent placeholder card IDs
	return transcendent_card_cache.keys()

func get_transcendent_card(card_id: String) -> CardData:
	## Get a transcendent card by ID
	return transcendent_card_cache.get(card_id, null)

func _initialize_generic_cards():
	## Initialize generic cards (strike_1, defend_1, heal_1)
	## These are basic cards available to all characters
	
	# Strike 1 - Basic attack card
	var strike_1 = CardData.new()
	strike_1.id = "strike_1"
	strike_1.name = "Strike"
	strike_1.cost = 1
	strike_1.card_type = CardData.CardType.ATTACK
	strike_1.targeting_mode = CardData.TargetingMode.ENEMY
	var strike_damage = EffectData.new("damage", {"amount": 6})
	strike_1.base_effects.append(strike_damage)
	generic_card_cache["strike_1"] = strike_1
	
	# Defend 1 - Basic block card
	var defend_1 = CardData.new()
	defend_1.id = "defend_1"
	defend_1.name = "Defend"
	defend_1.cost = 1
	defend_1.card_type = CardData.CardType.SKILL
	defend_1.targeting_mode = CardData.TargetingMode.SELF
	var defend_block = EffectData.new("block", {"amount": 5})
	defend_1.base_effects.append(defend_block)
	generic_card_cache["defend_1"] = defend_1
	
	# Heal 1 - Basic heal card
	var heal_1 = CardData.new()
	heal_1.id = "heal_1"
	heal_1.name = "Heal"
	heal_1.cost = 1
	heal_1.card_type = CardData.CardType.SKILL
	heal_1.targeting_mode = CardData.TargetingMode.SELF
	var heal_effect = EffectData.new("heal", {"amount": 5})
	heal_1.base_effects.append(heal_effect)
	generic_card_cache["heal_1"] = heal_1

func _initialize_enemies():
	## Initialize enemy definitions (currently hardcoded, later can load from .tres files)
	
	# Ash Men - Act 1 enemy
	var ash_man = EnemyData.new()
	ash_man.id = "ash_man"
	ash_man.display_name = "Ash Man"
	ash_man.name = "Ash Man"  # Legacy field
	ash_man.act = 1
	ash_man.min_hp = 38
	ash_man.max_hp = 44
	
	# Move 1: Timer 4, Damage 8
	var move_1 = {
		"id": "move_1",
		"timer": 4,
		"telegraph_text": "Attack 8",
		"effects": [
			EffectData.new("damage", {"amount": 8})
		]
	}
	
	# Move 2: Timer 1, Vulnerable 1
	var move_2 = {
		"id": "move_2",
		"timer": 1,
		"telegraph_text": "Apply Vulnerable",
		"effects": [
			EffectData.new("vulnerable", {"duration": 1})
		]
	}
	
	# Move 3: Timer 4, Damage 2, Heal 2
	var move_3 = {
		"id": "move_3",
		"timer": 4,
		"telegraph_text": "Attack 2, Heal 2",
		"effects": [
			EffectData.new("damage", {"amount": 2}),
			EffectData.new("heal", {"amount": 2})
		]
	}
	
	# Move 4: Timer 3, Damage 3x2 (3 damage twice)
	var move_4 = {
		"id": "move_4",
		"timer": 3,
		"telegraph_text": "Attack 3x2",
		"effects": [
			EffectData.new("damage", {"amount": 3, "hit_count": 2})
		]
	}
	
	ash_man.moves = [move_1, move_2, move_3, move_4]
	register_enemy(ash_man)
