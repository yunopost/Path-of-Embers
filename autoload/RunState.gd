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
var deck: Array = []  # Full deck - all cards owned (DeckCardData instances)
var draw_pile: Array = []  # Cards available to draw (legacy - use deck_model)
var hand: Array = []  # Cards currently in hand (legacy - use deck_model)
var discard_pile: Array = []  # Cards that have been played/discarded (legacy - use deck_model)

# Models (architecture rule 4.1, 8.1)
var deck_model: DeckModel = null
var combat_model: CombatModel = null

# Relics
var relics: Array = []  # Will contain relic data

# Resources
var gold: int = 0
var current_hp: int = 50
var max_hp: int = 50
var block: int = 0
var energy: int = 3
var max_energy: int = 3

# Map/Progress
var act: int = 1
var map: String = ""
var node_position: int = 0  # How many nodes progressed (0 = start)
var current_map: MapData = null  # Current map for the floor
var current_node_id: String = ""  # ID of currently selected node
var available_next_node_ids: Array[String] = []  # IDs of nodes that can be selected next

# Quests
var quests: Dictionary = {}  # Dictionary keyed by character_id or quest_id, value includes progress and completed

# Reward pool
var reward_card_pool: Array[CardData] = []  # Merged reward card pool from selected characters

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
	deck = []
	_initialize_deck_piles()
	relics = []
	gold = 0
	current_hp = 50
	max_hp = 50
	block = 0
	energy = 3
	max_energy = 3
	act = 1
	map = "Act1"
	node_position = 0
	current_map = null
	current_node_id = ""
	available_next_node_ids = []
	quests = {}
	reward_card_pool = []
	buffs = []
	
	# Initialize models
	deck_model = DeckModel.new()
	combat_model = CombatModel.new()
	
	# Connect model signals to RunState signals for backward compatibility
	if deck_model:
		deck_model.deck_changed.connect(func(): deck_changed.emit())
		deck_model.draw_pile_changed.connect(func(): draw_pile_changed.emit())
		deck_model.hand_changed.connect(func(): hand_changed.emit())
		deck_model.discard_pile_changed.connect(func(): discard_pile_changed.emit())
	
	if combat_model:
		combat_model.player_hp_changed.connect(func(new_hp, max_hp): 
			current_hp = new_hp
			self.max_hp = max_hp
			hp_changed.emit()
		)
		combat_model.player_block_changed.connect(func(new_block): 
			block = new_block
			block_changed.emit()
		)
		combat_model.player_energy_changed.connect(func(new_energy, max_energy): 
			energy = new_energy
			self.max_energy = max_energy
			energy_changed.emit()
		)

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
	if current_node_id != node_id:
		current_node_id = node_id
		
		# Mark node as completed
		if current_map and current_map.nodes.has(current_node_id):
			current_map.nodes[current_node_id].is_completed = true
		
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
	if not current_map or current_node_id.is_empty():
		return
	
	var node = current_map.get_node(current_node_id)
	if node:
		node.is_completed = true
		_update_available_nodes()
		# Emit map_changed to refresh map display
		map_changed.emit()

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
	var deck_card = DeckCardData.new(card_id, owner_character_id, upgrades, transcended, transcendent_card_id)
	deck.append(deck_card)
	
	# Update model if available
	if deck_model:
		deck_model.deck.append(deck_card)
		# Add to draw pile in model
		var deck_index = deck_model.deck.size() - 1
		deck_model.draw_pile.append(deck_index)
		deck_model.draw_pile_changed.emit()
		deck_model.deck_changed.emit()
		_sync_deck_arrays_from_model()
	else:
		# Legacy fallback
		# Also add to draw pile (create a copy)
		var card_copy = DeckCardData.new(card_id, owner_character_id, upgrades, transcended, transcendent_card_id)
		draw_pile.append(card_copy)
		draw_pile_changed.emit()
		deck_changed.emit()

func remove_card_from_deck(index: int):
	## Remove a card from the deck by index
	if index >= 0 and index < deck.size():
		deck.remove_at(index)
		deck_changed.emit()

func get_deck_size() -> int:
	return deck.size()

func _initialize_deck_piles():
	## Initialize draw pile with all cards from deck, clear hand and discard
	# Use deck_model if available (preferred)
	if deck_model:
		var deck_array: Array[DeckCardData] = []
		for card in deck:
			if card is DeckCardData:
				deck_array.append(card)
		deck_model.initialize(deck_array)
		# Sync legacy arrays for backward compatibility
		_sync_deck_arrays_from_model()
	else:
		# Legacy fallback
		draw_pile.clear()
		for card in deck:
			if card is DeckCardData:
				# Create a copy of the DeckCardData
				var card_copy = DeckCardData.new(card.card_id, card.owner_character_id, card.applied_upgrades.duplicate(), card.is_transcended, card.transcendent_card_id)
				draw_pile.append(card_copy)
			else:
				draw_pile.append(card)
		hand.clear()
		discard_pile.clear()
		_shuffle_draw_pile()

func _sync_deck_arrays_from_model():
	## Sync legacy arrays from deck_model (for backward compatibility)
	if not deck_model:
		return
	
	# Sync draw_pile, hand, discard_pile from model indices
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	
	for index in deck_model.draw_pile:
		if index >= 0 and index < deck_model.deck.size():
			draw_pile.append(deck_model.deck[index])
	
	for index in deck_model.hand:
		if index >= 0 and index < deck_model.deck.size():
			hand.append(deck_model.deck[index])
	
	for index in deck_model.discard_pile:
		if index >= 0 and index < deck_model.deck.size():
			discard_pile.append(deck_model.deck[index])

func _shuffle_draw_pile():
	## Shuffle the draw pile randomly
	draw_pile.shuffle()
	draw_pile_changed.emit()

func shuffle_discard_into_draw():
	## Shuffle discard pile into draw pile (when draw is empty)
	if discard_pile.size() > 0:
		# Move all discard to draw
		for card in discard_pile:
			draw_pile.append(card)
		discard_pile.clear()
		_shuffle_draw_pile()
		discard_pile_changed.emit()

func draw_cards(count: int = 5):
	## Draw cards from draw pile into hand
	## If draw pile is empty, shuffle discard into draw first
	if deck_model:
		# Use model (preferred)
		deck_model.draw_cards(count)
		_sync_deck_arrays_from_model()
	else:
		# Legacy fallback
		for i in range(count):
			if draw_pile.size() == 0:
				shuffle_discard_into_draw()
				# If still empty after shuffle, can't draw
				if draw_pile.size() == 0:
					break
			
			if draw_pile.size() > 0:
				var card = draw_pile.pop_front()
				hand.append(card)
		
		if hand.size() > 0:
			hand_changed.emit()
		if draw_pile.size() >= 0:  # Always emit if we modified draw pile
			draw_pile_changed.emit()

func discard_hand():
	## Move all cards from hand to discard pile
	if deck_model:
		# Use model (preferred)
		deck_model.discard_hand()
		_sync_deck_arrays_from_model()
	else:
		# Legacy fallback
		for card in hand:
			discard_pile.append(card)
		hand.clear()
		hand_changed.emit()
		discard_pile_changed.emit()

func get_draw_pile_count() -> int:
	if deck_model:
		return deck_model.get_draw_pile_count()
	return draw_pile.size()

func get_discard_pile_count() -> int:
	if deck_model:
		return deck_model.get_discard_pile_count()
	return discard_pile.size()

func get_hand_size() -> int:
	return hand.size()

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
	reward_card_pool.clear()
	
	# Generate deck: 3 generic + 2 unique per character = 15 cards total
	for char_data in character_data_list:
		# Add 3 generic cards based on role
		var generic_card_ids = RoleStarterSet.get_generic_starters_for_role(char_data.role)
		for card_id in generic_card_ids:
			var deck_card = DeckCardData.new(card_id, char_data.id)
			deck.append(deck_card)
		
		# Add 2 unique cards
		for unique_card in char_data.starter_unique_cards:
			if unique_card and unique_card.id:
				var deck_card = DeckCardData.new(unique_card.id, char_data.id)
				deck.append(deck_card)
		
		# Merge reward card pool
		for reward_card in char_data.reward_card_pool:
			if reward_card:
				reward_card_pool.append(reward_card)
	
	# Initialize deck piles
	_initialize_deck_piles()
	deck_changed.emit()

func initialize_quests(character_data_list: Array[CharacterData]):
	## Initialize quest state for selected characters
	## character_data_list must be exactly 3 CharacterData resources
	if character_data_list.size() != 3:
		push_error("initialize_quests requires exactly 3 characters, got %d" % character_data_list.size())
		return
	
	quests.clear()
	
	for char_data in character_data_list:
		if char_data.quest:
			var quest_state = {
				"quest_id": char_data.quest.id,
				"character_id": char_data.id,
				"title": char_data.quest.title,
				"description": char_data.quest.description,
				"progress": 0,
				"progress_max": char_data.quest.progress_max,
				"tracking_type": char_data.quest.tracking_type,
				"params": char_data.quest.params.duplicate(),
				"is_complete": false
			}
			# Use character_id as key for easy lookup
			quests[char_data.id] = quest_state
	
	quests_changed.emit()

func set_pending_rewards(bundle: RewardBundle):
	## Set pending rewards (called by EncounterScreen)
	pending_rewards = bundle

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

func can_upgrade_card_at(deck_index: int) -> bool:
	## Check if a card at the given index can be upgraded
	if deck_index < 0 or deck_index >= deck.size():
		return false
	
	var card_instance = deck[deck_index]
	if not card_instance is DeckCardData:
		return false
	
	# Check if card has available upgrades
	var pool = DataRegistry.get_upgrade_pool_for_card(card_instance.card_id)
	if pool.is_empty():
		return false
	
	# Check if all upgrades are already applied (limit to 1 for now)
	if card_instance.applied_upgrades.size() >= 1:
		return false
	
	# Check if there are any available upgrades
	var available = []
	for upgrade_id in pool:
		if not card_instance.applied_upgrades.has(upgrade_id):
			available.append(upgrade_id)
	
	return not available.is_empty()

func apply_upgrade_to_card_at(deck_index: int, upgrade_id: String) -> bool:
	## Apply an upgrade to a card instance at the given deck index
	if deck_index < 0 or deck_index >= deck.size():
		return false
	
	var card_instance = deck[deck_index]
	if not card_instance is DeckCardData:
		return false
	
	# Check if upgrade is already applied
	if card_instance.applied_upgrades.has(upgrade_id):
		return false
	
	# Limit to 1 upgrade per card for now
	if card_instance.applied_upgrades.size() >= 1:
		return false
	
	# Check if upgrade is valid for this card
	var pool = DataRegistry.get_upgrade_pool_for_card(card_instance.card_id)
	if not pool.has(upgrade_id):
		return false
	
	# Apply upgrade
	card_instance.applied_upgrades.append(upgrade_id)
	
	# Update the card in draw/discard/hand piles if it exists
	_update_card_in_piles(card_instance.card_id, card_instance.owner_character_id, card_instance.applied_upgrades)
	
	deck_changed.emit()
	return true

func _update_card_in_piles(card_id: String, owner_id: String, upgrades: Array[String]):
	## Update matching cards in draw/discard/hand piles with new upgrades
	# This ensures consistency across all piles
	for pile in [draw_pile, hand, discard_pile]:
		for card in pile:
			if card is DeckCardData:
				if card.card_id == card_id and card.owner_character_id == owner_id:
					# Update upgrades (but preserve other state)
					card.applied_upgrades = upgrades.duplicate()

func get_upgradeable_deck_indices() -> Array[int]:
	## Get all deck indices of cards that can be upgraded
	var indices: Array[int] = []
	for i in range(deck.size()):
		if can_upgrade_card_at(i):
			indices.append(i)
	return indices

