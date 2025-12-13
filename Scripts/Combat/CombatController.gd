extends Node
class_name CombatController

## Manages combat flow: turns, card play, enemy actions

signal turn_ended
signal combat_started
signal combat_ended

var player_stats: EntityStats
var enemies: Array[CombatEnemy] = []
var current_energy: int = 3
var max_energy: int = 3
var combat_active: bool = false

func _ready():
	player_stats = EntityStats.new(RunState.current_hp, RunState.max_hp)

func start_combat(enemy_data: Array):
	## Initialize combat with enemies
	combat_active = true
	
	# Create enemies
	enemies.clear()
	for enemy_info in enemy_data:
		var enemy = CombatEnemy.new(
			enemy_info.get("id", "enemy"),
			enemy_info.get("name", "Enemy"),
			enemy_info.get("max_hp", 50)
		)
		enemies.append(enemy)
	
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
	RunState.energy = current_energy
	RunState.max_energy = max_energy
	RunState.set_energy(current_energy, max_energy)
	
	# Draw 5 cards
	RunState.draw_cards(5)

func can_play_card(card_cost: int) -> bool:
	return current_energy >= card_cost

func play_card(deck_card: DeckCardData, target: Node = null):
	## Play a card from hand
	if not combat_active:
		return false
	
	# Get card cost (placeholder - should load from CardData)
	var card_cost = 1
	
	if not can_play_card(card_cost):
		return false
	
	# Remove card from hand
	var card_index = RunState.hand.find(deck_card)
	if card_index >= 0:
		RunState.hand.remove_at(card_index)
		RunState.hand_changed.emit()
	
	# Spend energy
	current_energy -= card_cost
	RunState.energy = current_energy
	RunState.set_energy(current_energy, max_energy)
	
	# Resolve card effects
	_resolve_card_effects(deck_card, target)
	
	# Move card to discard
	RunState.discard_pile.append(deck_card)
	RunState.discard_pile_changed.emit()
	
	return true

func _resolve_card_effects(deck_card: DeckCardData, target: Node = null):
	## Resolve the effects of a played card
	# TODO: Load actual CardData and get base_effects
	# For now, create placeholder effects based on card_id
	var effects = _get_card_effects(deck_card)
	
	var target_stats: EntityStats = null
	if target:
		# Find target's EntityStats
		if target.has_method("get_stats"):
			target_stats = target.get_stats()
		elif target.has_meta("enemy"):
			var enemy = target.get_meta("enemy")
			if enemy is CombatEnemy:
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
	## Get effects for a card (placeholder - should load from CardData)
	var effects: Array = []
	
	# Simple placeholder logic based on card_id
	if "attack" in deck_card.card_id or "strike" in deck_card.card_id:
		var damage_effect = EffectData.new("DealDamage", {"amount": 6})
		effects.append(damage_effect)
	elif "defend" in deck_card.card_id or "block" in deck_card.card_id:
		var block_effect = EffectData.new("GainBlock", {"amount": 5})
		effects.append(block_effect)
	
	return effects

func end_player_turn():
	## End the player turn and start enemy turn
	if not combat_active:
		return
	
	# Discard hand
	RunState.discard_hand()
	
	# Enemy turn
	await _enemy_turn()
	
	# Start new player turn
	start_player_turn()
	turn_ended.emit()

func _enemy_turn():
	## Execute enemy actions
	for enemy in enemies:
		if not enemy.stats.is_alive():
			continue
		
		# Set basic attack intent (placeholder)
		var attack_effect = EffectData.new("DealDamage", {"amount": 5})
		enemy.set_intent(attack_effect)
		
		# Execute intent
		if enemy.intent:
			EffectResolver.resolve_effect(enemy.intent, enemy.stats, player_stats)
		
		# Small delay between enemy actions
		await get_tree().create_timer(0.5).timeout
	
	# Update RunState HP
	RunState.set_hp(player_stats.current_hp, player_stats.max_hp)

func get_player_stats() -> EntityStats:
	return player_stats

func get_enemies() -> Array[CombatEnemy]:
	return enemies
