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
	for i in range(4):
		var char_data = CharacterData.new()
		char_data.id = "warrior_%d" % (i + 1)
		char_data.role = "Warrior"
		char_data.portrait_path = ""

		if i == 0:
			char_data.display_name = "Monster Hunter"
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
		elif i == 1:
			char_data.display_name = "Shadowfoot"
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
		elif i == 2:
			char_data.display_name = "Revenant"
			# Revenant starter 1: Spite Strike — deals bonus damage based on missing HP (Spite)
			var spite_strike = CardData.new()
			spite_strike.id = "revenant_spite_strike"
			spite_strike.name = "Spite Strike"
			spite_strike.cost = 1
			spite_strike.card_type = CardData.CardType.ATTACK
			spite_strike.targeting_mode = CardData.TargetingMode.ENEMY
			spite_strike.owner_character_id = "warrior_3"
			spite_strike.rarity = CardData.Rarity.COMMON
			spite_strike.base_effects.append(EffectData.new(EffectType.DAMAGE_SPITE, {"base_amount": 6, "bonus_per_10_missing_hp": 2}))
			char_data.starter_unique_cards.append(spite_strike)

			# Revenant starter 2: Blood Rite — gain block, draw if took damage this combat (Undying)
			var blood_rite = CardData.new()
			blood_rite.id = "revenant_blood_rite"
			blood_rite.name = "Blood Rite"
			blood_rite.cost = 0
			blood_rite.card_type = CardData.CardType.SKILL
			blood_rite.targeting_mode = CardData.TargetingMode.SELF
			blood_rite.owner_character_id = "warrior_3"
			blood_rite.rarity = CardData.Rarity.COMMON
			blood_rite.base_effects.append(EffectData.new(EffectType.BLOCK, {"amount": 2}))
			blood_rite.base_effects.append(EffectData.new(EffectType.DRAW_IF_TOOK_DAMAGE, {"amount": 1}))
			char_data.starter_unique_cards.append(blood_rite)
		else:
			char_data.display_name = "Tempest"
			# Tempest starter 1: Spark — cheap Haste attack that draws a card (Cantrips)
			var spark = CardData.new()
			spark.id = "tempest_spark"
			spark.name = "Spark"
			spark.cost = 0
			spark.card_type = CardData.CardType.ATTACK
			spark.targeting_mode = CardData.TargetingMode.ENEMY
			spark.owner_character_id = "warrior_4"
			spark.rarity = CardData.Rarity.COMMON
			spark.keywords.append("Haste")
			spark.base_effects.append(EffectData.new(EffectType.DAMAGE, {"amount": 4}))
			spark.base_effects.append(EffectData.new(EffectType.DRAW, {"amount": 1}))
			char_data.starter_unique_cards.append(spark)

			# Tempest starter 2: Afterburn — bonus damage if last card was an Attack (Sequencing)
			var afterburn = CardData.new()
			afterburn.id = "tempest_afterburn"
			afterburn.name = "Afterburn"
			afterburn.cost = 1
			afterburn.card_type = CardData.CardType.ATTACK
			afterburn.targeting_mode = CardData.TargetingMode.ENEMY
			afterburn.owner_character_id = "warrior_4"
			afterburn.rarity = CardData.Rarity.COMMON
			afterburn.base_effects.append(EffectData.new(EffectType.DAMAGE_SEQUENCING, {"base_amount": 5, "bonus_if_last_was_attack": 4}))
			char_data.starter_unique_cards.append(afterburn)

		# Set themes
		if i == 0:  # Monster Hunter
			char_data.theme_1 = "Timer Manipulation"
			char_data.theme_2 = "Vulnerability"
			char_data.theme_3 = "Elite Hunter"
		elif i == 1:  # Shadowfoot
			char_data.theme_1 = "Fast Actions"
			char_data.theme_2 = "Combo Chains"
			char_data.theme_3 = "Untouchable"
		elif i == 2:  # Revenant
			char_data.theme_1 = "Spite"
			char_data.theme_2 = "Undying"
			char_data.theme_3 = "Death Trigger"
		else:  # Tempest
			char_data.theme_1 = "Cantrips"
			char_data.theme_2 = "Sequencing"
			char_data.theme_3 = "Controlled Chaos"

		_generate_placeholder_reward_pool(char_data)

		var quest = QuestData.new()
		quest.id = "quest_warrior_%d" % (i + 1)
		if i == 0:
			quest.title = "Monster Hunter Quest"
			quest.description = "Complete %d nodes" % 10
			quest.progress_max = 10
			quest.tracking_type = "complete_nodes"
		elif i == 1:
			quest.title = "Shadowfoot Quest"
			quest.description = "Complete combat without taking damage %d times" % 6
			quest.progress_max = 6
			quest.tracking_type = "combat_no_damage"
		elif i == 2:
			quest.title = "Revenant Quest"
			quest.description = "Take %d hits in a single combat" % 10
			quest.progress_max = 10
			quest.tracking_type = "damage_hits_single_combat"
		else:
			quest.title = "Tempest Quest"
			quest.description = "Play 5+ cards in a single turn %d times" % 8
			quest.progress_max = 8
			quest.tracking_type = "high_volume_turn_5"
		char_data.quest = quest
		register_character(char_data)

	# ---- Healers ----
	for i in range(4):
		var char_data = CharacterData.new()
		char_data.id = "healer_%d" % (i + 1)
		char_data.role = "Healer"
		char_data.portrait_path = ""

		if i == 0:
			char_data.display_name = "Witch"
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
		elif i == 1:
			char_data.display_name = "Mechanist"
			# Mechanist starter 1: Overclock — Power, draw 1 extra card per turn (Board Control)
			var overclock = CardData.new()
			overclock.id = "mechanist_overclock"
			overclock.name = "Overclock"
			overclock.cost = 1
			overclock.card_type = CardData.CardType.POWER
			overclock.targeting_mode = CardData.TargetingMode.SELF
			overclock.owner_character_id = "healer_2"
			overclock.rarity = CardData.Rarity.COMMON
			overclock.base_effects.append(EffectData.new(EffectType.DRAW_PER_TURN, {"amount": 1}))
			char_data.starter_unique_cards.append(overclock)

			# Mechanist starter 2: Ratchet Blow — Attack, gains +2 damage per killing blow (Legacy)
			var ratchet_blow = CardData.new()
			ratchet_blow.id = "mechanist_ratchet_blow"
			ratchet_blow.name = "Ratchet Blow"
			ratchet_blow.cost = 1
			ratchet_blow.card_type = CardData.CardType.ATTACK
			ratchet_blow.targeting_mode = CardData.TargetingMode.ENEMY
			ratchet_blow.owner_character_id = "healer_2"
			ratchet_blow.rarity = CardData.Rarity.COMMON
			ratchet_blow.base_effects.append(EffectData.new(EffectType.DAMAGE, {"amount": 7}))
			ratchet_blow.base_effects.append(EffectData.new(EffectType.LEGACY_KILL_COUNTER, {"damage_per_kill": 2}))
			char_data.starter_unique_cards.append(ratchet_blow)
		elif i == 2:
			char_data.display_name = "Grove"
			# Grove starter 1: Seedling — places Bloom counters on a card in draw pile (Bloom)
			var seedling = CardData.new()
			seedling.id = "grove_seedling"
			seedling.name = "Seedling"
			seedling.cost = 1
			seedling.card_type = CardData.CardType.SKILL
			seedling.targeting_mode = CardData.TargetingMode.SELF
			seedling.owner_character_id = "healer_3"
			seedling.rarity = CardData.Rarity.COMMON
			seedling.base_effects.append(EffectData.new(EffectType.BLOOM, {"counters": 2, "trigger_threshold": 3, "trigger_effect": "block", "trigger_amount": 6}))
			char_data.starter_unique_cards.append(seedling)

			# Grove starter 2: Ancient Root — draw a card; returns to draw pile (Regrowth)
			var ancient_root = CardData.new()
			ancient_root.id = "grove_ancient_root"
			ancient_root.name = "Ancient Root"
			ancient_root.cost = 1
			ancient_root.card_type = CardData.CardType.SKILL
			ancient_root.targeting_mode = CardData.TargetingMode.SELF
			ancient_root.owner_character_id = "healer_3"
			ancient_root.rarity = CardData.Rarity.COMMON
			ancient_root.base_effects.append(EffectData.new(EffectType.DRAW, {"amount": 1}))
			ancient_root.base_effects.append(EffectData.new(EffectType.REGROWTH, {}))
			char_data.starter_unique_cards.append(ancient_root)
		else:
			char_data.display_name = "Sibyl"
			# Sibyl starter 1: Second Sight — Haste Scry 2, reorder top of draw pile (Foresight)
			var second_sight = CardData.new()
			second_sight.id = "sibyl_second_sight"
			second_sight.name = "Second Sight"
			second_sight.cost = 0
			second_sight.card_type = CardData.CardType.SKILL
			second_sight.targeting_mode = CardData.TargetingMode.SELF
			second_sight.owner_character_id = "healer_4"
			second_sight.rarity = CardData.Rarity.COMMON
			second_sight.keywords.append("Haste")
			second_sight.base_effects.append(EffectData.new(EffectType.SCRY, {"amount": 2}))
			char_data.starter_unique_cards.append(second_sight)

			# Sibyl starter 2: Augur's Strike — conditional damage based on top card type (Probability)
			var augurs_strike = CardData.new()
			augurs_strike.id = "sibyl_augurs_strike"
			augurs_strike.name = "Augur's Strike"
			augurs_strike.cost = 1
			augurs_strike.card_type = CardData.CardType.ATTACK
			augurs_strike.targeting_mode = CardData.TargetingMode.ENEMY
			augurs_strike.owner_character_id = "healer_4"
			augurs_strike.rarity = CardData.Rarity.COMMON
			augurs_strike.base_effects.append(EffectData.new(EffectType.DAMAGE_CONDITIONAL_TOP_CARD, {"attack_amount": 10, "default_amount": 5, "default_block": 3}))
			char_data.starter_unique_cards.append(augurs_strike)

		# Set themes
		if i == 0:  # Witch
			char_data.theme_1 = "Curse Generation"
			char_data.theme_2 = "Discard Payoffs"
			char_data.theme_3 = "Contagion"
		elif i == 1:  # Mechanist
			char_data.theme_1 = "Board Control"
			char_data.theme_2 = "Legacy Cards"
			char_data.theme_3 = "Transcendence Synergy"
		elif i == 2:  # Grove
			char_data.theme_1 = "Bloom"
			char_data.theme_2 = "Regrowth"
			char_data.theme_3 = "Energy Surge"
		else:  # Sibyl
			char_data.theme_1 = "Foresight"
			char_data.theme_2 = "Probability"
			char_data.theme_3 = "Inevitability"

		_generate_placeholder_reward_pool(char_data)

		var quest = QuestData.new()
		quest.id = "quest_healer_%d" % (i + 1)
		if i == 0:
			quest.title = "Witch Quest"
			quest.description = "Gain %d Curse cards" % 6
			quest.progress_max = 6
			quest.tracking_type = "gain_curse_cards"
		elif i == 1:
			quest.title = "Mechanist Quest"
			quest.description = "Have a card with %d upgrades" % 6
			quest.progress_max = 6
			quest.tracking_type = "card_upgrades"
		elif i == 2:
			quest.title = "Grove Quest"
			quest.description = "Trigger Bloom %d times" % 10
			quest.progress_max = 10
			quest.tracking_type = "bloom_triggers"
		else:
			quest.title = "Sibyl Quest"
			quest.description = "Use Scry or Foresight effects %d times" % 15
			quest.progress_max = 15
			quest.tracking_type = "foresight_uses"
		char_data.quest = quest
		register_character(char_data)

	# ---- Defenders ----
	for i in range(4):
		var char_data = CharacterData.new()
		char_data.id = "defender_%d" % (i + 1)
		char_data.role = "Defender"
		char_data.portrait_path = ""

		if i == 0:
			char_data.display_name = "Golemancer"
			# Golemancer starter 1: Earthshatter — Slow heavy attack (Heavy Strikes)
			var earthshatter = CardData.new()
			earthshatter.id = "golemancer_earthshatter"
			earthshatter.name = "Earthshatter"
			earthshatter.cost = 2
			earthshatter.card_type = CardData.CardType.ATTACK
			earthshatter.targeting_mode = CardData.TargetingMode.ENEMY
			earthshatter.owner_character_id = "defender_1"
			earthshatter.rarity = CardData.Rarity.COMMON
			earthshatter.keywords.append("Slow")
			earthshatter.base_effects.append(EffectData.new(EffectType.DAMAGE, {"amount": 18}))
			char_data.starter_unique_cards.append(earthshatter)

			# Golemancer starter 2: Iron Ward — solid block (Damage Reduction)
			var iron_ward = CardData.new()
			iron_ward.id = "golemancer_iron_ward"
			iron_ward.name = "Iron Ward"
			iron_ward.cost = 1
			iron_ward.card_type = CardData.CardType.SKILL
			iron_ward.targeting_mode = CardData.TargetingMode.SELF
			iron_ward.owner_character_id = "defender_1"
			iron_ward.rarity = CardData.Rarity.COMMON
			iron_ward.base_effects.append(EffectData.new(EffectType.BLOCK, {"amount": 9}))
			char_data.starter_unique_cards.append(iron_ward)
		elif i == 1:
			char_data.display_name = "Living Armor"
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
		elif i == 2:
			char_data.display_name = "Echo"
			# Echo starter 1: Refraction — replay the last card you played (Mirror)
			var refraction = CardData.new()
			refraction.id = "echo_refraction"
			refraction.name = "Refraction"
			refraction.cost = 1
			refraction.card_type = CardData.CardType.SKILL
			refraction.targeting_mode = CardData.TargetingMode.SELF
			refraction.owner_character_id = "defender_3"
			refraction.rarity = CardData.Rarity.COMMON
			refraction.base_effects.append(EffectData.new(EffectType.MIRROR, {}))
			char_data.starter_unique_cards.append(refraction)

			# Echo starter 2: Harmonic Guard — gain block, bonus if last card was also a Skill (Resonance)
			var harmonic_guard = CardData.new()
			harmonic_guard.id = "echo_harmonic_guard"
			harmonic_guard.name = "Harmonic Guard"
			harmonic_guard.cost = 1
			harmonic_guard.card_type = CardData.CardType.SKILL
			harmonic_guard.targeting_mode = CardData.TargetingMode.SELF
			harmonic_guard.owner_character_id = "defender_3"
			harmonic_guard.rarity = CardData.Rarity.COMMON
			harmonic_guard.base_effects.append(EffectData.new(EffectType.RESONANCE_BLOCK, {"base_amount": 5, "bonus_if_last_was_skill": 4}))
			char_data.starter_unique_cards.append(harmonic_guard)
		else:
			char_data.display_name = "Hollow"
			# Hollow starter 1: Void Tap — Haste, convert all Block into Energy (Conversion)
			var void_tap = CardData.new()
			void_tap.id = "hollow_void_tap"
			void_tap.name = "Void Tap"
			void_tap.cost = 0
			void_tap.card_type = CardData.CardType.SKILL
			void_tap.targeting_mode = CardData.TargetingMode.SELF
			void_tap.owner_character_id = "defender_4"
			void_tap.rarity = CardData.Rarity.COMMON
			void_tap.keywords.append("Haste")
			void_tap.base_effects.append(EffectData.new(EffectType.BLOCK_TO_ENERGY, {"block_per_energy": 3}))
			char_data.starter_unique_cards.append(void_tap)

			# Hollow starter 2: Iron Curtain — gain 12 Block then end your turn (Dominance)
			var iron_curtain = CardData.new()
			iron_curtain.id = "hollow_iron_curtain"
			iron_curtain.name = "Iron Curtain"
			iron_curtain.cost = 2
			iron_curtain.card_type = CardData.CardType.SKILL
			iron_curtain.targeting_mode = CardData.TargetingMode.SELF
			iron_curtain.owner_character_id = "defender_4"
			iron_curtain.rarity = CardData.Rarity.COMMON
			iron_curtain.base_effects.append(EffectData.new(EffectType.BLOCK, {"amount": 12}))
			iron_curtain.base_effects.append(EffectData.new(EffectType.FORCE_END_TURN, {}))
			char_data.starter_unique_cards.append(iron_curtain)

		# Set themes
		if i == 0:  # Golemancer
			char_data.theme_1 = "Damage Reduction"
			char_data.theme_2 = "Heavy Strikes"
			char_data.theme_3 = "Augury"
		elif i == 1:  # Living Armor
			char_data.theme_1 = "Defense into Offense"
			char_data.theme_2 = "Escalation"
			char_data.theme_3 = "Enemy Absorption"
		elif i == 2:  # Echo
			char_data.theme_1 = "Mirror"
			char_data.theme_2 = "Resonance"
			char_data.theme_3 = "Recursion"
		else:  # Hollow
			char_data.theme_1 = "Conversion"
			char_data.theme_2 = "Dominance"
			char_data.theme_3 = "Compression"

		_generate_placeholder_reward_pool(char_data)

		var quest = QuestData.new()
		quest.id = "quest_defender_%d" % (i + 1)
		if i == 0:
			quest.title = "Golemancer Quest"
			quest.description = "Have a card with %d upgrades" % 6
			quest.progress_max = 6
			quest.tracking_type = "card_upgrades"
		elif i == 1:
			quest.title = "Living Armor Quest"
			quest.description = "Buy %d relics" % 6
			quest.progress_max = 6
			quest.tracking_type = "buy_relics"
		elif i == 2:
			quest.title = "Echo Quest"
			quest.description = "Mirror a card %d times" % 10
			quest.progress_max = 10
			quest.tracking_type = "mirror_count"
		else:
			quest.title = "Hollow Quest"
			quest.description = "Convert %d total Block into Energy" % 50
			quest.progress_max = 50
			quest.tracking_type = "block_converted_to_energy"
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
