extends Node
## Scene construction/layout probe. Optional --capture=<absolute.png> on a rendering display.

func _ready() -> void:
	call_deferred("probe")

func probe() -> void:
	for i in range(5):
		await get_tree().process_frame
	get_tree().root.size = Vector2i(1920, 1080) if "--large" in OS.get_cmdline_user_args() else Vector2i(1600, 900)
	if "--small" in OS.get_cmdline_user_args():
		get_tree().root.size = Vector2i(1280, 720)
	if "--menu" in OS.get_cmdline_user_args():
		var menu = load("res://scenes/screens/Main.tscn").instantiate()
		add_child(menu)
		for i in range(15):
			await get_tree().process_frame
		var label = menu.get_node("VersionLabel")
		var version_ok: bool = label.text.ends_with("v" + str(ProjectSettings.get_setting("application/config/version"))) and label.global_position.x > get_viewport().get_visible_rect().size.x * 0.6 and get_viewport().get_visible_rect().encloses(label.get_global_rect())
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture="):
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
		print("--- menu version: ", version_ok, " ---")
		get_tree().quit(0 if version_ok else 1)
		return
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
	if "--boss" in OS.get_cmdline_user_args():
		SaveManager.combat_checkpoint = {"encounter": {"enemies": [{"enemy_id": "boss_act1", "count": 1}]}}
	ScreenManager.go_to_combat()
	RunState.deck_model.hand.clear()
	for card_id in ["hex", "dark_pact", "deadly_strike", "defend_1", "iron_tide", "pursuit", "strike_1", "shadow_step"]:
		var definition := DataRegistry.get_card_data(card_id)
		if definition == null:
			push_error("Missing probe card: " + card_id)
			get_tree().quit(1)
			return
		var card := DeckCardData.new(card_id, definition.owner_character_id)
		RunState.deck[card.instance_id] = card
		RunState.deck_model.hand.append(card.instance_id)
	RunState.hand_changed.emit()
	for i in range(40):
		await get_tree().process_frame
	var screen = ScreenManager.current_scene
	if "--boss" in OS.get_cmdline_user_args():
		screen.get_node("CombatBackground").texture = load("res://art/backgrounds/boss_courtyard_v2.png")
	if "--guide" in OS.get_cmdline_user_args():
		screen.combat_guide.show_guide()
		for i in range(5):
			await get_tree().process_frame
	var areas := {}
	areas["hand"] = str(screen.hand_container.get_global_rect())
	areas["enemies"] = str(screen.enemy_slots.get_global_rect())
	areas["bottom"] = str(screen.get_node("BottomUI").get_global_rect())
	for card in screen.card_ui_instances:
		areas[card.deck_card_data.card_id] = {"rect": str(card.get_global_rect()), "owner": str(card.card_widget.owner_label.get_global_rect())}
	print("LAYOUT ", JSON.stringify(areas))
	var failed := 0
	if screen.get_node("CombatGuideButton").global_position.y > 160:
		failed += 1
	for sprite in screen.presentation.party_art.get_children():
		if absf(sprite.get_global_rect().end.y - screen.size.y * 0.68) > 2:
			failed += 1
	if screen.card_ui_instances.size() != 8:
		failed += 1
	var previous_left := -1000.0
	for card in screen.card_ui_instances:
		var bounds: Rect2 = card.get_global_rect()
		if bounds.position.x - previous_left < 60 or bounds.position.x < 0 or bounds.end.x > get_viewport().get_visible_rect().size.x:
			failed += 1
		previous_left = bounds.position.x
		if bounds.position.y < get_viewport().get_visible_rect().size.y * 0.70:
			failed += 1
	if screen.enemy_slots.get_global_rect().intersects(screen.hand_container.get_global_rect()):
		failed += 1
	var first_card = screen.card_ui_instances[0]
	screen._update_hand()
	for i in range(5):
		await get_tree().process_frame
	if screen.card_ui_instances[0] != first_card:
		failed += 1
	if "--hover" in OS.get_cmdline_user_args():
		var hovered = screen.card_ui_instances[-1]
		hovered._on_mouse_entered()
		await get_tree().create_timer(0.25).timeout
		if not get_viewport().get_visible_rect().encloses(hovered.reading_card.get_global_rect()):
			failed += 1
		for label in hovered.reading_card.stats_container.get_children():
			if label is Label and not label.is_queued_for_deletion():
				if label.get_theme_font_size("font_size") < 14 or not hovered.reading_card.get_global_rect().encloses(label.get_global_rect()):
					failed += 1
		hovered.reading_pinned = true
		hovered._on_mouse_exited()
		if not is_instance_valid(hovered.reading_card):
			failed += 1
	if "--interaction" in OS.get_cmdline_user_args():
		screen.combat_guide.hide()
		var cc = screen.combat_controller
		cc.enemies[0].time_current = 100
		var target = screen.enemy_displays[0]
		var card = screen.card_ui_instances[0]
		var iid: String = card.deck_card_data.instance_id
		cc.current_energy = 99
		card._start_drag(card.global_position + card.size * 0.5)
		card._update_drag(target.get_global_rect().get_center())
		cc.current_energy = 0
		card._end_drag(target.get_global_rect().get_center())
		await get_tree().create_timer(0.3).timeout
		if not card.visible or not RunState.deck_model.hand.has(iid):
			failed += 1
		cc.current_energy = 99
		card._start_drag(card.global_position + card.size * 0.5)
		card._update_drag(target.get_global_rect().get_center())
		card._end_drag(target.get_global_rect().get_center())
		if RunState.deck_model.hand.has(iid):
			failed += 1
		await get_tree().create_timer(1.0).timeout
		if screen.get_node_or_null("PlayedCardMotion") != null:
			failed += 1
	print("--- combat_layout: %d layout failures ---" % failed)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	get_tree().quit(1 if failed else 0)
