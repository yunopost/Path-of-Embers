extends Node

var policy = preload("res://tests/sim.gd").new()
var run_index = 0
var transitions = 0
var actions = 0
var last_screen = ""
var reports = []

func _ready():
	call_deferred("run_tests")

func settle():
	for i in range(5):
		await get_tree().process_frame

func run_tests():
	get_tree().root.size = Vector2i(1920,1080)
	policy.cfg.party = ["warrior_1", "witch", "living_armor"]
	policy.cfg.policy = "timed"
	var dummy = Node.new()
	get_tree().root.add_child(dummy)
	ScreenManager.current_scene = dummy
	for trial in range(3):
		run_index = trial
		RunState.reset_run()
		PartyManager.party_ids = ["warrior_1", "witch", "living_armor"]
		var chars: Array[CharacterData] = []
		for id in PartyManager.party_ids:
			chars.append(DataRegistry.get_character(id))
		QuestManager.initialize_quests(chars)
		ScreenManager.go_to_loadout()
		await settle()
		var loadout = ScreenManager.current_scene
		for pair in [["swift_boots","BOOTS","warrior_1"],["chain_mail","CHEST","living_armor"],["iron_helm","HELMET","witch"]]:
			loadout._on_stash_item_clicked(pair[0])
			loadout._on_slot_clicked(pair[2],pair[1])
		loadout.start_btn.pressed.emit()
		await settle()
		var qs = ScreenManager.current_scene
		qs._on_quest_clicked("warrior_1", "warrior_1_quest_2")
		qs._on_quest_clicked("witch", "witch_quest_2")
		qs._on_quest_clicked("living_armor", "living_armor_quest_2")
		qs._begin_btn.pressed.emit()
		await settle()
		actions = 0
		transitions = 0
		last_screen = ""
		var outcome = "action_limit"
		for step in range(5000):
			await settle()
			var s = ScreenManager.current_scene
			var screen = ScreenManager.current_screen
			if screen != last_screen:
				transitions += 1
				print("FLOW ",trial," screen=",screen," act=",MapManager.act," row=",MapManager.node_position," hp=",ResourceManager.current_hp," deck=",RunState.deck.size())
				last_screen = screen
			match screen:
				"map":
					if MapManager.available_next_node_ids.is_empty():
						outcome = "no_available_nodes"
						break
					var id = MapManager.available_next_node_ids[0]
					# Prefer rest, events and shops to keep a weak heuristic alive.
					for candidate in MapManager.available_next_node_ids:
						var kind = MapManager.current_map.get_node(candidate).node_type
						if kind in [MapNodeData.NodeType.REST,MapNodeData.NodeType.ENCOUNTER,MapNodeData.NodeType.SHOP]:
							id = candidate
					var node_type = MapManager.current_map.get_node(id).node_type
					s._on_node_clicked(id)
					if node_type == MapNodeData.NodeType.REST:
						for child in s.get_children():
							if child is AcceptDialog:
								child.confirmed.emit()
				"combat":
					var cc = s.combat_controller
					if not cc.combat_active:
						outcome = "inactive_combat_without_transition"
						break
					var playable = policy._playable_cards(cc,{})
					policy._playable_now = playable.size()
					var ability = policy._try_use_ability(cc)
					if ability.is_empty():
						var choice = policy._policy_choose(cc,playable)
						if choice.is_empty():
							policy.advance(cc)
						else:
							var target = null
							if choice.enemy != null:
								target = Node.new()
								target.set_meta("enemy",choice.enemy)
							var ok = cc.play_card(choice.dc,target)
							if target: target.free()
							policy._zero_tick_ability_used_since_card.clear()
							if not ok:
								outcome = "refused_card"
								break
					actions += 1
				"rewards":
					var b = s.reward_bundle
					if b.gold > 0: s._on_claim_gold(b.gold)
					if not b.card_choices.is_empty(): s._on_choose_card(b.card_choices[0])
					if not b.equipment_drop_id.is_empty() and not s.equipment_claimed:
						if RunState.backpack_is_full():
							s._finish_equipment_claim()
						else: s._on_claim_equipment(b.equipment_drop_id)
					if b.upgrade_count > 0:
						s._on_upgrade_button_pressed()
						var found = false
						for iid in RunState.get_upgradeable_instance_ids():
							if not UpgradeService.can_afford_upgrade(RunState.deck[iid]): continue
							s.upgrade_flow_panel._on_card_widget_clicked(iid)
							if not s.upgrade_flow_panel.current_upgrade_options.is_empty():
								s.upgrade_flow_panel._on_upgrade_button_pressed(s.upgrade_flow_panel.current_upgrade_options[0])
								found = true
								break
						if not found:
							outcome = "mandatory_upgrade_unaffordable_or_no_options"
							break
					elif not s.continue_button.disabled:
						s.continue_button.pressed.emit()
						await settle()
						if is_instance_valid(s) and ScreenManager.current_scene == s:
							for child in s.get_children():
								if child is CanvasLayer:
									for button in child.find_children("*","Button",true,false):
										if button.text == "Continue": button.pressed.emit()
					else:
						outcome = "rewards_continue_disabled"
						break
				"encounter":
					if s.encounter_data and not s.encounter_data.choices.is_empty():
						s._on_choice_pressed(s.encounter_data.choices[0])
					else: s._on_fallback_continue()
				"shop": s._on_leave_pressed()
				"game_over":
					outcome = "death"
					break
				"victory":
					outcome = "victory"
					break
				_:
					outcome = "unexpected_screen:" + screen
					break
		var report = {"trial":trial,"outcome":outcome,"act":MapManager.act,"row":MapManager.node_position,"hp":ResourceManager.current_hp,"actions":actions,"transitions":transitions,"deck":RunState.deck.size()}
		reports.append(report)
		print("FLOW RESULT ",JSON.stringify(report))
	var f = FileAccess.open("res://assessment/2026-09-10/logs/run-flow.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(reports,"  "))
	f.close()
	policy.free()
	get_tree().quit()
