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
signal quests_changed
signal hp_changed
signal block_changed
signal energy_changed
signal buffs_changed
signal hand_changed
signal draw_pile_changed
signal discard_pile_changed

# Party (3 characters)
var party: Array = []  # Will contain character data

# Deck
var deck: Array = []  # Full deck - all cards owned
var draw_pile: Array = []  # Cards available to draw
var hand: Array = []  # Cards currently in hand
var discard_pile: Array = []  # Cards that have been played/discarded

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
var node_position: int = 0

# Quests
var quests: Array = []  # Will contain quest data

# Buffs list
var buffs: Array = []  # Will contain buff/debuff data

# Settings
var tap_to_play: bool = false

func _ready():
	# Initialize with dummy values
	party = ["Character1", "Character2", "Character3"]
	# Initialize deck with simple card IDs (will be converted to DeckCardData by SaveManager if loading)
	deck = [
		DeckCardData.new("strike_1"),
		DeckCardData.new("defend_1"),
		DeckCardData.new("bash_1"),
		DeckCardData.new("defend_1"),
		DeckCardData.new("defend_1")
	]
	_initialize_deck_piles()
	relics = ["Starting Relic"]
	gold = 100
	current_hp = 42
	max_hp = 50
	block = 0
	energy = 3
	max_energy = 3
	act = 1
	map = "Act1"
	node_position = 0
	quests = []
	buffs = []

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

func set_map(value: String):
	if map != value:
		map = value
		map_changed.emit()

func add_card_to_deck(card_id: String, upgrades: Array = [], transcended: bool = false, transcendent_card_id: String = ""):
	## Add a card to the deck with optional upgrades
	var deck_card = DeckCardData.new(card_id, upgrades, transcended, transcendent_card_id)
	deck.append(deck_card)
	# Also add to draw pile (create a copy)
	var card_copy = DeckCardData.new(card_id, upgrades, transcended, transcendent_card_id)
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
	# Create deep copies of deck cards for draw pile
	draw_pile.clear()
	for card in deck:
		if card is DeckCardData:
			# Create a copy of the DeckCardData
			var card_copy = DeckCardData.new(card.card_id, card.applied_upgrades.duplicate(), card.is_transcended, card.transcendent_card_id)
			draw_pile.append(card_copy)
		else:
			draw_pile.append(card)
	hand.clear()
	discard_pile.clear()
	_shuffle_draw_pile()

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
	for card in hand:
		discard_pile.append(card)
	hand.clear()
	hand_changed.emit()
	discard_pile_changed.emit()

func get_draw_pile_count() -> int:
	return draw_pile.size()

func get_discard_pile_count() -> int:
	return discard_pile.size()

func get_hand_size() -> int:
	return hand.size()

