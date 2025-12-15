extends RefCounted
class_name CombatModel

## Combat state model - authoritative source for combat state (architecture rule 8.1)
## No rendering, just data + rules

var player_hp: int = 0
var player_max_hp: int = 0
var player_block: int = 0
var player_energy: int = 0
var player_max_energy: int = 3

var enemies: Array[Enemy] = []
var turn_number: int = 0
var is_player_turn: bool = true
var combat_active: bool = false

signal player_hp_changed(new_hp: int, max_hp: int)
signal player_block_changed(new_block: int)
signal player_energy_changed(new_energy: int, max_energy: int)
signal turn_changed(turn_number: int, is_player_turn: bool)
signal combat_ended(victory: bool)

func initialize(p_max_hp: int, p_max_energy: int = 3):
	## Initialize combat model
	player_max_hp = p_max_hp
	player_hp = p_max_hp
	player_max_energy = p_max_energy
	player_energy = p_max_energy
	player_block = 0
	turn_number = 0
	is_player_turn = true
	combat_active = true
	enemies.clear()

func set_player_hp(new_hp: int):
	## Set player HP (clamped to 0-max)
	player_hp = clamp(new_hp, 0, player_max_hp)
	player_hp_changed.emit(player_hp, player_max_hp)

func set_player_block(new_block: int):
	## Set player block
	player_block = max(0, new_block)
	player_block_changed.emit(player_block)

func set_player_energy(new_energy: int):
	## Set player energy (clamped to 0-max)
	player_energy = clamp(new_energy, 0, player_max_energy)
	player_energy_changed.emit(player_energy, player_max_energy)

func add_enemy(enemy: Enemy):
	## Add an enemy to combat
	enemies.append(enemy)

func remove_enemy(enemy_id: String):
	## Remove an enemy by ID
	for i in range(enemies.size()):
		if enemies[i].enemy_id == enemy_id:
			enemies.remove_at(i)
			break

func get_alive_enemies() -> Array[Enemy]:
	## Get all alive enemies
	var alive: Array[Enemy] = []
	for enemy in enemies:
		if enemy.stats.is_alive():
			alive.append(enemy)
	return alive

func is_combat_over() -> bool:
	## Check if combat is over
	if not combat_active:
		return true
	
	# Check if all enemies are dead
	var alive = get_alive_enemies()
	if alive.is_empty():
		return true
	
	# Check if player is dead
	if player_hp <= 0:
		return true
	
	return false

func end_combat(victory: bool):
	## End combat
	combat_active = false
	combat_ended.emit(victory)

