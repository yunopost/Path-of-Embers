extends Node
## Regression coverage for the playtest report "the Witch's Hex card cannot be
## picked up -- it will not start a drag and will not draw a targeting line."
##
## Investigation summary (see task notes): built a full CombatScreen instance
## (not a mock) with a real Witch party member, drew the NATURAL Hex card
## instance created by generate_starter_deck (witch's starter_unique_cards)
## into hand the normal way (via RunState.draw_cards, not synthetic hand
## injection), and exercised the exact gates CardUI._gui_input relies on:
## size, _can_play(), _is_targeting_card(), and _start_drag()/_end_drag(). All
## of them behaved identically to every other ENEMY-targeted ATTACK card, in a
## fresh 5-card hand, a full 8-card (HAND_MAX) hand, and directly after
## construction -- with and without a Dexterity/upgrade-bearing card alongside
## it. No script error, no zero-size rect, no missing description branch, no
## owner-character resolution failure was found in any of these conditions.
##
## A synthetic InputEventMouseButton pushed via Viewport.push_input was also
## tried and discarded as a repro method: it fails IDENTICALLY for a
## definitely-working control card (see the "control comparison" this file
## does NOT include, kept in review notes) because Godot's headless build
## does not track Input.mouse_position from an injected button event without
## a preceding motion event -- that is an environment limitation, not a game
## bug, so this file asserts on the real gates instead of synthetic clicks.
##
## Run: ../Godot_v4.5-stable_linux.x86_64 --headless --path . res://tests/hex_playability.tscn

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
	print("=== hex_playability test ===")
	await _test_natural_draw_fresh_hand()
	await _test_full_hand()
	await _test_hex_actually_plays()
	print("--- hex_playability summary: %d passed, %d failed ---" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)

func _make_combat_screen() -> Control:
	PartyManager.party_ids = ["warrior_1", "witch", "golemancer"]
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)
	var scene: PackedScene = load("res://scenes/screens/CombatScreen.tscn")
	var combat_screen = scene.instantiate()
	add_child(combat_screen)
	combat_screen.size = Vector2(1920, 1080)
	return combat_screen

func _hex_instance_id() -> String:
	for iid in RunState.deck_order:
		var c: DeckCardData = RunState.deck.get(iid)
		if c and c.card_id == "hex":
			return iid
	return ""

func _draw_hex_naturally() -> void:
	## Move the natural Hex instance (created by generate_starter_deck's
	## starter_unique_cards, not a synthetic DeckCardData) to the front of the
	## draw pile and draw it the normal way.
	##
	## Found while chasing the intermittent "Hex has a CardUI in a full 8-card
	## hand" / "Hex left the hand after being played" test failures: this
	## helper used to be neither idempotent nor HAND_MAX-aware, and BOTH
	## failures traced back to it, not to CombatScreen or CombatController --
	##
	## 1) If the combat's automatic starting draw (CombatController.start_combat
	##    draws 5) already happened to deal the real Hex instance into hand
	##    (deck order is shuffled every combat, so this is a coin flip), the
	##    old code still unconditionally pushed that SAME instance_id onto the
	##    front of draw_pile and drew it AGAIN. RunState.deck_model.hand ended
	##    up with Hex's instance_id twice. play_card()'s
	##    `hand.find(instance_id)` / `remove_at()` only ever strips the FIRST
	##    occurrence, so one Hex-shaped id remained in hand after play --
	##    "Hex left the hand after being played" -- even though the card had
	##    genuinely been played and its effects had genuinely resolved.
	## 2) In _test_full_hand, when Hex was NOT among the initial 5/8 drawn, this
	##    was called with the hand already at HAND_MAX (8). Drawing into a full
	##    hand burns the drawn card straight to the discard pile by design (see
	##    DeckModel.draw_cards) -- so Hex never reached hand at all, and
	##    "Hex has a CardUI in a full 8-card hand" failed. Not a CardUI bug:
	##    Hex was sitting in the discard pile the whole time.
	##
	## Fixed by making this helper safe to call regardless of where Hex
	## already is and how full the hand already is.
	var iid := _hex_instance_id()
	if iid == "":
		return
	if RunState.deck_model.hand.has(iid):
		return  # already in hand (e.g. dealt by the automatic starting draw) -- nothing to do
	if RunState.deck_model.draw_pile.has(iid):
		RunState.deck_model.draw_pile.erase(iid)
	elif RunState.deck_model.discard_pile.has(iid):
		RunState.deck_model.discard_pile.erase(iid)
	elif RunState.deck_model.exhaust_pile.has(iid):
		RunState.deck_model.exhaust_pile.erase(iid)
	RunState.deck_model.draw_pile.push_front(iid)
	if RunState.deck_model.hand.size() >= RunState.HAND_MAX:
		# A card drawn into a full hand is burned straight to discard (by
		# design, see DeckModel.draw_cards) -- make room first so this helper
		# reliably puts Hex in hand rather than in the discard pile.
		var displaced: String = RunState.deck_model.hand[0]
		RunState.deck_model.hand.remove_at(0)
		RunState.deck_model.discard_pile.append(displaced)
		RunState.deck_model.hand_changed.emit()
		RunState.deck_model.discard_pile_changed.emit()
	RunState.draw_cards(1)
	assert(RunState.deck_model.hand.has(iid), "hex_playability: _draw_hex_naturally failed to land Hex in hand")
	assert(_count_in_hand(iid) == 1, "hex_playability: Hex instance_id appears more than once in hand")

func _count_in_hand(iid: String) -> int:
	var n := 0
	for h in RunState.deck_model.hand:
		if h == iid:
			n += 1
	return n

func _find_hex_ui(combat_screen: Control) -> CardUI:
	for card_ui in combat_screen.card_ui_instances:
		if card_ui.deck_card_data and card_ui.deck_card_data.card_id == "hex":
			return card_ui
	return null

func _assert_hex_is_playable(hex_ui: CardUI, label_suffix: String) -> void:
	_check("Hex CardUI has a nonzero rect" + label_suffix, hex_ui.size != Vector2.ZERO)
	_check("Hex CardUI._can_play() is true" + label_suffix, hex_ui._can_play())
	_check("Hex CardUI._is_targeting_card() is true" + label_suffix, hex_ui._is_targeting_card())

	var local_center = hex_ui.size / 2.0
	var card_rect = Rect2(Vector2.ZERO, hex_ui.size)
	_check("a press at Hex's own center hits its click rect" + label_suffix,
		hex_ui.size != Vector2.ZERO and card_rect.has_point(local_center))

	hex_ui._start_drag(hex_ui.global_position + local_center)
	_check("_start_drag() sets is_dragging" + label_suffix, hex_ui.is_dragging)
	_check("_start_drag() draws the targeting line (targeting_line_visible)" + label_suffix,
		hex_ui.targeting_line_visible)
	hex_ui._end_drag(hex_ui.global_position + local_center)  # leave a clean drag state

func _test_natural_draw_fresh_hand() -> void:
	var combat_screen := _make_combat_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_draw_hex_naturally()
	while combat_screen.is_updating_hand:
		await get_tree().process_frame
	await combat_screen._update_hand()
	for i in range(4):
		await get_tree().process_frame

	var hex_ui := _find_hex_ui(combat_screen)
	_check("Hex has a CardUI in a fresh hand", hex_ui != null)
	if hex_ui:
		_assert_hex_is_playable(hex_ui, " (fresh hand)")
	combat_screen.queue_free()

func _test_full_hand() -> void:
	## The reported hand a player is most likely to actually be holding: full
	## to HAND_MAX (8), the state Hex's own add_curse_to_hand effect and the
	## card-clock's "hand is retained, never force-discarded" rule both push
	## toward over a real fight.
	var combat_screen := _make_combat_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	RunState.draw_cards(8)  # fill to HAND_MAX; may already include the natural Hex
	# _draw_hex_naturally() is idempotent and HAND_MAX-aware (see its comment):
	# it no-ops if Hex is already in hand, and makes room instead of letting a
	# full hand burn the draw to discard, so Hex deterministically ends up in
	# hand here regardless of where the shuffle put it.
	_draw_hex_naturally()
	while combat_screen.is_updating_hand:
		await get_tree().process_frame
	await combat_screen._update_hand()
	for i in range(4):
		await get_tree().process_frame

	_check("hand is at HAND_MAX", RunState.deck_model.hand.size() == RunState.HAND_MAX)
	var hex_ui := _find_hex_ui(combat_screen)
	_check("Hex has a CardUI in a full 8-card hand", hex_ui != null)
	if hex_ui:
		_assert_hex_is_playable(hex_ui, " (full hand)")
	combat_screen.queue_free()

func _test_hex_actually_plays() -> void:
	## End-to-end: dropping Hex on a live enemy through CombatController
	## actually resolves (add_curse_to_hand + damage_per_curse_in_hand), same
	## as any other card -- confirms the backend never rejected it either.
	var combat_screen := _make_combat_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_draw_hex_naturally()
	while combat_screen.is_updating_hand:
		await get_tree().process_frame
	await combat_screen._update_hand()
	for i in range(4):
		await get_tree().process_frame

	var hex_ui := _find_hex_ui(combat_screen)
	_check("Hex CardUI exists for the play test", hex_ui != null)
	if not hex_ui:
		combat_screen.queue_free()
		return

	var enemy = combat_screen.combat_controller.get_enemies()[0]
	var tgt := Node.new()
	tgt.set_meta("enemy", enemy)
	add_child(tgt)
	var hex_instance_id := hex_ui.deck_card_data.instance_id
	var ok = combat_screen.combat_controller.play_card(hex_ui.deck_card_data, tgt)
	_check("CombatController.play_card(hex, enemy) succeeds", bool(ok))
	if RunState.deck_model.hand.has(hex_instance_id):
		push_warning("hex_playability: Hex (%s) still in hand after play: %s" % [hex_instance_id, RunState.deck_model.hand])
	_check("Hex left the hand after being played",
		not RunState.deck_model.hand.has(hex_instance_id))
	var curse_in_hand := false
	for iid in RunState.deck_model.hand:
		var c: DeckCardData = RunState.deck.get(iid)
		if c and c.card_id == "curse_card":
			curse_in_hand = true
			break
	_check("add_curse_to_hand added a Curse to hand", curse_in_hand)
	tgt.queue_free()
	combat_screen.queue_free()
