extends Node
class_name CombatController

## Manages combat flow: turns, card play, enemy actions

signal turn_ended
signal combat_started
signal combat_ended
signal boss_rush_combat_finished(victory: bool, score: int)

var player_stats: EntityStats
var enemies: Array[Enemy] = []
var current_energy: int = 3
var max_energy: int = 3
var combat_active: bool = false

# Per-character stat objects — keyed by character_id, seeded from CharacterData base stats.
# STRENGTH = str_base, DEXTERITY = def_base, FAITH = spirit_base.
# In-combat status effect cards that grant Strength/Dexterity/Faith apply to player_stats;
# these objects carry the fixed base-stat bonuses for the owning character's cards only.
var character_stats: Dictionary = {}  # String → EntityStats

var enemy_time_system: EnemyTimeSystem
var intent_system: IntentSystem
var pet_board: PetBoard

# Turn tracking
var damage_taken_this_turn: bool = false  # Track if damage was taken this turn (for Fade Step)
var cards_played_this_turn: int = 0  # Track cards played for Clear the way
var block_at_start_of_turn: int = 0  # Track block for block gain detection
var player_start_hp: int = 50  # Track starting HP for damage detection
var min_hp_this_turn: int = 50  # Track minimum HP this turn

# Combat-wide tracking
var damage_taken_this_combat: bool = false  # Track if any damage taken this entire combat (Revenant)

# Last-card tracking (for sequencing effects)
var last_card_type_played: int = -1  # CardData.CardType value; -1 = no card yet (Tempest, Echo)
var last_card_played: DeckCardData = null  # Last card played instance (Echo MIRROR)
var last_card_target_node: Node = null  # Target Node of last card (Echo MIRROR)

# Pending state flags (set during effect resolution, consumed after card fully resolves)
var _mirror_active: bool = false  # Prevent infinite MIRROR recursion
var _regrowth_pending: bool = false  # Grove: return played card to draw pile instead of discard
var _end_turn_pending: bool = false  # Hollow: end turn after this card fully resolves

# Delayed effects resolved at START_OF_NEXT_PLAYER_TURN (e.g. Delayed Slam)
# Each entry: { "type": String, "amount": int }
var _pending_next_turn_effects: Array = []

func _ready():
	# Get HP from ResourceManager if available, otherwise RunState (backward compatibility)
	var init_hp: int = ResourceManager.current_hp if ResourceManager else RunState.current_hp
	var init_max_hp: int = ResourceManager.max_hp if ResourceManager else RunState.max_hp
	player_stats = EntityStats.new(init_hp, init_max_hp)
	
	# Track HP changes for Fade Step damage detection
	player_stats.hp_changed.connect(_on_player_hp_changed)
	
	# Track block changes for Resonant Frame
	player_stats.block_changed.connect(_on_player_block_changed)
	
	# Initialize timer and intent systems
	intent_system = IntentSystem.new()
	enemy_time_system = EnemyTimeSystem.new(intent_system, self)

	# Initialize pet board
	pet_board = PetBoard.new(self)

func start_combat(enemy_data: Array):
	## Initialize combat with enemies
	## enemy_data can be Array of enemy_info Dicts with "enemy_id" and "count" OR legacy format with "id", "name", "max_hp", "time_max"
	combat_active = true
	damage_taken_this_combat = false
	last_card_type_played = -1
	last_card_played = null
	last_card_target_node = null

	# Boss Rush: record start time and total enemy HP for leaderboard scoring
	if RunState and RunState.is_boss_rush:
		RunState.boss_rush_stats = {
			"start_time":      Time.get_unix_time_from_system(),
			"enemy_total_hp":  0,   # filled after enemies are created below
			"cards_played":    0,
		}

	# Reset pet board and pending effects for fresh combat
	pet_board = PetBoard.new(self)
	_pending_next_turn_effects.clear()

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
				enemy.stats.died.connect(_on_enemy_died.bind(enemy))
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
			enemy.stats.died.connect(_on_enemy_died.bind(enemy))

	# Register enemies with time system
	enemy_time_system.register_enemies(enemies)

	# Boss Rush: capture total enemy HP now that enemies are built
	if RunState and RunState.is_boss_rush and RunState.boss_rush_stats.has("enemy_total_hp"):
		var total_hp: int = 0
		for e in enemies:
			total_hp += e.stats.max_hp
		RunState.boss_rush_stats["enemy_total_hp"] = total_hp

	# Sync player HP with ResourceManager (via RunState for backward compatibility)
	player_stats.current_hp = ResourceManager.current_hp if ResourceManager else RunState.current_hp
	player_stats.max_hp = ResourceManager.max_hp if ResourceManager else RunState.max_hp

	# Build per-character stat objects from CharacterData base stats (Phase 2.5)
	# STRENGTH = str_base, DEXTERITY = def_base, FAITH = spirit_base
	character_stats.clear()
	var party_ids = PartyManager.party_ids if PartyManager else []
	for char_id in party_ids:
		var char_data = DataRegistry.get_character(char_id) if DataRegistry else null
		if char_data:
			var cstats = EntityStats.new(1, 1)
			cstats.apply_status(StatusEffectType.STRENGTH, char_data.str_base)
			cstats.apply_status(StatusEffectType.DEXTERITY, char_data.def_base)
			cstats.apply_status(StatusEffectType.FAITH, char_data.spirit_base)
			character_stats[char_id] = cstats

	# Apply equipment stat_modifiers on top of base stats (Phase 6)
	for char_id in character_stats:
		var equip_slots: Dictionary = RunState.equipment_slots.get(char_id, {}) if RunState else {}
		for slot_name in equip_slots:
			var equipment_id: String = equip_slots[slot_name]
			if equipment_id.is_empty():
				continue
			var equip_data = DataRegistry.get_equipment(equipment_id) if DataRegistry else null
			if not equip_data:
				continue
			var mods: Dictionary = equip_data.stat_modifiers
			var str_bonus: int = int(mods.get("str", 0))
			var def_bonus: int = int(mods.get("def", 0))
			var spirit_bonus: int = int(mods.get("spirit", 0))
			var hp_bonus: int = int(mods.get("hp", 0))
			if str_bonus > 0:
				character_stats[char_id].apply_status(StatusEffectType.STRENGTH, str_bonus)
			if def_bonus > 0:
				character_stats[char_id].apply_status(StatusEffectType.DEXTERITY, def_bonus)
			if spirit_bonus > 0:
				character_stats[char_id].apply_status(StatusEffectType.FAITH, spirit_bonus)
			if hp_bonus > 0:
				player_stats.max_hp += hp_bonus
				player_stats.current_hp = min(player_stats.current_hp + hp_bonus, player_stats.max_hp)
				if ResourceManager:
					ResourceManager.set_hp(player_stats.current_hp, player_stats.max_hp)

	# Fire START_OF_COMBAT relic hooks (before first turn so effects apply to turn 1)
	if RunState and RunState.relic_system:
		RunState.relic_system.fire_hook("START_OF_COMBAT", {}, {"combat_controller": self})

	# Start player turn
	start_player_turn()
	combat_started.emit()

func start_player_turn():
	## Begin a new player turn
	if not combat_active:
		return

	# Advance pet board turn counter and fire START_OF_PLAYER_TURN hooks
	if pet_board:
		pet_board.on_start_player_turn()

	# Resolve START_OF_NEXT_PLAYER_TURN pending effects (e.g. Delayed Slam)
	_resolve_pending_next_turn_effects()

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
	if player_stats.get_status(StatusEffectType.RETAIN_BLOCK_THIS_TURN) == null:
		player_stats.reset_block()
		if ResourceManager:
			ResourceManager.set_block(0)
	else:
		# Remove the status after using it (it only applies once)
		player_stats.status_effects.erase(StatusEffectType.RETAIN_BLOCK_THIS_TURN)
		player_stats.status_effects_changed.emit()

	# Refill energy
	current_energy = max_energy
	# Use set_energy() which will emit the signal if value changed
	if ResourceManager:
		ResourceManager.set_energy(current_energy, max_energy)

	# Fire START_OF_PLAYER_TURN relic hooks (before draw — relic-drawn cards join opening hand)
	if RunState and RunState.relic_system:
		RunState.relic_system.fire_hook("START_OF_PLAYER_TURN", {}, {"combat_controller": self})

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
	if RunState and RunState.is_boss_rush and RunState.boss_rush_stats.has("cards_played"):
		RunState.boss_rush_stats["cards_played"] += 1
	
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
		if ResourceManager:
			ResourceManager.set_energy(current_energy, max_energy)
	
	# Determine timer tick amount BEFORE resolving effects
	# This ensures haste_next_card applies to the NEXT card, not the current one
	var timer_tick_amount = _get_card_timer_tick(deck_card)
	
	# For discard cost cards (Transcend 3), set hit_count dynamically based on cards discarded
	var effects = _get_card_effects(deck_card)
	if card_data.cost_type == CardData.CostType.DISCARD and cards_discarded > 0:
		# Modify effects to set hit_count to cards_discarded
		for effect in effects:
			if effect is EffectData and effect.effect_type == EffectType.DAMAGE:
				effect.params["hit_count"] = cards_discarded
	
	# Handle Power cards - set up persistent effects
	if card_data.card_type == CardData.CardType.POWER:
		_setup_power_card_effects(deck_card, card_data, effects)
	
	# Snapshot state for quest event tracking
	var _q_block_before: int = player_stats.block if player_stats else 0
	var _q_enemy_hp: Dictionary = {}
	for _q_e in enemies:
		if _q_e.stats.is_alive():
			_q_enemy_hp[_q_e.enemy_id] = _q_e.stats.current_hp

	# Resolve card effects (this may set haste_next_card status for the NEXT card)
	_resolve_card_effects_with_effects(deck_card, target, effects)

	# Quest events: BLOCK_GAINED and DAMAGE_DEALT
	if QuestManager:
		var _q_block_gained: int = (player_stats.block - _q_block_before) if player_stats else 0
		if _q_block_gained > 0:
			QuestManager.emit_game_event("BLOCK_GAINED", {"amount": _q_block_gained})
		var _q_dmg: int = 0
		for _q_e in enemies:
			var _q_before: int = _q_enemy_hp.get(_q_e.enemy_id, 0)
			var _q_delta: int = _q_before - _q_e.stats.current_hp
			if _q_delta > 0:
				_q_dmg += _q_delta
		if _q_dmg > 0:
			QuestManager.emit_game_event("DAMAGE_DEALT", {"amount": _q_dmg, "source": "player"})

	# Update last-card tracking AFTER effects resolve so sequencing effects on the
	# CURRENT card see the PREVIOUS card's type, while the NEXT card sees this card's type
	last_card_type_played = card_data.card_type
	last_card_played = deck_card
	last_card_target_node = target

	# Fire relic hooks for card played (after effects resolve, before timer ticks)
	if RunState and RunState.relic_system:
		var card_params := {"card_type": card_data.card_type, "card_id": deck_card.card_id}
		RunState.relic_system.fire_hook("ON_CARD_PLAYED", card_params, {"combat_controller": self})
		match card_data.card_type:
			CardData.CardType.ATTACK:
				RunState.relic_system.fire_hook("ON_ATTACK_PLAYED", card_params, {"combat_controller": self})
			CardData.CardType.SKILL:
				RunState.relic_system.fire_hook("ON_SKILL_PLAYED", card_params, {"combat_controller": self})

	# Quest event: CARD_PLAYED
	if QuestManager:
		QuestManager.emit_game_event("CARD_PLAYED", {"card_type": card_data.card_type, "card_id": deck_card.card_id})

	# Tick all enemies with the timer amount for THIS card
	enemy_time_system.tick_all_enemies(timer_tick_amount)
	
	# Resolve any enemies that hit 0
	enemy_time_system.resolve_enemy_time_triggers("card_played")
	
	# Move card to discard pile (or draw pile if REGROWTH is pending)
	# Re-fetch instance_id with explicit String conversion to ensure type safety
	var discard_instance_id: String = str(deck_card.instance_id)
	if discard_instance_id.is_empty():
		push_warning("CombatController.play_card: instance_id is empty, cannot add to discard")
	else:
		if _regrowth_pending:
			# REGROWTH: insert card at a random position in the draw pile instead of discarding
			_regrowth_pending = false
			var insert_pos = randi() % (RunState.deck_model.draw_pile.size() + 1)
			RunState.deck_model.draw_pile.insert(insert_pos, discard_instance_id)
		else:
			# Normal path: add to discard pile
			var discard_index = RunState.deck_model.discard_pile.find(discard_instance_id)
			if discard_index < 0:  # Not found, add it
				RunState.deck_model.discard_pile.append(discard_instance_id)
				RunState.deck_model.discard_pile_changed.emit()

	# FORCE_END_TURN: card is now fully resolved and discarded — safe to end the turn
	if _end_turn_pending:
		_end_turn_pending = false
		end_player_turn()

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
	
	# Look up the card owner's base-stat EntityStats (Phase 2.5)
	var owner_stats: EntityStats = character_stats.get(deck_card.owner_character_id, null)

	var draw_count = 0

	# Handle ALL_ENEMIES targeting (e.g., Transcend 1)
	if card_data.targeting_mode == CardData.TargetingMode.ALL_ENEMIES:
		# Resolve effects for each alive enemy
		for enemy in enemies:
			if enemy.stats.is_alive():
				draw_count += EffectResolver.resolve_effects(effects, player_stats, enemy.stats, enemy, self, owner_stats)
	else:
		# Single target resolution — all enemy nodes must carry a "enemy" meta set
		# by the UI when constructing the node.  The string-matching fallback has
		# been removed; any node without the meta is treated as self-targeting.
		var target_stats: EntityStats = null
		var enemy_context: Enemy = null
		if target and target.has_meta("enemy"):
			var meta_enemy = target.get_meta("enemy") as Enemy
			if meta_enemy:
				target_stats = meta_enemy.stats
				enemy_context = meta_enemy

		# Resolve effects
		draw_count = EffectResolver.resolve_effects(effects, player_stats, target_stats, enemy_context, self, owner_stats)
	
	# Update RunState block
	if ResourceManager:
		ResourceManager.set_block(player_stats.block)
	
	# Update RunState HP
	if ResourceManager:
		ResourceManager.set_hp(player_stats.current_hp, player_stats.max_hp)
	
	if draw_count > 0:
		RunState.draw_cards(draw_count)

func _get_card_effects(deck_card: DeckCardData) -> Array:
	## Returns resolved effects (base + upgrade modifications) via CardRules.
	return CardRules.get_resolved_effects(deck_card)

func _get_card_timer_tick(deck_card: DeckCardData) -> int:
	## Get the timer tick amount for a card
	## Returns 0 if card has Haste upgrade, 1 otherwise
	var instance_id_str: String = str(deck_card.instance_id)
	return RunState.get_timer_tick_amount_for_card(instance_id_str)

func end_player_turn():
	## End the player turn and start enemy turn
	if not combat_active:
		return

	# Fire END_OF_PLAYER_TURN relic hooks (before enemies act — block applies to enemy phase)
	if RunState and RunState.relic_system:
		RunState.relic_system.fire_hook("END_OF_PLAYER_TURN", {}, {"combat_controller": self})

	# Fire pet END_OF_PLAYER_TURN hooks
	if pet_board:
		pet_board.on_end_player_turn()

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
	var pending_strength = player_stats.get_status(StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE)
	if pending_strength != null:
		if not damage_taken_this_turn:
			var amount = int(pending_strength)
			player_stats.apply_status(StatusEffectType.STRENGTH, amount)
		# Remove pending status
		player_stats.status_effects.erase(StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE)
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
	## Track minimum HP for damage detection (Fade Step) and fire ON_PLAYER_DAMAGED relic hook.
	if new_hp < min_hp_this_turn:
		min_hp_this_turn = new_hp
		if min_hp_this_turn < player_start_hp:
			damage_taken_this_turn = true
			damage_taken_this_combat = true  # Never resets during combat (Revenant)
			# Fire ON_PLAYER_DAMAGED relic hooks (once per damage event, not per HP point)
			if RunState and RunState.relic_system:
				RunState.relic_system.fire_hook("ON_PLAYER_DAMAGED", {}, {"combat_controller": self})

var previous_block: int = 0  # Track previous block value for block gain detection

func _on_player_block_changed(new_block: int):
	## Handle Resonant Frame: deal damage to random enemy when block increases
	if new_block > previous_block:
		# Check if Resonant Frame power is active
		var resonant_damage = player_stats.get_status(StatusEffectType.RESONANT_FRAME_ACTIVE)
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


func _replay_last_card_effects(enemy_override: Enemy = null):
	## Replay the last played card's effects without paying its cost (Echo MIRROR).
	## enemy_override: if non-null, target this enemy; otherwise use stored last_card_target_node.
	if _mirror_active:
		push_warning("MIRROR: recursion prevented")
		return
	if not last_card_played:
		push_warning("MIRROR: no last card to replay")
		return

	_mirror_active = true

	# Build effects list, stripping any MIRROR effects to prevent infinite recursion
	var raw_effects = _get_card_effects(last_card_played)
	var filtered_effects: Array = []
	for e in raw_effects:
		if e is EffectData and e.effect_type != EffectType.MIRROR:
			filtered_effects.append(e)

	var mirror_owner_stats: EntityStats = character_stats.get(last_card_played.owner_character_id, null)

	if enemy_override != null:
		# Resolve directly against a specific enemy
		var draw_count = EffectResolver.resolve_effects(filtered_effects, player_stats, enemy_override.stats, enemy_override, self, mirror_owner_stats)
		if ResourceManager:
			ResourceManager.set_block(player_stats.block)
			ResourceManager.set_hp(player_stats.current_hp, player_stats.max_hp)
		if draw_count > 0:
			RunState.draw_cards(draw_count)
	else:
		# Re-use the stored target node (handles ALL_ENEMIES, self-targeting, etc.)
		_resolve_card_effects_with_effects(last_card_played, last_card_target_node, filtered_effects)

	_mirror_active = false


func _setup_power_card_effects(_deck_card: DeckCardData, _card_data: CardData, effects: Array):
	## Set up persistent effects for Power cards
	for effect in effects:
		if not effect is EffectData:
			continue
		
		if effect.effect_type == EffectType.BLOCK_ON_ENEMY_ACT:
			# Survey the Path: whenever enemy acts, gain block
			# Set status to track this power
			player_stats.apply_status(StatusEffectType.BLOCK_ON_ENEMY_ACT, effect.params.get("amount", 1))
		elif effect.effect_type == EffectType.DAMAGE_ON_BLOCK_GAIN:
			# Resonant Frame: whenever you gain Block, deal damage to random enemy
			# Set status to track this power
			player_stats.apply_status(StatusEffectType.RESONANT_FRAME_ACTIVE, effect.params.get("amount", 1))

func _pre_enemy_act(enemy) -> void:
	## Called by EnemyTimeSystem immediately before an enemy executes its intent.
	## Lets PetBoard know which enemy is currently acting (for WHEN_ENEMY_ACTS targeting).
	if pet_board:
		pet_board.current_acting_enemy = enemy

func _on_enemy_acted() -> void:
	## Called when an enemy performs an action.
	## Handles: relic WHEN_ENEMY_ACTS hooks, Survey-the-Path block, and pet hooks.

	# Fire WHEN_ENEMY_ACTS relic hooks
	if RunState and RunState.relic_system:
		RunState.relic_system.fire_hook("WHEN_ENEMY_ACTS", {}, {"combat_controller": self})

	var block_amount = player_stats.get_status(StatusEffectType.BLOCK_ON_ENEMY_ACT)
	if block_amount != null and int(block_amount) > 0:
		player_stats.add_block(int(block_amount))

	# Fire pet WHEN_ENEMY_ACTS triggers (deal damage, gain block, etc.)
	# Also handles Reinforced Frame draw check and clears per-action flags.
	if pet_board:
		pet_board.on_enemy_acted(pet_board.current_acting_enemy)

func get_pet_board() -> PetBoard:
	return pet_board

func _on_enemy_died(_enemy: Enemy) -> void:
	## Called when any enemy's stats.died signal fires.
	## Fires ON_ENEMY_KILLED relic hooks and quest events.
	if RunState and RunState.relic_system:
		RunState.relic_system.fire_hook("ON_ENEMY_KILLED", {}, {"combat_controller": self})
	if QuestManager:
		QuestManager.emit_game_event("ENEMY_KILLED", {})

func end_combat(victory: bool) -> void:
	## Cleanly end combat. Call from CombatScreen when all enemies are dead (victory)
	## or the player dies (defeat).
	if not combat_active:
		return
	combat_active = false
	if victory and RunState and RunState.relic_system:
		RunState.relic_system.fire_hook("END_OF_COMBAT", {}, {"combat_controller": self})
	_remove_temporary_cards()
	combat_ended.emit()

	# Boss Rush: score and signal CombatScreen to navigate back
	if RunState and RunState.is_boss_rush:
		var score: int = 0
		if victory and LeaderboardManager:
			var stats: Dictionary = RunState.boss_rush_stats
			var elapsed: float = Time.get_unix_time_from_system() - float(stats.get("start_time", Time.get_unix_time_from_system()))
			var enemy_hp: int = int(stats.get("enemy_total_hp", 1))
			var cards: int = int(stats.get("cards_played", 1))
			var hp_rem: int = ResourceManager.current_hp if ResourceManager else 0
			var hp_max: int = ResourceManager.max_hp if ResourceManager else 1
			score = LeaderboardManager.calculate_score(elapsed, enemy_hp, hp_rem, hp_max, cards,
				ModifierManager.get_active_count() if ModifierManager else 0)
			var build_label: String = ""
			if PartyManager:
				var names: Array[String] = []
				for pid in PartyManager.get_party_ids():
					var cd = DataRegistry.get_character(pid) if DataRegistry else null
					names.append(cd.display_name if cd else pid)
				build_label = " · ".join(names)
			LeaderboardManager.submit_score(
				RunState.boss_rush_boss_id,
				score,
				build_label,
				elapsed,
				enemy_hp,
				float(hp_rem) / float(hp_max),
				cards
			)
		boss_rush_combat_finished.emit(victory, score)

func _resolve_pending_next_turn_effects() -> void:
	## Process START_OF_NEXT_PLAYER_TURN queued effects (e.g. Delayed Slam).
	if _pending_next_turn_effects.is_empty():
		return
	var effects_snapshot: Array = _pending_next_turn_effects.duplicate()
	_pending_next_turn_effects.clear()
	for entry in effects_snapshot:
		var effect_type: String = entry.get("type", "")
		match effect_type:
			"damage_random_enemy":
				var dmg: int = int(entry.get("amount", 0))
				_apply_damage_to_random_enemy(dmg)
			_:
				push_warning("CombatController: unknown pending_next_turn_effect type '%s'" % effect_type)

func _apply_damage_to_random_enemy(amount: int) -> void:
	## Deal damage to a random alive enemy (used by Delayed Slam etc.)
	var alive: Array[Enemy] = []
	for enemy in enemies:
		if enemy.stats.is_alive():
			alive.append(enemy)
	if alive.is_empty():
		return
	var target: Enemy = alive[randi() % alive.size()]
	# Apply Strength / Weakness from player_stats
	var strength_val = player_stats.get_status(StatusEffectType.STRENGTH)
	var strength_bonus: int = int(strength_val) if strength_val != null else 0
	var weakness_val = player_stats.get_status(StatusEffectType.WEAKNESS)
	var is_weak: bool = (weakness_val != null and int(weakness_val) > 0)
	var final_dmg: int = amount + strength_bonus
	if is_weak:
		final_dmg = int(ceil(float(final_dmg) * 0.75))
	target.stats.take_damage(final_dmg, false)
