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

## Optional Callable set by PetBoard when SHARED_POOL pets are in play.
## Signature: func(raw_damage: int) -> int
## Intercepts post-vulnerable, pre-block damage; returns remaining damage.
var damage_interceptor: Callable = Callable()

func _init(initial_hp: int = 50, initial_max_hp: int = 50):
	current_hp = initial_hp
	max_hp = initial_max_hp
	block = 0

func take_damage(amount: int, ignore_block: bool = false):
	## Apply damage, accounting for block and vulnerable status
	## ignore_block: If true, bypass block completely
	var base_damage = amount
	
	# Apply vulnerable multiplier (1.5x damage) if vulnerable status is active
	var vulnerable_duration = get_status(StatusEffectType.VULNERABLE)
	if vulnerable_duration != null and vulnerable_duration > 0:
		base_damage = int(base_damage * 1.5)
	
	## Pet interception: after vulnerable calc, before block/hp
	if damage_interceptor.is_valid():
		base_damage = damage_interceptor.call(base_damage)

	if base_damage <= 0:
		return

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
	## Unconditionally reset block to 0.
	## NOTE: under card-clock combat the "Block survives the next enemy action"
	## rule (RETAIN_BLOCK_THIS_TURN) is checked and consumed by
	## CombatController._on_enemy_acted(), not here — this setter is for
	## effects that voluntarily zero their own block (e.g. Block-to-Energy).
	block = 0
	block_changed.emit(block)

func apply_status(effect_type: String, value):
	## Apply or update a status effect
	## For stacking statuses (strength, dexterity, faith): adds to existing value
	## For duration-based statuses (weakness, vulnerable): replaces existing value
	## Use StatusEffectType constants for type safety
	
	if StatusEffectType.is_stacking(effect_type):
		# Stacking status: add to existing value
		var current_value = status_effects.get(effect_type, 0)
		if current_value is int or current_value is float:
			status_effects[effect_type] = int(current_value) + int(value)
		else:
			status_effects[effect_type] = int(value)
	else:
		# Duration-based status: replace value
		status_effects[effect_type] = value
	status_effects_changed.emit()

func get_status(effect_type: String):
	return status_effects.get(effect_type, null)

func is_alive() -> bool:
	return current_hp > 0

func tick_statuses(n: int):
	## Decrease duration-based status effects by n ticks, remove when duration reaches 0.
	## Card-Clock Combat spec §4/§10.5: statuses tick on the shared clock, not at
	## turn start. Conversion from old per-turn data: 1 turn = 4 ticks.
	## Skips stacking status effects (strength, dexterity, faith) - they persist until combat ends.
	## Skips pending effects that are checked at specific times (pending_strength_if_no_damage).
	## Skips RETAIN_BLOCK_THIS_TURN — a one-shot flag consumed on the next enemy action, not a duration.
	if n <= 0:
		return
	var statuses_to_remove: Array[String] = []
	
	for effect_type in status_effects.keys():
		# Skip stacking statuses - they don't expire
		if StatusEffectType.is_stacking(effect_type):
			continue
		# Skip pending statuses - they're handled at specific times
		if StatusEffectType.is_pending(effect_type):
			continue
		# Skip the one-shot retain-block flag - it isn't a tick duration
		if effect_type == StatusEffectType.RETAIN_BLOCK_THIS_TURN:
			continue
		
		var value = status_effects[effect_type]
		# If value is a number (duration in ticks), decrease it
		if value is int or value is float:
			var duration = int(value) - n
			if duration <= 0:
				statuses_to_remove.append(effect_type)
			else:
				status_effects[effect_type] = duration
	
	# Remove expired statuses
	for effect_type in statuses_to_remove:
		status_effects.erase(effect_type)
	
	# Emit signal if any statuses changed
	if statuses_to_remove.size() > 0:
		status_effects_changed.emit()

func clear_combat_status_effects():
	## Clear stacking status effects that persist until combat ends
	for stacking_type in StatusEffectType.get_stacking_statuses():
		status_effects.erase(stacking_type)
	status_effects_changed.emit()
