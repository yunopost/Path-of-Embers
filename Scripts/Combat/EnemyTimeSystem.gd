extends RefCounted
class_name EnemyTimeSystem

## Manages enemy timer ticking and trigger resolution
## Does not know about UI - pure game logic

var enemies: Array = []  # Array of Enemy instances
var intent_system: IntentSystem
var combat_controller: CombatController = null  # Reference for enemy.perform_intent()

func _init(p_intent_system: IntentSystem, p_combat_controller: CombatController = null):
	intent_system = p_intent_system
	combat_controller = p_combat_controller

func register_enemies(p_enemies: Array):
	## Register the list of enemies to manage
	enemies = p_enemies

func tick_all_enemies(amount: int):
	## Tick all enemies' timers by the given amount
	for enemy in enemies:
		if not enemy.stats.is_alive():
			continue
		
		enemy.time_current -= amount
		# Ensure timer doesn't go below 0
		if enemy.time_current < 0:
			enemy.time_current = 0
		
		# Emit time changed signal
		enemy.time_changed.emit(enemy.time_current, enemy.time_max)

func force_all_enemies_to_zero():
	## Force all enemies' timers to 0 (used when End Turn is pressed)
	for enemy in enemies:
		if not enemy.stats.is_alive():
			continue
		
		enemy.time_current = 0
		enemy.time_changed.emit(enemy.time_current, enemy.time_max)

func resolve_enemy_time_triggers(_reason: String):
	## Resolve all enemies whose timer has hit 0
	## reason: String describing why this was called (e.g., "card_played", "end_turn")
	
	# Collect enemies that hit 0 in stable array order
	var enemies_to_act: Array = []
	for enemy in enemies:
		if not enemy.stats.is_alive():
			continue
		
		if enemy.time_current <= 0:
			enemies_to_act.append(enemy)
	
	# Execute all enemies that hit 0
	for enemy in enemies_to_act:
		# Enemy performs its intent
		enemy.perform_intent(combat_controller)
		
		# After acting, reset timer and generate new intent
		if enemy.stats.is_alive():  # Check if enemy is still alive after action
			# Check if intent has time_max_override
			var reset_time_max = enemy.time_max
			if enemy.intent and enemy.intent.time_max_override > 0:
				reset_time_max = enemy.intent.time_max_override
			
			enemy.time_current = reset_time_max
			var new_intent = intent_system.generate_intent(enemy)
			enemy.set_intent(new_intent)
			enemy.time_changed.emit(enemy.time_current, enemy.time_max)

