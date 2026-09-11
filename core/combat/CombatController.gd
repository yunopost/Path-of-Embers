extends Node
class_name CombatController

## Manages the shared clock, card play, and enemy actions

signal resource_action_taken
signal combat_started
signal combat_ended
signal boss_rush_combat_finished(victory: bool, score: int)

var player_stats: EntityStats
var enemies: Array[Enemy] = []
var current_energy: int = 3
# Energy has no maximum (Design ruling, 10 Sep 2026): Breathe converts one tick into
# one energy, so a cap would silently delete banked time. There is no max_energy field
# any more — only the 0 floor below is enforced. See can_play_card()/use_party_ability().
var combat_active: bool = false

# Per-character stat objects — keyed by character_id, seeded from CharacterData base stats.
# STRENGTH = str_base, DEXTERITY = def_base, FAITH = spirit_base.
# In-combat status effect cards that grant Strength/Dexterity/Faith apply to player_stats;
# these objects carry the fixed base-stat bonuses for the owning character's cards only.
var character_stats: Dictionary = {}  # String → EntityStats

# Party ability cooldown state (Card-Clock Combat spec §7/§10.6). Per-combat,
# keyed by character_id, value = ticks remaining (0 = ready). Only characters
# with a non-empty ability_id get an entry.
var ability_cooldowns: Dictionary = {}  # String → int

var enemy_time_system: EnemyTimeSystem
var intent_system: IntentSystem
var pet_board: PetBoard


# Fade Step: reset after each enemy action; set when player HP drops.
var damage_taken_since_last_enemy_action: bool = false
var _last_seen_hp: int = 50  # Watermark used by _on_player_hp_changed to detect any HP decrease

# Combat-wide tracking
var damage_taken_this_combat: bool = false  # Track if any damage taken this entire combat (Revenant)
var total_ticks: int = 0  # Running clock total this combat (spec §8 tick counter UI)

# Last-card tracking (for sequencing effects)
var last_card_type_played: int = -1  # CardData.CardType value; -1 = no card yet (Tempest, Echo)
var last_card_played: DeckCardData = null  # Last card played instance (Echo MIRROR)
# Shadowfoot - Cheap Shot: whether the LAST card played applied a debuff status
# (StatusEffectType.is_debuff) to an enemy. Set from _current_card_applied_debuff
# after each play_card() resolves (see play_card()); EffectResolver flips
# _current_card_applied_debuff true, via mark_debuff_applied(), whenever a
# debuff-classified status lands on an enemy while resolving the CURRENT card.
var last_card_applied_debuff: bool = false
var _current_card_applied_debuff: bool = false
var last_card_target_enemy: Enemy = null  # Target Enemy of last card (Echo MIRROR).
# Stored as the Enemy object itself, not the transient UI target Node passed into
# play_card() -- that Node is often freed by its caller right after the call
# returns (e.g. the headless sim), which used to throw "previously freed" when
# MIRROR replayed later. Enemy instances live for the whole combat, so this
# reference stays valid; is_instance_valid() still guards the case where the
# enemy itself is no longer around (freed at end of combat).

# Pending state flags (set during effect resolution, consumed after card fully resolves)
var _mirror_active: bool = false  # Prevent infinite MIRROR recursion
var _regrowth_pending: bool = false  # Grove: return played card to draw pile instead of discard

# Delayed effects that fire after N ticks pass on the shared clock (spec §5: "next
# turn" → "N ticks", default 4). Each entry: { "type": String, "amount": int, "ticks_remaining": int }
var _delayed_tick_effects: Array = []

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
	total_ticks = 0
	last_card_type_played = -1
	last_card_played = null
	last_card_target_enemy = null
	last_card_applied_debuff = false
	_current_card_applied_debuff = false

	# Boss Rush: record start time and total enemy HP for leaderboard scoring
	if RunState and RunState.is_boss_rush:
		RunState.boss_rush_stats = {
			"start_time":      Time.get_unix_time_from_system(),
			"enemy_total_hp":  0,   # filled after enemies are created below
			"cards_played":    0,
		}

	# Reset pet board and pending effects for fresh combat
	pet_board = PetBoard.new(self)

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
				# Act scaling from EncounterDirector (1.0 when absent)
				random_hp = int(round(float(random_hp) * float(enemy_info.get("hp_mult", 1.0))))
				if ModifierManager:
					var _is_boss = (enemy_data_def.enemy_type == EnemyData.EnemyType.BOSS)
					random_hp = int(float(random_hp) * ModifierManager.get_enemy_hp_multiplier(_is_boss))
				var display_name = enemy_data_def.display_name if enemy_data_def.display_name else enemy_data_def.name

				var enemy = Enemy.new(enemy_id, display_name, random_hp, 3)  # Default time_max, will be overridden by move timers
				enemy.damage_multiplier = float(enemy_info.get("dmg_mult", 1.0))

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
	ResourceManager.sync_equipment_hp()
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

	# Reset party ability cooldowns for the fresh combat (spec §7/§10.6 -- per-combat state)
	ability_cooldowns.clear()
	for char_id in party_ids:
		var _cd = DataRegistry.get_character(char_id) if DataRegistry else null
		if _cd and not _cd.ability_id.is_empty():
			ability_cooldowns[char_id] = 0

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
			if str_bonus > 0:
				character_stats[char_id].apply_status(StatusEffectType.STRENGTH, str_bonus)
			if def_bonus > 0:
				character_stats[char_id].apply_status(StatusEffectType.DEXTERITY, def_bonus)
			if spirit_bonus > 0:
				character_stats[char_id].apply_status(StatusEffectType.FAITH, spirit_bonus)

	# Player starts with 3 energy and a 5-card hand.
	current_energy = 3
	if ResourceManager:
		ResourceManager.set_energy(current_energy)
	damage_taken_since_last_enemy_action = false
	previous_block = player_stats.block  # Initialize previous_block for block gain detection
	_last_seen_hp = player_stats.current_hp
	RunState.draw_cards(5)

	combat_started.emit()

func breathe() -> void:
	## Universal player action (Addendum §1): +1 energy (uncapped — Design ruling,
	## 10 Sep 2026), then advances the clock by 1 tick. Half of
	## the old focus() — energy generation now costs a dedicated action so it is scarce.
	if not combat_active:
		return

	current_energy += 1
	if ResourceManager:
		ResourceManager.set_energy(current_energy)

	resource_action_taken.emit()
	advance_clock(1)

func focus() -> void:
	## Universal player action (Addendum §1): draw 2, then
	## advances the clock by 1 tick. The other half of the old focus() — pure
	## card draw, no energy.
	if not combat_active:
		return

	# Draw 2 + any bonus from Overclocked / DRAW_PER_TURN powers (spec §5: "+N draw on each Focus")
	var base_draw := 2
	var bonus_draw_status = player_stats.get_status(StatusEffectType.DRAW_PER_TURN)
	if bonus_draw_status != null:
		base_draw += int(bonus_draw_status)
	RunState.draw_cards(base_draw)

	resource_action_taken.emit()
	advance_clock(1)

func can_play_card(card_cost: int, card_data: CardData = null) -> bool:
	## Check if card can be played based on cost type. This gate is the floor
	## enforcement site for energy: 0 is a deliberate design floor (energy is a
	## resource, not a debt), and this check is what keeps current_energy from ever
	## going negative when a card cost is paid below. Do not turn energy into a
	## signed value in a future refactor.
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

	# Increment cards played counter
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
			ResourceManager.set_energy(current_energy)
	
	# Pursuit (GRANT_HASTE_NEXT_CARD's conditional_draw_*): capture BEFORE
	# _get_card_timer_tick() below consumes/resets it, since that's the same
	var _pursuit_draw_min_cost: int = RunState.next_card_conditional_draw_min_cost
	var _pursuit_draw_amount: int = RunState.next_card_conditional_draw_amount

	# Determine timer tick amount BEFORE resolving effects
	# This ensures haste_next_card applies to the NEXT card, not the current one
	var timer_tick_amount = _get_card_timer_tick(deck_card)

	# Pursuit's "if that card costs 2 or more, draw 2": card_cost above is
	# already this card's effective cost (upgrades + One Night Sooner-style
	# discount applied), so this is the SAME cost the player paid.
	if _pursuit_draw_min_cost > 0 and _pursuit_draw_amount > 0 and card_cost >= _pursuit_draw_min_cost:
		RunState.draw_cards(_pursuit_draw_amount)

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

	# Reset the working debuff flag BEFORE resolving THIS card's effects; it will
	# be set true (via mark_debuff_applied()) if any of them apply a debuff to
	# an enemy, then copied into last_card_applied_debuff below for the NEXT
	# card (e.g. Cheap Shot) to read.
	_current_card_applied_debuff = false

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
	last_card_applied_debuff = _current_card_applied_debuff
	last_card_target_enemy = null
	if target and target.has_meta("enemy"):
		var _mirror_target = target.get_meta("enemy") as Enemy
		if _mirror_target:
			last_card_target_enemy = _mirror_target

	# Quest event: CARD_PLAYED
	if QuestManager:
		QuestManager.emit_game_event("CARD_PLAYED", {"card_type": card_data.card_type, "card_id": deck_card.card_id})

	# Advance the clock by this card's tick amount (spec §10.1 — the single
	# entry point for time passing: ticks enemies, statuses, resolves any
	# enemy action, and wipes Block per the rule in §4).
	advance_clock(timer_tick_amount)

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
		elif CardRules.get_card_keywords(deck_card).has("Exhaust"):
			# Exhaust: the played card goes out of rotation for the rest of this
			# combat instead of to the discard pile (e.g. Compost Heap). Unlike
			# RunState.remove_card_instance, this does not delete the card from
			# the permanent deck -- it's back in the draw pile next combat.
			RunState.exhaust_card_instance(discard_instance_id)
		else:
			# Normal path: add to discard pile
			var discard_index = RunState.deck_model.discard_pile.find(discard_instance_id)
			if discard_index < 0:  # Not found, add it
				RunState.deck_model.discard_pile.append(discard_instance_id)
				RunState.deck_model.discard_pile_changed.emit()

	return true

func _pay_discard_cost(discard_amount: int, exclude_instance_id: String = "") -> int:
	## Pay discard cost by discarding cards from hand
	## exclude_instance_id: Instance ID to exclude from discarding (the card being played)
	## Returns number of cards actually discarded
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
			
			if RunState.deck_model.discard_card(card_to_discard_id):
				discarded += 1
	
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
	## Get the number of ticks this card advances the clock by (Haste 0 / Slow N / default 1).
	var instance_id_str: String = str(deck_card.instance_id)
	return RunState.get_timer_tick_amount_for_card(instance_id_str)

func advance_clock(ticks: int) -> void:
	## THE single entry point for time passing (spec §10.1). play_card() and
	## focus() call this instead of touching EnemyTimeSystem/statuses directly.
	## In order: (a) tick every alive enemy's timer, (b) tick-based ability
	## cooldowns (hook only — no abilities implemented yet), (c) tick-based
	## status durations on player and enemies, then anti-turtle damage
	## escalation, then (d) resolve any enemy whose timer hit 0 (each resolved
	## action fires _on_enemy_acted()).
	## ticks <= 0 (Haste) does nothing at all — no time passes, nothing resolves.
	if not combat_active:
		return
	if ticks <= 0:
		return

	total_ticks += ticks

	# (a) Tick every alive enemy's timer (EnemyTimeSystem applies the ModifierManager multiplier)
	enemy_time_system.tick_all_enemies(ticks)

	# (b) Tick-based ability cooldowns — hook for party abilities (spec §7/§10.6), none yet
	_tick_ability_cooldowns(ticks)

	# (c) Tick-based status durations on player and all alive enemies
	player_stats.tick_statuses(ticks)
	for enemy in enemies:
		if enemy.stats.is_alive():
			enemy.stats.tick_statuses(ticks)
	_tick_delayed_effects(ticks)

	# Anti-turtle damage escalation (Card-Clock Combat, 9 Sep 2026): bosses/elites
	# configured with EnemyData.escalation_* gain Strength stacks as the fight's
	# tick clock passes escalation_start_tick and then every escalation_interval
	# ticks after that. escalation_interval <= 0 means "never escalates".
	_apply_escalation()

	# (d) Resolve enemies whose timer hit 0. Enemy.perform_intent() calls
	# _on_enemy_acted() per resolved action.
	enemy_time_system.resolve_enemy_time_triggers("advance_clock")

func _apply_escalation() -> void:
	## Anti-turtle damage escalation (opening values — for the simulator to tune,
	## not final): once total_ticks reaches an enemy's EnemyData.escalation_start_tick,
	## it gains escalation_strength Strength every escalation_interval ticks after
	## that, via the normal Strength status (same mechanism player Strength cards
	## use) so it shows up wherever enemy statuses already display.
	for enemy in enemies:
		if not enemy.stats.is_alive():
			continue
		var edata: EnemyData = enemy.enemy_data if enemy.enemy_data else DataRegistry.get_enemy(enemy.enemy_id)
		if not edata or edata.escalation_interval <= 0 or edata.escalation_start_tick <= 0:
			continue
		if total_ticks < edata.escalation_start_tick:
			continue
		var stacks_due: int = 1 + int((total_ticks - edata.escalation_start_tick) / edata.escalation_interval)
		var delta: int = stacks_due - enemy.escalation_stacks_applied
		if delta > 0:
			enemy.stats.apply_status(StatusEffectType.STRENGTH, delta * edata.escalation_strength)
			enemy.escalation_stacks_applied = stacks_due

func _tick_ability_cooldowns(ticks: int) -> void:
	## Decrement every party ability's cooldown by `ticks`, floored at 0 (spec §7/§10.6).
	for char_id in ability_cooldowns.keys():
		ability_cooldowns[char_id] = maxi(0, int(ability_cooldowns[char_id]) - ticks)

func get_ability_cooldown(character_id: String) -> int:
	## Ticks remaining before character_id's ability is off cooldown (0 = ready).
	return int(ability_cooldowns.get(character_id, 0))

func can_use_ability(character_id: String) -> bool:
	## True if character_id has an ability, it is off cooldown, and every cost
	## it declares (Addendum §2: energy_cost, discard_cost, hp_cost,
	## consumes_block) is currently payable. Does not check targeting --
	## ENEMY-targeted abilities additionally need a live target passed to
	## use_ability().
	if not combat_active:
		return false
	var char_data = DataRegistry.get_character(character_id) if DataRegistry else null
	if not char_data or char_data.ability_id.is_empty():
		return false
	var ability: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id) if DataRegistry else null
	if not ability:
		return false
	if get_ability_cooldown(character_id) > 0:
		return false
	if ability.energy_cost > 0 and current_energy < ability.energy_cost:
		return false  # 0 floor gate (design floor, not a ceiling) — see can_play_card()
	if ability.discard_cost > 0 and RunState.deck_model.hand.size() < ability.discard_cost:
		return false
	if ability.hp_cost > 0 and player_stats.current_hp <= ability.hp_cost:
		return false
	if ability.consumes_block and player_stats.block <= 0:
		return false
	return true

func use_ability(character_id: String, target: Node = null) -> bool:
	## Use character_id's party ability (Card-Clock Combat spec §7/§10.6, re-costed
	## by Addendum §2). Checks cooldown and every declared cost, pays them all
	## (energy, discard, HP, consumed Block), resolves the ability's effects
	## through EffectResolver (same path as card effects), sets the cooldown,
	## then advances the clock by the ability's tick_cost.
	if not can_use_ability(character_id):
		return false

	var char_data: CharacterData = DataRegistry.get_character(character_id)
	var ability: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id)
	var owner_stats: EntityStats = character_stats.get(character_id, null)

	var target_stats: EntityStats = null
	var enemy_context: Enemy = null
	if ability.targeting_mode == CardData.TargetingMode.ENEMY:
		if target and target.has_meta("enemy"):
			var meta_enemy = target.get_meta("enemy") as Enemy
			if meta_enemy and meta_enemy.stats.is_alive():
				target_stats = meta_enemy.stats
				enemy_context = meta_enemy
		if enemy_context == null:
			return false  # ENEMY-targeted ability requires a valid, alive target

	# Pay costs BEFORE resolving effects (Addendum §2: "use_ability() must pay
	# them all before resolving effects"). consumes_block is paid AFTER effects
	# resolve instead — What Was Left needs the current Block value to compute
	# its damage, then consumes it.
	if ability.energy_cost > 0:
		current_energy -= ability.energy_cost
		if ResourceManager:
			ResourceManager.set_energy(current_energy)
	if ability.discard_cost > 0:
		_pay_discard_cost(ability.discard_cost)
	if ability.hp_cost > 0:
		player_stats.take_damage(ability.hp_cost, true)  # ignore_block -- HP cost, not an attack

	var draw_count: int = EffectResolver.resolve_effects(ability.effects, player_stats, target_stats, enemy_context, self, owner_stats)

	if ability.consumes_block:
		player_stats.reset_block()

	if ResourceManager:
		ResourceManager.set_block(player_stats.block)
		ResourceManager.set_hp(player_stats.current_hp, player_stats.max_hp)
	if draw_count > 0:
		RunState.draw_cards(draw_count)

	# Set the cooldown AFTER advancing the clock so a 1-tick ability's own
	# tick_cost doesn't immediately shave a tick off the cooldown it just set.
	advance_clock(ability.tick_cost)
	ability_cooldowns[character_id] = ability.cooldown
	return true

func get_ability_cost_summary(character_id: String) -> String:
	## Human-readable cost badge for character_id's ability button/tooltip
	## (Addendum §4 item 3: "cost on the button, inline").
	if not DataRegistry:
		return ""
	var char_data = DataRegistry.get_character(character_id)
	if not char_data or char_data.ability_id.is_empty():
		return ""
	var ability: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id)
	if not ability:
		return ""
	var parts: Array[String] = []
	if ability.energy_cost > 0:
		parts.append("%d⚡" % ability.energy_cost)
	if ability.tick_cost > 0:
		parts.append("%d⏱" % ability.tick_cost)
	if ability.discard_cost > 0:
		parts.append("discard %d" % ability.discard_cost)
	if ability.hp_cost > 0:
		parts.append("%d HP" % ability.hp_cost)
	if ability.consumes_block:
		parts.append("all Block")
	if parts.is_empty():
		parts.append("free")
	return " · ".join(parts)

func get_ability_preview_text(character_id: String) -> String:
	## Real numbers this ability would produce right NOW, given current state
	## (Addendum §4 item 5: "Hold the Door its actual Block including DEX, What
	## Was Left its actual damage given current Block"). Walks the same effects
	## the ability resolves through EffectResolver.
	if not DataRegistry:
		return ""
	var char_data = DataRegistry.get_character(character_id)
	if not char_data or char_data.ability_id.is_empty():
		return ""
	var ability: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id)
	if not ability:
		return ""
	var owner_stats: EntityStats = character_stats.get(character_id, null)
	var lines: Array[String] = []
	for effect in ability.effects:
		if effect is EffectData:
			lines.append(_describe_effect_value(effect, owner_stats))
	if ability.consumes_block:
		lines.append("then loses all Block")
	return "; ".join(lines) if not lines.is_empty() else ability.description

func _describe_effect_value(effect: EffectData, owner_stats: EntityStats) -> String:
	## One human-readable line for a single ability effect, with current-state
	## math (STR/DEX/Block) applied -- shared by the ability hover preview.
	var dex := 0
	if owner_stats:
		var dv = owner_stats.get_status(StatusEffectType.DEXTERITY)
		if dv != null:
			dex = int(dv)
	var str_bonus := 0
	if owner_stats:
		var sv = owner_stats.get_status(StatusEffectType.STRENGTH)
		if sv != null:
			str_bonus = int(sv)
	match effect.effect_type:
		EffectType.BLOCK:
			return "Gain %d Block" % (int(effect.params.get("amount", 0)) + dex)
		EffectType.DAMAGE:
			return "Deal %d damage" % (int(effect.params.get("amount", 0)) + str_bonus)
		EffectType.DAMAGE_EQUAL_TO_BLOCK:
			return "Deal %d damage (= current Block)" % player_stats.block
		EffectType.DELAY_ENEMY_TIMER:
			return "Delay target's timer by %d" % int(effect.params.get("amount", 0))
		EffectType.GRANT_HASTE_NEXT_CARD:
			return "Next card played gets Haste"
		EffectType.ADD_CURSE_TO_HAND:
			return "Add a Curse to your hand"
		EffectType.GAIN_ENERGY:
			return "Gain %d Energy" % int(effect.params.get("amount", 0))
		EffectType.DRAW:
			return "Draw %d" % int(effect.params.get("amount", 1))
		EffectType.ENERGY_PER_DISCARD_PILE:
			var per: int = int(effect.params.get("per", 4))
			var cap: int = int(effect.params.get("max", 3))
			var gained: int = 0
			if per > 0 and RunState and RunState.deck_model:
				gained = mini(int(RunState.deck_model.discard_pile.size() / per), cap)
			return "Gain %d Energy (from discard pile)" % gained
		_:
			return effect.effect_type.capitalize()

func _tick_delayed_effects(ticks: int) -> void:
	## Ticks down DELAYED_DAMAGE-style effects queued on the shared clock
	## (spec §5: "next turn" effects now fire after N ticks, default 4 — see
	## EffectResolver.DELAYED_DAMAGE).
	if _delayed_tick_effects.is_empty():
		return
	var still_pending: Array = []
	for entry in _delayed_tick_effects:
		entry["ticks_remaining"] = int(entry.get("ticks_remaining", 0)) - ticks
		if entry["ticks_remaining"] <= 0:
			_resolve_delayed_tick_effect(entry)
		else:
			still_pending.append(entry)
	_delayed_tick_effects = still_pending

func _resolve_delayed_tick_effect(entry: Dictionary) -> void:
	match str(entry.get("type", "")):
		"damage_random_enemy":
			_apply_damage_to_random_enemy(int(entry.get("amount", 0)))
		_:
			push_warning("CombatController: unknown delayed_tick_effect type '%s'" % entry.get("type", ""))

func _resolve_no_damage_reward():
	# Fade Step: gain Strength if no damage has been taken since the last enemy action.
	var pending_strength = player_stats.get_status(StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE)
	if pending_strength != null:
		if not damage_taken_since_last_enemy_action:
			var amount = int(pending_strength)
			player_stats.apply_status(StatusEffectType.STRENGTH, amount)
		# Remove pending status
		player_stats.status_effects.erase(StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE)
		player_stats.status_effects_changed.emit()

func get_total_ticks() -> int:
	return total_ticks

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
	## Detect any HP decrease (Fade Step: "since the last enemy action"; Revenant:
	## "this combat", which never resets).
	if new_hp < _last_seen_hp:
		damage_taken_since_last_enemy_action = true
		damage_taken_this_combat = true  # Never resets during combat (Revenant)
	_last_seen_hp = new_hp

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
		# Re-use the stored target Enemy (nil for SELF/ALL_ENEMIES-targeted cards). The
		# target Node passed into _resolve_card_effects_with_effects is a throwaway
		# built here for the duration of this call, since the original UI/sim Node
		# that carried the "enemy" meta may already be gone (see last_card_target_enemy).
		var replay_target: Node = null
		if is_instance_valid(last_card_target_enemy) and last_card_target_enemy.stats.is_alive():
			replay_target = Node.new()
			replay_target.set_meta("enemy", last_card_target_enemy)
		_resolve_card_effects_with_effects(last_card_played, replay_target, filtered_effects)
		if replay_target:
			replay_target.free()

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
		elif effect.effect_type == EffectType.DRAW_PER_TURN:
			# Overclocked: draw N extra cards at the start of each turn
			player_stats.apply_status(StatusEffectType.DRAW_PER_TURN, effect.params.get("amount", 1))

func _pre_enemy_act(enemy) -> void:
	## Close the no-damage window when the next enemy action begins.
	_resolve_no_damage_reward()
	## Called by EnemyTimeSystem immediately before an enemy executes its intent.
	## Lets PetBoard know which enemy is currently acting (for WHEN_ENEMY_ACTS targeting).
	if pet_board:
		pet_board.current_acting_enemy = enemy

func _on_enemy_acted() -> void:
	## Called when an enemy performs an action (from Enemy.perform_intent, right
	## after that action's effects resolve). Handles, in order:
	## (e) Block persists — this is the shipped rule as of 9 Sep 2026 (Addendum C
	##     §2). Block is only ever reduced by damage it absorbs; an enemy acting
	##     does NOT reset it. Do not re-add a wipe/decay here without a design
	##     sign-off — the whole point of this rule is that Block is banked, not
	##     spent on a timer.
	## Survey-the-Path block and pet hooks (as before), plus Fade Step's
	## "no damage since last enemy action" bookkeeping.
	damage_taken_since_last_enemy_action = false

	var block_amount = player_stats.get_status(StatusEffectType.BLOCK_ON_ENEMY_ACT)
	if block_amount != null and int(block_amount) > 0:
		player_stats.add_block(int(block_amount))

	# Fire pet WHEN_ENEMY_ACTS triggers (deal damage, gain block, etc.)
	# Also handles Reinforced Frame draw check and clears per-action flags.
	if pet_board:
		pet_board.on_enemy_acted(pet_board.current_acting_enemy)

func get_pet_board() -> PetBoard:
	return pet_board

func mark_debuff_applied() -> void:
	## Called by EffectResolver whenever a debuff-classified status
	## (StatusEffectType.is_debuff) is applied to an enemy while resolving the
	## card currently being played. play_card() copies this into
	## last_card_applied_debuff right after the card fully resolves, so the
	## NEXT card played (e.g. Cheap Shot) can read what the previous one did.
	_current_card_applied_debuff = true

func _on_enemy_died(_enemy: Enemy) -> void:
	## Called when any enemy's stats.died signal fires.
	## Fires quest events on enemy death.
	if QuestManager:
		QuestManager.emit_game_event("ENEMY_KILLED", {})

func end_combat(victory: bool) -> void:
	## Cleanly end combat. Call from CombatScreen when all enemies are dead (victory)
	## or the player dies (defeat).
	if not combat_active:
		return
	combat_active = false
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
