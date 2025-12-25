extends Control

## Deck view popup - shows all cards in deck with counts

@onready var close_button: Button = $VBoxContainer/CloseButton
@onready var total_cards_label: Label = $VBoxContainer/HeaderContainer/TotalCardsLabel
@onready var counts_label: Label = $VBoxContainer/CountsLabel
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var card_grid: GridContainer = $VBoxContainer/ScrollContainer/CardGrid

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.z_index = 20  # Ensure close button is above backdrop
	
	# Connect to RunState signals
	RunState.deck_changed.connect(_update_display)
	RunState.draw_pile_changed.connect(_update_counts)
	RunState.hand_changed.connect(_update_counts)
	RunState.discard_pile_changed.connect(_update_counts)
	
	_setup_popup()
	_setup_grid()
	_update_display()

func _setup_popup():
	# Make it a modal-like popup
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add darker backdrop for better readability
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)  # Darker backdrop
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 0)
	
	# Add panel behind content for better contrast (increased size to match content)
	var content_bg = Panel.new()
	content_bg.set_anchors_preset(Control.PRESET_CENTER)
	content_bg.offset_left = -700
	content_bg.offset_top = -450
	content_bg.offset_right = 700
	content_bg.offset_bottom = 450
	content_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_bg)
	move_child(content_bg, 1)
	
	# Center the content with more space (increased size to accommodate 5 cards per row and hover scale)
	# Width: 5 cards (220px each) + 4 gaps (15px each) = 1100px + padding = 1300px total (650 each side)
	# Height: Increased to show multiple rows comfortably
	var content = $VBoxContainer
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.offset_left = -650
	content.offset_top = -400
	content.offset_right = 650
	content.offset_bottom = 400
	content.z_index = 10  # Ensure content is above backdrop

func _setup_grid():
	## Setup grid with proper spacing - called after nodes are ready
	if card_grid:
		card_grid.columns = 5
		card_grid.add_theme_constant_override("h_separation", 15)
		card_grid.add_theme_constant_override("v_separation", 15)
		# Make grid fill available horizontal space
		card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _update_display():
	_update_card_grid()
	_update_counts()

func _update_card_grid():
	if not card_grid:
		return
	# Clear existing cards
	for child in card_grid.get_children():
		child.queue_free()
	
	# Load card widget scene
	var card_widget_scene = load("res://Path-of-Embers/scenes/ui/cards/DeckCardWidget.tscn")
	if not card_widget_scene:
		push_error("DeckViewPopup: Could not load DeckCardWidget scene")
		return
	
	# Add card widgets for each card in deck
	# Iterate over deck_order to maintain stable ordering
	for deck_index in range(RunState.deck_order.size()):
		var instance_id = RunState.deck_order[deck_index]
		var deck_card = RunState.deck.get(instance_id)
		if deck_card is DeckCardData:
			var card_widget = card_widget_scene.instantiate()
			card_widget.setup(deck_card, deck_index, false)  # Not clickable in deck view
			# Cards maintain their aspect ratio (custom_minimum_size) without expanding
			card_widget.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card_widget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			card_grid.add_child(card_widget)

func _update_counts():
	if not total_cards_label or not counts_label:
		return
	total_cards_label.text = "Total Cards: " + str(RunState.get_deck_size())
	var draw_count = RunState.get_draw_pile_count()
	var hand_count = RunState.get_hand_size()
	var discard_count = RunState.get_discard_pile_count()
	counts_label.text = "Draw: %d | Hand: %d | Discard: %d" % [draw_count, hand_count, discard_count]

func _on_close_pressed():
	visible = false
	# Notify UIRoot if needed
	if get_parent().has_method("close_popup"):
		get_parent().close_popup("deck")

func _input(event):
	# Close on escape
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
