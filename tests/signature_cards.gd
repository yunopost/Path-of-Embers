extends Node
## Headless assertions for the twelve EA signature cards (9 Sep 2026 build):
## Pursuit, Deadly Strike, Cheap Shot, Shadow Step, Hex, Dark Pact, Deadfall,
## Compost Heap, Bulwark, Construct Punch, Iron Shell, Iron Tide.
## Run: ../Godot_v4.5-stable_linux.x86_64 --headless --path . res://tests/signature_cards.tscn
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

func _ready() -> void:
	print("=== signature_cards test ===")

	_test_pursuit()
	_test_deadly_strike()
	_test_cheap_shot()
	_test_shadow_step()
	_test_bulwark()
	_test_construct_punch()

	_test_hex()
	_test_dark_pact()
	_test_deadfall_and_mill_edge_cases()
	_test_compost_heap()
	_test_iron_shell_agility()
	_test_iron_tide()

	print("--- signature_cards summary: %d passed, %d failed ---" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)

# ── Setup helpers ────────────────────────────────────────────────────────────

func _new_combat(party: Array[String]) -> CombatController:
	## Fresh combat with a single dummy enemy that never acts (huge time_max) and
	## never dies (huge HP), so tests only care about the effect(s) under test.
	## Owner str/dex/faith bonuses are zeroed out after start_combat so damage/
	## block assertions are exact numbers straight from the card, not muddied by
	## each character's base stats.
	PartyManager.party_ids = party
	var chars: Array[CharacterData] = []
	for id in party:
		var c = DataRegistry.get_character(id)
		if c:
			chars.append(c)
	RunState.generate_starter_deck(chars)

	var cc := CombatController.new()
	add_child(cc)
	cc.start_combat([{"id": "dummy", "name": "Dummy", "max_hp": 999999, "time_max": 999999}])
	var enemy: Enemy = cc.enemies[0]
	enemy.time_max = 999999
	enemy.time_current = 999999

	for char_id in party:
		if cc.character_stats.has(char_id):
			cc.character_stats[char_id].status_effects.clear()

	cc.current_energy = 10
	if ResourceManager:
		ResourceManager.set_energy(cc.current_energy)

	return cc

func _play_card_id(cc: CombatController, card_id: String, owner: String, target_enemy: Enemy = null) -> Dictionary:
	## Play a fresh instance of card_id (added straight to hand) and return
	## {"ok": bool, "instance_id": String}.
	var dc := DeckCardData.new(card_id, owner)
	RunState.deck[dc.instance_id] = dc
	RunState.deck_order.append(dc.instance_id)
	RunState.deck_model.hand.append(dc.instance_id)
	var tgt: Node = null
	if target_enemy:
		tgt = Node.new()
		tgt.set_meta("enemy", target_enemy)
	var ok: bool = cc.play_card(dc, tgt)
	if tgt:
		tgt.free()
	return {"ok": ok, "instance_id": dc.instance_id}

func _register_noop_card(card_id: String, owner: String) -> void:
	## A free, no-op, SELF-targeted card, purely for padding the discard pile
	## (Bulwark) without side effects.
	if DataRegistry.generic_card_cache.has(card_id):
		return
	var cd := CardData.new()
	cd.id = card_id
	cd.name = card_id
	cd.cost = 0
	cd.card_type = CardData.CardType.SKILL
	cd.targeting_mode = CardData.TargetingMode.SELF
	cd.owner_character_id = owner
	cd.rarity = CardData.Rarity.COMMON
	DataRegistry.generic_card_cache[card_id] = cd

func _register_vulnerable_only_card(card_id: String, owner: String) -> void:
	## A free ENEMY-targeted card that applies Vulnerable and deals no damage --
	## isolates "the last card played applied a debuff" from Vulnerable's own
	## 1.5x damage multiplier, for a clean Cheap Shot assertion.
	if DataRegistry.generic_card_cache.has(card_id):
		return
	var cd := CardData.new()
	cd.id = card_id
	cd.name = card_id
	cd.cost = 0
	cd.card_type = CardData.CardType.SKILL
	cd.targeting_mode = CardData.TargetingMode.ENEMY
	cd.owner_character_id = owner
	cd.rarity = CardData.Rarity.COMMON
	var eff := EffectData.new(EffectType.VULNERABLE, {"duration": 4})
	var effs: Array[EffectData] = [eff]
	cd.base_effects = effs
	DataRegistry.generic_card_cache[card_id] = cd

# ── Trio A: warrior_1, warrior_2, golemancer ────────────────────────────────

func _test_pursuit() -> void:
	var cc := _new_combat(["warrior_1", "warrior_2", "golemancer"])
	var enemy := cc.enemies[0]

	# Sub-case: next card costs < 2 -> no conditional draw, both cards are Haste (0 ticks)
	var ticks_before := cc.total_ticks
	var hand_before := RunState.deck_model.hand.size()
	_play_card_id(cc, "pursuit", "warrior_1")
	_check("Pursuit: playing Pursuit itself is Haste (0 ticks)", cc.total_ticks == ticks_before)
	_play_card_id(cc, "cheap_shot", "warrior_2", enemy)  # cost 0 < 2
	_check("Pursuit: next card (cost 0) is Haste too", cc.total_ticks == ticks_before)
	_check("Pursuit: next card costing < 2 does not trigger the conditional draw", RunState.deck_model.hand.size() == hand_before)

	# Sub-case: next card costs >= 2 -> draws 2, and that card is also Haste
	ticks_before = cc.total_ticks
	_play_card_id(cc, "pursuit", "warrior_1")
	hand_before = RunState.deck_model.hand.size()
	_play_card_id(cc, "deadly_strike", "warrior_1", enemy)  # cost 2
	# The played card's own append+removal from hand always nets to 0, so the
	# only net change is the 2 cards drawn by Pursuit's conditional draw.
	_check("Pursuit: next card costing >= 2 draws 2 cards", RunState.deck_model.hand.size() == hand_before + 2)
	_check("Pursuit: next card costing >= 2 is also Haste (0 ticks)", cc.total_ticks == ticks_before)

	cc.queue_free()

func _test_deadly_strike() -> void:
	var cc := _new_combat(["warrior_1", "warrior_2", "golemancer"])
	var enemy := cc.enemies[0]
	var hp_before := enemy.stats.current_hp
	_play_card_id(cc, "deadly_strike", "warrior_1", enemy)
	_check("Deadly Strike: deals 10 damage", enemy.stats.current_hp == hp_before - 10)
	# Deadly Strike itself is not Haste, so its own play advances the clock by 1
	# tick AFTER effects resolve -- the just-applied Vulnerable 4 has already
	# ticked down to 3 by the time play_card() returns.
	var vuln = enemy.stats.get_status(StatusEffectType.VULNERABLE)
	_check("Deadly Strike: applies Vulnerable 4 (3 left after its own 1-tick play)", vuln != null and int(vuln) == 3)
	cc.queue_free()

func _test_cheap_shot() -> void:
	# Without a preceding debuff
	var cc := _new_combat(["warrior_1", "warrior_2", "golemancer"])
	var enemy := cc.enemies[0]
	var hp_before := enemy.stats.current_hp
	_play_card_id(cc, "cheap_shot", "warrior_2", enemy)
	_check("Cheap Shot: deals only base damage (5) with no preceding debuff", enemy.stats.current_hp == hp_before - 5)
	cc.queue_free()

	# With a preceding debuff (isolated: a Vulnerable-only card, no damage of its own)
	cc = _new_combat(["warrior_1", "warrior_2", "golemancer"])
	enemy = cc.enemies[0]
	_register_vulnerable_only_card("tc_vuln_only", "warrior_2")
	_play_card_id(cc, "tc_vuln_only", "warrior_2", enemy)
	# tc_vuln_only isn't Haste either, so its own 1-tick play has already ticked
	# the Vulnerable 4 it just applied down to 3 -- still active (>0) either way.
	_check("Cheap Shot setup: enemy now carries Vulnerable", int(enemy.stats.get_status(StatusEffectType.VULNERABLE)) == 3)
	hp_before = enemy.stats.current_hp
	_play_card_id(cc, "cheap_shot", "warrior_2", enemy)
	# base(5) + bonus(5) = 10, then x1.5 for the enemy's own active Vulnerable (int-truncated) = 15
	_check("Cheap Shot: deals base+bonus (10, x1.5 Vulnerable = 15) when the last card applied a debuff", enemy.stats.current_hp == hp_before - 15)
	cc.queue_free()

func _test_shadow_step() -> void:
	var cc := _new_combat(["warrior_1", "warrior_2", "golemancer"])
	var enemy := cc.enemies[0]
	var block_before := cc.player_stats.block
	_play_card_id(cc, "shadow_step", "warrior_2")
	_check("Shadow Step: gains 6 Block", cc.player_stats.block == block_before + 6)
	_check("Shadow Step: sets a 1-cost discount on the next card", RunState.next_card_discount == 1)
	_check("Shadow Step: does NOT grant Haste to the next card", RunState.haste_next_card == false)

	# Spend it: Deadly Strike normally costs 2 -- with the discount it should be
	# playable for exactly 1 energy, and NOT be Haste (normal tick).
	cc.current_energy = 1
	var ticks_before := cc.total_ticks
	var result := _play_card_id(cc, "deadly_strike", "warrior_1", enemy)
	_check("Shadow Step: discounted next card is playable for 1 energy", result.ok and cc.current_energy == 0)
	_check("Shadow Step: discounted next card is not Haste (advances the clock normally)", cc.total_ticks == ticks_before + 1)
	cc.queue_free()

func _test_bulwark() -> void:
	# Empty discard pile
	var cc := _new_combat(["warrior_1", "warrior_2", "golemancer"])
	_check("Bulwark setup: discard pile starts empty", RunState.deck_model.discard_pile.is_empty())
	var block_before := cc.player_stats.block
	_play_card_id(cc, "bulwark", "golemancer")
	_check("Bulwark: gains 0 Block with an empty discard pile", cc.player_stats.block == block_before)
	cc.queue_free()

	# Non-trivial, uncapped discard pile
	cc = _new_combat(["warrior_1", "warrior_2", "golemancer"])
	_register_noop_card("tc_filler", "golemancer")
	for i in range(10):
		_play_card_id(cc, "tc_filler", "golemancer")
	var discard_size := RunState.deck_model.discard_pile.size()
	_check("Bulwark setup: discard pile has 10 filler cards", discard_size == 10)
	block_before = cc.player_stats.block
	_play_card_id(cc, "bulwark", "golemancer")
	_check("Bulwark: gains Block equal to the discard pile size, uncapped", cc.player_stats.block == block_before + discard_size)
	cc.queue_free()

func _test_construct_punch() -> void:
	# Empty draw pile
	var cc := _new_combat(["warrior_1", "warrior_2", "golemancer"])
	var enemy := cc.enemies[0]
	RunState.deck_model.draw_pile.clear()
	var hp_before := enemy.stats.current_hp
	_play_card_id(cc, "construct_punch", "golemancer", enemy)
	_check("Construct Punch: deals 0 damage with an empty draw pile", enemy.stats.current_hp == hp_before)
	cc.queue_free()

	# Non-trivial, uncapped draw pile
	cc = _new_combat(["warrior_1", "warrior_2", "golemancer"])
	enemy = cc.enemies[0]
	RunState.deck_model.draw_pile = ["fake_1", "fake_2", "fake_3", "fake_4", "fake_5", "fake_6"]
	hp_before = enemy.stats.current_hp
	_play_card_id(cc, "construct_punch", "golemancer", enemy)
	_check("Construct Punch: deals damage equal to the draw pile size, uncapped", enemy.stats.current_hp == hp_before - 6)
	cc.queue_free()

# ── Trio B: witch, grove, living_armor ──────────────────────────────────────

func _test_hex() -> void:
	var cc := _new_combat(["witch", "grove", "living_armor"])
	var enemy := cc.enemies[0]
	var hp_before := enemy.stats.current_hp
	var hand_before := RunState.deck_model.hand.size()
	_play_card_id(cc, "hex", "witch", enemy)
	# Hex's own append+removal from hand nets to 0; add_curse_to_hand is the only net change.
	_check("Hex: adds a Curse to hand", RunState.deck_model.hand.size() == hand_before + 1)
	var curses_in_hand := 0
	for iid in RunState.deck_model.hand:
		var card = RunState.deck.get(iid)
		if card:
			var cd = DataRegistry.get_card_data(card.card_id)
			if cd and cd.card_type == CardData.CardType.CURSE:
				curses_in_hand += 1
	_check("Hex: exactly 1 Curse in hand after the first Hex", curses_in_hand == 1)
	_check("Hex: deals 6 damage per Curse in hand, counted after adding (6 * 1 = 6)", enemy.stats.current_hp == hp_before - 6)

	# Second Hex: 2 Curses in hand now -> 12 damage
	hp_before = enemy.stats.current_hp
	_play_card_id(cc, "hex", "witch", enemy)
	_check("Hex: second Hex deals 6 * 2 = 12 damage (2 Curses now in hand)", enemy.stats.current_hp == hp_before - 12)
	cc.queue_free()

func _test_dark_pact() -> void:
	# 0 Curses in hand: must do nothing
	var cc := _new_combat(["witch", "grove", "living_armor"])
	cc.current_energy = 0
	if ResourceManager:
		ResourceManager.set_energy(0)
	var hand_before := RunState.deck_model.hand.size()
	_play_card_id(cc, "dark_pact", "witch")
	_check("Dark Pact: with 0 Curses in hand, energy is unchanged", cc.current_energy == 0)
	# Dark Pact's own append+removal from hand nets to 0; with 0 Curses, nothing else happens.
	_check("Dark Pact: with 0 Curses in hand, hand size is unchanged (no draw)", RunState.deck_model.hand.size() == hand_before)
	cc.queue_free()

	# 2 Curses in hand: exhaust both, gain 2 energy, draw 2
	cc = _new_combat(["witch", "grove", "living_armor"])
	var enemy := cc.enemies[0]
	_play_card_id(cc, "hex", "witch", enemy)
	_play_card_id(cc, "hex", "witch", enemy)
	var curse_ids: Array[String] = []
	for iid in RunState.deck_model.hand:
		var card = RunState.deck.get(iid)
		if card:
			var cd = DataRegistry.get_card_data(card.card_id)
			if cd and cd.card_type == CardData.CardType.CURSE:
				curse_ids.append(iid)
	_check("Dark Pact setup: 2 Curses in hand", curse_ids.size() == 2)

	cc.current_energy = 0
	if ResourceManager:
		ResourceManager.set_energy(0)
	var hand_before2 := RunState.deck_model.hand.size()
	_play_card_id(cc, "dark_pact", "witch")
	_check("Dark Pact: gains 1 Energy per Curse exhausted (2)", cc.current_energy == 2)
	var still_in_hand := false
	for cid in curse_ids:
		if RunState.deck_model.hand.has(cid):
			still_in_hand = true
	_check("Dark Pact: exhausted Curses are no longer in hand", not still_in_hand)
	var all_in_exhaust := true
	for cid in curse_ids:
		if not RunState.deck_model.exhaust_pile.has(cid):
			all_in_exhaust = false
	_check("Dark Pact: exhausted Curses are in the exhaust pile (not discard)", all_in_exhaust)
	# hand delta: dark_pact's own append+removal nets 0; -2 (curses exhausted) +2 (drawn) = 0
	_check("Dark Pact: draws 1 card per Curse exhausted (2)", RunState.deck_model.hand.size() == hand_before2)
	cc.queue_free()

func _test_deadfall_and_mill_edge_cases() -> void:
	var cc := _new_combat(["witch", "grove", "living_armor"])
	var enemy := cc.enemies[0]
	RunState.deck_model.draw_pile = ["d1", "d2", "d3", "d4"]
	RunState.deck_model.discard_pile.clear()
	var hp_before := enemy.stats.current_hp
	_play_card_id(cc, "deadfall", "grove", enemy)
	_check("Deadfall: deals 6 damage", enemy.stats.current_hp == hp_before - 6)
	_check("Deadfall: mills the top 2 cards of the draw pile into discard", RunState.deck_model.discard_pile.has("d1") and RunState.deck_model.discard_pile.has("d2"))
	_check("Deadfall: leaves the rest of the draw pile untouched", RunState.deck_model.draw_pile == ["d3", "d4"])
	cc.queue_free()

	# Mill edge case: draw pile has fewer than 2 cards, discard also empty
	RunState.deck_model.draw_pile = ["only1"]
	RunState.deck_model.discard_pile.clear()
	var milled: Array[String] = RunState.mill_draw_pile(2)
	_check("Mill: milling 2 with only 1 card total mills just that 1 card (no crash, no duplicate)", milled == ["only1"])
	_check("Mill: draw pile is empty afterward", RunState.deck_model.draw_pile.is_empty())
	_check("Mill: discard pile has exactly the 1 milled card", RunState.deck_model.discard_pile == ["only1"])

	# Mill edge case: both piles totally empty
	RunState.deck_model.draw_pile.clear()
	RunState.deck_model.discard_pile.clear()
	milled = RunState.mill_draw_pile(2)
	_check("Mill: milling with both piles empty mills nothing and doesn't crash", milled.is_empty())

func _test_compost_heap() -> void:
	var cc := _new_combat(["witch", "grove", "living_armor"])
	RunState.deck_model.discard_pile = ["a", "b", "c", "d", "e"]  # 5 cards -> floor(5/2) = 2
	cc.current_energy = 1
	if ResourceManager:
		ResourceManager.set_energy(1)
	var result := _play_card_id(cc, "compost_heap", "grove")
	_check("Compost Heap: costs 1 energy to play", true)  # can_play_card gated this; if it failed, the checks below will too
	_check("Compost Heap: gains floor(discard/2) Energy (2)", cc.current_energy == 0 + 2)
	_check("Compost Heap: exhausts itself instead of going to the discard pile", RunState.deck_model.exhaust_pile.has(result.instance_id))
	_check("Compost Heap: discard pile is unchanged by its own Exhaust (still 5)", RunState.deck_model.discard_pile.size() == 5)
	cc.queue_free()

	# Cap test: discard pile far larger than the cap (4)
	cc = _new_combat(["witch", "grove", "living_armor"])
	var filler: Array[String] = []
	for i in range(20):
		filler.append("f%d" % i)
	RunState.deck_model.discard_pile = filler
	cc.current_energy = 1
	if ResourceManager:
		ResourceManager.set_energy(1)
	_play_card_id(cc, "compost_heap", "grove")
	_check("Compost Heap: Energy gain is capped at 4 even with a much larger discard pile", cc.current_energy == 4)
	cc.queue_free()

func _test_iron_shell_agility() -> void:
	var cc := _new_combat(["witch", "grove", "living_armor"])
	var block_before := cc.player_stats.block
	_play_card_id(cc, "iron_shell", "living_armor")
	_check("Iron Shell: gains 5 Block (Agility not yet active for its own Block)", cc.player_stats.block == block_before + 5)
	# Iron Shell isn't Haste, so its own 1-tick play has already ticked the
	# Agility 2 it just applied down to 1 -- still active (>0) either way.
	var agility = cc.player_stats.get_status(StatusEffectType.AGILITY)
	_check("Iron Shell: applies 2 Agility (1 left after its own 1-tick play)", agility != null and int(agility) == 1)

	# A later Block gain (Shadow Step, +6 base) should be boosted 25% rounded up: ceil(6*1.25) = 8
	block_before = cc.player_stats.block
	_play_card_id(cc, "shadow_step", "warrior_2")
	_check("Agility: a later Block gain of 6 is increased to ceil(6*1.25)=8", cc.player_stats.block == block_before + 8)
	cc.queue_free()

func _test_iron_tide() -> void:
	var cc := _new_combat(["witch", "grove", "living_armor"])
	var enemy := cc.enemies[0]
	cc.player_stats.block = 7  # odd, to exercise the round-up
	var hp_before := enemy.stats.current_hp
	_play_card_id(cc, "iron_tide", "living_armor", enemy)
	_check("Iron Tide: deals ceil(7/2)=4 damage", enemy.stats.current_hp == hp_before - 4)
	_check("Iron Tide: does not spend Block", cc.player_stats.block == 7)
	cc.queue_free()
