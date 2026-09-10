extends Node
## Headless coverage for the card-portrait / owner-accent plumbing added to
## CardWidget (Job: at-a-glance owner identification in a 3-character party).
## Verifies CardWidget.resolve_card_art_path's fallback order (bespoke
## art_path -> owner portrait -> none), that every one of the six Early
## Access characters resolves to a distinct accent color, and that every art
## path this system actually resolves to exists on disk.
##
## Run: ../Godot_v4.5-stable_linux.x86_64 --headless --path . res://tests/card_art.tscn

var fail_count := 0
var pass_count := 0

const EA_CHARACTER_IDS := ["golemancer", "grove", "living_armor", "warrior_1", "warrior_2", "witch"]

func _check(label: String, ok: bool) -> void:
	if ok:
		pass_count += 1
		print("PASS: ", label)
	else:
		fail_count += 1
		print("FAIL: ", label)

func _ready() -> void:
	print("=== card_art test ===")
	_test_bespoke_art_path_wins()
	_test_owned_card_falls_back_to_owner_portrait()
	_test_unowned_card_has_no_art()
	_test_owner_without_portrait_has_no_art()
	_test_six_characters_have_distinct_accent_colors()
	_test_all_resolved_art_paths_exist_on_disk()
	print("--- card_art summary: %d passed, %d failed ---" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)

func _test_bespoke_art_path_wins() -> void:
	# A card with art_path set (and present on disk) must use it, even though
	# it also has an owner whose portrait exists -- bespoke art always wins.
	var card_data = CardData.new()
	card_data.owner_character_id = "witch"
	card_data.art_path = "res://Path-of-Embers/Art Assets/Card Assets/card_frame_curse.png"
	_check("art_path is set and exists on disk (test precondition)",
		ResourceLoader.exists(card_data.art_path))
	var resolved = CardWidget.resolve_card_art_path(card_data)
	_check("bespoke art_path is used over the owner's portrait",
		resolved == card_data.art_path)

func _test_owned_card_falls_back_to_owner_portrait() -> void:
	# hex.tres is owned by the Witch and has no art_path of its own.
	var card_data = DataRegistry.get_card_data("hex")
	_check("hex card data loaded", card_data != null)
	if not card_data:
		return
	_check("hex has no bespoke art_path (test precondition)", card_data.art_path == "")
	_check("hex is owned by the witch (test precondition)", card_data.owner_character_id == "witch")

	var witch_data = DataRegistry.get_character("witch")
	_check("witch character data loaded", witch_data != null)
	if not witch_data:
		return

	var resolved = CardWidget.resolve_card_art_path(card_data)
	_check("owned card with no art_path falls back to the owner's portrait",
		resolved == witch_data.portrait_path)
	_check("the resolved fallback path is non-empty", resolved != "")

func _test_unowned_card_has_no_art() -> void:
	# strike_1 is a generic card with no owner_character_id.
	var card_data = DataRegistry.get_card_data("strike_1")
	_check("strike_1 card data loaded", card_data != null)
	if not card_data:
		return
	_check("strike_1 has no owner (test precondition)", card_data.owner_character_id == "")
	var resolved = CardWidget.resolve_card_art_path(card_data)
	_check("unowned card resolves to no art (default type-icon treatment)", resolved == "")

func _test_owner_without_portrait_has_no_art() -> void:
	# A synthetic owner id that isn't one of the six EA characters (no
	# portrait_path registered) must not crash and must resolve to no art.
	var card_data = CardData.new()
	card_data.owner_character_id = "nonexistent_character_xyz"
	var resolved = CardWidget.resolve_card_art_path(card_data)
	_check("unknown/portrait-less owner resolves to no art, not a crash", resolved == "")

func _test_six_characters_have_distinct_accent_colors() -> void:
	var seen: Dictionary = {}
	for char_id in EA_CHARACTER_IDS:
		var color = CardWidget.get_owner_accent_color(char_id)
		var key = color.to_html(false)
		_check("%s has an accent color distinct from every other EA character so far" % char_id,
			not seen.has(key))
		seen[key] = char_id
	_check("all six EA characters resolved to distinct accent colors", seen.size() == 6)

	# Colorblind-safety: no two colors may differ only by a red/green swap --
	# approximate this by requiring every pair's blue channel to differ
	# meaningfully OR their perceptual (luma) distance to be non-trivial, so
	# no pair relies on red-vs-green alone.
	var colors: Array = []
	for char_id in EA_CHARACTER_IDS:
		colors.append(CardWidget.get_owner_accent_color(char_id))
	var all_distinguishable := true
	for i in range(colors.size()):
		for j in range(i + 1, colors.size()):
			var a: Color = colors[i]
			var b: Color = colors[j]
			var red_green_only = absf(a.r - b.r) > 0.15 and absf(a.g - b.g) > 0.15 \
				and absf(a.b - b.b) < 0.05
			if red_green_only:
				all_distinguishable = false
	_check("no two owner accent colors differ only by red vs. green", all_distinguishable)

func _test_all_resolved_art_paths_exist_on_disk() -> void:
	# Every EA character's portrait_path (the only art this system currently
	# resolves to, since no CardData.art_path is populated yet) must exist.
	for char_id in EA_CHARACTER_IDS:
		var char_data = DataRegistry.get_character(char_id)
		_check("%s character data loaded" % char_id, char_data != null)
		if not char_data:
			continue
		_check("%s.portrait_path is set" % char_id, char_data.portrait_path != "")
		_check("%s.portrait_path exists on disk: %s" % [char_id, char_data.portrait_path],
			ResourceLoader.exists(char_data.portrait_path))
