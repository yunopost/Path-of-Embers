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
