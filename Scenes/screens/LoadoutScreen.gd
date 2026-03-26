extends Control

## Pre-run loadout screen — step 3 of the pre-run flow (after party select).
## Displays per-character equipment slots and the run stash.
## Player configures equipment, then presses "Start Run" to begin.
##
## Run initialisation (starter deck + map) happens HERE so that
## equipment injected_cards are included in the starting deck.

# ── UI refs (built in _ready) ────────────────────────────────────────────────
var scroll_root: ScrollContainer = null
var character_panels: Dictionary = {}  # char_id -> Dictionary of slot buttons
var stash_container: HBoxContainer = null
var start_btn: Button = null
var stash_label: Label = null
var _modifier_score_label: Label = null
var _modifier_check_buttons: Dictionary = {}  # modifier_id -> CheckButton

# ── State ────────────────────────────────────────────────────────────────────
var _selected_stash_id: String = ""  # equipment_id currently selected from stash
var _selected_slot_char: String = ""
var _selected_slot_name: String = ""

func _ready():
	_build_ui()
	_load_stash_from_meta()
	refresh_from_state()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui():
	## Construct the entire loadout screen programmatically.
	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 12)
	add_child(root_vbox)

	# Title
	var title = Label.new()
	title.text = "Loadout"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	root_vbox.add_child(title)

	# Character panels row
	scroll_root = ScrollContainer.new()
	scroll_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_root.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root_vbox.add_child(scroll_root)

	var panels_hbox = HBoxContainer.new()
	panels_hbox.add_theme_constant_override("separation", 20)
	scroll_root.add_child(panels_hbox)

	for char_id in PartyManager.get_party_ids():
		var panel = _build_character_panel(char_id)
		panels_hbox.add_child(panel)

	# Stash section
	stash_label = Label.new()
	stash_label.text = "Stash (0/%d) — click an item then click a slot to equip" % RunState.MAX_STASH_SIZE
	stash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(stash_label)

	stash_container = HBoxContainer.new()
	stash_container.add_theme_constant_override("separation", 8)
	root_vbox.add_child(stash_container)

	# Difficulty modifiers section
	root_vbox.add_child(_build_modifier_panel())

	# Start Run button
	start_btn = Button.new()
	start_btn.text = "Start Run"
	start_btn.custom_minimum_size = Vector2(200, 50)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.pressed.connect(_on_start_run_pressed)
	root_vbox.add_child(start_btn)

func _build_character_panel(char_id: String) -> Control:
	## Build one character's equipment panel (name + 6 slot buttons).
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Character name header
	var char_data = DataRegistry.get_character(char_id) if DataRegistry else null
	var name_lbl = Label.new()
	name_lbl.text = char_data.display_name if char_data else char_id
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)

	# Six slot buttons
	var slot_buttons: Dictionary = {}
	for slot_name in EquipmentData.all_slot_names():
		var hbox = HBoxContainer.new()
		var slot_lbl = Label.new()
		slot_lbl.text = slot_name + ":"
		slot_lbl.custom_minimum_size = Vector2(90, 0)
		hbox.add_child(slot_lbl)

		var slot_btn = Button.new()
		slot_btn.text = "(empty)"
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.pressed.connect(_on_slot_clicked.bind(char_id, slot_name))
		hbox.add_child(slot_btn)

		vbox.add_child(hbox)
		slot_buttons[slot_name] = slot_btn

	character_panels[char_id] = slot_buttons
	return panel

# ── Meta save integration ─────────────────────────────────────────────────────

func _load_stash_from_meta():
	## Populate run_stash from persistent meta save.
	## Items already equipped are left in place; unequipped items go to run stash.
	if not SaveManager:
		return
	var persistent: Array[String] = SaveManager.load_persistent_stash()
	# Add persistent items to run stash (up to max)
	for equip_id in persistent:
		if RunState.run_stash.size() < RunState.MAX_STASH_SIZE:
			if not RunState.run_stash.has(equip_id):
				RunState.run_stash.append(equip_id)

# ── Refresh ───────────────────────────────────────────────────────────────────

func refresh_from_state():
	## Sync all slot buttons and stash display with RunState.
	_refresh_slot_buttons()
	_refresh_stash()

func _refresh_slot_buttons():
	for char_id in character_panels:
		var slot_buttons: Dictionary = character_panels[char_id]
		for slot_name in slot_buttons:
			var equip_id: String = RunState.get_equipped_item(char_id, slot_name)
			var btn: Button = slot_buttons[slot_name]
			if equip_id.is_empty():
				btn.text = "(empty)"
				btn.modulate = Color.WHITE
			else:
				var equip_data = DataRegistry.get_equipment(equip_id) if DataRegistry else null
				btn.text = equip_data.name if equip_data else equip_id
				btn.modulate = Color(0.7, 1.0, 0.7)

func _refresh_stash():
	## Rebuild stash item buttons from run_stash.
	for child in stash_container.get_children():
		stash_container.remove_child(child)
		child.queue_free()

	for equip_id in RunState.run_stash:
		var equip_data = DataRegistry.get_equipment(equip_id) if DataRegistry else null
		var btn = Button.new()
		btn.text = equip_data.name if equip_data else equip_id
		btn.custom_minimum_size = Vector2(120, 40)
		btn.pressed.connect(_on_stash_item_clicked.bind(equip_id))
		if equip_id == _selected_stash_id:
			btn.modulate = Color(1.0, 1.0, 0.4)  # Yellow highlight when selected
		stash_container.add_child(btn)

	if stash_label:
		stash_label.text = "Stash (%d/%d) — click an item then click a slot to equip" % [
			RunState.run_stash.size(), RunState.MAX_STASH_SIZE
		]

# ── Interaction ───────────────────────────────────────────────────────────────

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

# ── Difficulty Modifiers ──────────────────────────────────────────────────────

func _build_modifier_panel() -> Control:
	## Build the difficulty modifier section: a labelled panel with one toggle
	## per available modifier, plus a live score-multiplier preview.
	var panel := PanelContainer.new()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Header row
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)

	var header_label := Label.new()
	header_label.text = "Difficulty Modifiers"
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_label)

	_modifier_score_label = Label.new()
	_modifier_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_hbox.add_child(_modifier_score_label)

	# One row per modifier
	var available: Array = ModifierManager.get_available_modifiers() if ModifierManager else []
	if available.is_empty():
		var none_label := Label.new()
		none_label.text = "No modifiers available."
		none_label.modulate = Color(0.6, 0.6, 0.6)
		vbox.add_child(none_label)
	else:
		for mod in available:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			vbox.add_child(row)

			var check := CheckButton.new()
			check.text = mod["name"]
			check.button_pressed = ModifierManager.is_selected(mod["id"])
			check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var mid: String = mod["id"]
			check.toggled.connect(func(_on: bool): _on_modifier_toggled(mid))
			_modifier_check_buttons[mod["id"]] = check
			row.add_child(check)

			var desc := Label.new()
			desc.text = mod.get("description", "")
			desc.modulate = Color(0.75, 0.75, 0.75)
			desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(desc)

	_refresh_modifier_score_label()

	# Connect to future changes (e.g. from another screen or undo)
	if ModifierManager and not ModifierManager.modifiers_changed.is_connected(_on_modifiers_changed):
		ModifierManager.modifiers_changed.connect(_on_modifiers_changed)

	return panel


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


# ── Start Run ─────────────────────────────────────────────────────────────────

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
