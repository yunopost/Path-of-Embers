extends Node
## Not a pass/fail test -- a manual render-proof harness for the card
## portrait/owner-accent work. Builds a small hand of CardWidgets spanning
## several owners (plus one generic card) and screenshots the result to
## /home/claude/poe/out/card-frames-proof.png for visual verification.
##
## Run windowed (NOT --headless) under a virtual display, e.g.:
##   xvfb-run -a Godot --path . res://tests/card_art_render.tscn

func _ready() -> void:
	get_viewport().transparent_bg = false
	get_tree().root.size = Vector2i(1400, 420)

	var bg = ColorRect.new()
	bg.color = Color("#1c1c1c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.position = Vector2(16, 16)
	add_child(hbox)

	PartyManager.party_ids = ["warrior_1", "witch", "golemancer"]
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)

	# One card per owner (witch/hex, warrior_1/rend or a starter, golemancer/
	# construct_punch) plus one generic unowned card (strike_1), so the
	# screenshot shows every accent color and the default treatment side by
	# side.
	var card_ids_wanted = ["hex", "construct_punch", "strike_1", "defend_1"]
	var shown := {}
	for iid in RunState.deck_order:
		var dc: DeckCardData = RunState.deck.get(iid)
		if not dc:
			continue
		if dc.card_id in card_ids_wanted and not shown.has(dc.card_id):
			shown[dc.card_id] = true
			var widget = CardWidget.new()
			widget.custom_minimum_size = Vector2(210, 280)
			hbox.add_child(widget)
			widget.setup_card(dc)

	# Also show a warrior_1-owned card explicitly if one exists in the deck,
	# to get all three party accent colors on screen (construct_punch is
	# golemancer's signature; find a warrior_1 card too).
	for iid in RunState.deck_order:
		var dc: DeckCardData = RunState.deck.get(iid)
		if dc and dc.owner_character_id == "warrior_1" and not shown.has(dc.card_id):
			shown[dc.card_id] = true
			var widget2 = CardWidget.new()
			widget2.custom_minimum_size = Vector2(210, 280)
			hbox.add_child(widget2)
			widget2.setup_card(dc)
			break

	# Let layout + texture imports settle over a few frames before capturing.
	for i in range(10):
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var out_dir := "/home/claude/poe/out"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var err := img.save_png(out_dir + "/card-frames-proof.png")
	print("save_png result: ", err)
	await get_tree().process_frame
	get_tree().quit(0 if err == OK else 1)
