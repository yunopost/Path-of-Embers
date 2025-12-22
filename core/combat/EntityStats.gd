extends RefCounted
class_name EntityStats

## Tracks HP, block, and status effects for entities (player/enemies)

signal hp_changed(new_hp: int)
signal max_hp_changed(new_max_hp: int)
signal block_changed(new_block: int)
signal died
signal status_effects_changed  # Emitted when status_effects dictionary changes

var current_hp: int = 50
var max_hp: int = 50
var block: int = 0
var status_effects: Dictionary = {}  # Effect type -> amount/value

func _init(initial_hp: int = 50, initial_max_hp: int = 50):
	current_hp = initial_hp
	max_hp = initial_max_hp
	block = 0

func take_damage(amount: int, ignore_block: bool = false):
	## Apply damage, accounting for block and vulnerable status
	## ignore_block: If true, bypass block completely
	var base_damage = amount
	
	# Apply vulnerable multiplier (1.5x damage) if vulnerable status is active
	var vulnerable_duration = get_status("vulnerable")
	if vulnerable_duration != null and vulnerable_duration > 0:
		base_damage = int(base_damage * 1.5)
	
	var actual_damage = base_damage
	if not ignore_block and block > 0:
		if base_damage <= block:
			block -= base_damage
			actual_damage = 0
			block_changed.emit(block)
		else:
			actual_damage = base_damage - block
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
	status_effects_changed.emit()

func get_status(effect_type: String):
	return status_effects.get(effect_type, null)

func is_alive() -> bool:
	return current_hp > 0

func expire_status_effects():
	## Decrease duration-based status effects by 1 turn, remove when duration reaches 0
	## Called at the start/end of each turn
	var statuses_to_remove: Array[String] = []
	
	for effect_type in status_effects.keys():
		var value = status_effects[effect_type]
		# If value is a number (duration), decrease it
		if value is int or value is float:
			var duration = int(value)
			duration -= 1
			if duration <= 0:
				statuses_to_remove.append(effect_type)
			else:
				status_effects[effect_type] = duration
	
	# Remove expired statuses
	for effect_type in statuses_to_remove:
		status_effects.erase(effect_type)
	
	# Emit signal if any statuses changed
	if statuses_to_remove.size() > 0 or status_effects.size() > 0:
		status_effects_changed.emit()
