extends Node
## Headless coverage for the per-character stat readout on CharacterHUDBlock
## (Card-Clock Addendum §4 item 4 / "a per-character stat readout on the
## battle screen"): Strength/Dexterity/Faith (base + equipment, per-owner)
## and HP contribution, shown only while bound to a live combat and updating
## live as equipment/statuses change.
## Run: ../Godot_v4.5-stable_linux.x86_64 --headless --path . res://tests/party_hud_stats.tscn

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
	print("=== party_hud_stats test ===")
	await _run()
	print("--- party_hud_stats summary: %d passed, %d failed ---" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)

func _run() -> void:
	RunState.equipment_slots.clear()
	PartyManager.party_ids = ["warrior_1", "witch", "golemancer"]
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)

	var cc := CombatController.new()
	add_child(cc)
	cc.start_combat([{"enemy_id": "ash_man", "count": 1}])

	var block_scene: PackedScene = load("res://scenes/ui/hud/CharacterHUDBlock.tscn")
	var block = block_scene.instantiate()
	add_child(block)
	block.initialize("witch")
	await get_tree().process_frame

	_check("stats row hidden before combat is bound", not block.stats_row.visible)

	block.bind_combat(cc)
	_check("stats row visible once bound to combat", block.stats_row.visible)

	var witch_data := DataRegistry.get_character("witch")
	_check("STR label shows witch's base Strength",
		block.str_label.text == "STR %d" % witch_data.str_base)
	_check("DEF label shows witch's base Dexterity",
		block.def_label.text == "DEF %d" % witch_data.def_base)
	_check("SPI label shows witch's base Faith",
		block.spirit_label.text == "SPI %d" % witch_data.spirit_base)
	_check("HP contribution label shows witch's base HP with no equipment",
		block.hp_contribution_label.text == "HP +%d" % witch_data.hp_base)

	# Equip +1 DEF, +4 HP (chain_mail) and confirm the readout updates live,
	# and ONLY for this character -- a character's stats affect only their
	# own cards, so the readout must not leak into another character's block.
	RunState.equipment_slots["witch"] = {"chest": "chain_mail"}
	cc.character_stats["witch"].apply_status(StatusEffectType.DEXTERITY, 1)
	block.refresh_stats()
	_check("DEF label reflects the newly equipped Dexterity bonus",
		block.def_label.text == "DEF %d" % (witch_data.def_base + 1))
	_check("HP contribution label reflects the equipped HP bonus",
		block.hp_contribution_label.text == "HP +%d (%d+%d)" % [witch_data.hp_base + 4, witch_data.hp_base, 4])

	var block2 = block_scene.instantiate()
	add_child(block2)
	block2.initialize("golemancer")
	block2.bind_combat(cc)
	var golem_data := DataRegistry.get_character("golemancer")
	_check("golemancer's own block is unaffected by witch's equipment",
		block2.def_label.text == "DEF %d" % golem_data.def_base)

	block.unbind_combat()
	_check("stats row hidden again after unbind_combat", not block.stats_row.visible)

	block.queue_free()
	block2.queue_free()
	cc.queue_free()
