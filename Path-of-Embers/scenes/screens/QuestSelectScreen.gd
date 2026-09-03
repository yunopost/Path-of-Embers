extends Control

## Quest Select — step 4 of the pre-run wizard (Party → Modifiers → Loadout → Quests).
## Shows each party member's quest pool; the player picks exactly one quest per
## character. Selections default to whatever QuestManager already assigned
## (random pick from CharacterSelect), so "Begin Run" is always enabled.

const ROLE_COLORS := {
	"warrior": Color("#C0392B"),
	"healer": Color("#27AE60"),
	"defender": Color("#2980B9"),
}
const EMBER := Color(0.85, 0.50, 0.15)
const PALE := Color(0.92, 0.89, 0.84)
const FOG := Color(0.62, 0.64, 0.68)

# char_id -> quest_id
var _selected: Dictionary = {}
# char_id -> { quest_id -> PanelContainer }
var _quest_panels: Dictionary = {}

var _begin_btn: Button = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 80
	root.offset_right = -80
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	# Header
	var title := Label.new()
	title.text = "CHOOSE YOUR QUESTS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", PALE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Each companion carries one quest into the run. Complete all three to unlock the final boss."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", FOG)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)

	# Character columns
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var party_ids: Array = PartyManager.get_party_ids() if PartyManager else []
	for char_id in party_ids:
		var char_data: CharacterData = DataRegistry.get_character(char_id) if DataRegistry else null
		if not char_data:
			continue
		columns.add_child(_build_character_column(char_data))

	# Footer: back + begin
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(footer)

	var back_btn := Button.new()
	back_btn.text = "← Loadout"
	back_btn.custom_minimum_size = Vector2(160, 52)
	back_btn.pressed.connect(func(): ScreenManager.go_to_loadout())
	footer.add_child(back_btn)

	_begin_btn = Button.new()
	_begin_btn.text = "BEGIN RUN"
	_begin_btn.custom_minimum_size = Vector2(220, 52)
	_begin_btn.pressed.connect(_on_begin_pressed)
	footer.add_child(_begin_btn)

	_update_begin_button()

func _build_character_column(char_data: CharacterData) -> PanelContainer:
	var role: String = char_data.role.to_lower()
	var role_color: Color = ROLE_COLORS.get(role, FOG)

	var col_panel := PanelContainer.new()
	var col_style := StyleBoxFlat.new()
	col_style.bg_color = Color(0.10, 0.09, 0.09)
	col_style.set_border_width_all(1)
	col_style.border_color = Color(role_color, 0.35)
	col_style.set_corner_radius_all(4)
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

	vbox.add_child(HSeparator.new())

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
		style.set_corner_radius_all(3)
		style.set_content_margin_all(12)
		if _selected.get(char_id, "") == quest_id:
			style.bg_color = Color(0.18, 0.13, 0.08)
			style.set_border_width_all(2)
			style.border_color = EMBER
		else:
			style.bg_color = Color(0.13, 0.12, 0.12)
			style.set_border_width_all(1)
			style.border_color = Color(0.35, 0.33, 0.30, 0.5)
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
