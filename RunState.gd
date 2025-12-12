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

# Party (3 characters)
var party: Array = []  # Will contain character data

# Deck
var deck: Array = []  # Will contain DeckCardData with upgrades and transcend state

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
		DeckCardData.new("bash_1")
	]
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
	deck_changed.emit()

func remove_card_from_deck(index: int):
	## Remove a card from the deck by index
	if index >= 0 and index < deck.size():
		deck.remove_at(index)
		deck_changed.emit()

func get_deck_size() -> int:
	return deck.size()

