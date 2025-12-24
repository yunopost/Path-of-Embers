extends Node

## Autoload singleton - Source of truth for game state
## Emits signals when values change for reactive UI updates

signal party_changed
signal deck_changed
signal relics_changed
signal gold_changed
signal act_changed
signal map_changed
signal node_position_changed
signal current_node_changed
signal available_next_node_ids_changed
signal quests_changed
signal hp_changed
signal block_changed
signal energy_changed
signal buffs_changed
signal hand_changed
signal draw_pile_changed
signal discard_pile_changed

# Party (3 characters)
var party: Array = []  # Will contain character data (legacy, kept for compatibility)
var party_ids: Array[String] = []  # Array of 3 character IDs

# Deck
var deck: Dictionary = {}  # instance_id -> DeckCardData (authoritative registry)
var deck_order: Array[String] = []  # Stable ordering for deck view / upgrades UI
# Note: draw_pile, hand, discard_pile are now managed by deck_model only

# Models (architecture rule 4.1, 8.1)
var deck_model: DeckModel = null

# Relics
var relics: Array = []  # Will contain relic data

# Resources
var gold: int = 0
var current_hp: int = 50
var max_hp: int = 50
var block: int = 0
var energy: int = 3
var max_energy: int = 3

# Combat status effects
var haste_next_card: bool = false  # Next card played doesn't advance enemy timer

# Map/Progress
var act: int = 1
var map: String = ""
var node_position: int = 0  # How many nodes progressed (0 = start)
var current_map: MapData = null  # Current map for the floor
var current_node_id: String = ""  # ID of currently selected node
var available_next_node_ids: Array[String] = []  # IDs of nodes that can be selected next

# Quests
var quests: Dictionary = {}  # Dictionary keyed by character_id, value is QuestState

# Reward pool
var reward_card_pool: Array[CardData] = []  # Merged reward card pool from selected characters

# Rare pity system
var rare_pity_counter: int = -2  # Base chance starts at -2%, increases by +1 for each Common shown

# Pending rewards (set by EncounterScreen, consumed by RewardsScreen)
var pending_rewards: RewardBundle = null

# Buffs list
var buffs: Array = []  # Will contain buff/debuff data

# Settings
var tap_to_play: bool = false

func _ready():
	# Initialize with empty values (will be set by character selection)
	party = []
	party_ids = []
	deck = {}
	deck_order = []
	relics = []
	gold = 0
	current_hp = 50
	max_hp = 50
	block = 0
	energy = 3
	max_energy = 3
	haste_next_card = false
	act = 1
	map = "Act1"
	node_position = 0
	current_map = null
	current_node_id = ""
	available_next_node_ids = []
	quests = {}
	reward_card_pool = []
	rare_pity_counter = -2
	buffs = []
	
	# Initialize models
	deck_model = DeckModel.new()
	
	# Connect model signals to RunState signals for backward compatibility
	deck_model.deck_changed.connect(func(): deck_changed.emit())
	deck_model.draw_pile_changed.connect(func(): draw_pile_changed.emit())
	deck_model.hand_changed.connect(func(): hand_changed.emit())
	deck_model.discard_pile_changed.connect(func(): discard_pile_changed.emit())
	
	# Note: CombatModel removed - CombatController manages combat state directly

func set_gold(value: int):
	if gold != value:
		gold = value
		gold_changed.emit()

func set_hp(current: int, maximum: int = -1):
	if current_hp != current:
		current_hp = current
		if maximum > 0:
			max_hp = maximum
		hp_changed.emit()

func set_block(value: int):
	if block != value:
		block = value
		block_changed.emit()

func set_energy(current: int, maximum: int = -1):
	if energy != current:
		energy = current
		if maximum > 0:
			max_energy = maximum
		energy_changed.emit()

func reset_block():
	## Called at start of each player turn
	set_block(0)

func set_node_position(value: int):
	if node_position != value:
		node_position = value
		node_position_changed.emit()

func set_act(value: int):
	if act != value:
		act = value
		act_changed.emit()

func set_map_data(map_data: MapData):
	## Set the current map data
	if current_map != map_data:
		current_map = map_data
		map_changed.emit()
		_update_available_nodes()

func set_current_node(node_id: String):
	## Set the currently selected node
	## Note: Does NOT mark node as completed - use mark_current_node_completed() after encounter finishes
	if current_node_id != node_id:
		current_node_id = node_id
		
		# Update available next nodes
		_update_available_nodes()
		
		# Update node position
		if current_map and current_map.nodes.has(current_node_id):
			var node = current_map.nodes[current_node_id]
			node_position = node.row
		
		current_node_changed.emit(node_id)
		node_position_changed.emit()

func get_current_node_type() -> int:
	## Get the current node's type (MapNodeData.NodeType)
	## Returns FIGHT as fallback if node not found
	if not current_map or current_node_id.is_empty():
		return MapNodeData.NodeType.FIGHT
	
	var node = current_map.get_node(current_node_id)
	if node:
		return node.node_type
	
	return MapNodeData.NodeType.FIGHT

func mark_current_node_completed() -> void:
	## Mark the current node as completed and update available nodes
	## This is called after combat ends, separate from set_current_node
	## Emits NODE_COMPLETED event for quest system
	if not current_map or current_node_id.is_empty():
		return
	
	var node = current_map.get_node(current_node_id)
	if node:
		node.is_completed = true
		_update_available_nodes()
		# Emit map_changed to refresh map display
		map_changed.emit()
		
		# Emit NODE_COMPLETED event for quest system
		emit_game_event("NODE_COMPLETED", {
			"node_id": current_node_id,
			"node_type": node.node_type,
			"row": node.row
		})
		
		# Force save after node completion
		if AutoSaveManager:
			AutoSaveManager.force_save("node_completed")

func _update_available_nodes():
	## Update the list of available next nodes based on current selection
	var old_available = available_next_node_ids.duplicate()
	available_next_node_ids.clear()
	
	if not current_map:
		# No map - make start nodes available
		available_next_node_ids_changed.emit([])
		return
	
	if current_node_id.is_empty():
		# No node selected - start nodes are available
		available_next_node_ids = current_map.start_node_ids.duplicate()
	else:
		# Get nodes connected from current node
		var current_node = current_map.get_node(current_node_id)
		if current_node:
			available_next_node_ids = current_node.connected_to.duplicate()
	
	# Filter out completed nodes (can't go back)
	available_next_node_ids = available_next_node_ids.filter(func(id): return not current_map.get_node(id).is_completed)
	
	# Emit signal if changed
	if available_next_node_ids != old_available:
		available_next_node_ids_changed.emit(available_next_node_ids)

func set_map(value: String):
	if map != value:
		map = value
		map_changed.emit()

func add_card_to_deck(card_id: String, owner_character_id: String = "", upgrades: Array[String] = [], transcended: bool = false, transcendent_card_id: String = ""):
	## Add a card to the deck with optional upgrades and owner
	## Creates DeckCardData with instance_id and stores in registry
	# Validate card_id is non-empty
	if card_id.is_empty():
		push_error("RunState.add_card_to_deck: card_id is empty. owner=%s" % owner_character_id)
		return
	
	# Validate CardData exists
	var card_data = DataRegistry.get_card_data(card_id)
	if not card_data:
		push_error("RunState.add_card_to_deck: CardData not found for card_id='%s'. owner=%s" % [card_id, owner_character_id])
		return
	
	var deck_card = DeckCardData.new(card_id, owner_character_id, upgrades, transcended, transcendent_card_id)
	
	# Validate the created card instance
	if not CardValidation.validate_and_log_creation(deck_card, "add_card_to_deck"):
		return
	
	var instance_id = deck_card.instance_id
	
	# Store in registry
	deck[instance_id] = deck_card
	deck_order.append(instance_id)
	
	# Update model
	deck_model.add_card_instance(instance_id)
	draw_pile_changed.emit()
	
	deck_changed.emit()

func remove_card_from_deck(index: int):
	## DEPRECATED: Use remove_card_instance(instance_id) instead
	## Legacy method - converts index to instance_id and calls remove_card_instance
	if index >= 0 and index < deck_order.size():
		var instance_id = deck_order[index]
		remove_card_instance(instance_id)

func remove_card_instance(instance_id: String) -> void:
	## Remove a card instance from the deck and all piles
	if not deck.has(instance_id):
		return
	
	# Remove from registry
	deck.erase(instance_id)
	deck_order.erase(instance_id)
	
	# Remove from model piles
	deck_model.remove_instance_from_piles(instance_id)
	# Signals are emitted by deck_model.remove_instance_from_piles()
	deck_changed.emit()

func transform_card_instance(instance_id: String, new_card_id: String) -> void:
	## Transform a card instance to a different card
	## Clears upgrades (MVP decision)
	if not deck.has(instance_id):
		return
	
	var card_instance = deck[instance_id]
	if not card_instance:
		return
	
	# Validate new_card_id exists
	if new_card_id.is_empty():
		push_error("transform_card_instance: new_card_id is empty. instance_id=%s" % instance_id)
		return
	
	var new_card_data = DataRegistry.get_card_data(new_card_id)
	if not new_card_data:
		push_error("transform_card_instance: CardData not found for new_card_id='%s'. instance_id=%s" % [new_card_id, instance_id])
		return
	
	# Transform the card
	card_instance.card_id = new_card_id
	card_instance.applied_upgrades.clear()  # MVP: clear upgrades on transform
	card_instance.is_transcended = false
	card_instance.transcendent_card_id = ""
	
	# Validate the transformed card
	if not CardValidation.validate_card_instance(card_instance, "transform_card_instance"):
		push_error("transform_card_instance: Transformed card is invalid. instance_id=%s" % instance_id)
	
	# Emit signals
	deck_changed.emit()
	# If card is in hand, emit hand_changed
	if deck_model and deck_model.hand.has(instance_id):
		deck_model.hand_changed.emit()

func get_deck_size() -> int:
	return deck_order.size()

func _initialize_deck_piles():
	## Initialize draw pile with all cards from deck, clear hand and discard
	deck_model.initialize(deck_order.duplicate())


func shuffle_discard_into_draw():
	## Shuffle discard pile into draw pile (when draw is empty)
	## Note: This is handled automatically by deck_model.draw_cards() when draw pile is empty
	deck_model.draw_pile = deck_model.discard_pile.duplicate()
	deck_model.discard_pile.clear()
	deck_model.shuffle_draw_pile()
	deck_model.discard_pile_changed.emit()

func draw_cards(count: int = 5):
	## Draw cards from draw pile into hand
	## If draw pile is empty, shuffle discard into draw first
	deck_model.draw_cards(count)
	# Signals are emitted by deck_model

func discard_hand():
	## Move all cards from hand to discard pile
	deck_model.discard_hand()
	# Signals are emitted by deck_model

func get_draw_pile_count() -> int:
	return deck_model.get_draw_pile_count()

func get_discard_pile_count() -> int:
	return deck_model.get_discard_pile_count()

func get_hand_size() -> int:
	return deck_model.get_hand_size()

func set_party(character_ids: Array[String]):
	## Set the party to the given character IDs (must be exactly 3)
	if character_ids.size() != 3:
		push_error("Party must contain exactly 3 characters, got %d" % character_ids.size())
		return
	party_ids = character_ids.duplicate()
	party = character_ids.duplicate()  # Keep legacy party for compatibility
	party_changed.emit()

func generate_starter_deck(character_data_list: Array[CharacterData]):
	## Generate starter deck from selected characters
	## character_data_list must be exactly 3 CharacterData resources
	if character_data_list.size() != 3:
		push_error("generate_starter_deck requires exactly 3 characters, got %d" % character_data_list.size())
		return
	
	deck.clear()
	deck_order.clear()
	reward_card_pool.clear()
	
	# Generate deck: 3 generic + 2 unique per character = 15 cards total
	for char_data in character_data_list:
		# Add 3 generic cards based on role
		var generic_card_ids = RoleStarterSet.get_generic_starters_for_role(char_data.role)
		for card_id in generic_card_ids:
			# Validate card_id exists before creating
			if card_id.is_empty():
				push_error("generate_starter_deck: Empty card_id for generic starter. character=%s" % char_data.id)
				continue
			var card_data = DataRegistry.get_card_data(card_id)
			if not card_data:
				push_error("generate_starter_deck: CardData not found for generic card_id='%s'. character=%s" % [card_id, char_data.id])
				continue
			
			var deck_card = DeckCardData.new(card_id, char_data.id)
			if not CardValidation.validate_and_log_creation(deck_card, "generate_starter_deck (generic)"):
				continue
			var instance_id = deck_card.instance_id
			deck[instance_id] = deck_card
			deck_order.append(instance_id)
		
		# Add 2 unique cards
		for unique_card in char_data.starter_unique_cards:
			if not unique_card or not unique_card.id:
				push_error("generate_starter_deck: Invalid unique_card. character=%s" % char_data.id)
				continue
			var card_id = unique_card.id
			if card_id.is_empty():
				push_error("generate_starter_deck: Empty card_id for unique card. character=%s" % char_data.id)
				continue
			
			var deck_card = DeckCardData.new(card_id, char_data.id)
			if not CardValidation.validate_and_log_creation(deck_card, "generate_starter_deck (unique)"):
				continue
			var instance_id = deck_card.instance_id
			deck[instance_id] = deck_card
			deck_order.append(instance_id)
		
		# Merge reward card pool (22 cards per character = 66 total)
		for reward_card in char_data.reward_card_pool:
			if reward_card:
				reward_card_pool.append(reward_card)
	
	# Initialize deck piles
	_initialize_deck_piles()
	deck_changed.emit()
	
	# Initialize rare pity counter (starts at -2%)
	rare_pity_counter = -2

func initialize_quests(character_data_list: Array[CharacterData]):
	## Initialize quest state for selected characters
	## character_data_list must be exactly 3 CharacterData resources
	## Creates QuestState objects from QuestData templates
	if character_data_list.size() != 3:
		push_error("initialize_quests requires exactly 3 characters, got %d" % character_data_list.size())
		return
	
	quests.clear()
	
	for char_data in character_data_list:
		if char_data.quest:
			# Create QuestState from QuestData (immutable template)
			var quest_state = QuestState.new(
				char_data.quest.id,
				char_data.id,
				char_data.quest.title,
				char_data.quest.description,
				char_data.quest.progress_max,
				char_data.quest.tracking_type,
				char_data.quest.params.duplicate()
			)
			# Use character_id as key for easy lookup
			quests[char_data.id] = quest_state
	
	quests_changed.emit()

func get_quest(character_id: String) -> QuestState:
	## Get quest state for a character
	return quests.get(character_id, null)

func are_all_party_quests_complete() -> bool:
	## Check if all party member quests are complete
	if quests.is_empty():
		return false
	
	# Check all 3 party members have complete quests
	for character_id in party_ids:
		var quest = quests.get(character_id)
		if not quest or not quest.is_complete:
			return false
	
	return true

func emit_game_event(event_type: String, payload: Dictionary = {}) -> void:
	## Emit a game event and evaluate all quests
	## This is the single entry point for quest updates
	var any_changed = false
	
	for character_id in quests:
		var quest = quests[character_id]
		if quest and quest is QuestState:
			var changed = QuestSystem.evaluate(quest, event_type, payload)
			if changed:
				any_changed = true
	
	if any_changed:
		quests_changed.emit()

func set_pending_rewards(bundle: RewardBundle):
	## Set pending rewards (called by EncounterScreen)
	pending_rewards = bundle
	
	# Force save when pending rewards are set (so crash mid-rewards is recoverable)
	if AutoSaveManager:
		AutoSaveManager.force_save("pending_rewards_set")

func clear_pending_rewards():
	## Clear pending rewards (called by RewardsScreen after completion)
	pending_rewards = null

func apply_reward_bundle(bundle: RewardBundle):
	## Apply all rewards from a bundle to RunState
	## This is called by RewardsScreen after player makes choices
	if not bundle:
		return
	
	# Apply gold
	if bundle.gold > 0:
		set_gold(gold + bundle.gold)
	
	# Apply healing
	if bundle.heal_amount > 0:
		var new_hp = min(current_hp + bundle.heal_amount, max_hp)
		set_hp(new_hp, max_hp)
	
	# Card rewards are handled separately by RewardsScreen (player chooses which card)
	# Relic and upgrade rewards are also handled separately by RewardsScreen
	
	# Note: We don't apply cards/relics/upgrades here because player must choose
	# RewardsScreen calls add_card_to_deck/add_relic/etc. individually

func add_card_to_deck_from_reward(card_id: String, owner_character_id: String = ""):
	## Add a card to deck from reward (wrapper for add_card_to_deck)
	## Uses "Shared Deck" owner if no owner specified
	add_card_to_deck(card_id, owner_character_id)

func can_upgrade_instance(instance_id: String) -> bool:
	## Check if a card instance can be upgraded
	var card_instance = deck.get(instance_id)
	if not card_instance:
		return false
	
	# Check if card has available upgrades
	var pool = DataRegistry.get_upgrade_pool_for_card(card_instance.card_id)
	if pool.is_empty():
		return false
	
	# Check if there are any available upgrades (not already applied)
	var available = []
	for upgrade_id in pool:
		if not card_instance.applied_upgrades.has(upgrade_id):
			available.append(upgrade_id)
	
	return not available.is_empty()

func can_upgrade_card_at(deck_index: int) -> bool:
	## DEPRECATED: Use can_upgrade_instance(instance_id) instead
	## Legacy method - converts index to instance_id
	if deck_index < 0 or deck_index >= deck_order.size():
		return false
	var instance_id = deck_order[deck_index]
	return can_upgrade_instance(instance_id)

func apply_upgrade_to_instance(instance_id: String, upgrade_id: String) -> bool:
	## Apply an upgrade to a card instance by instance_id
	var card_instance = deck.get(instance_id)
	if not card_instance:
		return false
	
	# Check if upgrade is already applied (no duplicates)
	if card_instance.applied_upgrades.has(upgrade_id):
		return false
	
	# Check if upgrade is valid for this card
	var pool = DataRegistry.get_upgrade_pool_for_card(card_instance.card_id)
	if not pool.has(upgrade_id):
		return false
	
	# Apply upgrade (directly mutates the object in deck registry)
	card_instance.applied_upgrades.append(upgrade_id)
	
	# Emit signals (no need to sync piles - they reference the same object via instance_id lookup)
	deck_changed.emit()
	# If card is in hand, emit hand_changed
	if deck_model and deck_model.hand.has(instance_id):
		deck_model.hand_changed.emit()
	
	# Autosave after upgrade
	if AutoSaveManager:
		AutoSaveManager.force_save("card_upgraded")
	
	return true

func apply_upgrade_to_card_at(deck_index: int, upgrade_id: String) -> bool:
	## DEPRECATED: Use apply_upgrade_to_instance(instance_id, upgrade_id) instead
	## Legacy method - converts index to instance_id
	if deck_index < 0 or deck_index >= deck_order.size():
		return false
	var instance_id = deck_order[deck_index]
	return apply_upgrade_to_instance(instance_id, upgrade_id)

func get_upgradeable_instance_ids() -> Array[String]:
	## Get all instance_ids of cards that can be upgraded
	var instance_ids: Array[String] = []
	for instance_id in deck_order:
		if can_upgrade_instance(instance_id):
			instance_ids.append(instance_id)
	return instance_ids

func get_upgradeable_deck_indices() -> Array[int]:
	## DEPRECATED: Use get_upgradeable_instance_ids() instead
	## Legacy method - returns indices of upgradeable cards
	var indices: Array[int] = []
	for i in range(deck_order.size()):
		if can_upgrade_instance(deck_order[i]):
			indices.append(i)
	return indices

func get_effective_cost(instance_id: String) -> int:
	## Get the effective cost of a card after upgrades (delegates to CardRules)
	## Returns the base cost minus cost reduction upgrades (min 0)
	var card_instance = deck.get(instance_id)
	if not card_instance:
		return 1  # Default fallback
	
	var card_data = DataRegistry.get_card_data(card_instance.card_id)
	if not card_data:
		return 1  # Default fallback
	
	return CardRules.get_effective_cost(card_data, card_instance)

func has_upgrade(instance_id: String, upgrade_id: String) -> bool:
	## Check if a card instance has a specific upgrade
	var card_instance = deck.get(instance_id)
	if not card_instance:
		return false
	return card_instance.applied_upgrades.has(upgrade_id)

func get_timer_tick_amount_for_card(instance_id: String) -> int:
	## Get the timer tick amount for a card
	## Returns 0 if has Haste or haste_next_card status, 2 if has Slow keyword, 1 otherwise
	
	# Check for haste_next_card status (from Shoulder Tackle or similar effects)
	# This applies to the CURRENT card being played (which was granted haste by the previous card)
	if haste_next_card:
		# Clear the status after using it (it only applies once)
		haste_next_card = false
		return 0
	
	# Check for Haste upgrade
	if has_upgrade(instance_id, "upgrade_haste"):
		return 0
	
	# Check for Slow keyword on card (using CardRules to account for upgrades that remove keywords)
	var card_instance = deck.get(instance_id)
	if card_instance:
		var keywords = CardRules.get_card_keywords(card_instance)
		if keywords.has("Slow"):
			return 2
	
	return 1

func transcend_card(instance_id: String, new_card_id: String) -> bool:
	## Transform a card instance into a transcendent card
	## Replaces the card_id and marks as transcended
	if instance_id.is_empty() or new_card_id.is_empty():
		push_error("transcend_card: instance_id or new_card_id is empty")
		return false
	
	var card_instance = deck.get(instance_id)
	if not card_instance:
		push_error("transcend_card: Card instance not found. instance_id=%s" % instance_id)
		return false
	
	# Validate new_card_id exists
	var new_card_data = DataRegistry.get_card_data(new_card_id)
	if not new_card_data:
		push_error("transcend_card: CardData not found for new_card_id='%s'. instance_id=%s" % [new_card_id, instance_id])
		return false
	
	# Update card instance
	card_instance.card_id = new_card_id
	card_instance.is_transcended = true
	card_instance.transcendent_card_id = new_card_id
	
	# Validate the transcended card
	if not CardValidation.validate_card_instance(card_instance, "transcend_card"):
		push_error("transcend_card: Transcended card is invalid. instance_id=%s" % instance_id)
		return false
	
	# Emit signals (instance_id remains the same, so piles don't need updating)
	deck_changed.emit()
	if deck_model and deck_model.hand.has(instance_id):
		deck_model.hand_changed.emit()
	
	# Autosave after transcendence
	if AutoSaveManager:
		AutoSaveManager.force_save("card_transcended")
	
	return true

func add_relic(relic_id: String, is_boss: bool = false) -> void:
	## Add a relic to the player's collection
	## Emits RELIC_GAINED event for quest system
	## 
	## PLACEHOLDER FOR FUTURE WORK: Relic storage exists for testing game loop,
	## but relic effects are not implemented. Relics are stored but have no gameplay impact.
	if relic_id.is_empty():
		return
	
	relics.append({ "id": relic_id, "is_boss": is_boss })
	relics_changed.emit()
	
	# Emit RELIC_GAINED event for quest system
	emit_game_event("RELIC_GAINED", { "relic_id": relic_id, "is_boss": is_boss })

func get_rare_chance(node_type: MapNodeData.NodeType) -> float:
	## Calculate current Rare chance including Elite bonus
	## Deck penalty is applied per-card during selection, not to overall Rare chance
	var base_chance = rare_pity_counter / 100.0  # Convert counter to percentage
	
	# Apply Elite bonus (+10% for Elite nodes)
	var elite_bonus = 0.0
	if node_type == MapNodeData.NodeType.ELITE:
		elite_bonus = 0.10
	
	var final_chance = base_chance + elite_bonus
	return clamp(final_chance, 0.0, 1.0)  # Clamp between 0% and 100%

func get_rare_cards_in_deck() -> Array[String]:
	## Get array of card_ids for Rare cards currently in deck
	var rare_card_ids: Array[String] = []
	for instance_id in deck_order:
		var card_instance = deck.get(instance_id)
		if card_instance:
			var card_data = DataRegistry.get_card_data(card_instance.card_id)
			if card_data and card_data.rarity == CardData.Rarity.RARE:
				if not rare_card_ids.has(card_instance.card_id):
					rare_card_ids.append(card_instance.card_id)
	return rare_card_ids

func update_rare_pity_from_rewards(card_choices: Array[String]) -> void:
	## Update pity counter based on cards shown in rewards
	## Each Common increases counter by +1, Rare resets to -2
	var had_rare = false
	var common_count = 0
	
	for card_id in card_choices:
		var card_data = DataRegistry.get_card_data(card_id)
		if card_data:
			if card_data.rarity == CardData.Rarity.RARE:
				had_rare = true
			elif card_data.rarity == CardData.Rarity.COMMON:
				common_count += 1
	
	if had_rare:
		# Reset to -2 when Rare appears
		rare_pity_counter = -2
	else:
		# Increase by 1 for each Common shown
		rare_pity_counter += common_count

func reset_rare_pity() -> void:
	## Reset pity counter to -2
	rare_pity_counter = -2

func reset_run() -> void:
	## Reset all run state to initial values (for New Game)
	## Clears party, deck, quests, map, and all resources
	
	# Clear party
	party.clear()
	party_ids.clear()
	party_changed.emit()
	
	# Clear deck
	deck.clear()
	deck_order.clear()
	if deck_model:
		deck_model.draw_pile.clear()
		deck_model.hand.clear()
		deck_model.discard_pile.clear()
	deck_changed.emit()
	draw_pile_changed.emit()
	hand_changed.emit()
	discard_pile_changed.emit()
	
	# Clear quests
	quests.clear()
	quests_changed.emit()
	
	# Clear relics
	relics.clear()
	relics_changed.emit()
	
	# Reset resources
	set_gold(0)
	set_hp(50, 50)
	set_block(0)
	set_energy(3, 3)
	haste_next_card = false
	
	# Reset map/progress
	set_act(1)
	set_map("Act1")
	set_node_position(0)
	current_map = null
	current_node_id = ""
	available_next_node_ids.clear()
	map_changed.emit()
	current_node_changed.emit("")
	available_next_node_ids_changed.emit([])
	
	# Clear pending rewards
	pending_rewards = null
	
	# Clear reward pool
	reward_card_pool.clear()
	
	# Reset rare pity counter
	rare_pity_counter = -2
	
	# Clear buffs
	buffs.clear()
	buffs_changed.emit()
	
	# Reset settings
	tap_to_play = false
