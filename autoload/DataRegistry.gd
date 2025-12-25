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
	_initialize_full_attack_transcendence()
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
	
	# Full Attack upgrade pool
	var full_attack_upgrades: Array[String] = [
		"full_attack_ignore_block",
		"upgrade_cost_minus_1",  # Universal upgrade (note: not full_attack_cost_minus_1)
		"full_attack_damage_plus_6",
		"full_attack_half_damage_double_hit",
		"full_attack_remove_slow",
		"full_attack_block_plus_6"
	]
	card_upgrade_pools["monster_hunter_full_attack"] = full_attack_upgrades
	
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
	
	# Full Attack upgrade definitions
	upgrade_definitions["full_attack_ignore_block"] = {
		"id": "full_attack_ignore_block",
		"title": "Ignore Block",
		"description": "Damage bypasses block completely",
		"effects": {
			"ignore_block": true
		}
	}
	
	upgrade_definitions["full_attack_damage_plus_6"] = {
		"id": "full_attack_damage_plus_6",
		"title": "Damage+6",
		"description": "Increase damage by 6",
		"effects": {
			"damage_delta": 6
		}
	}
	
	upgrade_definitions["full_attack_half_damage_double_hit"] = {
		"id": "full_attack_half_damage_double_hit",
		"title": "Half Damage, Double Hit",
		"description": "Damage becomes 7, strikes twice",
		"effects": {
			"damage_multiply": 0.5,  # Multiply base damage by 0.5
			"hit_count_set": 2  # Set hit_count to 2
		}
	}
	
	upgrade_definitions["full_attack_remove_slow"] = {
		"id": "full_attack_remove_slow",
		"title": "Remove Slow",
		"description": "Removes Slow keyword",
		"effects": {
			"remove_keyword": "Slow"
		}
	}
	
	upgrade_definitions["full_attack_block_plus_6"] = {
		"id": "full_attack_block_plus_6",
		"title": "Block+6",
		"description": "Also gain 6 block when played",
		"effects": {
			"add_block": 6
		}
	}

func get_upgrade_pool_for_card(card_id: String) -> Array[String]:
	## Get the upgrade pool for a card ID
	## If card has a specific pool, return ONLY that pool (no universal upgrades added)
	## If card has no specific pool, return universal upgrades
	var card_specific_pool = card_upgrade_pools.get(card_id, null)
	
	# If card has a specific pool, return it as-is (no universal upgrades added)
	if card_specific_pool != null:
		var result_pool: Array[String] = []
		for upgrade_id in card_specific_pool:
			if upgrade_id is String and not result_pool.has(upgrade_id):
				result_pool.append(upgrade_id)
		return result_pool
	
	# If no card-specific pool exists, return universal upgrades
	var universal_upgrades: Array[String] = ["upgrade_cost_minus_1", "upgrade_haste"]
	return universal_upgrades

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
	
	# Curse card (no effects, unplayable)
	var curse_card = CardData.new()
	curse_card.id = "curse_card"
	curse_card.name = "Curse"
	curse_card.card_type = CardData.CardType.CURSE
	curse_card.cost = 0
	curse_card.targeting_mode = CardData.TargetingMode.NONE
	# No effects - curse cards do nothing
	generic_card_cache["curse_card"] = curse_card

func _initialize_enemies():
	## Initialize enemy definitions (currently hardcoded, later can load from .tres files)
	
	# Ash Men - Act 1 enemy
	var ash_man = EnemyData.new()
	ash_man.id = "ash_man"
	ash_man.display_name = "Ash Man"
	ash_man.name = "Ash Man"  # Legacy field
	ash_man.act = 1
	ash_man.min_hp = 6
	ash_man.max_hp = 6
	
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
	
	ash_man.moves.append(move_1)
	ash_man.moves.append(move_2)
	ash_man.moves.append(move_3)
	ash_man.moves.append(move_4)
	register_enemy(ash_man)

func _initialize_full_attack_transcendence():
	## Initialize Full Attack transcendence cards
	
	# Transcend 1: Cost 3, Slow, Deal 18 damage to each enemy, Apply 2 Vulnerable to each enemy
	var transcend_1 = CardData.new()
	transcend_1.id = "full_attack_transcend_1"
	transcend_1.name = "Full Attack"
	transcend_1.cost = 3
	transcend_1.card_type = CardData.CardType.ATTACK
	transcend_1.targeting_mode = CardData.TargetingMode.ALL_ENEMIES
	transcend_1.keywords.append("Slow")
	var damage_effect_1 = EffectData.new("damage", {"amount": 18})
	transcend_1.base_effects.append(damage_effect_1)
	var vulnerable_effect_1 = EffectData.new("vulnerable", {"duration": 2})
	transcend_1.base_effects.append(vulnerable_effect_1)
	transcendent_card_cache[transcend_1.id] = transcend_1
	
	# Transcend 2: Cost 2, Slow, Deal 18 damage OR 36 damage if Elite/Boss
	var transcend_2 = CardData.new()
	transcend_2.id = "full_attack_transcend_2"
	transcend_2.name = "Full Attack"
	transcend_2.cost = 2
	transcend_2.card_type = CardData.CardType.ATTACK
	transcend_2.targeting_mode = CardData.TargetingMode.ENEMY
	transcend_2.keywords.append("Slow")
	var conditional_damage = EffectData.new("damage_conditional_elite", {"normal_amount": 18, "elite_amount": 36})
	transcend_2.base_effects.append(conditional_damage)
	transcendent_card_cache[transcend_2.id] = transcend_2
	
	# Transcend 3: Cost Discard X, Slow, Deal 9 damage X times
	# Note: Discard cost handled separately in card play logic, hit_count set dynamically
	var transcend_3 = CardData.new()
	transcend_3.id = "full_attack_transcend_3"
	transcend_3.name = "Full Attack"
	transcend_3.cost = 1  # Display cost (not used for discard cost type)
	transcend_3.cost_type = CardData.CostType.DISCARD
	transcend_3.discard_cost_amount = 1  # Default X=1, can be modified if needed
	transcend_3.card_type = CardData.CardType.ATTACK
	transcend_3.targeting_mode = CardData.TargetingMode.ENEMY
	transcend_3.keywords.append("Slow")
	# Damage amount is 9, hit_count will be set dynamically to X (cards discarded) during play
	var damage_effect_3 = EffectData.new("damage", {"amount": 9, "hit_count": 1})  # hit_count set dynamically
	transcend_3.base_effects.append(damage_effect_3)
	transcendent_card_cache[transcend_3.id] = transcend_3
