extends RefCounted
class_name EntityStats

## Tracks HP, block, and status effects for entities (player/enemies)

signal hp_changed(new_hp: int)
signal max_hp_changed(new_max_hp: int)
signal block_changed(new_block: int)
signal died

var current_hp: int = 50
var max_hp: int = 50
var block: int = 0
var status_effects: Dictionary = {}  # Effect type -> amount/value

func _init(initial_hp: int = 50, initial_max_hp: int = 50):
	current_hp = initial_hp
	max_hp = initial_max_hp
	block = 0

func take_damage(amount: int):
	## Apply damage, accounting for block
	var actual_damage = amount
	if block > 0:
		if amount <= block:
			block -= amount
			actual_damage = 0
			block_changed.emit(block)
		else:
			actual_damage = amount - block
			block = 0
			block_changed.emit(block)
	
	if actual_damage > 0:
		current_hp -= actual_damage
		current_hp = max(0, current_hp)
		hp_changed.emit(current_hp)
		
		if current_hp <= 0:
			died.emit()

func heal(amount: int):
	current_hp = min(current_hp + amount, max_hp)
	hp_changed.emit(current_hp)

func add_block(amount: int):
	block += amount
	block_changed.emit(block)

func reset_block():
	block = 0
	block_changed.emit(block)

func apply_status(effect_type: String, value):
	## Apply or update a status effect
	status_effects[effect_type] = value

func get_status(effect_type: String):
	return status_effects.get(effect_type, null)

func is_alive() -> bool:
	return current_hp > 0
