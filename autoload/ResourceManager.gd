extends Node

## Autoload singleton - Manages game resources (gold, HP, energy, block)
## Handles resource-related state and signals

signal gold_changed
signal hp_changed
signal block_changed
signal energy_changed

var gold: int = 0
var current_hp: int = 50
var max_hp: int = 50
var block: int = 0
var energy: int = 3
var max_energy: int = 3

func _ready():
	# Initialize with default values
	gold = 0
	current_hp = 50
	max_hp = 50
	block = 0
	energy = 3
	max_energy = 3

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

func reset_resources():
	## Reset all resources to default values
	set_gold(0)
	set_hp(50, 50)
	set_block(0)
	set_energy(3, 3)

