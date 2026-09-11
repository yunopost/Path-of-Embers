extends Control

## Map-screen backpack / re-gear panel (Card-Clock Spec Addendum B §2/§3/§5).
## Built entirely in code (same pattern as the other screens) and added as an
## overlay child of MapScreen, toggled by its "Backpack" button.
##
## Shows the 9-slot run backpack (slot 1 marked SAFE) next to every party
## member's equipped slots, and lets the player swap between them by drag and
## drop OR click-to-select-then-click-target. Slot-type restrictions still
## apply (RunState.can_swap_backpack_item); an illegal drop/click says why.

const EQUIP_DND = preload("res://scenes/ui/equipment/EquipDragDrop.gd")

const SLOT_ICONS := {
	"HELMET": "🪖", "CHEST": "🛡", "LEGS": "🦺",
	"BOOTS": "👢", "WEAPON": "⚔", "RELIC_SLOT": "✨",
}
const RARITY_COLORS := {
	0: Color("#6A7080"), 1: Color("#3A8080"), 2: Color("#C4821A"),
}
const INK := Color("#0D0C0A")
const EMBER_MID := Color("#C4821A")
const PALE := Color("#F0E6C8")
const FOG := Color("#A09070")

var _backpack_tiles: Array[PanelContainer] = []   # index -> tile
var _slot_buttons: Dictionary = {}                # char_id -> slot_name -> Button
var _selected_backpack_index: int = -1
var _backpack_grid: GridContainer = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	if RunState and not RunState.backpack_changed.is_connected(_on_backpack_changed):
		RunState.backpack_changed.connect(_on_backpack_changed)
	if RunState and not RunState.equipment_changed.is_connected(_on_backpack_changed):
		RunState.equipment_changed.connect(_on_backpack_changed)

func _on_backpack_changed() -> void:
	_refresh()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = INK
	panel_style.set_border_width_all(2)
	panel_style.border_color = EMBER_MID
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 560)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "BACKPACK"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#E8A020"))
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	var subtitle := Label.new()
	subtitle.text = "Drag gear between your backpack and equipped slots, or click one then the other. Equipment is kept for this run. New Run starts with fresh gear."
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", FOG)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(subtitle)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	body.add_child(_build_backpack_grid())

	var chars_scroll := ScrollContainer.new()
	chars_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chars_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(chars_scroll)

	var chars_hbox := HBoxContainer.new()
	chars_hbox.add_theme_constant_override("separation", 12)
	chars_scroll.add_child(chars_hbox)

	if PartyManager:
		for char_id in PartyManager.get_party_ids():
			chars_hbox.add_child(_build_character_column(char_id))

	_refresh()

func _build_backpack_grid() -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(240, 0)
	vbox.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = "RUN BACKPACK"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#E8A020"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	_backpack_grid = GridContainer.new()
	_backpack_grid.columns = 3
	_backpack_grid.add_theme_constant_override("h_separation", 6)
	_backpack_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_backpack_grid)

	# The grid itself is also a drop target: dropping an equipped item with no
	# specific tile underneath still unequips it back to the backpack.
	EQUIP_DND.attach_target(_backpack_grid,
		func(_pos, data): return data.get("source", "") == "slot",
		func(_pos, data): _handle_unequip_drop(data)
	)

	return vbox

func _build_character_column(char_id: String) -> Control:
	var char_data: CharacterData = DataRegistry.get_character(char_id) if DataRegistry else null

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(200, 0)
	col.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = (char_data.display_name if char_data else char_id).to_upper()
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", PALE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)

	var slot_buttons: Dictionary = {}
	for slot_name in EquipmentData.all_slot_names():
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		col.add_child(hbox)

		var icon_lbl := Label.new()
		icon_lbl.text = SLOT_ICONS.get(slot_name, "◆")
		icon_lbl.custom_minimum_size = Vector2(20, 0)
		hbox.add_child(icon_lbl)

		var btn := Button.new()
		btn.text = "(empty)"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 11)
		btn.clip_text = true
		btn.pressed.connect(_on_slot_clicked.bind(char_id, slot_name))
		hbox.add_child(btn)

		slot_buttons[slot_name] = btn

	_slot_buttons[char_id] = slot_buttons
	return col

# ── Refresh ────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_refresh_backpack_grid()
	_refresh_slots()

func _refresh_backpack_grid() -> void:
	if not _backpack_grid:
		return
	for child in _backpack_grid.get_children():
		_backpack_grid.remove_child(child)
		child.queue_free()
	_backpack_tiles.clear()

	for i in range(RunState.BACKPACK_SIZE):
		var equipment_id: String = RunState.backpack[i] if i < RunState.backpack.size() else ""
		_backpack_grid.add_child(_build_backpack_tile(i, equipment_id))

func _build_backpack_tile(index: int, equipment_id: String) -> PanelContainer:
	var is_safe: bool = false
	var is_selected: bool = index == _selected_backpack_index

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1E2A1ACC") if not equipment_id.is_empty() else Color("#12161E99")
	style.set_border_width_all(3 if is_selected else (2 if is_safe else 1))
	style.border_color = Color("#E8A020") if is_selected else (Color("#3A8080") if is_safe else Color("#3A3F4A"))
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(70, 60)
	tile.add_theme_stylebox_override("panel", style)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(vbox)

	if is_safe:
		var safe_lbl := Label.new()
		safe_lbl.text = "SAFE"
		safe_lbl.add_theme_font_size_override("font_size", 9)
		safe_lbl.add_theme_color_override("font_color", Color("#3A8080"))
		safe_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		safe_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(safe_lbl)

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if equipment_id.is_empty():
		name_lbl.text = "—"
		name_lbl.add_theme_color_override("font_color", Color("#505060"))
	else:
		var equip_data: EquipmentData = DataRegistry.get_equipment(equipment_id) if DataRegistry else null
		name_lbl.text = equip_data.name if equip_data else equipment_id
		name_lbl.add_theme_color_override("font_color", PALE)
		tile.tooltip_text = equip_data.description if equip_data else ""
	vbox.add_child(name_lbl)

	if not equipment_id.is_empty():
		tile.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_backpack_tile_clicked(index)
		)
		EQUIP_DND.attach_source_and_target(tile,
			{"type": "equipment", "equipment_id": equipment_id, "source": "backpack", "index": index},
			name_lbl.text,
			func(_pos, _data): return true,
			_make_backpack_drop_handler(index)
		)
	else:
		EQUIP_DND.attach_target(tile,
			func(_pos, _data): return true,
			_make_backpack_drop_handler(index)
		)

	return tile

func _refresh_slots() -> void:
	for char_id in _slot_buttons:
		var slot_buttons: Dictionary = _slot_buttons[char_id]
		for slot_name in slot_buttons:
			var btn: Button = slot_buttons[slot_name]
			var equip_id: String = RunState.get_equipped_item(char_id, slot_name)
			if equip_id.is_empty():
				btn.text = "(empty)"
				btn.tooltip_text = ""
			else:
				var equip_data = DataRegistry.get_equipment(equip_id) if DataRegistry else null
				btn.text = equip_data.name if equip_data else equip_id
				btn.tooltip_text = equip_data.description if equip_data else ""

			EQUIP_DND.attach_source_and_target(btn,
				{"type": "equipment", "equipment_id": equip_id, "source": "slot", "char_id": char_id, "slot_name": slot_name},
				btn.text,
				func(_pos, _data): return true,
				_make_slot_drop_handler(char_id, slot_name)
			)

# ── Interaction ────────────────────────────────────────────────────────────────

func _on_backpack_tile_clicked(index: int) -> void:
	_selected_backpack_index = -1 if _selected_backpack_index == index else index
	_refresh_backpack_grid()

func _on_slot_clicked(char_id: String, slot_name: String) -> void:
	if _selected_backpack_index < 0:
		# Nothing selected in the backpack -- unequip whatever is here back to the backpack.
		if not RunState.unequip_to_backpack(char_id, slot_name) and RunState.has_pending_backpack_prompt():
			_show_full_backpack_prompt()
		return
	var equipment_id: String = RunState.backpack[_selected_backpack_index] if _selected_backpack_index < RunState.backpack.size() else ""
	var reason: String = RunState.can_swap_backpack_item(char_id, slot_name, equipment_id)
	if not reason.is_empty():
		_show_message(reason)
		return
	RunState.swap_backpack_with_equipped(char_id, slot_name, _selected_backpack_index)
	_selected_backpack_index = -1

func _make_backpack_drop_handler(index: int) -> Callable:
	return func(_pos: Vector2, data: Dictionary) -> void:
		var source: String = data.get("source", "")
		if source == "slot":
			# Equipped item dragged onto a backpack tile -- unequip it there.
			var char_id: String = data.get("char_id", "")
			var slot_name: String = data.get("slot_name", "")
			if not RunState.unequip_to_backpack(char_id, slot_name) and RunState.has_pending_backpack_prompt():
				_show_full_backpack_prompt()
		elif source == "backpack":
			# Reordering within the backpack (drag onto another tile) -- swap positions.
			var from_index: int = data.get("index", -1)
			if from_index < 0 or from_index == index or from_index >= RunState.backpack.size():
				return
			if index < RunState.backpack.size():
				var tmp = RunState.backpack[from_index]
				RunState.backpack[from_index] = RunState.backpack[index]
				RunState.backpack[index] = tmp
			else:
				var item = RunState.backpack_remove_at(from_index)
				RunState.backpack_add_at(item, index)
			RunState.backpack_changed.emit()

func _handle_unequip_drop(data: Dictionary) -> void:
	var char_id: String = data.get("char_id", "")
	var slot_name: String = data.get("slot_name", "")
	if char_id.is_empty() or slot_name.is_empty():
		return
	if not RunState.unequip_to_backpack(char_id, slot_name) and RunState.has_pending_backpack_prompt():
		_show_full_backpack_prompt()

func _make_slot_drop_handler(char_id: String, slot_name: String) -> Callable:
	return func(_pos: Vector2, data: Dictionary) -> void:
		var source: String = data.get("source", "")
		if source == "backpack":
			var index: int = data.get("index", -1)
			var equipment_id: String = data.get("equipment_id", "")
			var reason: String = RunState.can_swap_backpack_item(char_id, slot_name, equipment_id)
			if not reason.is_empty():
				_show_message(reason)
				return
			RunState.swap_backpack_with_equipped(char_id, slot_name, index)
		elif source == "slot":
			var from_char: String = data.get("char_id", "")
			var from_slot: String = data.get("slot_name", "")
			var equipment_id: String = data.get("equipment_id", "")
			if from_char == char_id and from_slot == slot_name:
				return
			var reason: String = RunState.can_swap_backpack_item(char_id, slot_name, equipment_id)
			if not reason.is_empty():
				_show_message(reason)
				return
			# Swap between two characters' equipped slots directly (both items
			# already proved compatible with their target slot above).
			var displaced: String = RunState.get_equipped_item(char_id, slot_name)
			if not RunState.equipment_slots.has(from_char):
				RunState.equipment_slots[from_char] = {}
			if not RunState.equipment_slots.has(char_id):
				RunState.equipment_slots[char_id] = {}
			RunState.equipment_slots[char_id][slot_name] = equipment_id
			if displaced.is_empty():
				RunState.equipment_slots[from_char].erase(from_slot)
			else:
				RunState.equipment_slots[from_char][from_slot] = displaced
			RunState.equipment_changed.emit()

func _show_full_backpack_prompt() -> void:
	var equipment_id: String = RunState.pending_backpack_drop
	var equip_data: EquipmentData = DataRegistry.get_equipment(equipment_id) if DataRegistry else null

	var dialog := ConfirmationDialog.new()
	dialog.title = "Backpack Full"
	dialog.ok_button_text = "Discard It"
	dialog.cancel_button_text = "Cancel"
	add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)

	var msg := Label.new()
	msg.text = "Your backpack is full. Make room by discarding one of these, or discard %s." % (equip_data.name if equip_data else equipment_id)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(msg)

	for i in range(RunState.backpack.size()):
		var existing_id: String = RunState.backpack[i]
		var existing_data: EquipmentData = DataRegistry.get_equipment(existing_id) if DataRegistry else null
		var name_text: String = existing_data.name if existing_data else existing_id
		var discard_btn := Button.new()
		discard_btn.text = "Make room: discard %s" % name_text
		discard_btn.pressed.connect(func():
			RunState.resolve_backpack_prompt_make_room(i)
			dialog.queue_free()
		)
		vbox.add_child(discard_btn)

	dialog.confirmed.connect(func():
		RunState.resolve_backpack_prompt_discard_incoming()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	dialog.unresizable = true
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
