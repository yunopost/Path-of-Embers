extends PanelContainer

## Addendum §6: the debug overlay. Built entirely in code (no .tscn) and
## added ONLY when DebugMode.is_enabled() is true, so it is inert in a
## release build and invisible to a normal player even in a debug build
## unless the developer toggle on the main menu is on.
##
## Preloaded by callers via a const (see DEBUG_PANEL_SCRIPT in each screen /
## DebugPanel.attach_to below) rather than referenced by class_name -- this
## script intentionally has no class_name so a missing .uid can never break
## global class registration and take a screen down with it.

signal instant_win_pressed

const NODE_NAME := "DebugPanel"
## Loaded at call time (not preloaded) to avoid a self-referencing preload
## cycle in this script's own compilation.
const SCRIPT_PATH := "res://Path-of-Embers/scenes/ui/debug/DebugPanel.gd"

var _context: String = ""
var _screen: Node = null
var _card_id_edit: LineEdit = null
var _status_label: Label = null

## Reusable attach point (Task 2): adds a DebugPanel to `screen` if debug mode
## is on and one isn't already present. No-op otherwise (including on repeat
## calls from a screen's re-initialization / refresh_from_state path).
## Returns the panel, or null if nothing was added.
static func attach_to(screen: Node, context: String) -> Node:
	if not DebugMode or not DebugMode.is_enabled():
		return null
	if screen.get_node_or_null(NODE_NAME):
		return null
	var panel = load(SCRIPT_PATH).new()
	panel.name = NODE_NAME
	screen.add_child(panel)
	panel.setup(context, screen)
	return panel

func setup(context: String, screen: Node = null) -> void:
	_context = context
	_screen = screen
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -230
	offset_right = -8
	offset_top = 8
	offset_bottom = -8
	custom_minimum_size = Vector2(222, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.05, 0.05, 0.88)
	style.set_border_width_all(2)
	style.border_color = Color(0.9, 0.2, 0.2, 0.9)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var header := Label.new()
	header.text = "DEBUG: ON"
	header.add_theme_color_override("font_color", Color(1, 0.75, 0.75))
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	_add_button(vbox, "+100 Gold", _on_add_gold)
	_add_button(vbox, "Grant All Equipment", _on_grant_all_equipment)
	_add_card_id_row(vbox)

	if _context == "combat":
		_add_button(vbox, "Instant Win", _on_instant_win)

	if _context == "map":
		_add_map_node_buttons(vbox)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)

func _add_button(parent: VBoxContainer, label_text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func _add_card_id_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	_card_id_edit = LineEdit.new()
	_card_id_edit.placeholder_text = "card_id"
	_card_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_id_edit.text_submitted.connect(func(_t): _on_add_card())
	row.add_child(_card_id_edit)

	var add_btn := Button.new()
	add_btn.text = "Add Card"
	add_btn.pressed.connect(_on_add_card)
	row.add_child(add_btn)

func _add_map_node_buttons(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "Jump to next:"
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)

	var entries := [
		["Fight", MapNodeData.NodeType.FIGHT],
		["Elite", MapNodeData.NodeType.ELITE],
		["Shop", MapNodeData.NodeType.SHOP],
		["Event", MapNodeData.NodeType.ENCOUNTER],
		["Rest", MapNodeData.NodeType.REST],
		["Boss", MapNodeData.NodeType.BOSS],
	]
	for entry in entries:
		var btn := Button.new()
		btn.text = entry[0]
		btn.pressed.connect(_on_jump_to_node_type.bind(entry[1]))
		grid.add_child(btn)

func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text

# ── Actions ─────────────────────────────────────────────────────────────────

func _on_add_gold() -> void:
	if ResourceManager:
		ResourceManager.set_gold(ResourceManager.gold + 100)
		_set_status("+100 gold")

func _on_add_card() -> void:
	if not _card_id_edit:
		return
	var card_id := _card_id_edit.text.strip_edges()
	if card_id.is_empty():
		return
	var card_data = DataRegistry.get_card_data(card_id) if DataRegistry else null
	if not card_data:
		_set_status("No card '%s'" % card_id)
		return
	if RunState:
		RunState.add_card_to_deck_from_reward(card_id)
		_set_status("Added '%s'" % card_id)
	_card_id_edit.text = ""

func _on_grant_all_equipment() -> void:
	if not DataRegistry or not SaveManager:
		return
	var count := 0
	for equip in DataRegistry.get_all_equipment():
		SaveManager.add_to_persistent_stash(equip.id)
		count += 1
	_set_status("Granted %d equipment ids" % count)
	# Refresh the Loadout screen's stash display immediately if that's where we are.
	if is_instance_valid(_screen) and _screen.has_method("debug_refresh_stash"):
		_screen.debug_refresh_stash()

func _on_instant_win() -> void:
	instant_win_pressed.emit()

func _on_jump_to_node_type(node_type: int) -> void:
	if is_instance_valid(_screen) and _screen.has_method("debug_jump_to_node_type"):
		var ok = _screen.debug_jump_to_node_type(node_type)
		if ok == false:
			_set_status("No available node of that type")
