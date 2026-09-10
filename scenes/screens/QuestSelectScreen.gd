extends Control

## Quest Select -- step 3 of the pre-run wizard (Party -> Loadout -> Quests).
## Shows each party member's quest pool; the player picks exactly one quest per
## character. Selections default to whatever QuestManager already assigned
## (random pick from CharacterSelect), so "Begin Run" is always enabled.
##
## Card-Clock Spec Addendum B §1: uses the same shared step bar, background,
## panel styling, header and footer as CharacterSelect / LoadoutScreen so this
## no longer reads as a different game.

const DEBUG_PANEL_SCRIPT = preload("res://scenes/ui/debug/DebugPanel.gd")
const PRE_RUN_CHROME = preload("res://scenes/ui/PreRunChrome.gd")

const ROLE_COLORS := {
	"warrior": Color("#C43030"),
	"healer": Color("#4A9A60"),
	"defender": Color("#3A70C4"),
}
const EMBER := Color("#E8A020")
const PALE := Color("#F0E6C8")
const FOG := Color("#A09070")
const CARD_BG := Color("#1A1F2BEE")
const BORDER_DIM := Color("#4A5060")

# char_id -> quest_id
var _selected: Dictionary = {}
# char_id -> { quest_id -> PanelContainer }
var _quest_panels: Dictionary = {}

var _begin_btn: Button = null

func _ready() -> void:
	_build_ui()
	DEBUG_PANEL_SCRIPT.attach_to(self, "quest_select")

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Shared background + vignette (same art as CharacterSelect / LoadoutScreen)
	PRE_RUN_CHROME.ensure_background(self)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# ── Header (shared pre-run chrome, step 3 = Quests) ──────────────────────
	root_vbox.add_child(PRE_RUN_CHROME.build_header(2, "CHOOSE YOUR QUESTS"))

	# ── Body (inset, matches LoadoutScreen's body margins) ───────────────────
	var body_margin := MarginContainer.new()
	body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 60)
	body_margin.add_theme_constant_override("margin_right", 60)
	body_margin.add_theme_constant_override("margin_top", 20)
	body_margin.add_theme_constant_override("margin_bottom", 20)
	root_vbox.add_child(body_margin)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 16)
	body_margin.add_child(body_vbox)

	var subtitle := Label.new()
	subtitle.text = "Each companion carries one quest into the run. Complete all three to unlock the final boss."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", FOG)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_vbox.add_child(subtitle)

	# Character columns
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_vbox.add_child(columns)

	var party_ids: Array = PartyManager.get_party_ids() if PartyManager else []
	for char_id in party_ids:
		var char_data: CharacterData = DataRegistry.get_character(char_id) if DataRegistry else null
		if not char_data:
			continue
		columns.add_child(_build_character_column(char_data))

	# ── Footer (shared pre-run chrome): Back bottom-left, Begin bottom-right ─
	var nav := PRE_RUN_CHROME.build_footer(
		"← Loadout", func(): ScreenManager.go_to_loadout(),
		"BEGIN RUN", _on_begin_pressed
	)
	_begin_btn = nav["next_btn"]
	root_vbox.add_child(nav["panel"])

	_update_begin_button()

func _build_character_column(char_data: CharacterData) -> PanelContainer:
	var role: String = char_data.role.to_lower()
	var role_color: Color = ROLE_COLORS.get(role, FOG)

	var col_panel := PanelContainer.new()
	var col_style := StyleBoxFlat.new()
	col_style.bg_color = CARD_BG
	col_style.set_border_width_all(2)
	col_style.border_color = Color(role_color, 0.5)
	col_style.set_corner_radius_all(6)
	col_style.set_content_margin_all(18)
	col_panel.add_theme_stylebox_override("panel", col_style)
	col_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	col_panel.add_child(vbox)

	# Character header
	var name_label := Label.new()
	name_label.text = char_data.display_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", PALE)
	vbox.add_child(name_label)

	var role_label := Label.new()
	role_label.text = char_data.role.to_upper()
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override("font_color", role_color)
	vbox.add_child(role_label)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", BORDER_DIM)
	vbox.add_child(sep)

	# Quest options
	_quest_panels[char_data.id] = {}

	# Default selection: whatever QuestManager already assigned (random from CharacterSelect)
	var current: QuestState = QuestManager.get_quest(char_data.id) if QuestManager else null
	if current:
		_selected[char_data.id] = current.quest_id
	elif not char_data.quests.is_empty():
		_selected[char_data.id] = char_data.quests[0].id

	for quest in char_data.quests:
		var quest_panel := _build_quest_option(char_data, quest, role_color)
		_quest_panels[char_data.id][quest.id] = quest_panel
		vbox.add_child(quest_panel)

	_refresh_column_visuals(char_data.id)
	return col_panel

func _build_quest_option(char_data: CharacterData, quest: QuestData, role_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vbox)

	var title := Label.new()
	title.text = quest.title
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", PALE)
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = quest.description
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", FOG)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(desc)

	var reward_gold: int = int(quest.reward.get("gold", 0)) if quest.reward is Dictionary else 0
	if reward_gold > 0:
		var reward_label := Label.new()
		reward_label.text = "Reward: %d gold" % reward_gold
		reward_label.add_theme_font_size_override("font_size", 12)
		reward_label.add_theme_color_override("font_color", Color(EMBER, 0.9))
		reward_label.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(reward_label)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_quest_clicked(char_data.id, quest.id)
	)
	return panel

func _on_quest_clicked(char_id: String, quest_id: String) -> void:
	_selected[char_id] = quest_id
	_refresh_column_visuals(char_id)
	_update_begin_button()

func _refresh_column_visuals(char_id: String) -> void:
	var panels: Dictionary = _quest_panels.get(char_id, {})
	for quest_id in panels:
		var panel: PanelContainer = panels[quest_id]
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_content_margin_all(12)
		if _selected.get(char_id, "") == quest_id:
			style.bg_color = Color("#2A2010CC")
			style.set_border_width_all(2)
			style.border_color = EMBER
		else:
			style.bg_color = Color("#12161ECC")
			style.set_border_width_all(1)
			style.border_color = Color(BORDER_DIM, 0.6)
		panel.add_theme_stylebox_override("panel", style)

func _update_begin_button() -> void:
	if not _begin_btn:
		return
	var party_ids: Array = PartyManager.get_party_ids() if PartyManager else []
	var all_chosen := not party_ids.is_empty()
	for char_id in party_ids:
		if not _selected.has(char_id):
			all_chosen = false
			break
	_begin_btn.disabled = not all_chosen

func _on_begin_pressed() -> void:
	# Apply chosen quests
	var party_ids: Array = PartyManager.get_party_ids() if PartyManager else []
	for char_id in party_ids:
		var char_data: CharacterData = DataRegistry.get_character(char_id) if DataRegistry else null
		if char_data and _selected.has(char_id):
			QuestManager.set_quest_choice(char_data, _selected[char_id])

	# Save with the chosen quests locked in
	if AutoSaveManager:
		AutoSaveManager.force_save("quests_chosen")

	ScreenManager.go_to_map()
