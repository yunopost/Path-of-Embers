extends Control
class_name CardUI

## Card UI element with drag and targeting support
## Works with both mouse and touch

signal card_played(card_ui: CardUI, target: Node)

var deck_card_data: DeckCardData = null
var card_data: CardData = null
var is_dragging: bool = false
var drag_start_pos: Vector2
var original_position: Vector2

var card_panel: Panel
var name_label: Label
var cost_label: Label
var owner_label: Label
var upgrade_indicator: Label = null  # Visual indicator for upgraded cards
var targeting_line_visible: bool = false
var targeting_line_end: Vector2 = Vector2.ZERO

var play_area: Rect2 = Rect2()
var valid_targets: Array = []
var current_target: Node = null

func _ready():
	_setup_ui()
	# Also process input globally when dragging
	set_process_input(true)
	# Ensure we can receive input
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Set minimum size to ensure card has area for input
	custom_minimum_size = Vector2(120, 160)

func _setup_ui():
	# Create card panel
	card_panel = Panel.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(card_panel)
	
	# Create VBox for content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 5
	vbox.offset_top = 5
	vbox.offset_right = -5
	vbox.offset_bottom = -5
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(vbox)
	
	# Cost label (top)
	cost_label = Label.new()
	cost_label.text = "1"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_label)
	
	# Name label (middle)
	name_label = Label.new()
	name_label.text = "Card"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	
	# Owner label (bottom)
	owner_label = Label.new()
	owner_label.text = ""
	owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_label.add_theme_font_size_override("font_size", 10)
	owner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(owner_label)
	
	# Upgrade indicator (badge in top-left corner, positioned relative to card_panel)
	upgrade_indicator = Label.new()
	upgrade_indicator.text = "★"
	upgrade_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upgrade_indicator.add_theme_font_size_override("font_size", 18)
	upgrade_indicator.modulate = Color.GOLD
	upgrade_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_indicator.visible = false
	upgrade_indicator.custom_minimum_size = Vector2(24, 24)
	card_panel.add_child(upgrade_indicator)
	
	# Create targeting line using a custom control (simpler for UI)
	# Will be drawn manually in _draw() if needed
	
	# Make card draggable and interactive
	mouse_filter = Control.MOUSE_FILTER_STOP
	# card_panel should be IGNORE so events reach CardUI, not the panel
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 160)
	
	# Ensure card can receive input
	set_process_input(true)

func setup_card(deck_card: DeckCardData):
	deck_card_data = deck_card
	_update_display()

func _update_display():
	if not deck_card_data:
		return
	
	# Get card display name
	if name_label:
		var display_name = DataRegistry.get_card_display_name(deck_card_data.card_id)
		name_label.text = display_name
	
	# Show effective cost (using get_effective_cost for upgrades)
	if cost_label and deck_card_data.instance_id:
		var effective_cost = RunState.get_effective_cost(deck_card_data.instance_id)
		cost_label.text = str(effective_cost)
		# Color cost differently if it's reduced (0 or less than base)
		if effective_cost == 0:
			cost_label.modulate = Color.GREEN
		elif deck_card_data.applied_upgrades.has("upgrade_cost_minus_1"):
			cost_label.modulate = Color.LIGHT_BLUE
		else:
			cost_label.modulate = Color.WHITE
	
	# Show owner
	if owner_label:
		if deck_card_data.owner_character_id:
			var owner_name = DataRegistry.get_character_display_name(deck_card_data.owner_character_id)
			owner_label.text = owner_name
		else:
			owner_label.text = ""
	
	# Show upgrade indicator and add visual styling
	if upgrade_indicator:
		var has_upgrades = deck_card_data.applied_upgrades.size() > 0
		upgrade_indicator.visible = has_upgrades
		if has_upgrades:
			# Position badge in top-left corner of card_panel
			upgrade_indicator.position = Vector2(2, 2)
			upgrade_indicator.text = "★"
			upgrade_indicator.modulate = Color.GOLD
		
		# Add glow effect to the card panel for upgraded cards
		if card_panel:
			if has_upgrades:
				# Add a subtle golden tint to upgraded cards
				card_panel.modulate = Color(1.1, 1.05, 0.95, 1.0)
			else:
				# Reset to normal for non-upgraded cards
				card_panel.modulate = Color.WHITE

func _can_play() -> bool:
	# Check if player has enough energy using effective cost
	if not deck_card_data or not deck_card_data.instance_id:
		return false
	var effective_cost = RunState.get_effective_cost(deck_card_data.instance_id)
	return RunState.energy >= effective_cost

func _is_targeting_card() -> bool:
	# For now, assume cards with "attack" or "strike" in name need targets
	if not deck_card_data:
		return false
	return "attack" in deck_card_data.card_id or "strike" in deck_card_data.card_id

func _gui_input(event):
	if not visible:
		return
	
	# Handle mouse/touch press on card
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos = get_local_mouse_position()
				var card_rect = Rect2(Vector2.ZERO, size)
				if size != Vector2.ZERO and card_rect.has_point(local_pos):
					_start_drag(get_global_mouse_position())
					accept_event()
			elif not event.pressed and is_dragging:
				_end_drag(get_global_mouse_position())
				accept_event()
	
	# Handle drag motion while over card
	if is_dragging and event is InputEventMouseMotion:
		_update_drag(get_global_mouse_position())
		accept_event()

func _input(event):
	# Handle drag motion globally when dragging
	if is_dragging and event is InputEventMouseMotion:
		_update_drag(get_global_mouse_position())
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()
	elif is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(get_global_mouse_position())
			var viewport = get_viewport()
			if viewport:
				viewport.set_input_as_handled()

func _start_drag(start_pos: Vector2):
	if not _can_play():
		return
	
	is_dragging = true
	drag_start_pos = start_pos
	original_position = global_position
	z_index = 100
	
	if _is_targeting_card():
		_show_targeting_line(start_pos)

func _show_targeting_line(start_pos: Vector2):
	targeting_line_visible = true
	targeting_line_end = start_pos
	queue_redraw()

func _update_drag(current_pos: Vector2):
	if _is_targeting_card():
		_update_targeting_line(current_pos)
	else:
		# Non-target card follows input
		global_position = current_pos - size / 2

func _update_targeting_line(current_pos: Vector2):
	targeting_line_end = current_pos
	
	# Check for valid target under cursor
	var target = _get_target_at_position(current_pos)
	if target and target in valid_targets:
		current_target = target
	else:
		current_target = null
	
	queue_redraw()

func _get_target_at_position(pos: Vector2) -> Node:
	for target in valid_targets:
		if target is Control:
			var target_rect = Rect2(target.global_position, target.size)
			if target_rect.has_point(pos):
				return target
	return null

func _draw():
	if targeting_line_visible and is_dragging:
		var start = size / 2
		var end = get_local_mouse_position()
		var color = Color.GREEN if current_target else Color.YELLOW
		draw_line(start, end, color, 2.0)

func _end_drag(end_pos: Vector2):
	if not is_dragging:
		return
	
	is_dragging = false
	z_index = 0
	targeting_line_visible = false
	queue_redraw()
	
	var can_play = false
	
	if _is_targeting_card():
		if current_target and current_target in valid_targets:
			can_play = true
			card_played.emit(self, current_target)
	else:
		if play_area.has_point(end_pos):
			can_play = true
			card_played.emit(self, null)
	
	if can_play:
		visible = false
	else:
		_snap_back()

func _snap_back():
	var tween = create_tween()
	tween.tween_property(self, "global_position", original_position, 0.2)
	tween.tween_callback(func(): global_position = original_position)
