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

var card_widget: CardWidget  # Unified card widget for visual display
var card_panel: Panel  # Wrapper panel for drag/targeting
var targeting_line_visible: bool = false
var targeting_line_end: Vector2 = Vector2.ZERO
var tooltip_popup: PopupPanel = null  # Tooltip for keywords

var play_area: Rect2 = Rect2()
var valid_targets: Array = []
var current_target: Node = null

func _ready():
	_setup_ui()
	# Also process input globally when dragging
	set_process_input(true)
	# Ensure we can receive input
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Set minimum size to ensure card has area for input (matches CardWidget size)
	custom_minimum_size = Vector2(210, 280)
	
	# Connect hover signals for scale effect
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _setup_ui():
	# Create wrapper panel for drag/targeting functionality
	card_panel = Panel.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_panel)
	
	# Create unified CardWidget for visual display
	card_widget = CardWidget.new()
	card_widget.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE  # CardWidget is visual-only
	card_panel.add_child(card_widget)
	
	# Make card draggable and interactive
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(210, 280)
	
	# Ensure card can receive input
	set_process_input(true)

func setup_card(deck_card: DeckCardData):
	deck_card_data = deck_card
	if card_widget:
		card_widget.setup_card(deck_card)

# _update_display() removed - CardWidget handles all visual display

func _can_play() -> bool:
	# Check if player has enough energy using effective cost
	if not deck_card_data or not deck_card_data.instance_id:
		return false
	var effective_cost = RunState.get_effective_cost(deck_card_data.instance_id)
	var current_energy = ResourceManager.energy if ResourceManager else 0
	return current_energy >= effective_cost

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
	# Reset scale when starting drag
	scale = Vector2(1.0, 1.0)
	
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

func _on_keyword_mouse_entered(keyword: String, keyword_label: Label):
	## Show tooltip for keyword
	var tooltip_text = CardRules.get_keyword_tooltip(keyword)
	if tooltip_text.is_empty():
		return
	
	# Create or get tooltip popup
	if not tooltip_popup:
		tooltip_popup = PopupPanel.new()
		var tooltip_label = Label.new()
		tooltip_label.text = tooltip_text
		tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tooltip_popup.add_child(tooltip_label)
		add_child(tooltip_popup)
		tooltip_popup.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	else:
		var tooltip_label = tooltip_popup.get_child(0) as Label
		if tooltip_label:
			tooltip_label.text = tooltip_text
	
	# Position tooltip near the keyword label
	var global_pos = keyword_label.global_position
	tooltip_popup.position = global_pos + Vector2(0, keyword_label.size.y)
	tooltip_popup.popup()

func _on_keyword_mouse_exited():
	## Hide tooltip
	if tooltip_popup:
		tooltip_popup.visible = false

func _on_mouse_entered():
	## Hover effect: scale up card from center
	if is_dragging:
		return  # Don't scale during drag
	# Set pivot to center for scaling
	pivot_offset = size / 2.0
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)
	# Bring to front during hover to prevent clipping
	z_index = 10

func _on_mouse_exited():
	## Hover effect: scale back down
	if is_dragging:
		return  # Don't scale during drag
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	# Reset z-index if not dragging
	if not is_dragging:
		z_index = 0
