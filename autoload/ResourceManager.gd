extends Node

## Autoload singleton - Manages game resources (gold, HP, energy, block)
## Handles resource-related state and signals

signal gold_changed
signal hp_changed
signal block_changed
signal energy_changed
signal upgrade_points_changed

var gold: int = 0
var current_hp: int = 50
var max_hp: int = 50
var block: int = 0
var energy: int = 3
var max_energy: int = 3
var upgrade_points: int = 0  # Run-wide upgrade currency (Phase 4)

func _ready():
	# Initialize with default values
	gold = 0
	current_hp = 50
	max_hp = 50
	block = 0
	energy = 3
	max_energy = 3
	upgrade_points = 0

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

func set_upgrade_points(value: int) -> void:
	var clamped = max(0, value)
	if upgrade_points != clamped:
		upgrade_points = clamped
		upgrade_points_changed.emit()

func add_upgrade_points(amount: int) -> void:
	set_upgrade_points(upgrade_points + amount)

func spend_upgrade_points(amount: int) -> bool:
	## Deduct upgrade_points if affordable. Returns false if insufficient funds.
	if upgrade_points < amount:
		return false
	set_upgrade_points(upgrade_points - amount)
	return true

func reset_resources():
	## Reset all resources to default values (used by reset_run when no party data available)
	set_gold(0)
	set_hp(50, 50)
	set_block(0)
	set_energy(3, 3)
	set_upgrade_points(0)

func reset_resources_for_party(party_max_hp: int) -> void:
	## Reset all resources, seeding max_hp from the party's combined hp_base.
	## Called by RunState.generate_starter_deck() after the party is known.
	set_gold(0)
	set_hp(party_max_hp, party_max_hp)
	set_block(0)
	set_energy(3, 3)
	set_upgrade_points(0)

