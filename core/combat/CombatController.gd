extends Node
class_name CombatController

## Manages combat flow: turns, card play, enemy actions

signal turn_ended
signal combat_started
signal combat_ended

var player_stats: EntityStats
var enemies: Array[Enemy] = []
var current_energy: int = 3
var max_energy: int = 3
var combat_active: bool = false

var enemy_time_system: EnemyTimeSystem
var intent_system: IntentSystem

func _ready():
	player_stats = EntityStats.new(RunState.current_hp, RunState.max_hp)
	
	# Initialize timer and intent systems
	intent_system = IntentSystem.new()
	enemy_time_system = EnemyTimeSystem.new(intent_system, self)

func start_combat(enemy_data: Array):
	## Initialize combat with enemies
	combat_active = true
	
	# Initialize deck piles (ensure fresh state for combat)
	RunState._initialize_deck_piles()
	
	# Create enemies
	enemies.clear()
	for enemy_info in enemy_data:
		var enemy = Enemy.new(
			enemy_info.get("id", "enemy"),
			enemy_info.get("name", "Enemy"),
			enemy_info.get("max_hp", 50),
			enemy_info.get("time_max", 3)
		)
		
		# Generate initial intent
		var initial_intent = intent_system.generate_intent(enemy)
		enemy.set_intent(initial_intent)
		
		enemies.append(enemy)
	
	# Register enemies with time system
	enemy_time_system.register_enemies(enemies)
	
	# Sync player HP with RunState
	player_stats.current_hp = RunState.current_hp
	player_stats.max_hp = RunState.max_hp
	
	# Start player turn
	start_player_turn()
	combat_started.emit()

func start_player_turn():
	## Begin a new player turn
	if not combat_active:
		return
	
	# Reset block at start of turn (combat rule)
	player_stats.reset_block()
	RunState.set_block(0)
	
	# Refill energy
	current_energy = max_energy
	# Use set_energy() which will emit the signal if value changed
	RunState.set_energy(current_energy, max_energy)
	
	# Draw 5 cards
	RunState.draw_cards(5)

func can_play_card(card_cost: int) -> bool:
	return current_energy >= card_cost

func play_card(deck_card: DeckCardData, target: Node = null):
	## Play a card from hand
	if not combat_active:
		return false
	
	# Get effective card cost (including upgrades) using CardRules
	var card_data = DataRegistry.get_card_data(deck_card.card_id)
	if not card_data:
		return false
	var card_cost = CardRules.get_effective_cost(card_data, deck_card)
	
	if not can_play_card(card_cost):
		return false
	
	# Remove card from hand using instance_id
	if not deck_card:
		push_error("CombatController.play_card: deck_card is null")
		return false
	
	# Get instance_id - convert to String explicitly to ensure type safety
	var instance_id: String = str(deck_card.instance_id)
	if instance_id.is_empty():
		push_error("CombatController.play_card: deck_card has empty instance_id")
		return false
	
	# Remove from deck_model hand
	var hand_index = RunState.deck_model.hand.find(instance_id)
	if hand_index >= 0:
		RunState.deck_model.hand.remove_at(hand_index)
		RunState.deck_model.hand_changed.emit()
	
	# Spend energy
	current_energy -= card_cost
	# Use set_energy() which will emit the signal if value changed
	RunState.set_energy(current_energy, max_energy)
	
	# Resolve card effects
	_resolve_card_effects(deck_card, target)
	
	# Determine timer tick amount (default 1, can be overridden by card)
	var timer_tick_amount = _get_card_timer_tick(deck_card)
	
	# Tick all enemies
	enemy_time_system.tick_all_enemies(timer_tick_amount)
	
	# Resolve any enemies that hit 0
	enemy_time_system.resolve_enemy_time_triggers("card_played")
	
	# Move card to discard pile using instance_id
	# Re-fetch instance_id with explicit String conversion to ensure type safety
	var discard_instance_id: String = str(deck_card.instance_id)
	if discard_instance_id.is_empty():
		push_warning("CombatController.play_card: instance_id is empty, cannot add to discard")
	else:
		# Add to deck_model discard pile
		var discard_index = RunState.deck_model.discard_pile.find(discard_instance_id)
		if discard_index < 0:  # Not found, add it
			RunState.deck_model.discard_pile.append(discard_instance_id)
			RunState.deck_model.discard_pile_changed.emit()
	
	return true

func _resolve_card_effects(deck_card: DeckCardData, target: Node = null):
	## Resolve the effects of a played card
	## Loads CardData and applies base_effects with upgrade modifications
	var effects = _get_card_effects(deck_card)
	
	var target_stats: EntityStats = null
	if target:
		# Find target's EntityStats
		if target.has_method("get_stats"):
			target_stats = target.get_stats()
		elif target.has_meta("enemy"):
			var enemy = target.get_meta("enemy")
			if enemy is Enemy:
				target_stats = enemy.stats
		else:
			# Try to find enemy by iterating through enemies
			for enemy in enemies:
				if target.name.begins_with("Enemy_") and enemy.enemy_id in target.name:
					target_stats = enemy.stats
					break
	
	# Resolve effects
	var draw_count = EffectResolver.resolve_effects(effects, player_stats, target_stats)
	
	# Update RunState block
	RunState.set_block(player_stats.block)
	
	# Update RunState HP
	RunState.set_hp(player_stats.current_hp, player_stats.max_hp)
	
	if draw_count > 0:
		RunState.draw_cards(draw_count)

func _get_card_effects(deck_card: DeckCardData) -> Array:
	## Get effects for a card from CardData, with upgrade modifications applied
	var effects: Array = []
	
	# Load CardData from DataRegistry
	var card_data = DataRegistry.get_card_data(deck_card.card_id)
	if not card_data:
		push_warning("CombatController._get_card_effects: Could not find CardData for card_id: " + deck_card.card_id)
		return effects
	
	# Start with base effects from CardData
	for base_effect in card_data.base_effects:
		if base_effect is EffectData:
			# Create a copy of the effect to avoid modifying the original
			var effect_copy = EffectData.new(base_effect.effect_type, base_effect.params.duplicate())
			effects.append(effect_copy)
	
	# Apply upgrade modifications to effects
	for upgrade_id in deck_card.applied_upgrades:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		if not upgrade_def.has("effects"):
			continue
		
		var upgrade_effects = upgrade_def["effects"]
		
		# Apply damage modifications
		if upgrade_effects.has("damage_delta"):
			var damage_delta = upgrade_effects["damage_delta"]
			# Find damage effects and modify them
			for effect in effects:
				if effect is EffectData and effect.effect_type == "damage":
					var current_amount = effect.params.get("amount", 0)
					effect.params["amount"] = current_amount + damage_delta
		
		# Apply block modifications
		if upgrade_effects.has("block_delta"):
			var block_delta = upgrade_effects["block_delta"]
			# Find block effects and modify them
			for effect in effects:
				if effect is EffectData and effect.effect_type == "block":
					var current_amount = effect.params.get("amount", 0)
					effect.params["amount"] = current_amount + block_delta
		
		# Apply heal modifications
		if upgrade_effects.has("heal_delta"):
			var heal_delta = upgrade_effects["heal_delta"]
			# Find heal effects and modify them
			for effect in effects:
				if effect is EffectData and effect.effect_type == "heal":
					var current_amount = effect.params.get("amount", 0)
					effect.params["amount"] = current_amount + heal_delta
		
		# Add new effects from upgrades (e.g., "draw card" upgrade)
		# This can be extended for upgrades that add new effects
	
	return effects

func _get_card_timer_tick(deck_card: DeckCardData) -> int:
	## Get the timer tick amount for a card
	## Returns 0 if card has Haste upgrade, 1 otherwise
	var instance_id_str: String = str(deck_card.instance_id)
	return RunState.get_timer_tick_amount_for_card(instance_id_str)

func end_player_turn():
	## End the player turn and start enemy turn
	if not combat_active:
		return
	
	# Discard hand
	RunState.discard_hand()
	
	# Force all enemies to 0 and resolve triggers
	enemy_time_system.force_all_enemies_to_zero()
	enemy_time_system.resolve_enemy_time_triggers("end_turn")
	
	# Check if combat should end (enemies may have died during enemy actions)
	# Note: CombatScreen will handle the actual transition via signal
	
	# Only start new player turn if combat is still active
	if combat_active:
		start_player_turn()
		turn_ended.emit()

func get_player_stats() -> EntityStats:
	return player_stats

func get_enemies() -> Array[Enemy]:
	return enemies
