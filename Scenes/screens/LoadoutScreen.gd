extends Control

## Pre-run loadout screen — step 3 of the pre-run flow (after party select).
## Displays per-character equipment slots and the run stash.
## Player configures equipment, then presses "Start Run" to begin.
##
## Run initialisation (starter deck + map) happens HERE so that
## equipment injected_cards are included in the starting deck.

# ── UI refs (built in _build_ui) ──────────────────────────────────────────────
var scroll_root: ScrollContainer = null       # unused; kept for API compatibility
var character_panels: Dictionary = {}          # char_id -> slot_name -> Button
var stash_container: VBoxContainer = null      # inner vbox holding stash item panels
var start_btn: Button = null
var stash_label: Label = null                  # stash header label
var _modifier_score_label: Label = null
var _modifier_check_buttons: Dictionary = {}   # modifier_id -> CheckButton

# ── State ─────────────────────────────────────────────────────────────────────
var _selected_stash_id: String = ""
var _selected_slot_char: String = ""
var _selected_slot_name: String = ""

# ── Visual helpers ─────────────────────────────────────────────────────────────
var _slot_styles: Dictionary = {}              # char_id -> slot_name -> {empty, filled}
var _stash_panels: Dictionary = {}             # equip_id -> PanelContainer

# ── Font cache ─────────────────────────────────────────────────────────────────
var _font_extrabold: Font = null
var _font_bold: Font = null
var _font_regular: Font = null

# ── Constants ──────────────────────────────────────────────────────────────────
const SLOT_ICONS := {
	"HELMET": "🪖", "CHEST": "🛡", "LEGS": "🦺",
	"BOOTS": "👢", "WEAPON": "⚔", "RELIC_SLOT": "✨",
}

const ROLE_COLORS := {
	"warrior":  Color(0.65, 0.20, 0.15),
	"defender": Color(0.20, 0.38, 0.65),
	"healer":   Color(0.18, 0.62, 0.40),
	"mage":     Color(0.55, 0.18, 0.75),
	"rogue":    Color(0.65, 0.55, 0.15),
	"ranger":   Color(0.25, 0.55, 0.28),
}

const RARITY_COLORS := {
	0: Color("#6A7080"),  # COMMON
	1: Color("#3A8080"),  # UNCOMMON
	2: Color("#C4821A"),  # RARE
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
	_build_ui()
	_load_stash_from_meta()
	refresh_from_state()

# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui():
	## Construct the entire loadout screen programmatically.

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.offset_left = 60.0
	root_vbox.offset_top = 30.0
	root_vbox.offset_right = -60.0
	root_vbox.offset_bottom = -30.0
	root_vbox.add_theme_constant_override("separation", 10)
	add_child(root_vbox)

	# ── Header ──────────────────────────────────────────────────────────────
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(header_hbox)

	var back_btn := Button.new()
	back_btn.text = "← BACK"
	back_btn.custom_minimum_size = Vector2(130, 0)
	_style_back_button(back_btn)
	back_btn.pressed.connect(func(): ScreenManager.go_to_character_select())
	header_hbox.add_child(back_btn)

	var title := Label.new()
	title.text = "CONFIGURE YOUR LOADOUT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eb_font := _get_font("extrabold")
	if eb_font:
		title.add_theme_font_override("font", eb_font)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#E8A020"))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color("#12161E"))
	header_hbox.add_child(title)

	# Spacer mirrors back_btn width so title stays truly centred
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(130, 0)
	header_hbox.add_child(spacer)

	# ── Body: stash | character panels ──────────────────────────────────────
	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 16)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body_hbox)

	body_hbox.add_child(_build_stash_panel())

	var chars_hbox := HBoxContainer.new()
	chars_hbox.add_theme_constant_override("separation", 16)
	chars_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chars_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(chars_hbox)

	if PartyManager:
		for char_id in PartyManager.get_party_ids():
			chars_hbox.add_child(_build_character_panel(char_id))

	# ── Bottom bar: difficulty + start ──────────────────────────────────────
	root_vbox.add_child(_build_bottom_bar())

func _build_stash_panel() -> Control:
	## Left sidebar: scrollable list of stash items with rarity colours.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1F2BCC")
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color("#4A5060")
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Header label (updated by _refresh_stash)
	stash_label = Label.new()
	stash_label.text = "STASH (0/%d)" % (RunState.MAX_STASH_SIZE if RunState else 9)
	stash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stash_eb := _get_font("extrabold")
	if stash_eb:
		stash_label.add_theme_font_override("font", stash_eb)
	stash_label.add_theme_font_size_override("font_size", 16)
	stash_label.add_theme_color_override("font_color", Color("#E8A020"))
	vbox.add_child(stash_label)

	var instruction := Label.new()
	instruction.text = "Select item, then click a slot"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_size_override("font_size", 11)
	instruction.add_theme_color_override("font_color", Color("#807060"))
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(instruction)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color("#4A5060"))
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	stash_container = VBoxContainer.new()
	stash_container.add_theme_constant_override("separation", 6)
	stash_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stash_container)

	return panel

func _build_character_panel(char_id: String) -> Control:
	## Build one character's card: nameplate + portrait + 6 styled slot buttons.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1F2BEE")
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color("#4A5060")
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Nameplate
	var char_data = DataRegistry.get_character(char_id) if DataRegistry else null
	var nameplate := Label.new()
	nameplate.text = char_data.display_name.to_upper() if char_data else char_id.to_upper()
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var eb := _get_font("extrabold")
	if eb:
		nameplate.add_theme_font_override("font", eb)
	nameplate.add_theme_font_size_override("font_size", 18)
	nameplate.add_theme_color_override("font_color", Color("#E8A020"))
	var np_bg := StyleBoxFlat.new()
	np_bg.bg_color = Color("#0A0D14CC")
	np_bg.content_margin_left = 4
	np_bg.content_margin_right = 4
	np_bg.content_margin_top = 4
	np_bg.content_margin_bottom = 4
	nameplate.add_theme_stylebox_override("normal", np_bg)
	vbox.add_child(nameplate)

	# Portrait (top, fixed height, full width)
	if char_data:
		var portrait := _load_portrait_for(char_data)
		vbox.add_child(portrait)

	# Slots (below portrait, fills remaining space)
	var slots_vbox := VBoxContainer.new()
	slots_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(slots_vbox)

	var slot_buttons: Dictionary = {}
	_slot_styles[char_id] = {}

	for slot_name in EquipmentData.all_slot_names():
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		slots_vbox.add_child(hbox)

		# Slot label with icon
		var slot_lbl := Label.new()
		slot_lbl.text = "%s %s" % [SLOT_ICONS.get(slot_name, "◆"), slot_name]
		slot_lbl.custom_minimum_size = Vector2(110, 0)
		slot_lbl.add_theme_font_size_override("font_size", 12)
		slot_lbl.add_theme_color_override("font_color", Color("#A09070"))
		hbox.add_child(slot_lbl)

		# Build the two slot StyleBoxes
		var empty_style := StyleBoxFlat.new()
		empty_style.bg_color = Color("#12161E99")
		empty_style.set_border_width_all(1)
		empty_style.border_color = Color("#3A3F4A")
		empty_style.set_corner_radius_all(4)
		empty_style.content_margin_left = 8
		empty_style.content_margin_right = 8
		empty_style.content_margin_top = 4
		empty_style.content_margin_bottom = 4

		var filled_style := StyleBoxFlat.new()
		filled_style.bg_color = Color("#1E2A1ACC")
		filled_style.set_border_width_all(2)
		filled_style.border_color = Color("#E8A020")
		filled_style.set_corner_radius_all(4)
		filled_style.content_margin_left = 8
		filled_style.content_margin_right = 8
		filled_style.content_margin_top = 4
		filled_style.content_margin_bottom = 4

		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color("#2A3040CC")
		hover_style.set_border_width_all(1)
		hover_style.border_color = Color("#C4821A")
		hover_style.set_corner_radius_all(4)
		hover_style.content_margin_left = 8
		hover_style.content_margin_right = 8
		hover_style.content_margin_top = 4
		hover_style.content_margin_bottom = 4

		_slot_styles[char_id][slot_name] = {"empty": empty_style, "filled": filled_style}

		var slot_btn := Button.new()
		slot_btn.text = "(empty)"
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.add_theme_font_size_override("font_size", 12)
		slot_btn.add_theme_color_override("font_color", Color("#606070"))
		slot_btn.add_theme_stylebox_override("normal", empty_style)
		slot_btn.add_theme_stylebox_override("hover", hover_style)
		slot_btn.add_theme_stylebox_override("pressed", hover_style)
		slot_btn.pressed.connect(_on_slot_clicked.bind(char_id, slot_name))
		hbox.add_child(slot_btn)

		slot_buttons[slot_name] = slot_btn

	character_panels[char_id] = slot_buttons
	return panel

func _build_bottom_bar() -> Control:
	## Slim bottom bar: condensed difficulty grid (left) + Start Run button (right).
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color("#0D1018CC")
	bar_style.border_width_top = 2
	bar_style.border_width_left = 0
	bar_style.border_width_right = 0
	bar_style.border_width_bottom = 0
	bar_style.border_color = Color("#C4821A")
	bar_style.content_margin_left = 12
	bar_style.content_margin_right = 12
	bar_style.content_margin_top = 10
	bar_style.content_margin_bottom = 10

	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 110)
	bar.add_theme_stylebox_override("panel", bar_style)

	var inner_hbox := HBoxContainer.new()
	inner_hbox.add_theme_constant_override("separation", 20)
	bar.add_child(inner_hbox)

	# ── Modifier section (expand fill) ──────────────────────────────────────
	var mod_vbox := VBoxContainer.new()
	mod_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mod_vbox.add_theme_constant_override("separation", 6)
	inner_hbox.add_child(mod_vbox)

	var mod_header_hbox := HBoxContainer.new()
	mod_vbox.add_child(mod_header_hbox)

	var diff_label := Label.new()
	diff_label.text = "DIFFICULTY MODIFIERS"
	diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reg_font := _get_font("regular")
	if reg_font:
		diff_label.add_theme_font_override("font", reg_font)
	diff_label.add_theme_font_size_override("font_size", 13)
	diff_label.add_theme_color_override("font_color", Color("#C4821A"))
	mod_header_hbox.add_child(diff_label)

	_modifier_score_label = Label.new()
	_modifier_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_modifier_score_label.add_theme_font_size_override("font_size", 13)
	mod_header_hbox.add_child(_modifier_score_label)

	# 2-row × 3-column grid of toggle chips
	var mod_grid := GridContainer.new()
	mod_grid.columns = 3
	mod_grid.add_theme_constant_override("h_separation", 12)
	mod_grid.add_theme_constant_override("v_separation", 4)
	mod_vbox.add_child(mod_grid)

	var available: Array = ModifierManager.get_available_modifiers() if ModifierManager else []
	if available.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No modifiers available."
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color("#606060"))
		mod_grid.add_child(none_lbl)
	else:
		for mod in available:
			var check := CheckButton.new()
			check.text = mod["name"]
			check.button_pressed = ModifierManager.is_selected(mod["id"])
			check.add_theme_font_size_override("font_size", 13)
			check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			check.tooltip_text = mod.get("description", "")
			var mid: String = mod["id"]
			check.toggled.connect(func(_on: bool): _on_modifier_toggled(mid))
			_modifier_check_buttons[mod["id"]] = check
			mod_grid.add_child(check)

	_refresh_modifier_score_label()

	if ModifierManager and not ModifierManager.modifiers_changed.is_connected(_on_modifiers_changed):
		ModifierManager.modifiers_changed.connect(_on_modifiers_changed)

	# ── Start Run button (right) ─────────────────────────────────────────────
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_vbox.add_theme_constant_override("separation", 8)
	inner_hbox.add_child(right_vbox)

	start_btn = Button.new()
	start_btn.text = "START RUN"
	start_btn.custom_minimum_size = Vector2(220, 60)
	_style_start_button(start_btn)
	start_btn.pressed.connect(_on_start_run_pressed)
	right_vbox.add_child(start_btn)

	return bar

# ── Button styling helpers ─────────────────────────────────────────────────────

func _style_back_button(btn: Button) -> void:
	var reg_font := _get_font("regular")
	if reg_font:
		btn.add_theme_font_override("font", reg_font)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color("#C0A878"))
	btn.add_theme_color_override("font_hover_color", Color("#E8A020"))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#1A1F2B88")
	normal_style.set_border_width_all(1)
	normal_style.border_color = Color("#706050")
	normal_style.set_corner_radius_all(4)
	normal_style.content_margin_left = 14
	normal_style.content_margin_right = 14
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color("#2A3040CC")
	hover_style.border_color = Color("#C4821A")
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.bg_color = Color("#C4821A33")
	btn.add_theme_stylebox_override("pressed", pressed_style)

func _style_start_button(btn: Button) -> void:
	var bold_font := _get_font("bold")
	if bold_font:
		btn.add_theme_font_override("font", bold_font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color("#F0E6C8"))
	btn.add_theme_color_override("font_hover_color", Color("#D4A847"))
	btn.add_theme_color_override("font_pressed_color", Color("#C4821A"))
	btn.add_theme_color_override("font_disabled_color", Color("#60606A"))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#2A3040E8")
	normal_style.set_border_width_all(4)
	normal_style.border_color = Color("#C4821A")
	normal_style.set_corner_radius_all(4)
	normal_style.content_margin_left = 32
	normal_style.content_margin_right = 32
	normal_style.content_margin_top = 12
	normal_style.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color("#4A5566CC")
	hover_style.border_color = Color("#D4A847")
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.bg_color = Color("#C4821A33")
	pressed_style.border_color = Color("#F0E6C8")
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_color_override("font_outline_color", Color("#12161E"))

# ── Portrait helper ────────────────────────────────────────────────────────────

func _load_portrait_for(char_data: CharacterData) -> Control:
	## Load portrait TextureRect, or a role-coloured placeholder with initials.
	if not char_data.portrait_path.is_empty():
		var tex = load(char_data.portrait_path)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.custom_minimum_size = Vector2(0, 180)
			tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return tr

	var placeholder := ColorRect.new()
	var role_key: String = char_data.role.to_lower()
	placeholder.color = ROLE_COLORS.get(role_key, Color(0.25, 0.28, 0.38))
	placeholder.custom_minimum_size = Vector2(0, 180)
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var initials := Label.new()
	initials.text = char_data.display_name.substr(0, 2).to_upper()
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", 36)
	initials.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	var eb := _get_font("extrabold")
	if eb:
		initials.add_theme_font_override("font", eb)
	initials.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.add_child(initials)

	return placeholder

# ── Meta save integration ──────────────────────────────────────────────────────

func _load_stash_from_meta():
	## Populate run_stash from persistent meta save.
	if not SaveManager:
		return
	var persistent: Array[String] = SaveManager.load_persistent_stash()
	for equip_id in persistent:
		if RunState.run_stash.size() < RunState.MAX_STASH_SIZE:
			if not RunState.run_stash.has(equip_id):
				RunState.run_stash.append(equip_id)

# ── Refresh ────────────────────────────────────────────────────────────────────

func refresh_from_state():
	## Sync all slot buttons and stash display with RunState.
	_refresh_slot_buttons()
	_refresh_stash()

func _refresh_slot_buttons():
	for char_id in character_panels:
		var slot_buttons: Dictionary = character_panels[char_id]
		var char_styles: Dictionary = _slot_styles.get(char_id, {})
		for slot_name in slot_buttons:
			var equip_id: String = RunState.get_equipped_item(char_id, slot_name)
			var btn: Button = slot_buttons[slot_name]
			var styles: Dictionary = char_styles.get(slot_name, {})
			if equip_id.is_empty():
				btn.text = "(empty)"
				btn.add_theme_color_override("font_color", Color("#606070"))
				if styles.has("empty"):
					btn.add_theme_stylebox_override("normal", styles["empty"])
			else:
				var equip_data = DataRegistry.get_equipment(equip_id) if DataRegistry else null
				btn.text = equip_data.name if equip_data else equip_id
				btn.add_theme_color_override("font_color", Color("#F0E6C8"))
				if styles.has("filled"):
					btn.add_theme_stylebox_override("normal", styles["filled"])

func _refresh_stash():
	## Rebuild stash item panels from run_stash.
	_stash_panels.clear()
	for child in stash_container.get_children():
		stash_container.remove_child(child)
		child.queue_free()

	var stash_size: int = RunState.run_stash.size() if RunState else 0
	var max_size: int = RunState.MAX_STASH_SIZE if RunState else 9

	if stash_label:
		stash_label.text = "STASH (%d/%d)" % [stash_size, max_size]

	if not RunState or RunState.run_stash.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No equipment\nfrom previous runs"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color("#505060"))
		stash_container.add_child(empty_lbl)
		return

	for equip_id in RunState.run_stash:
		var equip_data = DataRegistry.get_equipment(equip_id) if DataRegistry else null
		var is_selected: bool = equip_id == _selected_stash_id

		var item_style := StyleBoxFlat.new()
		item_style.bg_color = Color("#12161ECC")
		item_style.set_border_width_all(2 if is_selected else 1)
		item_style.border_color = Color("#E8A020") if is_selected else Color("#3A3F4A")
		item_style.set_corner_radius_all(4)
		item_style.content_margin_left = 8
		item_style.content_margin_right = 8
		item_style.content_margin_top = 4
		item_style.content_margin_bottom = 4

		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(0, 36)
		item_panel.add_theme_stylebox_override("panel", item_style)
		item_panel.mouse_filter = Control.MOUSE_FILTER_STOP

		var eid := equip_id  # capture for closure
		item_panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_stash_item_clicked(eid)
		)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		item_panel.add_child(row)

		# Rarity dot
		var rarity_idx: int = int(equip_data.rarity) if equip_data else 0
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = RARITY_COLORS.get(rarity_idx, Color("#6A7080"))
		dot.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(dot)

		# Item name
		var name_lbl := Label.new()
		name_lbl.text = equip_data.name if equip_data else equip_id
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color",
			Color("#F0E6C8") if is_selected else Color("#C0B090"))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name_lbl)

		# Slot icon badge
		var slot_type_str := ""
		if equip_data:
			for key in EquipmentData.SlotType.keys():
				if EquipmentData.SlotType[key] == equip_data.slot_type:
					slot_type_str = key
					break
		var badge_lbl := Label.new()
		badge_lbl.text = SLOT_ICONS.get(slot_type_str, "◆")
		badge_lbl.add_theme_font_size_override("font_size", 13)
		badge_lbl.add_theme_color_override("font_color", Color("#707070"))
		badge_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(badge_lbl)

		stash_container.add_child(item_panel)
		_stash_panels[equip_id] = item_panel

# ── Interaction ────────────────────────────────────────────────────────────────

func _on_stash_item_clicked(equip_id: String):
	## Select an item from the stash for equipping.
	_selected_stash_id = equip_id
	_refresh_stash()

func _on_slot_clicked(char_id: String, slot_name: String):
	## If an item is selected from stash, equip it. Otherwise unequip the current item.
	if not _selected_stash_id.is_empty():
		# Validate lock constraint
		var equip_data = DataRegistry.get_equipment(_selected_stash_id) if DataRegistry else null
		if equip_data:
			var char_data = DataRegistry.get_character(char_id) if DataRegistry else null
			if not equip_data.can_be_equipped_by(char_data):
				_show_message("That item cannot be equipped by %s." % (char_data.display_name if char_data else char_id))
				return
		RunState.equip_item(char_id, slot_name, _selected_stash_id)
		_selected_stash_id = ""
	else:
		# No item selected — unequip whatever is in the slot
		RunState.unequip_item(char_id, slot_name)
	refresh_from_state()

func _show_message(text: String):
	## Show a brief popup message.
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	dialog.unresizable = true
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

# ── Difficulty Modifiers ───────────────────────────────────────────────────────

func _on_modifier_toggled(modifier_id: String) -> void:
	if ModifierManager:
		ModifierManager.toggle_modifier(modifier_id)

func _on_modifiers_changed() -> void:
	## Keep checkboxes and score preview in sync when ModifierManager changes.
	for mid in _modifier_check_buttons:
		var check: CheckButton = _modifier_check_buttons[mid]
		var should_be: bool = ModifierManager.is_selected(mid) if ModifierManager else false
		if check.button_pressed != should_be:
			check.set_pressed_no_signal(should_be)
	_refresh_modifier_score_label()

func _refresh_modifier_score_label() -> void:
	if _modifier_score_label == null:
		return
	var mult: float = ModifierManager.get_score_multiplier_preview() if ModifierManager else 1.0
	var count: int = ModifierManager.get_selected_count() if ModifierManager else 0
	if count == 0:
		_modifier_score_label.text = "Score: ×1.0"
		_modifier_score_label.modulate = Color(1, 1, 1)
	else:
		_modifier_score_label.text = "Score: ×%.1f" % mult
		_modifier_score_label.modulate = Color(1.0, 0.85, 0.3)

# ── Start Run ──────────────────────────────────────────────────────────────────

func _on_start_run_pressed():
	## Finalize the run: generate starter deck (with equipment injections),
	## create the initial map, save, and navigate to the map screen.
	var party_ids = PartyManager.get_party_ids()
	if party_ids.size() != 3:
		push_error("LoadoutScreen: party_ids is not 3 — cannot start run")
		return

	# Collect CharacterData for the party
	var party_char_data: Array[CharacterData] = []
	for char_id in party_ids:
		var cd = DataRegistry.get_character(char_id) if DataRegistry else null
		if not cd:
			push_error("LoadoutScreen: Missing CharacterData for '%s'" % char_id)
			return
		party_char_data.append(cd)

	# Reset per-run milestone counters (e.g. gain_gold tracking)
	if MilestoneManager:
		MilestoneManager.reset_run_counters()

	# Lock in difficulty modifiers for this run
	if ModifierManager:
		ModifierManager.begin_run()

	# Generate starter deck (includes equipment card injections)
	if RunState:
		RunState.generate_starter_deck(party_char_data)

	# Generate initial map
	var map_gen = MapGenerator.new()
	var act = MapManager.act if MapManager else 1
	var map_data = map_gen.generate_map(act)
	if MapManager:
		MapManager.set_map_data(map_data)

	# Force save before entering the run
	if AutoSaveManager:
		AutoSaveManager.force_save("new_run_started")

	ScreenManager.go_to_map()
