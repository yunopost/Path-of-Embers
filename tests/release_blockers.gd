extends Node
## Integration regressions. Run with a disposable APPDATA profile: writes run/meta saves.

var passed := 0
var failed := 0
var chars: Array[CharacterData] = []

func check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		print("FAIL: ", label)

func settle() -> void:
	for i in range(5):
		await get_tree().process_frame

func fresh() -> void:
	RunState.reset_run()
	PartyManager.set_party(["warrior_1", "witch", "living_armor"])
	chars.clear()
	for id in PartyManager.party_ids:
		chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)
	QuestManager.initialize_quests(chars)

func rewards_screen():
	var screen = load("res://scenes/screens/RewardsScreen.tscn").instantiate()
	add_child(screen)
	return screen

func _ready() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	await settle()
	test_equipment_hp()
	test_discard_quest()
	test_upgrade_pools()
	await test_rewards()
	test_milestones()
	await test_party_hud()
	await test_resume()
	print("--- release_blockers summary: %d passed, %d failed ---" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func test_equipment_hp() -> void:
	fresh()
	RunState.run_stash = ["chain_mail", "iron_helm"]
	RunState.equip_item("living_armor", "CHEST", "chain_mail")
	RunState.equip_item("witch", "HELMET", "iron_helm")
	for i in range(3):
		var cc := CombatController.new()
		add_child(cc)
		cc.start_combat([{"enemy_id": "ash_man", "count": 1}])
		check("unchanged equipment caps HP at 81, fight %d" % i, ResourceManager.max_hp == 81)
		check("unchanged equipment preserves attrition, fight %d" % i, ResourceManager.current_hp == 81 - i * 5)
		ResourceManager.set_hp(ResourceManager.current_hp - 5)
		cc.free()
	check("HP save succeeds", SaveManager.save_game())
	ResourceManager.equipment_hp_bonus = 0
	check("HP load succeeds", SaveManager.load_game())
	ResourceManager.sync_equipment_hp()
	check("reload does not add equipment HP again", ResourceManager.max_hp == 81 and ResourceManager.current_hp == 66)
	ResourceManager.set_hp(66, 85)
	check("maximum-only HP changes work", ResourceManager.max_hp == 85)
	var legacy := SaveManager._serialize_run_state().duplicate(true)
	legacy.erase("equipment_hp_bonus")
	legacy["max_hp"] = 93
	legacy["current_hp"] = 83
	SaveManager._deserialize_run_state(legacy)
	ResourceManager.sync_equipment_hp()
	check("legacy accumulation repaired, missing HP preserved", ResourceManager.max_hp == 81 and ResourceManager.current_hp == 71)

func test_discard_quest() -> void:
	fresh()
	QuestManager.set_quest_choice(chars[1], "witch_quest_1")
	var cc := CombatController.new()
	add_child(cc)
	cc.start_combat([{"enemy_id": "ash_man", "count": 1}])
	RunState.deck_model.draw_cards(20, 8)
	RunState.mill_draw_pile(2)
	check("overflow and mill do not count as explicit discards", QuestManager.get_quest("witch").progress == 0)
	RunState.deck_model.hand.resize(2)
	check("ability may pay exactly the remaining hand", cc._pay_discard_cost(2) == 2)
	check("each discarded card advances quest once", QuestManager.get_quest("witch").progress == 2)
	check("failed discard does not advance quest", cc._pay_discard_cost(1) == 0 and QuestManager.get_quest("witch").progress == 2)
	for i in range(5):
		RunState._initialize_deck_piles()
		RunState.draw_cards(4)
		cc._pay_discard_cost(4)
	check("Curse Weaver completes through gameplay discard path", QuestManager.get_quest("witch").is_complete)
	cc.free()
	MapManager.set_map_data(MapGenerator.new().generate_map(3))
	for id in ["warrior_1", "living_armor"]:
		var q = QuestManager.get_quest(id)
		q.set_progress(q.progress_max)
	for node in MapManager.current_map.nodes.values():
		if MapManager.current_map.boss_node_id in node.connected_to:
			MapManager.set_current_node(node.id)
			MapManager.mark_current_node_completed()
			break
	check("completed discard quest opens final boss gate", MapManager.current_map.boss_node_id in MapManager.available_next_node_ids)

func test_upgrade_pools() -> void:
	fresh()
	var card := DeckCardData.new("strike_1", "warrior_1")
	var pool = DataRegistry.get_upgrade_pool_for_card(card.card_id)
	for remaining in [3, 2, 1, 0]:
		card.applied_upgrades.clear()
		for i in range(pool.size() - remaining):
			card.applied_upgrades.append(pool[i])
		var options: Array[String] = UpgradeService.roll_upgrade_options_for_card(card)
		check("typed pool returns %d remaining upgrades" % remaining, options.size() == remaining)

func test_rewards() -> void:
	fresh()
	ResourceManager.set_hp(40, 75)
	var bundle := RewardBundle.new(10, ["strike_1", "defend_1"], 1, 5, true, false, 10)
	bundle.equipment_drop_id = "iron_helm"
	RunState.set_pending_rewards(bundle)
	var screen = rewards_screen()
	check("automatic heal and points applied", ResourceManager.current_hp == 45 and ResourceManager.upgrade_points == 10)
	screen._on_claim_gold(10)
	screen._on_claim_gold(10)
	check("gold claimed once and Continue awaits other rewards", ResourceManager.gold == 10 and screen.continue_button.disabled)
	screen.free()
	check("partial reward reload succeeds", SaveManager.load_game())
	screen = rewards_screen()
	check("reload does not repeat gold/heal/points", ResourceManager.gold == 10 and ResourceManager.current_hp == 45 and ResourceManager.upgrade_points == 10)
	var deck_size := RunState.deck.size()
	screen._on_choose_card("strike_1")
	screen.free()
	SaveManager.load_game()
	screen = rewards_screen()
	check("card reward survives reload without duplication", RunState.deck.size() == deck_size + 1 and screen.card_claimed)
	screen._on_claim_equipment("iron_helm")
	screen.free()
	SaveManager.load_game()
	screen = rewards_screen()
	check("equipment claim survives reload", RunState.backpack == ["iron_helm"] and screen.equipment_claimed)
	var card = RunState.deck[RunState.deck_order[0]]
	var options = UpgradeService.roll_upgrade_options_for_card(card)
	screen.upgrade_flow_panel.selected_instance_id = card.instance_id
	screen._on_upgrade_option_selected(options[0])
	var points := ResourceManager.upgrade_points
	var instance_id: String = card.instance_id
	screen.free()
	SaveManager.load_game()
	screen = rewards_screen()
	check("upgrade and consumed count survive reload", RunState.deck[instance_id].applied_upgrades.has(options[0]) and screen.reward_bundle.upgrade_count == 0)
	check("upgrade currency survives reload", ResourceManager.upgrade_points == points and points < 10)
	check("Continue enables after all reward categories resolved", not screen.continue_button.disabled)
	screen.free()
	RunState.set_pending_rewards(RewardBundle.new(0, ["strike_1"]))
	screen = rewards_screen()
	screen._on_skip_cards()
	screen.free()
	SaveManager.load_game()
	check("skipped card choice persists", RunState.pending_rewards.card_choices.is_empty())
	RunState.set_pending_rewards(RewardBundle.new(0, [], 1, 0, true, true))
	screen = rewards_screen()
	check("saved unavailable transcendence becomes normal upgrade", not screen.reward_bundle.is_transcendence_upgrade)
	screen.free()
	# Exercise the real future transcendence path with a test-only definition.
	var transcendent: CardData = DataRegistry.get_card_data("strike_1").duplicate(true)
	transcendent.id = "test_transcend"
	DataRegistry.transcendent_card_cache[transcendent.id] = transcendent
	RunState.set_pending_rewards(RewardBundle.new(0, [], 1, 0, true, true))
	screen = rewards_screen()
	screen._on_upgrade_button_pressed()
	var transcend_instance: String = RunState.deck_order[0]
	screen.upgrade_flow_panel._on_card_widget_clicked(transcend_instance)
	await settle()
	var transformed := false
	for button in screen.upgrade_flow_panel.upgrade_content.get_children():
		if button is Button and not button.is_queued_for_deletion():
			button.pressed.emit()
			transformed = true
			break
	check("boss transcendence offers usable buttons", transformed)
	check("boss upgrade refreshes Continue", not screen.continue_button.disabled)
	screen.free()
	SaveManager.load_game()
	check("transcendence and consumed reward persist", RunState.deck[transcend_instance].is_transcended and RunState.pending_rewards.upgrade_count == 0)
	DataRegistry.transcendent_card_cache.erase("test_transcend")
	await settle()

func test_milestones() -> void:
	SaveManager.save_milestone_meta({"completed_milestones": [], "unlocked_characters": [], "milestone_progress": {}})
	MilestoneManager._load_from_meta()
	check("fresh profile retains starting three", MilestoneManager.unlocked_characters.size() == 3)
	check("three unlock milestones registered", DataRegistry.get_all_milestones().size() == 3)
	QuestManager.emit_game_event("COMBAT_VICTORY", {"node_type": MapNodeData.NodeType.FIGHT, "act": 1})
	MilestoneManager._load_from_meta()
	check("partial milestone progress persisted", MilestoneManager._progress_counters.get("unlock_shadowfoot") == 1)
	QuestManager.emit_game_event("COMBAT_VICTORY", {"node_type": MapNodeData.NodeType.FIGHT, "act": 1})
	check("Shadowfoot locked before third combat", not MilestoneManager.is_unlocked("character", "warrior_2"))
	QuestManager.emit_game_event("COMBAT_VICTORY", {"node_type": MapNodeData.NodeType.ELITE, "act": 1})
	check("third combat unlocks Shadowfoot", MilestoneManager.is_unlocked("character", "warrior_2"))
	check("elite victory unlocks Grove", MilestoneManager.is_unlocked("character", "grove"))
	QuestManager.emit_game_event("COMBAT_VICTORY", {"node_type": MapNodeData.NodeType.BOSS, "act": 2})
	check("later boss does not satisfy Act I requirement", not MilestoneManager.is_unlocked("character", "golemancer"))
	QuestManager.emit_game_event("COMBAT_VICTORY", {"node_type": MapNodeData.NodeType.BOSS, "act": 1})
	MilestoneManager._load_from_meta()
	check("all six characters unlocked persistently", MilestoneManager.unlocked_characters.size() == 6)

func test_party_hud() -> void:
	fresh()
	var hud = load("res://scenes/ui/hud/PartyHUD.tscn").instantiate()
	add_child(hud)
	await settle()
	check("parent creates three HUD slots", hud._character_hud_blocks.size() == 3)
	for block in hud._character_hud_blocks:
		check("parent initializes real name and portrait", block.name_label.text != "Character Name" and block.portrait.texture != null)
	hud.free()

func test_resume() -> void:
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	ScreenManager.current_scene = dummy
	for scenario in [{"kind": MapNodeData.NodeType.FIGHT, "act": 1}, {"kind": MapNodeData.NodeType.BOSS, "act": 1}, {"kind": MapNodeData.NodeType.BOSS, "act": 2}, {"kind": MapNodeData.NodeType.FINAL_BOSS, "act": 3}]:
		var kind = scenario.kind
		fresh()
		for quest in QuestManager.quests.values():
			quest.set_progress(quest.progress_max)
		MapManager.set_act(scenario.act)
		var map := MapData.new()
		var node := MapNodeData.new("resume", 0, 0, kind)
		var next := MapNodeData.new("next", 1, 0)
		if kind == MapNodeData.NodeType.FIGHT:
			node.connected_to.append("next")
		map.nodes = {"resume": node, "next": next}
		map.start_node_ids = ["resume"]
		MapManager.set_map_data(map)
		MapManager.set_current_node("resume")
		ResourceManager.set_hp(61, 75)
		ScreenManager.go_to_combat()
		await settle()
		check("checkpoint captured before fight %d" % kind, not SaveManager.combat_checkpoint.is_empty())
		ResourceManager.set_hp(31)
		RunState.buffs.append("checkpoint_probe")
		SaveManager.save_game()
		ScreenManager.go_to_main_menu()
		await settle()
		ScreenManager.current_scene._on_continue_pressed()
		await settle()
		check("Continue re-enters unfinished fight %d" % kind, ScreenManager.current_screen == "combat")
		check("Continue restores pre-fight HP %d" % kind, ResourceManager.current_hp == 61)
		check("checkpoint is a deep snapshot %d" % kind, not RunState.buffs.has("checkpoint_probe"))
		check("unfinished node cannot expose successors %d" % kind, MapManager.available_next_node_ids == ["resume"])
		ScreenManager.go_to_main_menu()
		await settle()
	SaveManager.clear_combat_checkpoint()
	fresh()
	MapManager.set_map_data(MapGenerator.new().generate_map(1))
	var encounter_node = MapManager.current_map.get_node(MapManager.current_map.start_node_ids[0])
	encounter_node.node_type = MapNodeData.NodeType.ENCOUNTER
	MapManager.set_current_node(encounter_node.id)
	ScreenManager.go_to_encounter()
	await settle()
	ScreenManager.current_scene._on_choice_pressed(ScreenManager.current_scene.encounter_data.choices[0])
	await settle()
	check("encounter choice completes the node", encounter_node.is_completed)
	check("encounter choice routes to rewards", ScreenManager.current_screen == "rewards")
	check("encounter cannot be repeated for rewards", not encounter_node.id in MapManager.available_next_node_ids)
	ResourceManager.set_hp(0)
	ScreenManager.go_to_game_over()
	await settle()
	var stats: String = ScreenManager.current_scene._build_stats_text()
	check("defeat screen shows current party and deck", stats.contains("Monster Hunter") and stats.contains("Deck size:"))
