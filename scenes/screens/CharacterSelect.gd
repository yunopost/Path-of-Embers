extends Control

## Character selection screen — 3-zone redesign (Slice-8)
## Layout: Header (steps + HP badge) | Body (grid + detail panel) | Footer (slots + confirm)
## Interaction: hover card → detail panel populates; click card → toggle selection (max 3)

# ─────────────────────────────────────────────────────────────────────────────
# Colour constants
# ─────────────────────────────────────────────────────────────────────────────

const EMBER_GLOW  := Color("#C4621E")   # selection border / accent stripe
const EMBER_MID   := Color("#C4821A")   # section labels, badge border, quest accent
const EMBER_BRIGHT := Color("#E8A020")  # theme names in detail panel
const FOG         := Color("#A09070")   # muted / secondary text
const PALE        := Color("#F0E6C8")   # primary text
const INK         := Color("#0D0C0A")   # header / footer background
const SECTION_BG  := Color("#16130F")   # detail panel background
const CARD_BG     := Color("#1A1F2BEE") # character card background
const BORDER_DIM  := Color("#4A5060")   # unselected card border
const BORDER_GLOW := Color("#3A2E1F")   # general border tint

const PRE_RUN_CHROME = preload("res://scenes/ui/PreRunChrome.gd")

const HP_GREEN    := Color("#3A9050")
const HP_GOLD     := Color("#C4821A")
const HP_RED      := Color("#A03020")

const ROLE_COLORS := {
	"warrior":  Color("#C43030"),
	"healer":   Color("#4A9A60"),
	"defender": Color("#3A70C4"),
}

const CARD_TYPE_COLORS := {
	0: Color("#A03020"),  # ATTACK
	1: Color("#2060A0"),  # SKILL
	2: Color("#806020"),  # POWER
	3: Color("#602080"),  # CURSE
}
const CARD_TYPE_NAMES := ["ATK", "SKL", "PWR", "CRS"]

const ROLE_LABELS := {
	"warrior":  "Warriors — Offense & Tempo",
	"healer":   "Healers — Engine & Scaling",
	"defender": "Defenders — Survivability & Control",
}
const ROLE_ICONS := {
	"warrior":  "⚔",
	"healer":   "✦",
	"defender": "◈",
}
const ROLE_STAT_SUMMARIES := {
	"warrior":  "STR 2  ·  DEF 1  ·  SPR 1  ·  HP 25",
	"healer":   "STR 1  ·  DEF 1  ·  SPR 2  ·  HP 22",
	"defender": "STR 1  ·  DEF 2  ·  SPR 1  ·  HP 28",
}

# ─────────────────────────────────────────────────────────────────────────────
# Font cache
# ─────────────────────────────────────────────────────────────────────────────

var _font_extrabold: Font = null
var _font_bold: Font = null
var _font_regular: Font = null

func _get_font(variant: String) -> Font:
	match variant:
		"extrabold":
			if not _font_extrabold:
				_font_extrabold = load("res://fonts/Cinzel/static/Cinzel-ExtraBold.ttf")
			return _font_extrabold
		"bold":
			if not _font_bold:
				_font_bold = load("res://fonts/Cinzel/static/Cinzel-Bold.ttf")
			return _font_bold
		_:
			if not _font_regular:
				_font_regular = load("res://fonts/Cinzel/static/Cinzel-Regular.ttf")
			return _font_regular

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

var available_characters: Array[CharacterData] = []
var selected_character_ids: Array[String] = []   # ordered, max 3
var hovered_character_id: String = ""
var _detail_character_id: String = ""            # character currently shown in detail panel
var character_card_nodes: Dictionary = {}  # char_id → { root, normal_style, selected_style, check_badge, lock_badge }

# ─────────────────────────────────────────────────────────────────────────────
# UI node references (set during _build_ui)
# ─────────────────────────────────────────────────────────────────────────────

var _grid_content_vbox: VBoxContainer = null
var _detail_content_vbox: VBoxContainer = null
var _hp_value_label: Label = null
var _hp_badge_panel: PanelContainer = null
var _hp_badge_style: StyleBoxFlat = null
var _footer_slot_displays: Array = []   # Array of Dicts
var _confirm_button: Button = null
var _count_label: Label = null

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	await get_tree().process_frame
	_build_ui()
	initialize()
	visible = true
	get_tree().paused = false

func initialize() -> void:
	## Public entry point (architecture rule 2.1)
	refresh_from_state()

func refresh_from_state() -> void:
	_load_characters()
	_populate_grid()
	_update_ui()

# ─────────────────────────────────────────────────────────────────────────────
# UI Construction — top level
# ─────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Dark dimming overlay so the busy background image doesn't drown out the UI
	var dim_overlay := ColorRect.new()
	dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_overlay.color = Color(0.04, 0.035, 0.03, 0.78)
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim_overlay)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	root_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root_vbox)

	root_vbox.add_child(_build_header())
	root_vbox.add_child(_build_body())
	root_vbox.add_child(_build_footer())

# ─────────────────────────────────────────────────────────────────────────────
# Header
# ─────────────────────────────────────────────────────────────────────────────

func _build_header() -> HBoxContainer:
	## Shared pre-run header (PreRunChrome) — step bar + title + HP badge.
	## Step index 0 = Party (this screen).
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 92
	header.add_theme_constant_override("separation", 0)
	header.mouse_filter = Control.MOUSE_FILTER_PASS

	var right_content := _build_hp_badge()
	var header_panel := PRE_RUN_CHROME.build_header(0, "PATH OF EMBERS", right_content)
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_panel)

	return header

func _build_hp_badge() -> PanelContainer:
	## Right-side HP badge shown in the shared header on this screen only.
	_hp_badge_style = StyleBoxFlat.new()
	_hp_badge_style.bg_color = Color(0, 0, 0, 0.4)
	_hp_badge_style.set_border_width_all(2)
	_hp_badge_style.border_color = Color(FOG, 0.4)
	_hp_badge_style.set_corner_radius_all(5)
	_hp_badge_style.content_margin_left = 16
	_hp_badge_style.content_margin_right = 16
	_hp_badge_style.content_margin_top = 10
	_hp_badge_style.content_margin_bottom = 10

	_hp_badge_panel = PanelContainer.new()
	_hp_badge_panel.custom_minimum_size = Vector2(260, 64)
	_hp_badge_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hp_badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_badge_panel.add_theme_stylebox_override("panel", _hp_badge_style)
	_hp_badge_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var badge_hbox := HBoxContainer.new()
	badge_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badge_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_hbox.add_theme_constant_override("separation", 10)
	badge_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_hp_badge_panel.add_child(badge_hbox)

	var heart_label := Label.new()
	heart_label.text = "♥"
	heart_label.add_theme_color_override("font_color", Color("#C43030"))
	heart_label.add_theme_font_size_override("font_size", 22)
	heart_label.mouse_filter = Control.MOUSE_FILTER_PASS
	badge_hbox.add_child(heart_label)

	var hp_lbl_label := Label.new()
	hp_lbl_label.text = "PARTY HP"
	hp_lbl_label.add_theme_color_override("font_color", FOG)
	hp_lbl_label.add_theme_font_size_override("font_size", 13)
	hp_lbl_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var reg_font = _get_font("regular")
	if reg_font:
		hp_lbl_label.add_theme_font_override("font", reg_font)
	badge_hbox.add_child(hp_lbl_label)

	_hp_value_label = Label.new()
	_hp_value_label.text = "—"
	_hp_value_label.add_theme_color_override("font_color", PALE)
	_hp_value_label.add_theme_font_size_override("font_size", 28)
	_hp_value_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var bold_font = _get_font("bold")
	if bold_font:
		_hp_value_label.add_theme_font_override("font", bold_font)
	badge_hbox.add_child(_hp_value_label)

	return _hp_badge_panel

# ─────────────────────────────────────────────────────────────────────────────
# Body
# ─────────────────────────────────────────────────────────────────────────────

func _build_body() -> Control:
	# Anchor-based proportional split: grid 72% | detail 28%.
	# This avoids min-width propagation issues and scales with the window.
	var body := Control.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_PASS

	# ── Left: scrollable character grid (0% – 72%) ─────────────────────────
	var grid_scroll := ScrollContainer.new()
	grid_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_scroll.anchor_right = 0.72
	grid_scroll.offset_left = 0
	grid_scroll.offset_right = 0
	grid_scroll.offset_top = 0
	grid_scroll.offset_bottom = 0
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	grid_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(grid_scroll)

	var grid_margin := MarginContainer.new()
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_margin.add_theme_constant_override("margin_left", 32)
	grid_margin.add_theme_constant_override("margin_right", 24)
	grid_margin.add_theme_constant_override("margin_top", 24)
	grid_margin.add_theme_constant_override("margin_bottom", 20)
	grid_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	grid_scroll.add_child(grid_margin)

	_grid_content_vbox = VBoxContainer.new()
	_grid_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_content_vbox.add_theme_constant_override("separation", 22)
	_grid_content_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	grid_margin.add_child(_grid_content_vbox)

	# ── Right: detail panel (72% – 100%) ────────────────────────────────────
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = SECTION_BG
	detail_style.set_border_width_all(0)
	detail_style.border_width_left = 1
	detail_style.border_color = Color(BORDER_GLOW, 0.6)

	var detail_panel := PanelContainer.new()
	detail_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_panel.anchor_left = 0.72
	detail_panel.offset_left = 0
	detail_panel.offset_right = 0
	detail_panel.offset_top = 0
	detail_panel.offset_bottom = 0
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	detail_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(detail_panel)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	detail_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_panel.add_child(detail_scroll)

	var detail_margin := MarginContainer.new()
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.add_theme_constant_override("margin_left", 24)
	detail_margin.add_theme_constant_override("margin_right", 24)
	detail_margin.add_theme_constant_override("margin_top", 26)
	detail_margin.add_theme_constant_override("margin_bottom", 22)
	detail_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_scroll.add_child(detail_margin)

	_detail_content_vbox = VBoxContainer.new()
	_detail_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_content_vbox.add_theme_constant_override("separation", 14)
	_detail_content_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_margin.add_child(_detail_content_vbox)

	# Populate with empty state immediately
	_show_detail_empty_state()

	return body

# ─────────────────────────────────────────────────────────────────────────────
# Footer
# ─────────────────────────────────────────────────────────────────────────────

func _build_footer() -> PanelContainer:
	## Shared pre-run footer (PreRunChrome): Back is bottom-left, Confirm is
	## bottom-right, always -- slot displays + count sit in the center.
	var nav := PRE_RUN_CHROME.build_footer(
		"← Back", func(): ScreenManager.go_to_main_menu(),
		"Confirm Party →", _on_confirm_pressed
	)
	var footer_panel: PanelContainer = nav["panel"]
	_confirm_button = nav["next_btn"]
	_confirm_button.disabled = true

	var center: Control = nav["center"]
	var center_hbox := HBoxContainer.new()
	center_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_hbox.add_theme_constant_override("separation", 22)
	center_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(center_hbox)

	# ── Left of center: slot displays ────────────────────────────────────────
	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 14)
	slots_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	center_hbox.add_child(slots_hbox)

	_footer_slot_displays = []
	for i in range(3):
		_build_slot_display(i, slots_hbox)

	# ── Rest of center: count label ──────────────────────────────────────────
	_count_label = Label.new()
	_count_label.text = "0 / 3 selected"
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_color_override("font_color", FOG)
	_count_label.add_theme_font_size_override("font_size", 15)
	_count_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var reg_font = _get_font("regular")
	if reg_font:
		_count_label.add_theme_font_override("font", reg_font)
	center_hbox.add_child(_count_label)

	return footer_panel

# ─────────────────────────────────────────────────────────────────────────────
# Footer slot display
# ─────────────────────────────────────────────────────────────────────────────

func _build_slot_display(index: int, parent: HBoxContainer) -> void:
	var empty_style := StyleBoxFlat.new()
	empty_style.bg_color = Color(0, 0, 0, 0.3)
	empty_style.set_border_width_all(2)
	empty_style.border_color = Color(EMBER_MID, 0.35)
	empty_style.set_corner_radius_all(5)

	var filled_style := StyleBoxFlat.new()
	filled_style.bg_color = Color(0, 0, 0, 0.3)
	filled_style.set_border_width_all(2)
	filled_style.border_color = EMBER_MID
	filled_style.set_corner_radius_all(5)

	var slot_panel := PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(64, 64)
	slot_panel.add_theme_stylebox_override("panel", empty_style)
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(slot_panel)

	# Inner container (full-rect) for portrait + remove button overlay
	var inner := Control.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	slot_panel.add_child(inner)

	# Placeholder plus icon (empty state visual)
	var plus_label := Label.new()
	plus_label.text = "+"
	plus_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus_label.add_theme_color_override("font_color", Color(FOG, 0.3))
	plus_label.add_theme_font_size_override("font_size", 30)
	plus_label.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.add_child(plus_label)

	# Portrait area (filled state)
	var portrait_area := Control.new()
	portrait_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_area.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.add_child(portrait_area)

	# Remove button (visible on hover when filled)
	var remove_btn := Button.new()
	remove_btn.text = "×"
	remove_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	remove_btn.visible = false
	remove_btn.add_theme_font_size_override("font_size", 24)
	remove_btn.add_theme_color_override("font_color", Color("#E05050"))
	remove_btn.add_theme_color_override("font_hover_color", Color("#FF7070"))
	remove_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var remove_normal := StyleBoxFlat.new()
	remove_normal.bg_color = Color(0, 0, 0, 0.7)
	remove_normal.set_border_width_all(0)
	remove_btn.add_theme_stylebox_override("normal", remove_normal)
	remove_btn.add_theme_stylebox_override("hover", remove_normal)
	remove_btn.add_theme_stylebox_override("pressed", remove_normal)
	remove_btn.add_theme_stylebox_override("focus", remove_normal)
	inner.add_child(remove_btn)

	# Hover signals to show/hide remove button
	slot_panel.mouse_entered.connect(func():
		if is_instance_valid(remove_btn) and index < selected_character_ids.size():
			remove_btn.visible = true
	)
	slot_panel.mouse_exited.connect(func():
		if is_instance_valid(remove_btn):
			remove_btn.visible = false
	)

	remove_btn.pressed.connect(_on_slot_remove_pressed.bind(index))

	_footer_slot_displays.append({
		"panel": slot_panel,
		"portrait_area": portrait_area,
		"remove_btn": remove_btn,
		"plus_label": plus_label,
		"empty_style": empty_style,
		"filled_style": filled_style,
		"portrait_node": null,
	})

# ─────────────────────────────────────────────────────────────────────────────
# Data loading
# ─────────────────────────────────────────────────────────────────────────────

func _load_characters() -> void:
	available_characters.clear()
	if DataRegistry:
		available_characters = DataRegistry.get_all_characters()

func _is_character_locked(char_id: String) -> bool:
	if DebugMode and DebugMode.is_enabled():
		return false  # Addendum §6: debug mode ignores unlock state
	if not MilestoneManager:
		return false
	return not MilestoneManager.is_unlocked("character", char_id)

# ─────────────────────────────────────────────────────────────────────────────
# Grid population
# ─────────────────────────────────────────────────────────────────────────────

func _populate_grid() -> void:
	# Clear old children
	for child in _grid_content_vbox.get_children():
		child.queue_free()
	character_card_nodes.clear()

	# Group by role
	var groups: Dictionary = { "warrior": [], "healer": [], "defender": [] }
	for char_data in available_characters:
		if not char_data:
			continue
		var role: String = char_data.role.to_lower()
		if role in groups:
			groups[role].append(char_data)
		else:
			groups["warrior"].append(char_data)  # fallback

	for role in ["warrior", "healer", "defender"]:
		var chars: Array = groups[role]
		if chars.is_empty():
			continue
		var group_node := _build_archetype_group(role, chars)
		_grid_content_vbox.add_child(group_node)

func _build_archetype_group(role: String, chars: Array) -> VBoxContainer:
	var group_vbox := VBoxContainer.new()
	group_vbox.add_theme_constant_override("separation", 12)
	group_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	# Archetype header row
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	group_vbox.add_child(header_hbox)

	var role_color: Color = ROLE_COLORS.get(role, FOG)
	var reg_font = _get_font("regular")

	# Icon
	var icon_label := Label.new()
	icon_label.text = ROLE_ICONS.get(role, "·")
	icon_label.add_theme_color_override("font_color", role_color)
	icon_label.add_theme_font_size_override("font_size", 18)
	icon_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header_hbox.add_child(icon_label)

	# Label
	var arch_label := Label.new()
	arch_label.text = ROLE_LABELS.get(role, role.capitalize())
	arch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arch_label.add_theme_color_override("font_color", Color(FOG, 0.8))
	arch_label.add_theme_font_size_override("font_size", 14)
	arch_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if reg_font:
		arch_label.add_theme_font_override("font", reg_font)
	header_hbox.add_child(arch_label)

	# Stat summary
	var stat_label := Label.new()
	stat_label.text = ROLE_STAT_SUMMARIES.get(role, "")
	stat_label.add_theme_color_override("font_color", Color(role_color, 0.55))
	stat_label.add_theme_font_size_override("font_size", 12)
	stat_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if reg_font:
		stat_label.add_theme_font_override("font", reg_font)
	header_hbox.add_child(stat_label)

	# Divider line
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(role_color, 0.18))
	sep.mouse_filter = Control.MOUSE_FILTER_PASS
	group_vbox.add_child(sep)

	# Cards row — fixed 4-column GridContainer so each row aligns evenly.
	# Cards use SIZE_EXPAND_FILL so the four columns share the row width.
	var cards_grid := GridContainer.new()
	cards_grid.columns = 4
	cards_grid.add_theme_constant_override("h_separation", 14)
	cards_grid.add_theme_constant_override("v_separation", 14)
	cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	group_vbox.add_child(cards_grid)

	for char_data in chars:
		var card := _build_character_card(char_data)
		cards_grid.add_child(card)

	return group_vbox

func _build_character_card(char_data: CharacterData) -> PanelContainer:
	var locked: bool = _is_character_locked(char_data.id)
	var role: String = char_data.role.to_lower()
	var role_color: Color = ROLE_COLORS.get(role, FOG)
	var reg_font = _get_font("regular")
	var bold_font = _get_font("bold")

	# Styles
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = CARD_BG
	normal_style.set_border_width_all(1)
	normal_style.border_color = BORDER_DIM
	normal_style.set_corner_radius_all(3)
	normal_style.content_margin_left = 0
	normal_style.content_margin_right = 0
	normal_style.content_margin_top = 0
	normal_style.content_margin_bottom = 0

	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = CARD_BG
	selected_style.set_border_width_all(2)
	selected_style.border_color = EMBER_GLOW
	selected_style.set_corner_radius_all(3)
	selected_style.shadow_color = Color(EMBER_GLOW, 0.3)
	selected_style.shadow_size = 6
	selected_style.content_margin_left = 0
	selected_style.content_margin_right = 0
	selected_style.content_margin_top = 0
	selected_style.content_margin_bottom = 0

	# Root panel — fixed height; width is divided evenly by GridContainer columns
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 104)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", normal_style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true

	# Single content VBox (the PanelContainer's one managed child)
	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 0)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(content_vbox)

	# ── Accent stripe (top gradient) ─────────────────────────────────────────
	# Gradient: role_color (left/opaque) → role_color @ alpha 0 (right/transparent)
	var gradient := Gradient.new()
	gradient.set_color(0, role_color)
	gradient.set_offset(0, 0.0)
	gradient.set_color(1, Color(role_color.r, role_color.g, role_color.b, 0.0))
	gradient.set_offset(1, 1.0)

	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	grad_tex.width = 256

	var stripe := TextureRect.new()
	stripe.texture = grad_tex
	stripe.custom_minimum_size = Vector2(0, 2)
	stripe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# EXPAND_IGNORE_SIZE: don't let the 256×1 gradient texture dictate min width
	# (FIT_WIDTH_PROPORTIONAL forced min width = height × 256, breaking the grid)
	stripe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stripe.stretch_mode = TextureRect.STRETCH_SCALE
	stripe.mouse_filter = Control.MOUSE_FILTER_PASS
	content_vbox.add_child(stripe)

	# ── Inner VBox (card body) ───────────────────────────────────────────────
	var inner_margin := MarginContainer.new()
	inner_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_margin.add_theme_constant_override("margin_left", 12)
	inner_margin.add_theme_constant_override("margin_right", 12)
	inner_margin.add_theme_constant_override("margin_top", 10)
	inner_margin.add_theme_constant_override("margin_bottom", 10)
	inner_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	content_vbox.add_child(inner_margin)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 6)
	body_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	inner_margin.add_child(body_vbox)

	# Portrait + meta HBox
	var portrait_meta_hbox := HBoxContainer.new()
	portrait_meta_hbox.add_theme_constant_override("separation", 12)
	portrait_meta_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	body_vbox.add_child(portrait_meta_hbox)

	# Portrait (56×56 placeholder)
	var portrait := _load_portrait_compact(char_data, 56)
	portrait_meta_hbox.add_child(portrait)

	# Meta VBox
	var meta_vbox := VBoxContainer.new()
	meta_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_vbox.add_theme_constant_override("separation", 5)
	meta_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	portrait_meta_hbox.add_child(meta_vbox)

	var name_label := Label.new()
	name_label.text = char_data.display_name
	name_label.add_theme_color_override("font_color", Color(PALE, 0.85) if locked else PALE)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if bold_font:
		name_label.add_theme_font_override("font", bold_font)
	meta_vbox.add_child(name_label)

	var badge_label := Label.new()
	badge_label.text = ROLE_ICONS.get(role, "") + "  " + role.capitalize().to_upper()
	badge_label.add_theme_color_override("font_color", Color(role_color, 1.0))
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.clip_text = true
	badge_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if reg_font:
		badge_label.add_theme_font_override("font", reg_font)
	meta_vbox.add_child(badge_label)

	# Stat pips
	var pips := _build_stat_pips(char_data, role_color)
	meta_vbox.add_child(pips)

	# ── Selected checkmark badge (top-right overlay) ─────────────────────────
	# Use layout_mode = 1 (anchors) so it overlays the panel rather than
	# being managed by the PanelContainer's layout engine.
	var check_badge := Label.new()
	check_badge.text = "✓"
	check_badge.layout_mode = 1
	check_badge.anchor_left = 1.0
	check_badge.anchor_right = 1.0
	check_badge.anchor_top = 0.0
	check_badge.anchor_bottom = 0.0
	check_badge.offset_left = -30.0
	check_badge.offset_top = 5.0
	check_badge.offset_right = -6.0
	check_badge.offset_bottom = 28.0
	check_badge.add_theme_color_override("font_color", EMBER_GLOW)
	check_badge.add_theme_font_size_override("font_size", 20)
	check_badge.visible = false
	check_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(check_badge)

	# ── Lock badge (top-right overlay, shown when locked) ────────────────────
	var lock_badge := Label.new()
	lock_badge.text = "🔒"
	lock_badge.layout_mode = 1
	lock_badge.anchor_left = 1.0
	lock_badge.anchor_right = 1.0
	lock_badge.anchor_top = 0.0
	lock_badge.anchor_bottom = 0.0
	lock_badge.offset_left = -26.0
	lock_badge.offset_top = 8.0
	lock_badge.offset_right = -8.0
	lock_badge.offset_bottom = 28.0
	lock_badge.add_theme_color_override("font_color", Color(FOG, 0.85))
	lock_badge.add_theme_font_size_override("font_size", 16)
	lock_badge.visible = locked
	lock_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(lock_badge)

	# Store entry
	character_card_nodes[char_data.id] = {
		"root": panel,
		"normal_style": normal_style,
		"selected_style": selected_style,
		"check_badge": check_badge,
		"lock_badge": lock_badge,
	}

	if locked:
		panel.modulate = Color(1, 1, 1, 0.5)
		panel.tooltip_text = "Not available in this demo."
		for milestone in DataRegistry.milestone_cache.values():
			if milestone.unlock_type == "character" and milestone.unlock_target == char_data.id:
				panel.tooltip_text = milestone.unlock_hint + " Progress carries across runs."
				break
	else:
		# Hover: show detail panel
		panel.mouse_entered.connect(_on_card_hover.bind(char_data.id))
		panel.mouse_exited.connect(_on_card_hover_exit.bind(char_data.id))
		# Click: toggle selection
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton \
					and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				_on_character_clicked(char_data.id)
		)

	return panel

func _load_portrait_compact(char_data: CharacterData, size: int) -> Control:
	## Returns a square portrait Control (TextureRect or ColorRect placeholder)
	if not char_data.portrait_path.is_empty() and ResourceLoader.exists(char_data.portrait_path):
		var tex = load(char_data.portrait_path)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.custom_minimum_size = Vector2(size, size)
			tr.clip_contents = true
			tr.mouse_filter = Control.MOUSE_FILTER_PASS
			return tr

	# Coloured placeholder with initials
	var role: String = char_data.role.to_lower()
	var role_color: Color = ROLE_COLORS.get(role, Color(0.25, 0.28, 0.38))

	var placeholder := ColorRect.new()
	placeholder.color = Color(role_color, 0.25)
	placeholder.custom_minimum_size = Vector2(size, size)
	placeholder.mouse_filter = Control.MOUSE_FILTER_PASS

	var initials := Label.new()
	initials.text = char_data.display_name.substr(0, 2).to_upper()
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", int(size * 0.4))
	initials.add_theme_color_override("font_color", Color(role_color, 0.9))
	var eb_font = _get_font("extrabold")
	if eb_font:
		initials.add_theme_font_override("font", eb_font)
	initials.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initials.mouse_filter = Control.MOUSE_FILTER_PASS
	placeholder.add_child(initials)

	return placeholder

func _build_stat_pips(char_data: CharacterData, role_color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	var reg_font = _get_font("regular")

	var stats := [
		["STR", char_data.str_base],
		["DEF", char_data.def_base],
		["SPR", char_data.spirit_base],
	]
	for stat_pair in stats:
		var label_str: String = stat_pair[0]
		var value: int = stat_pair[1]

		var group_vbox := VBoxContainer.new()
		group_vbox.add_theme_constant_override("separation", 2)
		group_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_child(group_vbox)

		var lbl := Label.new()
		lbl.text = label_str
		lbl.add_theme_color_override("font_color", Color(FOG, 0.85))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		if reg_font:
			lbl.add_theme_font_override("font", reg_font)
		group_vbox.add_child(lbl)

		var dots_hbox := HBoxContainer.new()
		dots_hbox.add_theme_constant_override("separation", 3)
		dots_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		group_vbox.add_child(dots_hbox)

		for i in range(2):
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(9, 9)
			dot.mouse_filter = Control.MOUSE_FILTER_PASS
			if i < value:
				dot.color = role_color
			else:
				dot.color = Color("#3A3F4A")
			dots_hbox.add_child(dot)

	return hbox

func _build_theme_tags(char_data: CharacterData, role_color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	var reg_font = _get_font("regular")

	var themes := [char_data.theme_1, char_data.theme_2, char_data.theme_3]
	for i in range(themes.size()):
		var theme_str: String = themes[i]
		if theme_str.is_empty():
			continue

		var is_advanced: bool = (i == 2)
		var tag_color: Color = Color(role_color, 0.95) if not is_advanced else Color(EMBER_BRIGHT, 1.0)
		var tag_bg: Color = Color(role_color.r, role_color.g, role_color.b, 0.14) if not is_advanced else Color(EMBER_MID.r, EMBER_MID.g, EMBER_MID.b, 0.12)
		var tag_border: Color = Color(role_color.r, role_color.g, role_color.b, 0.5) if not is_advanced else Color(EMBER_MID.r, EMBER_MID.g, EMBER_MID.b, 0.55)

		var tag_style := StyleBoxFlat.new()
		tag_style.bg_color = tag_bg
		tag_style.set_border_width_all(1)
		tag_style.border_color = tag_border
		tag_style.set_corner_radius_all(2)
		tag_style.content_margin_left = 5
		tag_style.content_margin_right = 5
		tag_style.content_margin_top = 2
		tag_style.content_margin_bottom = 2

		var tag_panel := PanelContainer.new()
		tag_panel.add_theme_stylebox_override("panel", tag_style)
		tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_child(tag_panel)

		var tag_label := Label.new()
		tag_label.text = theme_str.substr(0, 11) + ("…" if theme_str.length() > 11 else "")
		tag_label.clip_text = true
		tag_label.add_theme_color_override("font_color", tag_color)
		tag_label.add_theme_font_size_override("font_size", 9)
		tag_label.mouse_filter = Control.MOUSE_FILTER_PASS
		if reg_font:
			tag_label.add_theme_font_override("font", reg_font)
		tag_panel.add_child(tag_label)

	return hbox

# ─────────────────────────────────────────────────────────────────────────────
# Detail panel
# ─────────────────────────────────────────────────────────────────────────────

func _clear_detail_panel() -> void:
	for child in _detail_content_vbox.get_children():
		child.queue_free()

func _show_detail_empty_state() -> void:
	_detail_character_id = ""
	_clear_detail_panel()
	var reg_font = _get_font("regular")

	var empty_label := Label.new()
	empty_label.text = "Select a character to view their history, themes, and starting cards."
	empty_label.add_theme_color_override("font_color", Color(FOG, 0.55))
	empty_label.add_theme_font_size_override("font_size", 15)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if reg_font:
		empty_label.add_theme_font_override("font", reg_font)
	_detail_content_vbox.add_child(empty_label)

func _show_detail_for_character(char_data: CharacterData) -> void:
	_detail_character_id = char_data.id
	_clear_detail_panel()
	var role: String = char_data.role.to_lower()
	var role_color: Color = ROLE_COLORS.get(role, FOG)
	var reg_font = _get_font("regular")
	var bold_font = _get_font("bold")
	var eb_font = _get_font("extrabold")

	# ── 1. Name row ──────────────────────────────────────────────────────────
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	name_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_detail_content_vbox.add_child(name_row)

	var portrait := _load_portrait_compact(char_data, 80)
	name_row.add_child(portrait)

	var identity_vbox := VBoxContainer.new()
	identity_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_vbox.add_theme_constant_override("separation", 4)
	identity_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	name_row.add_child(identity_vbox)

	var detail_name := Label.new()
	detail_name.text = char_data.display_name
	detail_name.add_theme_color_override("font_color", PALE)
	detail_name.add_theme_font_size_override("font_size", 24)
	detail_name.mouse_filter = Control.MOUSE_FILTER_PASS
	if eb_font:
		detail_name.add_theme_font_override("font", eb_font)
	identity_vbox.add_child(detail_name)

	var arch_line := Label.new()
	arch_line.text = ROLE_ICONS.get(role, "") + "  " + role.capitalize()
	arch_line.add_theme_color_override("font_color", role_color)
	arch_line.add_theme_font_size_override("font_size", 13)
	arch_line.mouse_filter = Control.MOUSE_FILTER_PASS
	if reg_font:
		arch_line.add_theme_font_override("font", reg_font)
	identity_vbox.add_child(arch_line)

	var detail_tags := _build_theme_tags(char_data, role_color)
	identity_vbox.add_child(detail_tags)

	# ── 2. Stats row ──────────────────────────────────────────────────────────
	var stats_hbox := HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 10)
	stats_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_detail_content_vbox.add_child(stats_hbox)

	var stat_defs := [
		["STR", str(char_data.str_base), role_color],
		["DEF", str(char_data.def_base), role_color],
		["SPR", str(char_data.spirit_base), role_color],
		["HP",  str(char_data.hp_base),  EMBER_MID],
	]
	for sd in stat_defs:
		var stat_box_style := StyleBoxFlat.new()
		stat_box_style.bg_color = Color(0, 0, 0, 0.3)
		stat_box_style.set_border_width_all(2)
		stat_box_style.border_color = Color(BORDER_GLOW, 0.5)
		stat_box_style.set_corner_radius_all(5)
		stat_box_style.content_margin_left = 12
		stat_box_style.content_margin_right = 12
		stat_box_style.content_margin_top = 10
		stat_box_style.content_margin_bottom = 10

		var stat_box := PanelContainer.new()
		stat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_box.add_theme_stylebox_override("panel", stat_box_style)
		stat_box.mouse_filter = Control.MOUSE_FILTER_PASS
		stats_hbox.add_child(stat_box)

		var stat_vbox := VBoxContainer.new()
		stat_vbox.add_theme_constant_override("separation", 2)
		stat_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		stat_box.add_child(stat_vbox)

		var stat_lbl := Label.new()
		stat_lbl.text = sd[0]
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_lbl.add_theme_color_override("font_color", sd[2])
		stat_lbl.add_theme_font_size_override("font_size", 11)
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		if reg_font:
			stat_lbl.add_theme_font_override("font", reg_font)
		stat_vbox.add_child(stat_lbl)

		var stat_val := Label.new()
		stat_val.text = sd[1]
		stat_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_val.add_theme_color_override("font_color", PALE)
		stat_val.add_theme_font_size_override("font_size", 24)
		stat_val.mouse_filter = Control.MOUSE_FILTER_PASS
		if bold_font:
			stat_val.add_theme_font_override("font", bold_font)
		stat_vbox.add_child(stat_val)

	# ── 3. Starting cards ─────────────────────────────────────────────────────
	_detail_content_vbox.add_child(_build_section_label("STARTING CARDS"))
	var cards := char_data.starter_unique_cards
	if cards.is_empty():
		var no_cards_lbl := Label.new()
		no_cards_lbl.text = "No signature cards."
		no_cards_lbl.add_theme_color_override("font_color", Color(FOG, 0.6))
		no_cards_lbl.add_theme_font_size_override("font_size", 10)
		no_cards_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		_detail_content_vbox.add_child(no_cards_lbl)
	else:
		for card in cards:
			if card:
				_detail_content_vbox.add_child(_build_card_detail_row(card))

	# ── 4. Themes ─────────────────────────────────────────────────────────────
	_detail_content_vbox.add_child(_build_section_label("THEMES"))
	var theme_list := [
		["1.", char_data.theme_1],
		["2.", char_data.theme_2],
		["★", char_data.theme_3],
	]
	var any_theme := false
	for td in theme_list:
		if td[1].is_empty():
			continue
		any_theme = true
		var theme_row := HBoxContainer.new()
		theme_row.add_theme_constant_override("separation", 12)
		theme_row.mouse_filter = Control.MOUSE_FILTER_PASS
		_detail_content_vbox.add_child(theme_row)

		var num_lbl := Label.new()
		num_lbl.text = td[0]
		num_lbl.custom_minimum_size.x = 22
		num_lbl.add_theme_color_override("font_color", Color(FOG, 0.6))
		num_lbl.add_theme_font_size_override("font_size", 12)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		if reg_font:
			num_lbl.add_theme_font_override("font", reg_font)
		theme_row.add_child(num_lbl)

		var theme_lbl := Label.new()
		theme_lbl.text = td[1]
		theme_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_lbl.add_theme_color_override("font_color", EMBER_BRIGHT)
		theme_lbl.add_theme_font_size_override("font_size", 14)
		theme_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		theme_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		if reg_font:
			theme_lbl.add_theme_font_override("font", reg_font)
		theme_row.add_child(theme_lbl)
		# TODO: add theme_desc fields to CharacterData for one-line descriptions

	if not any_theme:
		var no_theme_lbl := Label.new()
		no_theme_lbl.text = "No themes defined."
		no_theme_lbl.add_theme_color_override("font_color", Color(FOG, 0.5))
		no_theme_lbl.add_theme_font_size_override("font_size", 10)
		no_theme_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		_detail_content_vbox.add_child(no_theme_lbl)

	# ── 5. Quest (seed) ───────────────────────────────────────────────────────
	_detail_content_vbox.add_child(_build_section_label("QUEST (SEED)"))
	if char_data.quests.is_empty():
		var no_quest := Label.new()
		no_quest.text = "No quests assigned."
		no_quest.add_theme_color_override("font_color", Color(FOG, 0.5))
		no_quest.add_theme_font_size_override("font_size", 10)
		no_quest.mouse_filter = Control.MOUSE_FILTER_PASS
		_detail_content_vbox.add_child(no_quest)
	else:
		for quest in char_data.quests:
			if not quest:
				continue
			var quest_style := StyleBoxFlat.new()
			quest_style.bg_color = Color(0, 0, 0, 0.25)
			quest_style.set_border_width_all(1)
			quest_style.border_color = Color(BORDER_GLOW, 0.4)
			quest_style.border_width_left = 4
			# Override just the left border color using the per-side border color approach.
			# StyleBoxFlat uses a single border_color for all sides; to simulate a coloured
			# left accent we set border_color to EMBER_MID (dominant left edge) and keep
			# bg_color dark so the overall impression reads as a left-accent panel.
			quest_style.border_color = EMBER_MID
			quest_style.set_corner_radius_all(4)
			quest_style.content_margin_left = 14
			quest_style.content_margin_right = 14
			quest_style.content_margin_top = 12
			quest_style.content_margin_bottom = 12

			var quest_panel := PanelContainer.new()
			quest_panel.add_theme_stylebox_override("panel", quest_style)
			quest_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			quest_panel.mouse_filter = Control.MOUSE_FILTER_PASS
			_detail_content_vbox.add_child(quest_panel)

			var quest_vbox := VBoxContainer.new()
			quest_vbox.add_theme_constant_override("separation", 5)
			quest_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
			quest_panel.add_child(quest_vbox)

			var quest_title := Label.new()
			quest_title.text = quest.title if not quest.title.is_empty() else "Unnamed Quest"
			quest_title.add_theme_color_override("font_color", PALE)
			quest_title.add_theme_font_size_override("font_size", 15)
			quest_title.mouse_filter = Control.MOUSE_FILTER_PASS
			if bold_font:
				quest_title.add_theme_font_override("font", bold_font)
			quest_vbox.add_child(quest_title)

			if not quest.description.is_empty():
				var quest_desc := Label.new()
				quest_desc.text = quest.description
				quest_desc.add_theme_color_override("font_color", FOG)
				quest_desc.add_theme_font_size_override("font_size", 13)
				quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				quest_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				quest_desc.mouse_filter = Control.MOUSE_FILTER_PASS
				if reg_font:
					quest_desc.add_theme_font_override("font", reg_font)
				quest_vbox.add_child(quest_desc)

	# ── 6. Key synergies ──────────────────────────────────────────────────────
	_detail_content_vbox.add_child(_build_section_label("KEY SYNERGIES"))
	var shown: int = 0
	for pid in selected_character_ids:
		if pid == char_data.id:
			continue
		var desc: String = SynergyData.get_synergy(char_data.id, pid)
		if desc.is_empty():
			continue
		var partner = DataRegistry.get_character(pid) if DataRegistry else null
		var partner_name: String = partner.display_name if partner else pid
		var partner_role: String = partner.role.to_lower() if partner else ""
		var partner_color: Color = ROLE_COLORS.get(partner_role, FOG)

		var synergy_row := VBoxContainer.new()
		synergy_row.add_theme_constant_override("separation", 2)
		synergy_row.mouse_filter = Control.MOUSE_FILTER_PASS

		var partner_label := Label.new()
		partner_label.text = partner_name.to_upper()
		partner_label.add_theme_color_override("font_color", partner_color)
		partner_label.add_theme_font_size_override("font_size", 12)
		partner_label.mouse_filter = Control.MOUSE_FILTER_PASS
		if bold_font:
			partner_label.add_theme_font_override("font", bold_font)
		synergy_row.add_child(partner_label)

		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.add_theme_color_override("font_color", FOG)
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.mouse_filter = Control.MOUSE_FILTER_PASS
		if reg_font:
			desc_label.add_theme_font_override("font", reg_font)
		synergy_row.add_child(desc_label)

		_detail_content_vbox.add_child(synergy_row)
		shown += 1

	if shown == 0:
		var synergy_placeholder := Label.new()
		if selected_character_ids.is_empty() or (selected_character_ids.size() == 1 and selected_character_ids[0] == char_data.id):
			synergy_placeholder.text = "Synergies revealed as party forms."
		else:
			synergy_placeholder.text = "No signature synergies with the current party."
		synergy_placeholder.add_theme_color_override("font_color", Color(FOG, 0.55))
		synergy_placeholder.add_theme_font_size_override("font_size", 14)
		synergy_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		synergy_placeholder.mouse_filter = Control.MOUSE_FILTER_PASS
		if reg_font:
			synergy_placeholder.add_theme_font_override("font", reg_font)
		_detail_content_vbox.add_child(synergy_placeholder)

func _build_section_label(text: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	# Top spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(spacer)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", EMBER_MID)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	var reg_font = _get_font("regular")
	if reg_font:
		lbl.add_theme_font_override("font", reg_font)
	vbox.add_child(lbl)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(EMBER_MID, 0.25))
	sep.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(sep)

	return vbox

func _build_card_detail_row(card: CardData) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS

	var card_type_idx: int = int(card.card_type)
	var type_color: Color = CARD_TYPE_COLORS.get(card_type_idx, Color("#808080"))
	var reg_font = _get_font("regular")
	var bold_font = _get_font("bold")

	# Cost pip (circle)
	var pip_style := StyleBoxFlat.new()
	pip_style.bg_color = Color(0, 0, 0, 0.5)
	pip_style.set_border_width_all(1)
	pip_style.border_color = Color(EMBER_MID, 0.6)
	pip_style.set_corner_radius_all(14)
	pip_style.content_margin_left = 4
	pip_style.content_margin_right = 4
	pip_style.content_margin_top = 2
	pip_style.content_margin_bottom = 2

	var pip_panel := PanelContainer.new()
	pip_panel.custom_minimum_size = Vector2(28, 28)
	pip_panel.add_theme_stylebox_override("panel", pip_style)
	pip_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(pip_panel)

	var cost_lbl := Label.new()
	cost_lbl.text = str(card.cost)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_color_override("font_color", Color("#D4A847"))
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if bold_font:
		cost_lbl.add_theme_font_override("font", bold_font)
	pip_panel.add_child(cost_lbl)

	# Type colour stripe
	var stripe := ColorRect.new()
	stripe.color = type_color
	stripe.custom_minimum_size = Vector2(3, 0)
	stripe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stripe.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(stripe)

	# Text VBox
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 4)
	text_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(text_vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	name_row.mouse_filter = Control.MOUSE_FILTER_PASS
	text_vbox.add_child(name_row)

	var card_name := Label.new()
	card_name.text = card.name
	card_name.add_theme_color_override("font_color", PALE)
	card_name.add_theme_font_size_override("font_size", 14)
	card_name.mouse_filter = Control.MOUSE_FILTER_PASS
	if bold_font:
		card_name.add_theme_font_override("font", bold_font)
	name_row.add_child(card_name)

	var type_name_str: String = CARD_TYPE_NAMES[card_type_idx] if card_type_idx < CARD_TYPE_NAMES.size() else "???"
	var type_lbl := Label.new()
	type_lbl.text = type_name_str
	type_lbl.add_theme_color_override("font_color", type_color)
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if reg_font:
		type_lbl.add_theme_font_override("font", reg_font)
	name_row.add_child(type_lbl)

	var effect_text := _build_effect_text(card)
	if not effect_text.is_empty():
		var effect_lbl := Label.new()
		effect_lbl.text = effect_text
		effect_lbl.add_theme_color_override("font_color", FOG)
		effect_lbl.add_theme_font_size_override("font_size", 13)
		effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		effect_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		if reg_font:
			effect_lbl.add_theme_font_override("font", reg_font)
		text_vbox.add_child(effect_lbl)

	return hbox

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
	if result.length() > 80:
		result = result.substr(0, 77) + "…"
	return result

# ─────────────────────────────────────────────────────────────────────────────
# Interaction handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_card_hover(char_id: String) -> void:
	hovered_character_id = char_id
	var char_data = DataRegistry.get_character(char_id) if DataRegistry else null
	if char_data:
		_show_detail_for_character(char_data)

func _on_card_hover_exit(char_id: String) -> void:
	if hovered_character_id != char_id:
		return
	hovered_character_id = ""
	if selected_character_ids.is_empty():
		_show_detail_empty_state()
	else:
		var last_id: String = selected_character_ids.back()
		var char_data = DataRegistry.get_character(last_id) if DataRegistry else null
		if char_data:
			_show_detail_for_character(char_data)
		else:
			_show_detail_empty_state()

func _on_character_clicked(char_id: String) -> void:
	if _is_character_locked(char_id):
		return
	if char_id in selected_character_ids:
		selected_character_ids.erase(char_id)
	else:
		if selected_character_ids.size() < 3:
			selected_character_ids.append(char_id)
		else:
			return
	_update_ui()

func _on_slot_remove_pressed(index: int) -> void:
	if index >= selected_character_ids.size():
		return
	selected_character_ids.remove_at(index)
	_update_ui()

# ─────────────────────────────────────────────────────────────────────────────
# Update functions
# ─────────────────────────────────────────────────────────────────────────────

func _update_ui() -> void:
	_update_card_visuals()
	_update_footer_slots()
	_update_hp_badge()
	_update_count_label()
	_update_confirm_button()
	# Re-render the open detail panel so its synergy section tracks the party
	if _detail_character_id != "":
		var detail_char = DataRegistry.get_character(_detail_character_id) if DataRegistry else null
		if detail_char:
			_show_detail_for_character(detail_char)

func _update_card_visuals() -> void:
	var party_full: bool = selected_character_ids.size() >= 3
	for char_id in character_card_nodes:
		var entry: Dictionary = character_card_nodes[char_id]
		var panel: PanelContainer = entry.get("root")
		if not is_instance_valid(panel):
			continue
		if _is_character_locked(char_id):
			continue  # modulate set once at build; no style change
		var is_selected: bool = char_id in selected_character_ids
		var check_badge: Label = entry.get("check_badge")
		if is_selected:
			panel.add_theme_stylebox_override("panel", entry["selected_style"])
			panel.modulate = Color(1, 1, 1, 1)
			if is_instance_valid(check_badge):
				check_badge.visible = true
		elif party_full:
			panel.add_theme_stylebox_override("panel", entry["normal_style"])
			panel.modulate = Color(1, 1, 1, 0.4)
			if is_instance_valid(check_badge):
				check_badge.visible = false
		else:
			panel.add_theme_stylebox_override("panel", entry["normal_style"])
			panel.modulate = Color(1, 1, 1, 1)
			if is_instance_valid(check_badge):
				check_badge.visible = false

func _update_footer_slots() -> void:
	for i in range(3):
		var slot: Dictionary = _footer_slot_displays[i]
		var slot_panel: PanelContainer = slot["panel"]
		var portrait_area: Control = slot["portrait_area"]
		var remove_btn: Button = slot["remove_btn"]
		var plus_label: Label = slot["plus_label"]

		if i < selected_character_ids.size():
			# Slot filled
			slot_panel.add_theme_stylebox_override("panel", slot["filled_style"])

			# Clear old portrait
			var old_portrait = slot.get("portrait_node")
			if is_instance_valid(old_portrait):
				old_portrait.queue_free()
			slot["portrait_node"] = null

			# Build new portrait thumbnail
			var char_id: String = selected_character_ids[i]
			var char_data = DataRegistry.get_character(char_id) if DataRegistry else null
			if char_data:
				var thumb := _load_portrait_compact(char_data, 36)
				thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
				thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
				portrait_area.add_child(thumb)
				slot["portrait_node"] = thumb

			if is_instance_valid(plus_label):
				plus_label.visible = false
		else:
			# Slot empty
			slot_panel.add_theme_stylebox_override("panel", slot["empty_style"])
			var old_portrait = slot.get("portrait_node")
			if is_instance_valid(old_portrait):
				old_portrait.queue_free()
			slot["portrait_node"] = null
			if is_instance_valid(remove_btn):
				remove_btn.visible = false
			if is_instance_valid(plus_label):
				plus_label.visible = true

func _update_hp_badge() -> void:
	var total: int = 0
	for char_id in selected_character_ids:
		var char_data = DataRegistry.get_character(char_id) if DataRegistry else null
		if char_data:
			total += char_data.hp_base

	if not is_instance_valid(_hp_value_label) or not is_instance_valid(_hp_badge_style):
		return

	if selected_character_ids.is_empty():
		_hp_value_label.text = "—"
		_hp_value_label.add_theme_color_override("font_color", PALE)
		_hp_badge_style.border_color = Color(FOG, 0.4)
	else:
		_hp_value_label.text = str(total)
		var hp_color: Color
		if total >= 75:
			hp_color = HP_GREEN
		elif total >= 70:
			hp_color = HP_GOLD
		else:
			hp_color = HP_RED
		_hp_value_label.add_theme_color_override("font_color", hp_color)
		_hp_badge_style.border_color = Color(hp_color, 0.6)
	# Re-apply to trigger redraw
	if is_instance_valid(_hp_badge_panel):
		_hp_badge_panel.add_theme_stylebox_override("panel", _hp_badge_style)

func _update_count_label() -> void:
	if is_instance_valid(_count_label):
		_count_label.text = "%d / 3 selected" % selected_character_ids.size()

func _update_confirm_button() -> void:
	if is_instance_valid(_confirm_button):
		_confirm_button.disabled = selected_character_ids.size() != 3

# ─────────────────────────────────────────────────────────────────────────────
# Confirm (unchanged logic)
# ─────────────────────────────────────────────────────────────────────────────

func _on_confirm_pressed() -> void:
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
