extends Control

## Reusable card widget for displaying deck cards
## Scene-based widget - instantiate via scene, not class_name
## Follows architecture: scene-based, uses setup() method

signal card_clicked(instance_id: String)

@onready var card_panel: Panel = $CardPanel
@onready var transcend_label: Label = $CardPanel/VBoxContainer/TranscendLabel
@onready var disabled_label: Label = $CardPanel/VBoxContainer/DisabledLabel

var card_widget: CardWidget = null
var deck_index: int = -1
var card_instance: DeckCardData = null
var is_clickable: bool = false

func setup(p_card_instance: DeckCardData, p_deck_index: int, p_clickable: bool = false):
	## Initialize the widget with card data
	## Must be called after instantiation, before use
	card_instance = p_card_instance
	deck_index = p_deck_index
	is_clickable = p_clickable
	
	# Update display immediately (works if nodes are ready) or defer
	if is_inside_tree():
		_update_display()
	else:
		call_deferred("_update_display")

func _ready():
	## Refresh display when node is ready (in case setup() was called before add_child)
	if card_instance:
		_update_display()

func _update_display():
	## Update all visual elements from card_instance
	if not card_instance:
		return
	
	# Get panel safely
	var panel = _get_card_panel()
	if not panel:
		return
	
	# Create or reuse CardWidget for display
	if not card_widget:
		card_widget = CardWidget.new()
		# Find VBoxContainer in panel
		var vbox = panel.get_node_or_null("VBoxContainer")
		if vbox:
			# Make CardWidget fill available space in VBoxContainer
			card_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
			# Insert CardWidget at the beginning of VBoxContainer
			vbox.add_child(card_widget)
			vbox.move_child(card_widget, 0)
	
	# Setup CardWidget with card instance
	if card_widget:
		card_widget.setup_card(card_instance)
	
	# Get label nodes safely
	var transcend_lbl = _get_transcend_label()
	var disabled_lbl = _get_disabled_label()
	
	# Transcend indicator
	if transcend_lbl:
		transcend_lbl.visible = card_instance.is_transcended
	
	# Disabled state (for upgrade selection)
	if disabled_lbl:
		if is_clickable and card_instance:
			var can_upgrade = RunState.can_upgrade_instance(card_instance.instance_id)
			if not can_upgrade:
				disabled_lbl.visible = true
				modulate = Color(0.5, 0.5, 0.5, 0.7)
			else:
				disabled_lbl.visible = false
				modulate = Color.WHITE
		else:
			disabled_lbl.visible = false
			modulate = Color.WHITE
	
	# Make clickable if needed
	if is_clickable and panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		# Connect gui_input signal
		if not panel.gui_input.is_connected(_on_card_clicked):
			panel.gui_input.connect(_on_card_clicked)
	else:
		if panel:
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Helper methods to get nodes safely (works before @onready vars are set)
func _get_transcend_label() -> Label:
	return transcend_label if transcend_label else get_node_or_null("CardPanel/VBoxContainer/TranscendLabel") as Label

func _get_disabled_label() -> Label:
	return disabled_label if disabled_label else get_node_or_null("CardPanel/VBoxContainer/DisabledLabel") as Label

func _get_card_panel() -> Panel:
	return card_panel if card_panel else get_node_or_null("CardPanel") as Panel

func _on_card_clicked(event: InputEvent):
	if is_clickable and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if card_instance:
				card_clicked.emit(card_instance.instance_id)
			get_viewport().set_input_as_handled()
