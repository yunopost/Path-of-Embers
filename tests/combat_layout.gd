extends Node
## Scene construction/layout probe. Optional --capture=<absolute.png> on a rendering display.

func _ready() -> void:
	call_deferred("probe")

func probe() -> void:
	for i in range(5):
		await get_tree().process_frame
	get_tree().root.size = Vector2i(1920, 1080) if "--large" in OS.get_cmdline_user_args() else Vector2i(1600, 900)
	RunState.reset_run()
	PartyManager.set_party(["warrior_1", "witch", "living_armor"])
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)
	QuestManager.initialize_quests(chars)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	ScreenManager.current_scene = dummy
	ScreenManager.go_to_combat()
	RunState.deck_model.hand.clear()
	for card_id in ["hex", "dark_pact", "overclocked", "deadfall", "iron_tide", "pursuit", "resonant_guard", "calibrate"]:
		var card := DeckCardData.new(card_id, DataRegistry.get_card_data(card_id).owner_character_id)
		RunState.deck[card.instance_id] = card
		RunState.deck_model.hand.append(card.instance_id)
	RunState.hand_changed.emit()
	for i in range(40):
		await get_tree().process_frame
	var screen = ScreenManager.current_scene
	var areas := {}
	areas["hand"] = str(screen.hand_container.get_global_rect())
	areas["enemies"] = str(screen.enemy_slots.get_global_rect())
	areas["bottom"] = str(screen.get_node("BottomUI").get_global_rect())
	for card in screen.card_ui_instances:
		areas[card.deck_card_data.card_id] = {"rect": str(card.get_global_rect()), "owner": str(card.card_widget.owner_label.get_global_rect())}
	print("LAYOUT ", JSON.stringify(areas))
	var failed := 0
	var previous_right := 0.0
	for card in screen.card_ui_instances:
		var bounds: Rect2 = card.get_global_rect()
		if bounds.position.x < previous_right or not get_viewport().get_visible_rect().encloses(bounds):
			failed += 1
		previous_right = bounds.end.x
		if not bounds.encloses(card.card_widget.owner_label.get_global_rect()):
			failed += 1
	if screen.enemy_slots.get_global_rect().intersects(screen.hand_container.get_global_rect()):
		failed += 1
	print("--- combat_layout: %d layout failures ---" % failed)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	get_tree().quit(1 if failed else 0)
