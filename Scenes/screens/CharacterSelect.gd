extends Control

## Character selection screen - allows selection of exactly 3 characters

var selection_count_label: Label = null
var character_grid: GridContainer = null
var confirm_button: Button = null
var party_summary_label: Label = null

var available_characters: Array[CharacterData] = []
var selected_character_ids: Array[String] = []
var character_entries: Dictionary = {}  # Maps character_id to entry dict

# Font cache - loaded once, reused for all cards
var _font_extrabold: Font = null
var _font_bold: Font = null
var _font_regular: Font = null

const CARD_TYPE_COLORS := {
	0: Color("#A03020"),  # ATTACK - red-orange
	1: Color("#2060A0"),  # SKILL - blue
	2: Color("#806020"),  # POWER - gold
	3: Color("#602080"),  # CURSE - purple
}

const CARD_TYPE_NAMES := ["ATK", "SKL", "PWR", "CRS"]

const ROLE_COLORS := {
	"warrior": Color(0.65, 0.20, 0.15),
	"defender": Color(0.20, 0.38, 0.65),
	"healer": Color(0.18, 0.62, 0.40),
	"mage": Color(0.55, 0.18, 0.75),
	"rogue": Color(0.65, 0.55, 0.15),
	"ranger": Color(0.25, 0.55, 0.28),
}

func _get_font(variant: String) -> Font:
	## Lazy-load Cinzel fonts; returns null gracefully if file is missing.
	match variant:
		"extrabold":
			if not _font_extrabold:
				_font_extrabold = load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-ExtraBold.ttf")
			return _font_extrabold
		"bold":
			if not _font_bold:
				_font_bold = load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-Bold.ttf")
			return _font_bold
		_:
			if not _font_regular:
				_font_regular = load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-Regular.ttf")
			return _font_regular

func _ready():
	# Wait one frame to ensure nodes are ready
	await get_tree().process_frame

	# Get node references safely
	selection_count_label = get_node_or_null("VBoxContainer/SelectionCountLabel")
	character_grid = get_node_or_null("VBoxContainer/ScrollContainer/CharacterGrid")
	confirm_button = get_node_or_null("VBoxContainer/ConfirmButton")
	party_summary_label = get_node_or_null("VBoxContainer/PartySummaryLabel")

	# Style static UI elements
	_setup_screen_header()
	_style_confirm_button()

	# Connect confirm button (with safety check)
	if is_instance_valid(confirm_button):
		if not confirm_button.pressed.is_connected(_on_confirm_pressed):
			confirm_button.pressed.connect(_on_confirm_pressed)
		confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP

	# Initialize screen (architecture rule 2.1)
	initialize()

	# Ensure scene is visible
	visible = true

	# Force a redraw
	call_deferred("_ensure_visible")

	# Keep the game running
	get_tree().paused = false
	set_process(true)
	set_physics_process(false)

func initialize():
	## Initialize the screen with current state
	## Must be called after instantiation, before use (architecture rule 2.1)
	refresh_from_state()

func refresh_from_state():
	## Refresh UI from RunState (architecture rule 11.2)
	_create_placeholder_characters()
	_populate_character_grid()
	_update_ui()

func _ensure_visible():
	## Ensure all UI elements are visible and properly sized
	if is_instance_valid(character_grid):
		character_grid.visible = true
		character_grid.show()
		for i in range(character_grid.get_child_count()):
			var child = character_grid.get_child(i)
			if is_instance_valid(child):
				child.visible = true
				child.show()

	if is_instance_valid(self):
		visible = true
		show()

func _create_placeholder_characters():
	## Populate available_characters from DataRegistry.
	available_characters.clear()
	if DataRegistry:
		available_characters = DataRegistry.get_all_characters()

func _populate_character_grid():
	## Create character entry cards for each available character
	if not is_instance_valid(character_grid):
		push_error("CharacterSelect: character_grid is null!")
		return

	for char_data in available_characters:
		if not char_data:
			push_warning("CharacterSelect: null char_data in available_characters")
			continue

		var entry = _create_character_entry(char_data)
		character_grid.add_child(entry["root"])
		character_entries[char_data.id] = entry
		entry["root"].set_owner(character_grid)

func _is_character_locked(char_id: String) -> bool:
	## Returns true if this character has not been unlocked yet.
	if not MilestoneManager:
		return false
	return not MilestoneManager.is_unlocked("character", char_id)

# ─────────────────────────────────────────────────────────────────────────────
# Card creation
# ─────────────────────────────────────────────────────────────────────────────

func _create_character_entry(char_data: CharacterData) -> Dictionary:
	## Build a styled PanelContainer card for one character.
	## Returns a dict with "root", "panel", "normal_style", "selected_style".

	var locked: bool = _is_character_locked(char_data.id)

	# ── StyleBoxes ──────────────────────────────────────────────────────────
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#1A1F2BEE")
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color("#4A5060")
	normal_style.set_corner_radius_all(6)
	normal_style.content_margin_left = 8
	normal_style.content_margin_right = 8
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8

	var selected_style: StyleBoxFlat = normal_style.duplicate()
	selected_style.border_color = Color("#E8A020")
	selected_style.set_border_width_all(3)
	selected_style.shadow_color = Color(0.91, 0.63, 0.13, 0.3)
	selected_style.shadow_size = 6

	# ── Root PanelContainer ──────────────────────────────────────────────────
	var panel := PanelContainer.new()
	panel.name = "Entry_" + char_data.id
	panel.custom_minimum_size = Vector2(560, 240)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", normal_style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if not locked:
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton \
					and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				_on_character_selected(char_data.id)
		)

	# ── Inner VBoxContainer ──────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vbox)

	# ── Nameplate ────────────────────────────────────────────────────────────
	var nameplate_text: String = char_data.display_name.to_upper()
	if locked:
		nameplate_text = "🔒  " + nameplate_text

	var nameplate := Label.new()
	nameplate.text = nameplate_text
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.mouse_filter = Control.MOUSE_FILTER_PASS
	var eb_font = _get_font("extrabold")
	if eb_font:
		nameplate.add_theme_font_override("font", eb_font)
	nameplate.add_theme_font_size_override("font_size", 18)
	nameplate.add_theme_color_override("font_color",
		Color("#A08040") if locked else Color("#E8A020"))
	var np_bg := StyleBoxFlat.new()
	np_bg.bg_color = Color("#0A0D14CC")
	np_bg.content_margin_left = 4
	np_bg.content_margin_right = 4
	np_bg.content_margin_top = 4
	np_bg.content_margin_bottom = 4
	nameplate.add_theme_stylebox_override("normal", np_bg)
	vbox.add_child(nameplate)

	# ── Body: portrait left │ signature cards right ──────────────────────────
	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 10)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(body_hbox)

	# Portrait
	var portrait := _load_portrait_for(char_data)
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	body_hbox.add_child(portrait)

	# Signature cards column
	var cards_vbox := VBoxContainer.new()
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 4)
	cards_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	body_hbox.add_child(cards_vbox)

	var cards_header := Label.new()
	cards_header.text = "SIGNATURE CARDS"
	cards_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_header.mouse_filter = Control.MOUSE_FILTER_PASS
	var reg_font = _get_font("regular")
	if reg_font:
		cards_header.add_theme_font_override("font", reg_font)
	cards_header.add_theme_font_size_override("font_size", 11)
	cards_header.add_theme_color_override("font_color", Color(0.77, 0.51, 0.10, 0.6))
	cards_vbox.add_child(cards_header)

	var cards_hbox := HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 6)
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	cards_vbox.add_child(cards_hbox)

	var sig_cards: Array = char_data.starter_unique_cards
	for i in range(min(2, sig_cards.size())):
		var mini := _create_card_miniature(sig_cards[i])
		mini.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards_hbox.add_child(mini)
	# Fill empty slots so layout is consistent
	for _i in range(sig_cards.size(), 2):
		var empty := PanelContainer.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.mouse_filter = Control.MOUSE_FILTER_PASS
		var empty_style := StyleBoxFlat.new()
		empty_style.bg_color = Color("#12161E88")
		empty_style.set_border_width_all(1)
		empty_style.border_color = Color("#3A3F4A")
		empty_style.set_corner_radius_all(4)
		empty.add_theme_stylebox_override("panel", empty_style)
		cards_hbox.add_child(empty)

	# ── Themes row ────────────────────────────────────────────────────────────
	var t1: String = char_data.theme_1
	var t2: String = char_data.theme_2
	var themes_text := ""
	if not t1.is_empty() and not t2.is_empty():
		themes_text = "◆ %s   ◆ %s" % [t1, t2]
	elif not t1.is_empty():
		themes_text = "◆ %s" % t1
	elif not t2.is_empty():
		themes_text = "◆ %s" % t2

	if not themes_text.is_empty():
		var themes_label := Label.new()
		themes_label.text = themes_text
		themes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		themes_label.mouse_filter = Control.MOUSE_FILTER_PASS
		themes_label.add_theme_font_size_override("font_size", 11)
		themes_label.add_theme_color_override("font_color", Color("#8AACCC"))
		vbox.add_child(themes_label)

	# ── Quest row ─────────────────────────────────────────────────────────────
	var quest_text := ""
	if locked:
		var hint := ""
		if DataRegistry:
			for milestone in DataRegistry.get_all_milestones():
				if milestone.unlock_type == "character" and milestone.unlock_target == char_data.id:
					hint = milestone.unlock_hint if not milestone.unlock_hint.is_empty() else milestone.description
					break
		quest_text = hint if not hint.is_empty() else "Complete milestones to unlock."
	elif not char_data.quests.is_empty():
		var q = char_data.quests[0]
		quest_text = "Quest: %s" % q.title
		if q.progress_max > 0:
			quest_text += " (×%d)" % q.progress_max
	else:
		quest_text = "Quest: None"

	var quest_label := Label.new()
	quest_label.text = quest_text
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_label.mouse_filter = Control.MOUSE_FILTER_PASS
	quest_label.add_theme_font_size_override("font_size", 11)
	quest_label.add_theme_color_override("font_color",
		Color("#707060") if locked else Color("#A09070"))
	vbox.add_child(quest_label)

	# Dim locked cards
	if locked:
		panel.modulate = Color(0.6, 0.6, 0.6, 0.85)

	return {
		"root": panel,
		"panel": panel,
		"normal_style": normal_style,
		"selected_style": selected_style,
	}

func _load_portrait_for(char_data: CharacterData) -> Control:
	## Load portrait TextureRect, or a role-coloured placeholder with initials.
	if not char_data.portrait_path.is_empty():
		var tex = load(char_data.portrait_path)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.custom_minimum_size = Vector2(160, 140)
			tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
			return tr

	# Placeholder
	var placeholder := ColorRect.new()
	var role_key: String = char_data.role.to_lower()
	placeholder.color = ROLE_COLORS.get(role_key, Color(0.25, 0.28, 0.38))
	placeholder.custom_minimum_size = Vector2(160, 140)
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var initials := Label.new()
	initials.text = char_data.display_name.substr(0, 2).to_upper()
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", 40)
	initials.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	var eb_font = _get_font("extrabold")
	if eb_font:
		initials.add_theme_font_override("font", eb_font)
	initials.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.add_child(initials)

	return placeholder

func _create_card_miniature(card: CardData) -> PanelContainer:
	## Build a compact card preview panel showing name, type/cost, and effects.
	var mini := PanelContainer.new()
	mini.mouse_filter = Control.MOUSE_FILTER_PASS

	var card_type_idx: int = int(card.card_type)
	var type_color: Color = CARD_TYPE_COLORS.get(card_type_idx, Color("#808080"))

	var mini_style := StyleBoxFlat.new()
	mini_style.bg_color = Color("#12161ECC")
	mini_style.set_border_width_all(1)
	mini_style.border_color = Color("#C4821A")
	mini_style.set_corner_radius_all(4)
	mini_style.content_margin_left = 5
	mini_style.content_margin_right = 5
	mini_style.content_margin_top = 5
	mini_style.content_margin_bottom = 5
	mini.add_theme_stylebox_override("panel", mini_style)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 3)
	inner_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	mini.add_child(inner_vbox)

	# Card name
	var name_label := Label.new()
	name_label.text = card.name
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var bold_font = _get_font("bold")
	if bold_font:
		name_label.add_theme_font_override("font", bold_font)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("#F0E6C8"))
	name_label.clip_contents = true
	inner_vbox.add_child(name_label)

	# Type + Cost row
	var type_cost_hbox := HBoxContainer.new()
	type_cost_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	inner_vbox.add_child(type_cost_hbox)

	var type_label := Label.new()
	type_label.text = CARD_TYPE_NAMES[card_type_idx] if card_type_idx < CARD_TYPE_NAMES.size() else "???"
	type_label.mouse_filter = Control.MOUSE_FILTER_PASS
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", type_color)
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_cost_hbox.add_child(type_label)

	var cost_label := Label.new()
	cost_label.text = str(card.cost)
	cost_label.mouse_filter = Control.MOUSE_FILTER_PASS
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Color("#D4A847"))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_cost_hbox.add_child(cost_label)

	# Effect text
	var effect_text := _build_effect_text(card)
	if not effect_text.is_empty():
		var effect_label := Label.new()
		effect_label.text = effect_text
		effect_label.mouse_filter = Control.MOUSE_FILTER_PASS
		effect_label.add_theme_font_size_override("font_size", 10)
		effect_label.add_theme_color_override("font_color", Color("#B0B8C0"))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner_vbox.add_child(effect_label)

	return mini

func _build_effect_text(card: CardData) -> String:
	## Summarise a card's base_effects into a short human-readable string.
	if card.base_effects.is_empty():
		return ""

	var parts: Array[String] = []
	for effect: EffectData in card.base_effects:
		if not effect:
			continue
		var etype: String = effect.effect_type
		var amount: int = int(effect.params.get("amount", 0))
		var text := ""
		match etype:
			"damage":      text = "Deal %d dmg" % amount if amount > 0 else "Deal damage"
			"shield", "block": text = "Gain %d Shield" % amount if amount > 0 else "Gain Shield"
			"heal":        text = "Heal %d HP" % amount if amount > 0 else "Heal HP"
			"vulnerable":  text = "Apply %d Vulnerable" % amount if amount > 0 else "Apply Vulnerable"
			"weak":        text = "Apply %d Weak" % amount if amount > 0 else "Apply Weak"
			"burn":        text = "Apply %d Burn" % amount if amount > 0 else "Apply Burn"
			"bleed":       text = "Apply %d Bleed" % amount if amount > 0 else "Apply Bleed"
			"poison":      text = "Apply %d Poison" % amount if amount > 0 else "Apply Poison"
			"strength":    text = "Gain %d Strength" % amount if amount > 0 else "Gain Strength"
			"draw":        text = "Draw %d" % amount if amount > 0 else "Draw cards"
			"energy":      text = "Gain %d Energy" % amount if amount > 0 else "Gain Energy"
			"exhaust":     text = "Exhaust"
			"retain":      text = "Retain"
			"discard":     text = "Discard %d" % amount if amount > 0 else "Discard"
			"upgrade":     text = "Upgrade %d" % amount if amount > 0 else "Upgrade"
			"curse":       text = "Add Curse"
			"multiply":    text = "×%d damage" % amount if amount > 0 else "Multiply dmg"
			"status":
				var stype: String = effect.params.get("status_type", effect.params.get("type", ""))
				text = "Apply %s" % stype if not stype.is_empty() else "Apply status"
			_:
				if not etype.is_empty():
					text = etype.replace("_", " ").capitalize()
		if not text.is_empty():
			parts.append(text)

	var result: String = " • ".join(parts)
	if result.length() > 60:
		result = result.substr(0, 57) + "…"
	return result

# ─────────────────────────────────────────────────────────────────────────────
# Header / footer styling
# ─────────────────────────────────────────────────────────────────────────────

func _setup_screen_header() -> void:
	var title: Label = get_node_or_null("VBoxContainer/Title")
	if is_instance_valid(title):
		title.text = "SELECT YOUR PARTY"
		var eb_font = _get_font("extrabold")
		if eb_font:
			title.add_theme_font_override("font", eb_font)
		title.add_theme_font_size_override("font_size", 36)
		title.add_theme_color_override("font_color", Color("#E8A020"))
		title.add_theme_constant_override("outline_size", 2)
		title.add_theme_color_override("font_outline_color", Color("#12161E"))

	if is_instance_valid(selection_count_label):
		selection_count_label.add_theme_font_size_override("font_size", 16)
		selection_count_label.add_theme_color_override("font_color", Color("#C0B090"))

func _style_confirm_button() -> void:
	if not is_instance_valid(confirm_button):
		return
	confirm_button.text = "CONFIRM PARTY"
	var bold_font = _get_font("bold")
	if bold_font:
		confirm_button.add_theme_font_override("font", bold_font)
	confirm_button.add_theme_font_size_override("font_size", 28)
	confirm_button.add_theme_color_override("font_color", Color("#F0E6C8"))
	confirm_button.add_theme_color_override("font_hover_color", Color("#D4A847"))
	confirm_button.add_theme_color_override("font_pressed_color", Color("#C4821A"))
	confirm_button.add_theme_color_override("font_disabled_color", Color("#60606A"))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#2A3040E8")
	normal_style.set_border_width_all(4)
	normal_style.border_color = Color("#C4821A")
	normal_style.set_corner_radius_all(4)
	normal_style.content_margin_left = 32
	normal_style.content_margin_right = 32
	normal_style.content_margin_top = 12
	normal_style.content_margin_bottom = 12
	confirm_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color("#4A5566CC")
	hover_style.border_color = Color("#D4A847")
	confirm_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.bg_color = Color("#C4821A33")
	pressed_style.border_color = Color("#F0E6C8")
	confirm_button.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style: StyleBoxFlat = normal_style.duplicate()
	disabled_style.bg_color = Color("#1A1F2B88")
	disabled_style.border_color = Color("#404550")
	confirm_button.add_theme_stylebox_override("disabled", disabled_style)

	confirm_button.add_theme_constant_override("outline_size", 1)
	confirm_button.add_theme_color_override("font_outline_color", Color("#12161E"))

# ─────────────────────────────────────────────────────────────────────────────
# Selection logic (unchanged)
# ─────────────────────────────────────────────────────────────────────────────

func _on_character_selected(character_id: String):
	## Handle character selection/deselection
	if _is_character_locked(character_id):
		return
	if character_id in selected_character_ids:
		selected_character_ids.erase(character_id)
	else:
		if selected_character_ids.size() < 3:
			selected_character_ids.append(character_id)
		else:
			return

	_update_ui()

func _update_ui():
	## Update UI to reflect current selection state
	if is_instance_valid(selection_count_label):
		selection_count_label.text = "Selected: %d / 3" % selected_character_ids.size()

	for char_id in character_entries:
		var entry = character_entries[char_id]
		if not entry:
			continue
		var panel: PanelContainer = entry.get("panel")
		if not is_instance_valid(panel):
			continue

		var is_locked: bool = _is_character_locked(char_id)
		var is_selected: bool = char_id in selected_character_ids

		if is_locked:
			# Locked modulate is set once at card creation; no StyleBox change needed
			pass
		elif is_selected:
			panel.add_theme_stylebox_override("panel", entry["selected_style"])
		else:
			panel.add_theme_stylebox_override("panel", entry["normal_style"])

	_update_party_summary()

	if is_instance_valid(confirm_button):
		confirm_button.disabled = selected_character_ids.size() != 3

func _update_party_summary():
	## Update the party summary label
	if not is_instance_valid(party_summary_label):
		return

	if selected_character_ids.size() == 3:
		var summary_lines: Array[String] = []
		summary_lines.append("Selected Party:")
		for char_id in selected_character_ids:
			var char_data = null
			if DataRegistry:
				char_data = DataRegistry.get_character(char_id)
			if char_data:
				summary_lines.append("  • %s" % char_data.display_name)
			else:
				summary_lines.append("  • %s" % char_id)
		party_summary_label.text = "\n".join(summary_lines)
		party_summary_label.visible = true
	else:
		party_summary_label.text = ""
		party_summary_label.visible = false

# ─────────────────────────────────────────────────────────────────────────────
# Confirm (unchanged)
# ─────────────────────────────────────────────────────────────────────────────

func _on_confirm_pressed():
	## Confirm party selection and proceed to loadout screen.
	if selected_character_ids.size() != 3:
		push_error("Cannot confirm party: must select exactly 3 characters")
		return

	var selected_char_data: Array[CharacterData] = []
	for char_id in selected_character_ids:
		for char_data in available_characters:
			if char_data.id == char_id:
				selected_char_data.append(char_data)
				break

	if selected_char_data.size() != 3:
		push_error("Failed to find CharacterData for all selected characters")
		return

	if PartyManager:
		PartyManager.set_party(selected_character_ids)

	if QuestManager:
		QuestManager.initialize_quests(selected_char_data)

	if RunState:
		RunState.equipment_slots.clear()
		RunState.run_stash.clear()

	ScreenManager.go_to_loadout()
