extends Node

func _ready():
	call_deferred("run_probes")

func run_probes():
	print("ASSESSMENT USER DIR: ", OS.get_user_data_dir())
	RunState.reset_run()
	PartyManager.party_ids = ["warrior_1", "witch", "living_armor"]
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)
	QuestManager.initialize_quests(chars)
	QuestManager.set_quest_choice(chars[1], "witch_quest_1")
	var cc = CombatController.new()
	add_child(cc)
	cc.start_combat([{"enemy_id":"ash_man", "count":1}])
	var discarded = 0
	for i in range(5):
		RunState.deck_model.draw_cards(8, 8)
		discarded += cc._pay_discard_cost(4)
	print("PROBE discard quest: actual discards=", discarded, " progress=", QuestManager.get_quest("witch").progress)
	cc.end_combat(false)
	cc.queue_free()
	var m = MapGenerator.new().generate_map(3)
	MapManager.set_act(3)
	MapManager.current_node_id = ""
	MapManager.set_map_data(m)
	for id in ["warrior_1", "living_armor"]:
		var q = QuestManager.get_quest(id)
		q.set_progress(q.progress_max)
	for n in m.nodes.values():
		if m.boss_node_id in n.connected_to:
			MapManager.set_current_node(n.id)
			break
	print("PROBE final gate after 20 discards: available=", MapManager.available_next_node_ids)
	RunState.reset_run()
	PartyManager.party_ids = ["warrior_1", "witch", "living_armor"]
	RunState.generate_starter_deck(chars)
	QuestManager.initialize_quests(chars)
	MapManager.set_map_data(MapGenerator.new().generate_map(1))
	var start_id = MapManager.current_map.start_node_ids[0]
	MapManager.set_current_node(start_id)
	ResourceManager.set_hp(31,75)
	SaveManager.save_game()
	var saved = SaveManager._serialize_run_state()
	print("PROBE mid-combat save: selected=", start_id, " completed=", MapManager.current_map.get_node(start_id).is_completed, " next=", MapManager.available_next_node_ids, " enemy state saved=", saved.has("enemies"))
	var menu = load("res://scenes/screens/Main.tscn").instantiate()
	get_tree().root.add_child(menu)
	ScreenManager.current_scene = menu
	await get_tree().process_frame
	await get_tree().process_frame
	menu._on_continue_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	print("PROBE Continue: screen=", ScreenManager.current_screen, " selected completed=", MapManager.current_map.get_node(start_id).is_completed, " selectable=", MapManager.available_next_node_ids, " hp=", ResourceManager.current_hp)
	print("PROBE roster: milestones=", DataRegistry.get_all_milestones().size(), " unlocked=", MilestoneManager.unlocked_characters)
	RunState.reset_run()
	PartyManager.party_ids = ["warrior_1", "witch", "living_armor"]
	RunState.generate_starter_deck(chars)
	RunState.run_stash = ["chain_mail", "iron_helm"]
	RunState.equip_item("living_armor", "CHEST", "chain_mail")
	RunState.equip_item("witch", "HELMET", "iron_helm")
	var maxima = [ResourceManager.max_hp]
	for i in range(3):
		var fresh_cc = CombatController.new()
		add_child(fresh_cc)
		fresh_cc.start_combat([{"enemy_id":"ash_man", "count":1}])
		maxima.append(ResourceManager.max_hp)
		fresh_cc.end_combat(false)
		fresh_cc.queue_free()
	print("PROBE unchanged equipment max HP across three combat starts: ",maxima)
	var b = RewardBundle.new()
	b.gold = 10
	RunState.set_pending_rewards(b)
	ScreenManager.go_to_rewards(b)
	await get_tree().process_frame
	await get_tree().process_frame
	var rewards = ScreenManager.current_scene
	rewards._on_claim_gold(10)
	print("PROBE gold reward: gold=",ResourceManager.gold," bundle gold=",b.gold," Continue disabled=",rewards.continue_button.disabled)
	get_tree().quit()
