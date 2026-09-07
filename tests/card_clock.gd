extends Node
## Headless assertions for the card-clock combat model (Card-Clock Combat spec §10 items 1-5,7).
## Run: ../Godot_v4.5-stable_linux.x86_64 --headless --path . res://tests/card_clock.tscn
## Prints "FAIL: <msg>" for every failed assertion and exits non-zero if any failed.

var fail_count := 0
var pass_count := 0

func _check(label: String, ok: bool) -> void:
	if ok:
		pass_count += 1
		print("PASS: ", label)
	else:
		fail_count += 1
		print("FAIL: ", label)

func _register_test_card(card_id: String, keywords: Array) -> void:
	## Registers a synthetic no-op SELF-targeted card so tick/keyword behaviour
	## can be tested without depending on which starter cards a party draws.
	var cd := CardData.new()
	cd.id = card_id
	cd.name = card_id
	cd.cost = 0
	cd.card_type = CardData.CardType.SKILL
	cd.targeting_mode = CardData.TargetingMode.SELF
	cd.owner_character_id = "warrior_1"
	cd.rarity = CardData.Rarity.COMMON
	for kw in keywords:
		cd.keywords.append(kw)
	DataRegistry.generic_card_cache[card_id] = cd

func _play_test_card(cc: CombatController, card_id: String) -> bool:
	var dc := DeckCardData.new(card_id, "warrior_1")
	RunState.deck[dc.instance_id] = dc
	RunState.deck_order.append(dc.instance_id)
	RunState.deck_model.hand.append(dc.instance_id)
	return cc.play_card(dc, null)

func _ready() -> void:
	print("=== card_clock test ===")

	_test_deck_model_hand_overflow()
	_test_combat_flow()
	_test_party_abilities_timer_trio()
	_test_party_abilities_mass_trio()

	print("--- card_clock summary: %d passed, %d failed ---" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)

func _test_deck_model_hand_overflow() -> void:
	## Isolated unit test of the HAND_MAX overflow-to-discard rule (spec §10.4),
	## independent of RunState/DataRegistry so it can't be confounded by deck size.
	_check("RunState.HAND_MAX == 8", RunState.HAND_MAX == 8)

	var dm := DeckModel.new()
	var ids: Array[String] = []
	for i in range(12):
		ids.append("fake_%d" % i)
	dm.draw_pile = ids.duplicate()

	var r1: Dictionary = dm.draw_cards(8, 8)
	_check("hand fills to HAND_MAX (8) with no burns", dm.hand.size() == 8 and r1.burned.is_empty())

	var r2: Dictionary = dm.draw_cards(3, 8)
	_check("drawing past HAND_MAX burns the overflow instead of growing hand", dm.hand.size() == 8 and r2.drawn.is_empty() and r2.burned.size() == 3)
	_check("burned cards land in the discard pile", dm.discard_pile.size() == 3)

func _test_combat_flow() -> void:
	PartyManager.party_ids = ["warrior_1", "witch", "golemancer"]
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		var c = DataRegistry.get_character(id)
		if c:
			chars.append(c)
	if chars.size() != 3:
		_check("setup: 3 party characters resolved", false)
		return
	RunState.generate_starter_deck(chars)

	_register_test_card("tc_haste", ["Haste"])
	_register_test_card("tc_slow", ["Slow"])
	_register_test_card("tc_slow3", ["Slow 3"])
	_register_test_card("tc_plain", [])

	var cc := CombatController.new()
	add_child(cc)
	# Legacy-format dummy enemy: no EnemyData, so IntentSystem always falls back to a
	# fixed "Attack 6" intent — deterministic, and we control its timer directly so
	# tests can force (or defer) an enemy action on demand.
	cc.start_combat([{"id": "dummy", "name": "Dummy", "max_hp": 9999, "time_max": 1000}])
	var enemy: Enemy = cc.enemies[0]
	enemy.time_max = 1000
	enemy.time_current = 1000

	# ---- start_combat: energy 3, cap 4, hand 5 (spec §10.3) ----
	_check("start_combat: max_energy == 4", cc.max_energy == 4)
	_check("start_combat: current_energy == 3", cc.current_energy == 3)
	_check("start_combat: hand size == 5", RunState.deck_model.hand.size() == 5)

	# ---- Focus: +2 energy (capped), draw 2, advance 1 tick (spec §10.2) ----
	var hand_before := RunState.deck_model.hand.size()
	var timer_before := enemy.time_current
	cc.focus()
	_check("focus: energy 3 -> 4 (capped, not 5)", cc.current_energy == 4)
	_check("focus: drew 2 cards", RunState.deck_model.hand.size() == hand_before + 2)
	_check("focus: advanced the clock by 1 tick", enemy.time_current == timer_before - 1)

	cc.focus()
	_check("focus: energy stays capped at max_energy when already at cap", cc.current_energy == 4)

	# ---- Haste card advances 0 ticks ----
	var t_haste := enemy.time_current
	var ok_haste := _play_test_card(cc, "tc_haste")
	_check("Haste card played successfully", ok_haste)
	_check("Haste card advances the clock by 0 ticks", enemy.time_current == t_haste)

	# ---- Slow card advances 2 ticks ----
	var t_slow := enemy.time_current
	var ok_slow := _play_test_card(cc, "tc_slow")
	_check("Slow card played successfully", ok_slow)
	_check("Slow card advances the clock by 2 ticks", enemy.time_current == t_slow - 2)

	# ---- Slow 3 card advances 3 ticks ----
	var t_slow3 := enemy.time_current
	var ok_slow3 := _play_test_card(cc, "tc_slow3")
	_check("Slow 3 card played successfully", ok_slow3)
	_check("Slow 3 card advances the clock by 3 ticks", enemy.time_current == t_slow3 - 3)

	# ---- Block survives multiple card plays; wiped after an enemy acts (spec §4) ----
	cc.player_stats.block = 0
	cc.player_stats.add_block(10)
	_play_test_card(cc, "tc_plain")
	_check("Block persists across a card play with no enemy action", cc.player_stats.block == 10)
	_play_test_card(cc, "tc_plain")
	_check("Block persists across a second card play with no enemy action", cc.player_stats.block == 10)

	enemy.time_current = 1  # force the enemy to act on the next tick
	_play_test_card(cc, "tc_plain")
	_check("enemy timer reset after acting", enemy.time_current == enemy.time_max)
	_check("Block wiped to 0 after an enemy action resolves", cc.player_stats.block == 0)

	# ---- 4-tick Vulnerable expires after exactly 4 ticks, not before ----
	enemy.time_current = 1000  # keep the enemy from acting during this sequence
	cc.player_stats.apply_status(StatusEffectType.VULNERABLE, 4)
	for i in range(3):
		_play_test_card(cc, "tc_plain")
		_check("4-tick Vulnerable still present after tick %d" % (i + 1), cc.player_stats.get_status(StatusEffectType.VULNERABLE) != null)
	_play_test_card(cc, "tc_plain")
	_check("4-tick Vulnerable expired after the 4th tick", cc.player_stats.get_status(StatusEffectType.VULNERABLE) == null)

	cc.end_combat(true)

func _make_enemy_target(enemy: Enemy) -> Node:
	## Builds a throwaway target Node carrying the "enemy" meta CardUI/ability
	## buttons attach in the real game — freed by the caller after use.
	var n := Node.new()
	n.set_meta("enemy", enemy)
	return n

func _test_party_abilities_timer_trio() -> void:
	## Card-Clock Combat spec §7/§10.6: The Wait (warrior_1), One Night Sooner
	## (warrior_2), Hold the Door (golemancer).
	PartyManager.party_ids = ["warrior_1", "warrior_2", "golemancer"]
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		var c = DataRegistry.get_character(id)
		if c:
			chars.append(c)
	if chars.size() != 3:
		_check("ability setup: 3 timer-trio characters resolved", false)
		return
	RunState.generate_starter_deck(chars)
	_register_test_card("tc_ability_cost2", [])

	var cc := CombatController.new()
	add_child(cc)
	cc.start_combat([{"id": "dummy", "name": "Dummy", "max_hp": 9999, "time_max": 1000}])
	var enemy: Enemy = cc.enemies[0]
	enemy.time_max = 10
	enemy.time_current = 6

	# ---- The Wait: delay target enemy's timer by 2, clamped to time_max, 0 ticks, cooldown 5 ----
	var target := _make_enemy_target(enemy)
	var ok_wait := cc.use_ability("warrior_1", target)
	_check("The Wait: use_ability succeeds", ok_wait)
	_check("The Wait: delays the enemy timer by 2 (6 -> 8)", enemy.time_current == 8)
	_check("The Wait: sets a 5-tick cooldown", cc.get_ability_cooldown("warrior_1") == 5)
	_check("The Wait: costs 0 ticks (cooldown itself doesn't tick down)", cc.get_ability_cooldown("warrior_1") == 5)

	enemy.time_current = 9
	var ok_wait_clamp := cc.use_ability("warrior_1", target)
	_check("The Wait: refuses reuse while on cooldown", not ok_wait_clamp)
	target.free()

	# Advance 5 ticks (via Slow-3 + Slow-2 test cards) to clear the cooldown, then reuse.
	enemy.time_current = 1000
	_register_test_card("tc_ability_slow5", ["Slow 3"])
	_play_test_card(cc, "tc_ability_slow5")  # 3 ticks
	_check("The Wait: cooldown ticks down (5 -> 2)", cc.get_ability_cooldown("warrior_1") == 2)
	_play_test_card(cc, "tc_slow")  # 2 more ticks (already registered by _test_combat_flow)
	_check("The Wait: cooldown reaches 0 after 5 total ticks", cc.get_ability_cooldown("warrior_1") == 0)

	var enemy2: Enemy = cc.enemies[0]
	enemy2.time_current = 4
	enemy2.time_max = 4
	var target2 := _make_enemy_target(enemy2)
	var ok_wait_clamped := cc.use_ability("warrior_1", target2)
	_check("The Wait: use_ability succeeds again once off cooldown", ok_wait_clamped)
	_check("The Wait: delay clamps at time_max instead of overshooting", enemy2.time_current == enemy2.time_max)
	target2.free()

	# ---- One Night Sooner: next card gets Haste (0 ticks) and costs 1 less, then expires ----
	var ok_sooner := cc.use_ability("warrior_2", null)
	_check("One Night Sooner: use_ability succeeds (SELF-targeted)", ok_sooner)
	_check("One Night Sooner: sets a 4-tick cooldown", cc.get_ability_cooldown("warrior_2") == 4)

	var dc := DeckCardData.new("tc_ability_cost2", "warrior_1")
	RunState.deck[dc.instance_id] = dc
	RunState.deck_order.append(dc.instance_id)
	RunState.deck_model.hand.append(dc.instance_id)
	var card_data := DataRegistry.get_card_data("tc_ability_cost2")
	card_data.cost = 2
	var discounted_cost := CardRules.get_effective_cost(card_data, dc)
	_check("One Night Sooner: next card's cost is discounted by 1 (2 -> 1)", discounted_cost == 1)

	var t_before_sooner_card := enemy2.time_current
	var energy_before := cc.current_energy
	var ok_card: bool = cc.play_card(dc, null)
	_check("One Night Sooner: discounted card is playable", ok_card)
	_check("One Night Sooner: the card actually spent the discounted cost", cc.current_energy == energy_before - 1)
	_check("One Night Sooner: the card ticks the clock by 0 (Haste)", enemy2.time_current == t_before_sooner_card)

	_register_test_card("tc_ability_cost2_b", [])
	var dc2 := DeckCardData.new("tc_ability_cost2_b", "warrior_1")
	RunState.deck[dc2.instance_id] = dc2
	RunState.deck_order.append(dc2.instance_id)
	RunState.deck_model.hand.append(dc2.instance_id)
	var card_data2 := DataRegistry.get_card_data("tc_ability_cost2_b")
	card_data2.cost = 2
	_check("One Night Sooner: the discount/haste is consumed -- does not carry to a second card", CardRules.get_effective_cost(card_data2, dc2) == 2)

	# ---- Hold the Door: 5 Block + Dexterity, 1 tick, cooldown 4 ----
	cc.player_stats.block = 0
	var block_before_hold := cc.player_stats.block
	var t_before_hold := enemy2.time_current
	var ok_hold := cc.use_ability("golemancer", null)
	_check("Hold the Door: use_ability succeeds", ok_hold)
	_check("Hold the Door: grants at least 5 Block", cc.player_stats.block >= block_before_hold + 5)
	_check("Hold the Door: costs 1 tick", enemy2.time_current == t_before_hold - 1)
	_check("Hold the Door: sets a 4-tick cooldown", cc.get_ability_cooldown("golemancer") == 4)

	cc.end_combat(true)

func _test_party_abilities_mass_trio() -> void:
	## Card-Clock Combat spec §7/§10.6: The Small Ending (witch), What Was Left
	## (living_armor), Leaf-fall (grove).
	PartyManager.party_ids = ["witch", "living_armor", "grove"]
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		var c = DataRegistry.get_character(id)
		if c:
			chars.append(c)
	if chars.size() != 3:
		_check("ability setup: 3 mass-trio characters resolved", false)
		return
	RunState.generate_starter_deck(chars)

	var cc := CombatController.new()
	add_child(cc)
	cc.start_combat([{"id": "dummy", "name": "Dummy", "max_hp": 9999, "time_max": 1000}])
	var enemy: Enemy = cc.enemies[0]

	# ---- The Small Ending: add a Curse to hand, gain 2 Energy, draw 1 ----
	var hand_before := RunState.deck_model.hand.size()
	var curses_before := _count_curses_in_hand()
	var energy_before := cc.current_energy
	var ok_small_ending := cc.use_ability("witch", null)
	_check("The Small Ending: use_ability succeeds", ok_small_ending)
	_check("The Small Ending: adds a Curse to hand", _count_curses_in_hand() == curses_before + 1)
	_check("The Small Ending: gains 2 Energy", cc.current_energy == mini(energy_before + 2, cc.max_energy))
	_check("The Small Ending: hand grows by 2 (1 Curse + 1 draw)", RunState.deck_model.hand.size() == hand_before + 2)
	_check("The Small Ending: sets a 3-tick cooldown", cc.get_ability_cooldown("witch") == 3)

	# ---- What Was Left: deal damage equal to current Block to target enemy ----
	cc.player_stats.block = 0
	cc.player_stats.add_block(9)
	var enemy_hp_before := enemy.stats.current_hp
	var target := _make_enemy_target(enemy)
	var ok_retaliate := cc.use_ability("living_armor", target)
	target.free()
	_check("What Was Left: use_ability succeeds", ok_retaliate)
	_check("What Was Left: deals damage equal to current Block (>= 9)", enemy.stats.current_hp <= enemy_hp_before - 9)
	_check("What Was Left: sets a 5-tick cooldown", cc.get_ability_cooldown("living_armor") == 5)

	# ---- Leaf-fall: 1 Energy per 4 cards in discard pile, capped at 3, 1 tick ----
	RunState.deck_model.discard_pile.clear()
	for i in range(10):
		RunState.deck_model.discard_pile.append("fake_discard_%d" % i)  # 10 cards -> floor(10/4) = 2
	cc.current_energy = 0
	var t_before_leaf := enemy.time_current
	var ok_leaf := cc.use_ability("grove", null)
	_check("Leaf-fall: use_ability succeeds", ok_leaf)
	_check("Leaf-fall: gains floor(discard/4) Energy (10 cards -> 2)", cc.current_energy == 2)
	_check("Leaf-fall: costs 1 tick", enemy.time_current == t_before_leaf - 1)
	_check("Leaf-fall: sets a 6-tick cooldown", cc.get_ability_cooldown("grove") == 6)

	for i in range(10, 30):
		RunState.deck_model.discard_pile.append("fake_discard_%d" % i)  # 30 cards -> floor(30/4) = 7, capped at 3
	for i in range(6):  # tick the cooldown back to 0
		enemy.time_current = 1000
		_play_test_card_generic(cc, "grove")
	cc.current_energy = 0
	var ok_leaf2 := cc.use_ability("grove", null)
	_check("Leaf-fall: use_ability succeeds again once off cooldown", ok_leaf2)
	_check("Leaf-fall: caps the Energy gain at 3 even with a larger discard pile", cc.current_energy == 3)

	cc.end_combat(true)

func _count_curses_in_hand() -> int:
	var count := 0
	for iid in RunState.deck_model.hand:
		var card = RunState.deck.get(iid)
		if card:
			var cd = DataRegistry.get_card_data(card.card_id)
			if cd and cd.card_type == CardData.CardType.CURSE:
				count += 1
	return count

func _play_test_card_generic(cc: CombatController, owner_id: String) -> bool:
	var card_id := "tc_tick_%s" % owner_id
	if not DataRegistry.generic_card_cache.has(card_id):
		var cd := CardData.new()
		cd.id = card_id
		cd.name = card_id
		cd.cost = 0
		cd.card_type = CardData.CardType.SKILL
		cd.targeting_mode = CardData.TargetingMode.SELF
		cd.owner_character_id = owner_id
		cd.rarity = CardData.Rarity.COMMON
		DataRegistry.generic_card_cache[card_id] = cd
	var dc := DeckCardData.new(card_id, owner_id)
	RunState.deck[dc.instance_id] = dc
	RunState.deck_order.append(dc.instance_id)
	RunState.deck_model.hand.append(dc.instance_id)
	return cc.play_card(dc, null)
