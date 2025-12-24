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

# Turn tracking
var damage_taken_this_turn: bool = false  # Track if damage was taken this turn (for Fade Step)
var cards_played_this_turn: int = 0  # Track cards played for Clear the way
var block_at_start_of_turn: int = 0  # Track block for block gain detection
var player_start_hp: int = 50  # Track starting HP for damage detection
var min_hp_this_turn: int = 50  # Track minimum HP this turn

func _ready():
	player_stats = EntityStats.new(RunState.current_hp, RunState.max_hp)
	
	# Track HP changes for Fade Step damage detection
	player_stats.hp_changed.connect(_on_player_hp_changed)
	
	# Track block changes for Resonant Frame
	player_stats.block_changed.connect(_on_player_block_changed)
	
	# Initialize timer and intent systems
	intent_system = IntentSystem.new()
	enemy_time_system = EnemyTimeSystem.new(intent_system, self)

func start_combat(enemy_data: Array):
	## Initialize combat with enemies
	## enemy_data can be Array of enemy_info Dicts with "enemy_id" and "count" OR legacy format with "id", "name", "max_hp", "time_max"
	combat_active = true
	
	# Initialize deck piles (ensure fresh state for combat)
	RunState._initialize_deck_piles()
	# Shuffle draw pile for randomized starting hand
	RunState.deck_model.shuffle_draw_pile()
	
	# Create enemies
	enemies.clear()
	for enemy_info in enemy_data:
		var enemy_id = enemy_info.get("enemy_id", enemy_info.get("id", ""))
		
		# Try to load from EnemyData registry first
		var enemy_data_def = DataRegistry.get_enemy(enemy_id)
		
		if enemy_data_def:
			# New system: create from EnemyData
			var count = enemy_info.get("count", 1)
			for i in range(count):
				# Randomize HP from range
				var random_hp = randi_range(enemy_data_def.min_hp, enemy_data_def.max_hp)
				var display_name = enemy_data_def.display_name if enemy_data_def.display_name else enemy_data_def.name
				
				var enemy = Enemy.new(enemy_id, display_name, random_hp, 3)  # Default time_max, will be overridden by move timers
				
				# Generate initial intent
				var initial_intent = intent_system.generate_intent(enemy)
				enemy.set_intent(initial_intent, true)  # Update timer for initial intent
				
				enemies.append(enemy)
		else:
			# Legacy system: create from enemy_info directly
			var enemy = Enemy.new(
				enemy_info.get("id", "enemy"),
				enemy_info.get("name", "Enemy"),
				enemy_info.get("max_hp", 50),
				enemy_info.get("time_max", 3)
			)
			
			# Generate initial intent
			var initial_intent = intent_system.generate_intent(enemy)
			enemy.set_intent(initial_intent, true)  # Update timer for initial intent
			
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
	
	# Reset turn tracking
	damage_taken_this_turn = false
	cards_played_this_turn = 0
	block_at_start_of_turn = player_stats.block
	previous_block = player_stats.block  # Initialize previous_block for block gain detection
	# Store starting HP for damage tracking
	player_start_hp = player_stats.current_hp
	min_hp_this_turn = player_stats.current_hp
	
	# Expire status effects at start of turn
	player_stats.expire_status_effects()
	for enemy in enemies:
		if enemy.stats.is_alive():
			enemy.stats.expire_status_effects()
	
	# Reset block at start of turn (combat rule) - unless retain_block_this_turn is active
	if player_stats.get_status("retain_block_this_turn") == null:
		player_stats.reset_block()
		RunState.set_block(0)
	else:
		# Remove the status after using it (it only applies once)
		player_stats.status_effects.erase("retain_block_this_turn")
		player_stats.status_effects_changed.emit()
	
	# Refill energy
	current_energy = max_energy
	# Use set_energy() which will emit the signal if value changed
	RunState.set_energy(current_energy, max_energy)
	
	# Draw 5 cards
	RunState.draw_cards(5)

func can_play_card(card_cost: int, card_data: CardData = null) -> bool:
	## Check if card can be played based on cost type
	if not card_data:
		return current_energy >= card_cost  # Default energy check
	
	# Curse cards cannot be played
	if card_data.card_type == CardData.CardType.CURSE:
		return false
	
	if card_data.cost_type == CardData.CostType.DISCARD:
		# For discard cost, check if hand has enough cards
		var discard_amount = card_data.discard_cost_amount
		return RunState.deck_model.hand.size() >= discard_amount + 1  # +1 because we remove the played card first
	else:
		# Energy cost
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
	
	if not can_play_card(card_cost, card_data):
		return false
	
	# Check FirstCardOnly keyword (Clear the way) - use CardRules to account for upgrades
	var card_keywords = CardRules.get_card_keywords(deck_card)
	if card_keywords.has("FirstCardOnly") and cards_played_this_turn > 0:
		return false
	
	# Increment cards played counter
	cards_played_this_turn += 1
	
	# Remove card from hand using instance_id
	if not deck_card:
		push_error("CombatController.play_card: deck_card is null")
		return false
	
	# Get instance_id - convert to String explicitly to ensure type safety
	var instance_id: String = str(deck_card.instance_id)
	if instance_id.is_empty():
		push_error("CombatController.play_card: deck_card has empty instance_id")
		return false
	
	# Handle discard cost before removing card from hand (pass instance_id to exclude it)
	var cards_discarded = 0
	if card_data.cost_type == CardData.CostType.DISCARD:
		cards_discarded = _pay_discard_cost(card_data.discard_cost_amount, instance_id)
		if cards_discarded < card_data.discard_cost_amount:
			# Failed to discard enough cards (shouldn't happen if can_play_card worked)
			push_warning("Failed to discard required cards for discard cost card")
			return false
	
	# Remove from deck_model hand
	var hand_index = RunState.deck_model.hand.find(instance_id)
	if hand_index >= 0:
		RunState.deck_model.hand.remove_at(hand_index)
		RunState.deck_model.hand_changed.emit()
	
	# Spend energy (if not discard cost)
	if card_data.cost_type != CardData.CostType.DISCARD:
		current_energy -= card_cost
		# Use set_energy() which will emit the signal if value changed
		RunState.set_energy(current_energy, max_energy)
	
	# Determine timer tick amount BEFORE resolving effects
	# This ensures haste_next_card applies to the NEXT card, not the current one
	var timer_tick_amount = _get_card_timer_tick(deck_card)
	
	# For discard cost cards (Transcend 3), set hit_count dynamically based on cards discarded
	var effects = _get_card_effects(deck_card)
	if card_data.cost_type == CardData.CostType.DISCARD and cards_discarded > 0:
		# Modify effects to set hit_count to cards_discarded
		for effect in effects:
			if effect is EffectData and effect.effect_type == "damage":
				effect.params["hit_count"] = cards_discarded
	
	# Handle Power cards - set up persistent effects
	if card_data.card_type == CardData.CardType.POWER:
		_setup_power_card_effects(deck_card, card_data, effects)
	
	# Resolve card effects (this may set haste_next_card status for the NEXT card)
	_resolve_card_effects_with_effects(deck_card, target, effects)
	
	# Tick all enemies with the timer amount for THIS card
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

func _pay_discard_cost(discard_amount: int, exclude_instance_id: String = "") -> int:
	## Pay discard cost by discarding cards from hand
	## exclude_instance_id: Instance ID to exclude from discarding (the card being played)
	## Returns number of cards actually discarded
	var hand_size = RunState.deck_model.hand.size()
	if hand_size <= discard_amount:
		# Not enough cards (shouldn't happen if can_play_card worked)
		return 0
	
	# Get cards to discard (exclude the card being played)
	var cards_available_to_discard: Array[String] = []
	for card_id in RunState.deck_model.hand:
		if card_id != exclude_instance_id:
			cards_available_to_discard.append(card_id)
	
	if cards_available_to_discard.size() < discard_amount:
		# Not enough cards available (shouldn't happen)
		return 0
	
	# Discard cards (for now, remove from end of available cards; UI for player choice can be added later)
	var discarded = 0
	for i in range(discard_amount):
		if cards_available_to_discard.size() > 0:
			var card_to_discard_id = cards_available_to_discard[cards_available_to_discard.size() - 1]
			cards_available_to_discard.pop_back()
			
			var hand_index = RunState.deck_model.hand.find(card_to_discard_id)
			if hand_index >= 0:
				RunState.deck_model.hand.remove_at(hand_index)
				# Add to discard pile
				var discard_index = RunState.deck_model.discard_pile.find(card_to_discard_id)
				if discard_index < 0:
					RunState.deck_model.discard_pile.append(card_to_discard_id)
				discarded += 1
	
	if discarded > 0:
		RunState.deck_model.hand_changed.emit()
		RunState.deck_model.discard_pile_changed.emit()
	
	return discarded

func _resolve_card_effects_with_effects(deck_card: DeckCardData, target: Node = null, effects: Array = []):
	## Resolve card effects using provided effects array (for dynamic modifications)
	
	# Get card data to check targeting mode
	var card_data = DataRegistry.get_card_data(deck_card.card_id)
	if not card_data:
		return
	
	var draw_count = 0
	
	# Handle ALL_ENEMIES targeting (e.g., Transcend 1)
	if card_data.targeting_mode == CardData.TargetingMode.ALL_ENEMIES:
		# Resolve effects for each alive enemy
		for enemy in enemies:
			if enemy.stats.is_alive():
				draw_count += EffectResolver.resolve_effects(effects, player_stats, enemy.stats, enemy, self)
	else:
		# Single target resolution
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
		
		# Get enemy context if targeting an enemy
		var enemy_context: Enemy = null
		if target:
			if target.has_meta("enemy"):
				enemy_context = target.get_meta("enemy") as Enemy
			else:
				# Try to find enemy by iterating
				for enemy in enemies:
					if target.name.begins_with("Enemy_") and enemy.enemy_id in target.name:
						enemy_context = enemy
						break
		
		# Resolve effects
		draw_count = EffectResolver.resolve_effects(effects, player_stats, target_stats, enemy_context, self)
	
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
		
		# Apply damage multiplier (for half damage double hit)
		if upgrade_effects.has("damage_multiply"):
			var multiplier = upgrade_effects["damage_multiply"]
			if multiplier is float or multiplier is int:
				for effect in effects:
					if effect is EffectData and effect.effect_type == "damage":
						var current_amount = effect.params.get("amount", 0)
						effect.params["amount"] = int(current_amount * float(multiplier))
		
		# Set hit_count (for double hit)
		if upgrade_effects.has("hit_count_set"):
			var hit_count = upgrade_effects["hit_count_set"]
			if hit_count is int:
				for effect in effects:
					if effect is EffectData and effect.effect_type == "damage":
						effect.params["hit_count"] = hit_count
		
		# Apply ignore_block flag
		if upgrade_effects.has("ignore_block") and upgrade_effects["ignore_block"] == true:
			for effect in effects:
				if effect is EffectData and effect.effect_type == "damage":
					effect.params["ignore_block"] = true
		
		# Apply block modifications
		if upgrade_effects.has("block_delta"):
			var block_delta = upgrade_effects["block_delta"]
			# Find block effects and modify them
			for effect in effects:
				if effect is EffectData and effect.effect_type == "block":
					var current_amount = effect.params.get("amount", 0)
					effect.params["amount"] = current_amount + block_delta
		
		# Add block effect (for upgrades that add block)
		if upgrade_effects.has("add_block"):
			var block_amount = upgrade_effects["add_block"]
			if block_amount is int:
				var block_effect = EffectData.new("block", {"amount": block_amount})
				effects.append(block_effect)
		
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
	
	# Check pending effects that trigger at end of turn (Fade Step)
	_check_end_of_turn_effects()
	
	# Only start new player turn if combat is still active
	if combat_active:
		start_player_turn()
		turn_ended.emit()

func _check_end_of_turn_effects():
	## Check effects that trigger at end of turn
	# Fade Step: gain Strength if no damage was taken
	var pending_strength = player_stats.get_status("pending_strength_if_no_damage")
	if pending_strength != null:
		if not damage_taken_this_turn:
			var amount = int(pending_strength)
			player_stats.apply_status("strength", amount)
		# Remove pending status
		player_stats.status_effects.erase("pending_strength_if_no_damage")
		player_stats.status_effects_changed.emit()

func get_player_stats() -> EntityStats:
	return player_stats

func get_enemies() -> Array[Enemy]:
	return enemies

func _remove_temporary_cards():
	## Remove all temporary cards from deck at end of combat
	var cards_to_remove: Array[String] = []
	for instance_id in RunState.deck_order:
		var card = RunState.deck.get(instance_id)
		if card and card.is_temporary:
			cards_to_remove.append(instance_id)
	
	for instance_id in cards_to_remove:
		RunState.remove_card_instance(instance_id)
	
	if cards_to_remove.size() > 0:
		print("CombatController: Removed %d temporary card(s) from deck" % cards_to_remove.size())

func _on_player_hp_changed(new_hp: int):
	## Track minimum HP for damage detection (Fade Step)
	if new_hp < min_hp_this_turn:
		min_hp_this_turn = new_hp
		if min_hp_this_turn < player_start_hp:
			damage_taken_this_turn = true

var previous_block: int = 0  # Track previous block value for block gain detection

func _on_player_block_changed(new_block: int):
	## Handle Resonant Frame: deal damage to random enemy when block increases
	if new_block > previous_block:
		# Check if Resonant Frame power is active
		var resonant_damage = player_stats.get_status("resonant_frame_active")
		if resonant_damage != null and int(resonant_damage) > 0:
			# Deal damage to a random enemy
			var alive_enemies: Array[Enemy] = []
			for enemy in enemies:
				if enemy.stats.is_alive():
					alive_enemies.append(enemy)
			
			if alive_enemies.size() > 0:
				var random_enemy = alive_enemies[randi() % alive_enemies.size()]
				random_enemy.stats.take_damage(int(resonant_damage), false)
	
	previous_block = new_block

func _add_curse_to_hand(is_temporary: bool):
	## Add a curse card to hand (Hexbound Ritual)
	# Get curse card data from DataRegistry
	var curse_card_data = DataRegistry.get_card_data("curse_card")
	if not curse_card_data:
		push_error("CombatController._add_curse_to_hand: Could not find curse_card in DataRegistry")
		return
	
	# Create card instance
	var curse_instance = DeckCardData.new(curse_card_data.id, "", [], false, "", "", is_temporary)
	RunState.deck[curse_instance.instance_id] = curse_instance
	RunState.deck_order.append(curse_instance.instance_id)
	
	# Add to hand
	RunState.deck_model.hand.append(curse_instance.instance_id)
	RunState.deck_model.hand_changed.emit()
	RunState.deck_changed.emit()


func _setup_power_card_effects(deck_card: DeckCardData, card_data: CardData, effects: Array):
	## Set up persistent effects for Power cards
	for effect in effects:
		if not effect is EffectData:
			continue
		
		if effect.effect_type == "block_on_enemy_act":
			# Survey the Path: whenever enemy acts, gain block
			# Set status to track this power
			player_stats.apply_status("block_on_enemy_act", effect.params.get("amount", 1))
		elif effect.effect_type == "damage_on_block_gain":
			# Resonant Frame: whenever you gain Block, deal damage to random enemy
			# Set status to track this power
			player_stats.apply_status("resonant_frame_active", effect.params.get("amount", 1))

func _on_enemy_acted():
	## Called when an enemy performs an action - check for block_on_enemy_act
	var block_amount = player_stats.get_status("block_on_enemy_act")
	if block_amount != null and int(block_amount) > 0:
		player_stats.add_block(int(block_amount))
