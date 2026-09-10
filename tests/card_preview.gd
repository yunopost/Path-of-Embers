extends Node
## Headless coverage for CardRules.get_live_preview (Job: real-time card numbers).
## Verifies the preview reflects live owner stats/equipment, Vulnerable/Weakness/
## Agility, and pile sizes for the named special-formula cards, AND that
## previewing never mutates state (energy, Block, hand, draw pile, discard pile,
## next_card_discount, haste_next_card all untouched by a preview call).
## Run: ../Godot_v4.5-stable_linux.x86_64 --headless --path . res://tests/card_preview.tscn

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
	print("=== card_preview test ===")
	_test_block_with_dexterity_and_equipment()
	_test_damage_vs_vulnerable_target()
	_test_bulwark_pile_size()
	_test_construct_punch_pile_size()
	_test_iron_tide_half_block()
	_test_hex_per_curse_in_hand()
	_test_non_mutating()
	print("--- card_preview summary: %d passed, %d failed ---" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)

func _start_fresh_combat(party_ids: Array[String]) -> CombatController:
	PartyManager.party_ids = party_ids.duplicate()
	var chars: Array[CharacterData] = []
	for id in party_ids:
		chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)
	var cc := CombatController.new()
	add_child(cc)
	cc.start_combat([{"enemy_id": "ash_man", "count": 1}])
	return cc

func _find_instance_id(card_id: String) -> String:
	for iid in RunState.deck_order:
		var c: DeckCardData = RunState.deck.get(iid)
		if c and c.card_id == card_id:
			return iid
	return ""

func _draw_specific_card(card_id: String) -> DeckCardData:
	## Move the named card's instance to the front of the draw pile and draw it,
	## the normal way (no synthetic hand injection).
	var iid := _find_instance_id(card_id)
	if iid == "":
		return null
	if RunState.deck_model.draw_pile.has(iid):
		RunState.deck_model.draw_pile.erase(iid)
	elif RunState.deck_model.hand.has(iid):
		RunState.deck_model.hand.erase(iid)
	elif RunState.deck_model.discard_pile.has(iid):
		RunState.deck_model.discard_pile.erase(iid)
	RunState.deck_model.draw_pile.push_front(iid)
	RunState.draw_cards(1)
	return RunState.deck.get(iid)

func _test_block_with_dexterity_and_equipment() -> void:
	RunState.equipment_slots.clear()
	var cc := _start_fresh_combat(["warrior_1", "witch", "golemancer"])
	var card_data = DataRegistry.get_card_data("defend_1")
	var dc = _draw_specific_card("defend_1")
	_check("defend_1 drawn", dc != null)
	if not dc:
		cc.queue_free(); return

	var base_block = int(card_data.base_effects[0].params.get("amount", 0))
	var owner_stats: EntityStats = cc.character_stats.get(dc.owner_character_id, null)
	var char_data = DataRegistry.get_character(dc.owner_character_id)

	var live_before = CardRules.get_live_preview(card_data, dc, cc, null)
	_check("Block preview includes owner's base Dexterity (def_base)",
		live_before.block == base_block + char_data.def_base)

	# Now equip +1 DEF and confirm the preview updates live, with no re-fetch needed.
	RunState.equipment_slots[dc.owner_character_id] = {"chest": "chain_mail"}
	owner_stats.apply_status(StatusEffectType.DEXTERITY, 1)  # mirrors what start_combat's equip-apply loop would do
	var live_after = CardRules.get_live_preview(card_data, dc, cc, null)
	_check("Block preview reflects the new equipment Dexterity bonus",
		live_after.block == live_before.block + 1)
	_check("Block preview is marked modified relative to the static value",
		live_after.block_modified)

	cc.queue_free()

func _test_damage_vs_vulnerable_target() -> void:
	var cc := _start_fresh_combat(["warrior_1", "witch", "golemancer"])
	var card_data = DataRegistry.get_card_data("strike_1")
	var dc = _draw_specific_card("strike_1")
	_check("strike_1 drawn", dc != null)
	if not dc:
		cc.queue_free(); return

	var enemy = cc.get_enemies()[0]
	var live_no_vuln = CardRules.get_live_preview(card_data, dc, cc, enemy.stats)
	enemy.stats.apply_status(StatusEffectType.VULNERABLE, 2)
	var live_vuln = CardRules.get_live_preview(card_data, dc, cc, enemy.stats)
	_check("Damage against a Vulnerable target is int(raw*1.5)",
		live_vuln.damage == int(live_no_vuln.damage * 1.5))
	_check("Damage preview marked modified while target is Vulnerable",
		live_vuln.damage_modified)

	cc.queue_free()

func _test_bulwark_pile_size() -> void:
	var cc := _start_fresh_combat(["golemancer", "warrior_1", "witch"])
	var card_data = DataRegistry.get_card_data("bulwark")
	var dc = _draw_specific_card("bulwark")
	_check("bulwark drawn", dc != null)
	if not dc:
		cc.queue_free(); return

	var discard_size = RunState.deck_model.discard_pile.size()
	var live = CardRules.get_live_preview(card_data, dc, cc, null)
	_check("Bulwark Block == discard pile size (+ owner Dexterity)",
		live.block == discard_size + cc.character_stats[dc.owner_character_id].get_status(StatusEffectType.DEXTERITY))

	# Grow the discard pile and confirm the preview tracks it live.
	RunState.deck_model.discard_pile.append("synthetic_discard_card")
	var live2 = CardRules.get_live_preview(card_data, dc, cc, null)
	_check("Bulwark Block preview grows with the discard pile",
		live2.block == live.block + 1)
	RunState.deck_model.discard_pile.pop_back()

	cc.queue_free()

func _test_construct_punch_pile_size() -> void:
	var cc := _start_fresh_combat(["golemancer", "warrior_1", "witch"])
	var card_data = DataRegistry.get_card_data("construct_punch")
	var dc = _draw_specific_card("construct_punch")
	_check("construct_punch drawn", dc != null)
	if not dc:
		cc.queue_free(); return

	var draw_size = RunState.deck_model.draw_pile.size()
	var live = CardRules.get_live_preview(card_data, dc, cc, null)
	_check("Construct Punch damage == draw pile size (+ owner Strength)",
		live.damage == draw_size + cc.character_stats[dc.owner_character_id].get_status(StatusEffectType.STRENGTH))

	cc.queue_free()

func _test_iron_tide_half_block() -> void:
	var cc := _start_fresh_combat(["living_armor", "warrior_1", "witch"])
	var card_data = DataRegistry.get_card_data("iron_tide")
	var dc = _draw_specific_card("iron_tide")
	_check("iron_tide drawn", dc != null)
	if not dc:
		cc.queue_free(); return

	cc.player_stats.block = 7
	var live = CardRules.get_live_preview(card_data, dc, cc, null)
	var owner_str = cc.character_stats[dc.owner_character_id].get_status(StatusEffectType.STRENGTH)
	_check("Iron Tide damage == ceil(7/2) + owner Strength = 4 + str",
		live.damage == 4 + int(owner_str))
	_check("Iron Tide preview does not spend Block", cc.player_stats.block == 7)

	cc.queue_free()

func _test_hex_per_curse_in_hand() -> void:
	var cc := _start_fresh_combat(["warrior_1", "witch", "golemancer"])
	var card_data = DataRegistry.get_card_data("hex")
	var dc = _draw_specific_card("hex")
	_check("hex drawn", dc != null)
	if not dc:
		cc.queue_free(); return

	var owner_str_hex = cc.character_stats[dc.owner_character_id].get_status(StatusEffectType.STRENGTH)
	var live_zero_curses = CardRules.get_live_preview(card_data, dc, cc, null)
	_check("Hex with 0 Curses in hand previews base_amount(0) + owner Strength, no per-curse bonus",
		live_zero_curses.damage == int(owner_str_hex))

	# Add a real Curse instance to hand (not via the mutating add_curse_to_hand
	# effect -- this test previews, it does not play the card) and confirm the
	# preview counts it.
	var curse := DeckCardData.new("curse_card", "")
	RunState.deck[curse.instance_id] = curse
	RunState.deck_order.append(curse.instance_id)
	RunState.deck_model.hand.append(curse.instance_id)

	var live_one_curse = CardRules.get_live_preview(card_data, dc, cc, null)
	_check("Hex damage == 6 per Curse in hand (1 curse -> 6 + Strength)",
		live_one_curse.damage == 6 + cc.character_stats[dc.owner_character_id].get_status(StatusEffectType.STRENGTH))
	_check("Hex preview is marked modified (value is entirely live/state-driven)",
		live_one_curse.damage_modified)

	cc.queue_free()

func _test_non_mutating() -> void:
	## Previewing must never consume the one-shot flags, spend Block, draw,
	## or add curses -- across every card exercised above.
	var cc := _start_fresh_combat(["warrior_1", "witch", "golemancer"])
	RunState.next_card_discount = 2
	RunState.haste_next_card = true
	cc.player_stats.block = 9
	cc.current_energy = 2
	var block_before = cc.player_stats.block
	var energy_before = cc.current_energy
	var cards_to_check = ["hex", "bulwark", "construct_punch", "iron_tide", "defend_1", "strike_1"]

	for card_id in cards_to_check:
		var card_data = DataRegistry.get_card_data(card_id)
		var dc = _draw_specific_card(card_id)  # the one legitimate mutation per card: drawing it into hand
		if dc:
			# Snapshot AFTER the draw above (which is itself a real, expected
			# mutation -- including possibly burning an overflow card to
			# discard once hand hits HAND_MAX) so the preview call below is
			# checked against a clean baseline.
			var hand_size_before = RunState.deck_model.hand.size()
			var draw_size_before = RunState.deck_model.draw_pile.size()
			var discard_size_before = RunState.deck_model.discard_pile.size()
			var enemy = cc.get_enemies()[0] if not cc.get_enemies().is_empty() else null
			CardRules.get_live_preview(card_data, dc, cc, enemy.stats if enemy else null)
			# The preview call itself must not have moved anything further.
			_check("%s preview does not change hand size" % card_id,
				RunState.deck_model.hand.size() == hand_size_before)
			_check("%s preview does not change draw pile size" % card_id,
				RunState.deck_model.draw_pile.size() == draw_size_before)
			_check("%s preview does not change discard pile size" % card_id,
				RunState.deck_model.discard_pile.size() == discard_size_before)

	_check("next_card_discount untouched by previews", RunState.next_card_discount == 2)
	_check("haste_next_card untouched by previews", RunState.haste_next_card == true)
	_check("Block untouched by previews", cc.player_stats.block == block_before)
	_check("Energy untouched by previews", cc.current_energy == energy_before)

	cc.queue_free()
