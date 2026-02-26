extends Node

## Autoload singleton - Provides access to CharacterData and CardData resources
## Loads resources from .tres files and provides caching/registry functionality

# Data directory paths (relative to res://)
const DATA_DIR_CARDS = "res://Path-of-Embers/data/cards/"
const DATA_DIR_CHARACTERS = "res://Path-of-Embers/data/characters/"
const DATA_DIR_ENEMIES = "res://Path-of-Embers/data/enemies/"
const DATA_DIR_UPGRADES = "res://Path-of-Embers/data/upgrades/"

var character_cache: Dictionary = {}  # Maps character_id -> CharacterData

# Enemy cache
var enemy_cache: Dictionary = {}  # Maps enemy_id -> EnemyData

# Upgrade cache
var upgrade_resource_cache: Dictionary = {}  # Maps upgrade_id -> UpgradeData Resource
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

func _load_all_resources():
	## Load all resources from .tres files
	## All game data must be provided as .tres resource files - no hardcoded fallbacks
	
	# Load resources from files
	var loaded_cards = _load_resources_from_directory(DATA_DIR_CARDS, "CardData")
	var loaded_enemies = _load_resources_from_directory(DATA_DIR_ENEMIES, "EnemyData")
	var loaded_characters = _load_resources_from_directory(DATA_DIR_CHARACTERS, "CharacterData")
	var loaded_upgrades = _load_resources_from_directory(DATA_DIR_UPGRADES, "UpgradeData")
	
	# Cache loaded cards
	for card in loaded_cards:
		if card and card is CardData and not card.id.is_empty():
			if _validate_card_resource(card):
				generic_card_cache[card.id] = card
	
	# Cache loaded enemies
	for enemy in loaded_enemies:
		if enemy and enemy is EnemyData and not enemy.id.is_empty():
			if _validate_enemy_resource(enemy):
				register_enemy(enemy)
	
	# Cache loaded characters
	for character in loaded_characters:
		if character and character is CharacterData and not character.id.is_empty():
			if _validate_character_resource(character):
				register_character(character)
	
	# Cache loaded upgrades and build upgrade pools
	for upgrade in loaded_upgrades:
		if upgrade and upgrade is UpgradeData and not upgrade.id.is_empty():
			if _validate_upgrade_resource(upgrade):
				upgrade_resource_cache[upgrade.id] = upgrade
				# Build upgrade pools from applies_to_cards field
				for card_id in upgrade.applies_to_cards:
					if not card_upgrade_pools.has(card_id):
						card_upgrade_pools[card_id] = []
					if not card_upgrade_pools[card_id].has(upgrade.id):
						card_upgrade_pools[card_id].append(upgrade.id)
	
	# Log loading summary
	var total_loaded = loaded_cards.size() + loaded_enemies.size() + loaded_characters.size() + loaded_upgrades.size()
	if total_loaded == 0:
		push_error("DataRegistry: No resource files found! Please create .tres files in data directories.")
	else:
		print("DataRegistry: Loaded %d cards, %d enemies, %d characters, %d upgrades" % [loaded_cards.size(), loaded_enemies.size(), loaded_characters.size(), loaded_upgrades.size()])

func _load_resources_from_directory(path: String, resource_type_name: String) -> Array:
	## Load all .tres files of the specified resource type from a directory
	## Returns Array of loaded resources (empty if directory doesn't exist or has no valid files)
	## resource_type_name should be the class_name string (e.g., "CardData", "EnemyData")
	var resources: Array = []
	
	# Check if directory exists
	if not DirAccess.dir_exists_absolute(path):
		push_warning("DataRegistry: Directory does not exist: %s" % path)
		return resources
	
	var dir = DirAccess.open(path)
	if not dir:
		push_error("DataRegistry: Failed to open directory: %s" % path)
		return resources
	
	# Iterate through files in directory
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = path + file_name
			var resource = load(full_path)
			
			# Validate resource type by checking class name
			if resource:
				var script = resource.get_script()
				if script and script.get_global_name() == resource_type_name:
					resources.append(resource)
				else:
					var actual_type = script.get_global_name() if script else "unknown"
					push_error("DataRegistry: Invalid resource type in %s (expected %s, got %s)" % [full_path, resource_type_name, actual_type])
		
		file_name = dir.get_next()
	
	return resources

func _validate_card_resource(card: CardData) -> bool:
	## Validate a CardData resource has required fields
	if card.id.is_empty():
		push_error("DataRegistry: Card resource missing id")
		return false
	if card.name.is_empty():
		push_warning("DataRegistry: Card '%s' missing name" % card.id)
	return true

func _validate_enemy_resource(enemy: EnemyData) -> bool:
	## Validate an EnemyData resource has required fields
	if enemy.id.is_empty():
		push_error("DataRegistry: Enemy resource missing id")
		return false
	if enemy.display_name.is_empty() and enemy.name.is_empty():
		push_warning("DataRegistry: Enemy '%s' missing display_name" % enemy.id)
	return true

func _validate_character_resource(character: CharacterData) -> bool:
	## Validate a CharacterData resource has required fields
	if character.id.is_empty():
		push_error("DataRegistry: Character resource missing id")
		return false
	return true

func _validate_upgrade_resource(upgrade: UpgradeData) -> bool:
	## Validate an UpgradeData resource has required fields
	if upgrade.id.is_empty():
		push_error("DataRegistry: Upgrade resource missing id")
		return false
	if upgrade.name.is_empty():
		push_warning("DataRegistry: Upgrade '%s' missing name" % upgrade.id)
	return true

func _build_upgrade_dict_from_resource(upgrade: UpgradeData) -> Dictionary:
	## Build Dictionary from UpgradeData Resource for legacy code compatibility
	## Prefer using get_upgrade_resource() instead
	if not upgrade or not upgrade.id:
		return {}
	
	var upgrade_dict = {
		"id": upgrade.id,
		"title": upgrade.name,
		"description": upgrade.description
	}
	
	# Merge effects_dict if present (legacy format)
	if upgrade.effects_dict and upgrade.effects_dict.size() > 0:
		if not upgrade_dict.has("effects"):
			upgrade_dict["effects"] = {}
		for key in upgrade.effects_dict:
			upgrade_dict["effects"][key] = upgrade.effects_dict[key]
	
	return upgrade_dict

func register_enemy(enemy_data: EnemyData):
	## Register an EnemyData resource
	if enemy_data and enemy_data.id:
		enemy_cache[enemy_data.id] = enemy_data

func get_enemy(enemy_id: String) -> EnemyData:
	## Get EnemyData by ID, returns null if not found
	return enemy_cache.get(enemy_id, null)

func _ready():
	## Load all resources from .tres files
	_load_all_resources()
	## Register placeholder characters if no .tres characters were loaded
	## (Placeholder logic runs until real CharacterData .tres files exist)
	if character_cache.is_empty():
		_create_placeholder_characters()

func get_all_characters() -> Array[CharacterData]:
	## Return all registered CharacterData sorted by id
	var result: Array[CharacterData] = []
	for char_data in character_cache.values():
		result.append(char_data)
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

func _create_placeholder_characters():
	## Create and register placeholder CharacterData in lieu of .tres files.
	## Mirrors the data in CharacterSelect._create_placeholder_characters().
	## Remove this function once real CharacterData .tres files exist in data/characters/.

	# ---- Warriors ----
	for i in range(2):
		var char_data = CharacterData.new()
		char_data.id = "warrior_%d" % (i + 1)
		char_data.display_name = "Monster Hunter" if i == 0 else "Shadowfoot"
		char_data.role = "Warrior"
		char_data.portrait_path = ""

		if i == 0:
			var full_attack = CardData.new()
			full_attack.id = "monster_hunter_full_attack"
			full_attack.name = "Full Attack"
			full_attack.cost = 2
			full_attack.card_type = CardData.CardType.ATTACK
			full_attack.targeting_mode = CardData.TargetingMode.ENEMY
			full_attack.owner_character_id = "warrior_1"
			full_attack.rarity = CardData.Rarity.COMMON
			full_attack.keywords.append("Slow")
			full_attack.base_effects.append(EffectData.new(EffectType.DAMAGE, {"amount": 14}))
			char_data.starter_unique_cards.append(full_attack)

			var shoulder_tackle = CardData.new()
			shoulder_tackle.id = "monster_hunter_shoulder_tackle"
			shoulder_tackle.name = "Shoulder Tackle"
			shoulder_tackle.cost = 0
			shoulder_tackle.card_type = CardData.CardType.SKILL
			shoulder_tackle.targeting_mode = CardData.TargetingMode.SELF
			shoulder_tackle.owner_character_id = "warrior_1"
			shoulder_tackle.rarity = CardData.Rarity.COMMON
			shoulder_tackle.base_effects.append(EffectData.new(EffectType.GRANT_HASTE_NEXT_CARD, {}))
			char_data.starter_unique_cards.append(shoulder_tackle)
		else:
			var dark_knife = CardData.new()
			dark_knife.id = "shadowfoot_dark_knife"
			dark_knife.name = "Dark Knife"
			dark_knife.cost = 1
			dark_knife.card_type = CardData.CardType.ATTACK
			dark_knife.targeting_mode = CardData.TargetingMode.ENEMY
			dark_knife.owner_character_id = "warrior_2"
			dark_knife.rarity = CardData.Rarity.COMMON
			dark_knife.base_effects.append(EffectData.new(EffectType.DAMAGE, {"amount": 6, "double_strength": true}))
			char_data.starter_unique_cards.append(dark_knife)

			var fade_step = CardData.new()
			fade_step.id = "shadowfoot_fade_step"
			fade_step.name = "Fade Step"
			fade_step.cost = 1
			fade_step.card_type = CardData.CardType.SKILL
			fade_step.targeting_mode = CardData.TargetingMode.SELF
			fade_step.owner_character_id = "warrior_2"
			fade_step.rarity = CardData.Rarity.COMMON
			fade_step.base_effects.append(EffectData.new(EffectType.BLOCK, {"amount": 4}))
			fade_step.base_effects.append(EffectData.new(EffectType.CONDITIONAL_STRENGTH_IF_NO_DAMAGE, {"amount": 1}))
			char_data.starter_unique_cards.append(fade_step)

		# Set themes
		if i == 0:  # Monster Hunter
			char_data.theme_1 = "Timer Manipulation"
			char_data.theme_2 = "Vulnerability"
			char_data.theme_3 = "Elite Hunter"
		else:  # Shadowfoot
			char_data.theme_1 = "Fast Actions"
			char_data.theme_2 = "Combo Chains"
			char_data.theme_3 = "Untouchable"

		_generate_placeholder_reward_pool(char_data)

		var quest = QuestData.new()
		quest.id = "quest_warrior_%d" % (i + 1)
		if i == 0:
			quest.title = "Monster Hunter Quest"
			quest.description = "Complete %d nodes" % 10
			quest.progress_max = 10
			quest.tracking_type = "complete_nodes"
		else:
			quest.title = "Shadowfoot Quest"
			quest.description = "Complete combat without taking damage %d times" % 6
			quest.progress_max = 6
			quest.tracking_type = "combat_no_damage"
		char_data.quest = quest
		register_character(char_data)

	# ---- Healers ----
	for i in range(2):
		var char_data = CharacterData.new()
		char_data.id = "healer_%d" % (i + 1)
		char_data.display_name = "Witch" if i == 0 else "Wanderer"
		char_data.role = "Healer"
		char_data.portrait_path = ""

		if i == 0:
			var hexbound = CardData.new()
			hexbound.id = "witch_hexbound_ritual"
			hexbound.name = "Hexbound Ritual"
			hexbound.cost = 0
			hexbound.card_type = CardData.CardType.SKILL
			hexbound.targeting_mode = CardData.TargetingMode.SELF
			hexbound.owner_character_id = "healer_1"
			hexbound.rarity = CardData.Rarity.COMMON
			hexbound.base_effects.append(EffectData.new(EffectType.ADD_CURSE_TO_HAND, {"is_temporary": true}))
			hexbound.base_effects.append(EffectData.new(EffectType.VULNERABLE_ALL_ENEMIES, {"duration": 2}))
			char_data.starter_unique_cards.append(hexbound)

			var malediction = CardData.new()
			malediction.id = "witch_malediction_lash"
			malediction.name = "Malediction Lash"
			malediction.cost = 1
			malediction.card_type = CardData.CardType.ATTACK
			malediction.targeting_mode = CardData.TargetingMode.ALL_ENEMIES
			malediction.owner_character_id = "healer_1"
			malediction.rarity = CardData.Rarity.COMMON
			malediction.base_effects.append(EffectData.new(EffectType.DAMAGE_PER_CURSE, {"base_amount": 2, "per_curse": 2}))
			char_data.starter_unique_cards.append(malediction)
		else:
			var clear_the_way = CardData.new()
			clear_the_way.id = "wanderer_clear_the_way"
			clear_the_way.name = "Clear the way"
			clear_the_way.cost = 1
			clear_the_way.card_type = CardData.CardType.ATTACK
			clear_the_way.targeting_mode = CardData.TargetingMode.ENEMY
			clear_the_way.owner_character_id = "healer_2"
			clear_the_way.rarity = CardData.Rarity.COMMON
			clear_the_way.keywords.append("FirstCardOnly")
			clear_the_way.base_effects.append(EffectData.new(EffectType.DAMAGE, {"amount": 10}))
			char_data.starter_unique_cards.append(clear_the_way)

			var survey = CardData.new()
			survey.id = "wanderer_survey_path"
			survey.name = "Survey the Path"
			survey.cost = 2
			survey.card_type = CardData.CardType.POWER
			survey.targeting_mode = CardData.TargetingMode.SELF
			survey.owner_character_id = "healer_2"
			survey.rarity = CardData.Rarity.COMMON
			survey.base_effects.append(EffectData.new(EffectType.BLOCK_ON_ENEMY_ACT, {"amount": 1}))
			char_data.starter_unique_cards.append(survey)

		# Set themes
		if i == 0:  # Witch
			char_data.theme_1 = "Curse Generation"
			char_data.theme_2 = "Discard Payoffs"
			char_data.theme_3 = "Contagion"
		else:  # Golemancer (Wanderer)
			char_data.theme_1 = "Damage Reduction"
			char_data.theme_2 = "Heavy Strikes"
			char_data.theme_3 = "Augury"

		_generate_placeholder_reward_pool(char_data)

		var quest = QuestData.new()
		quest.id = "quest_healer_%d" % (i + 1)
		if i == 0:
			quest.title = "Witch Quest"
			quest.description = "Gain %d Curse cards" % 6
			quest.progress_max = 6
			quest.tracking_type = "gain_curse_cards"
		else:
			quest.title = "Wanderer Quest"
			quest.description = "Take the explore action at rest sites %d times" % 3
			quest.progress_max = 3
			quest.tracking_type = "rest_site_explore"
		char_data.quest = quest
		register_character(char_data)

	# ---- Defenders ----
	for i in range(2):
		var char_data = CharacterData.new()
		char_data.id = "defender_%d" % (i + 1)
		char_data.display_name = "Golemancer" if i == 0 else "Living Armor"
		char_data.role = "Defender"
		char_data.portrait_path = ""

		if i == 0:
			var stonebound = CardData.new()
			stonebound.id = "golemancer_stonebound_strike"
			stonebound.name = "Stonebound Strike"
			stonebound.cost = 1
			stonebound.card_type = CardData.CardType.ATTACK
			stonebound.targeting_mode = CardData.TargetingMode.ENEMY
			stonebound.owner_character_id = "defender_1"
			stonebound.rarity = CardData.Rarity.COMMON
			stonebound.base_effects.append(EffectData.new(EffectType.DAMAGE, {"amount": 6}))
			stonebound.base_effects.append(EffectData.new(EffectType.BLOCK, {"amount": 3}))
			char_data.starter_unique_cards.append(stonebound)

			var reinforce = CardData.new()
			reinforce.id = "golemancer_reinforce"
			reinforce.name = "Reinforce"
			reinforce.cost = 1
			reinforce.card_type = CardData.CardType.SKILL
			reinforce.targeting_mode = CardData.TargetingMode.SELF
			reinforce.owner_character_id = "defender_1"
			reinforce.rarity = CardData.Rarity.COMMON
			reinforce.base_effects.append(EffectData.new(EffectType.BLOCK, {"amount": 4}))
			reinforce.base_effects.append(EffectData.new(EffectType.ADD_TEMPORARY_UPGRADE_TO_RANDOM_HAND_CARD, {}))
			char_data.starter_unique_cards.append(reinforce)
		else:
			var plated_guard = CardData.new()
			plated_guard.id = "living_armor_plated_guard"
			plated_guard.name = "Plated Guard"
			plated_guard.cost = 1
			plated_guard.card_type = CardData.CardType.SKILL
			plated_guard.targeting_mode = CardData.TargetingMode.SELF
			plated_guard.owner_character_id = "defender_2"
			plated_guard.rarity = CardData.Rarity.COMMON
			plated_guard.base_effects.append(EffectData.new(EffectType.BLOCK, {"amount": 8}))
			plated_guard.base_effects.append(EffectData.new(EffectType.RETAIN_BLOCK_THIS_TURN, {}))
			char_data.starter_unique_cards.append(plated_guard)

			var resonant = CardData.new()
			resonant.id = "living_armor_resonant_frame"
			resonant.name = "Resonant Frame"
			resonant.cost = 1
			resonant.card_type = CardData.CardType.POWER
			resonant.targeting_mode = CardData.TargetingMode.SELF
			resonant.owner_character_id = "defender_2"
			resonant.rarity = CardData.Rarity.COMMON
			resonant.base_effects.append(EffectData.new(EffectType.DAMAGE_ON_BLOCK_GAIN, {"amount": 1}))
			char_data.starter_unique_cards.append(resonant)

		# Set themes
		if i == 0:  # Mechanist (Golemancer)
			char_data.theme_1 = "Board Control"
			char_data.theme_2 = "Legacy Cards"
			char_data.theme_3 = "Transcendence Synergy"
		else:  # Living Armor
			char_data.theme_1 = "Defense into Offense"
			char_data.theme_2 = "Escalation"
			char_data.theme_3 = "Enemy Absorption"

		_generate_placeholder_reward_pool(char_data)

		var quest = QuestData.new()
		quest.id = "quest_defender_%d" % (i + 1)
		if i == 0:
			quest.title = "Golemancer Quest"
			quest.description = "Have a card with %d upgrades" % 6
			quest.progress_max = 6
			quest.tracking_type = "card_upgrades"
		else:
			quest.title = "Living Armor Quest"
			quest.description = "Buy %d relics" % 6
			quest.progress_max = 6
			quest.tracking_type = "buy_relics"
		char_data.quest = quest
		register_character(char_data)

func _generate_placeholder_reward_pool(char_data: CharacterData):
	## Generate 22 placeholder reward pool cards (7 Common, 12 Uncommon, 3 Rare)
	var char_id = char_data.id
	for i in range(1, 8):
		var card = CardData.new()
		card.id = "%s_common_%d" % [char_id, i]
		card.name = "%s Common %d" % [char_data.display_name, i]
		card.rarity = CardData.Rarity.COMMON
		card.cost = 1
		char_data.reward_card_pool.append(card)
	for i in range(1, 13):
		var card = CardData.new()
		card.id = "%s_uncommon_%d" % [char_id, i]
		card.name = "%s Uncommon %d" % [char_data.display_name, i]
		card.rarity = CardData.Rarity.UNCOMMON
		card.cost = 1
		char_data.reward_card_pool.append(card)
	for i in range(1, 4):
		var card = CardData.new()
		card.id = "%s_rare_%d" % [char_id, i]
		card.name = "%s Rare %d" % [char_data.display_name, i]
		card.rarity = CardData.Rarity.RARE
		card.cost = 2
		char_data.reward_card_pool.append(card)

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
	
	# If no card-specific pool exists, return universal upgrades from resources
	# Universal upgrades are those that have empty applies_to_cards array (applies to all cards)
	var universal_upgrades: Array[String] = []
	for upgrade_id in upgrade_resource_cache:
		var upgrade = upgrade_resource_cache[upgrade_id]
		if upgrade and upgrade.applies_to_cards.is_empty():
			universal_upgrades.append(upgrade_id)
	return universal_upgrades

func get_upgrade_resource(upgrade_id: String) -> UpgradeData:
	## Get UpgradeData Resource by ID (preferred method)
	## Returns null if not found
	return upgrade_resource_cache.get(upgrade_id, null)

func get_upgrade_def(upgrade_id: String) -> Dictionary:
	## Get upgrade definition as Dictionary (legacy method)
	## Prefer using get_upgrade_resource() instead
	var upgrade = get_upgrade_resource(upgrade_id)
	if upgrade:
		return _build_upgrade_dict_from_resource(upgrade)
	return {}

func get_all_upgrade_definitions() -> Dictionary:
	## Get all upgrade definitions as Dictionary (legacy method)
	## Prefer iterating upgrade_resource_cache directly
	var result = {}
	for upgrade_id in upgrade_resource_cache:
		var upgrade = upgrade_resource_cache[upgrade_id]
		if upgrade:
			result[upgrade_id] = _build_upgrade_dict_from_resource(upgrade)
	return result

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

func get_transcendent_card_ids() -> Array[String]:
	## Get all available transcendent placeholder card IDs
	return transcendent_card_cache.keys()

func get_transcendent_card(card_id: String) -> CardData:
	## Get a transcendent card by ID
	return transcendent_card_cache.get(card_id, null)
