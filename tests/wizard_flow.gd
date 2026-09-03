extends Node
## Headless check: Loadout "NEXT: QUESTS" -> QuestSelectScreen -> BEGIN RUN -> map.
func _ready():
	PartyManager.party_ids = ["warrior_1", "witch", "golemancer"]
	# Give ScreenManager a throwaway current_scene so it does not free this test node
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	ScreenManager.current_scene = dummy
	await get_tree().process_frame
	ScreenManager.go_to_loadout()
	await get_tree().process_frame
	await get_tree().process_frame
	var loadout = ScreenManager.current_scene
	print("screen=", ScreenManager.current_screen, " scene=", loadout)
	if loadout and loadout.start_btn:
		print("start_btn text=", loadout.start_btn.text, " disabled=", loadout.start_btn.disabled)
		print("stash=", RunState.run_stash)
		for pair in [["iron_helm","HELMET"],["chain_mail","CHEST"],["swift_boots","BOOTS"]]:
			if RunState.run_stash.has(pair[0]):
				loadout._on_stash_item_clicked(pair[0])
				loadout._on_slot_clicked("warrior_1", pair[1])
		print("equipped=", RunState.equipment_slots)
		loadout.start_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	print("after NEXT: screen=", ScreenManager.current_screen, " scene=", ScreenManager.current_scene)
	var qs = ScreenManager.current_scene
	if qs and "_begin_btn" in qs and qs._begin_btn:
		print("begin_btn text=", qs._begin_btn.text, " disabled=", qs._begin_btn.disabled)
		qs._begin_btn.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		print("after BEGIN: screen=", ScreenManager.current_screen, " quests=", QuestManager.quests.keys())
	get_tree().quit()
