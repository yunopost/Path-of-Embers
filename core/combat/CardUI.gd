extends Control
class_name CardUI

## Card UI element with drag and targeting support
## Works with both mouse and touch

signal card_played(card_ui: CardUI, target: Node)

var deck_card_data: DeckCardData = null
var card_data: CardData = null
var card_width: float = 210.0
var is_dragging: bool = false
var drag_start_pos: Vector2
var original_position: Vector2

var card_widget: CardWidget  # Unified card widget for visual display
var card_panel: Panel  # Wrapper panel for drag/targeting
var targeting_line_visible: bool = false
var targeting_line_end: Vector2 = Vector2.ZERO
var tooltip_popup: PopupPanel = null  # Tooltip for keywords

var play_area: Rect2 = Rect2()
var play_area_node: ColorRect = null  # Optional: node ref for visual highlight
var valid_targets: Array = []
var current_target: Node = null

## Live-preview combat context (Job: real-time card numbers) -- see
## CardWidget.set_preview_context / CardRules.get_live_preview.
var combat_controller: Node = null

func _ready():
	_setup_ui()
	# Also process input globally when dragging
	set_process_input(true)
	# Ensure we can receive input
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Set minimum size to ensure card has area for input (matches CardWidget size)
	custom_minimum_size = Vector2(card_width, 280)
	
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
	card_widget.card_width = card_width
	card_widget.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE  # CardWidget is visual-only
	card_panel.add_child(card_widget)
	
	# Make card draggable and interactive
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(card_width, 280)
	
	# Ensure card can receive input
	set_process_input(true)

func setup_card(deck_card: DeckCardData):
	deck_card_data = deck_card
	card_data = DataRegistry.get_card_data(deck_card.card_id) if deck_card else null
	if card_widget:
		card_widget.setup_card(deck_card)
		card_widget.set_preview_context(combat_controller, _resolve_preview_target())

func set_combat_controller(cc: Node) -> void:
	## Give this card the live-combat context its widget previews against
	## (Job: real-time card numbers). Call once after setup_card(); the
	## widget re-renders immediately.
	combat_controller = cc
	if card_widget:
		card_widget.set_preview_context(combat_controller, _resolve_preview_target())

func refresh_preview() -> void:
	## Re-render the live numbers against current state without moving the
	## card -- cheap enough to call every frame for a hand's worth of cards.
	if card_widget:
		card_widget.set_preview_context(combat_controller, _resolve_preview_target())

func _resolve_preview_target() -> EntityStats:
	## The enemy the preview should read Vulnerable/Weakness from: the one
	## currently under the drag (if any and it's a targeting card), else the
	## first alive valid target, so the number shown before any drag starts
	## already reflects a sensible default.
	var node: Node = current_target
	if not node or not (node in valid_targets):
		for candidate in valid_targets:
			if is_instance_valid(candidate):
				node = candidate
				break
	if node and node.has_meta("enemy"):
		var enemy = node.get_meta("enemy")
		if enemy and "stats" in enemy:
			return enemy.stats
	return null

# _update_display() removed - CardWidget handles all visual display

func _can_play() -> bool:
	# Check if player has enough energy using effective cost
	if not deck_card_data or not deck_card_data.instance_id:
		return false
	var effective_cost = RunState.get_effective_cost(deck_card_data.instance_id)
	var current_energy = ResourceManager.energy if ResourceManager else 0
	return current_energy >= effective_cost

func _is_targeting_card() -> bool:
	if not card_data:
		return false
	return card_data.targeting_mode == CardData.TargetingMode.ENEMY

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
	elif play_area_node:
		play_area_node.color = Color(0.2, 0.8, 0.2, 0.35)  # Green highlight when dragging

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
	var previous_target = current_target
	if target and target in valid_targets:
		current_target = target
	else:
		current_target = null

	if current_target != previous_target:
		refresh_preview()

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

	# Reset play area highlight
	if play_area_node:
		play_area_node.color = Color(1, 1, 1, 0.1)

	var can_play = false

	if _is_targeting_card():
		if current_target and current_target in valid_targets:
			can_play = true
			card_played.emit(self, current_target)
	else:
		# Play if dropped in play zone OR dragged upward by at least 80px
		var dragged_up = (end_pos.y < drag_start_pos.y - 80)
		if play_area.has_point(end_pos) or dragged_up:
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
	# Read the complete live rules without relying on narrow hand-card text.
	tooltip_text = "Card rules"

func _get_tooltip(_at_position: Vector2) -> String:
	if not card_widget or not card_data or is_dragging:
		return ""
	var lines: Array[String] = [card_data.name]
	for container in [card_widget.keywords_container, card_widget.stats_container]:
		if container:
			for child in container.get_children():
				if child is Label and not child.is_queued_for_deletion():
					lines.append(child.text)
	return "\n".join(lines)

func _make_custom_tooltip(for_text: String) -> Object:
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = 340
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	return label

func _on_mouse_exited():
	## Hover effect: scale back down
	if is_dragging:
		return  # Don't scale during drag
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	# Reset z-index if not dragging
	if not is_dragging:
		z_index = 0
