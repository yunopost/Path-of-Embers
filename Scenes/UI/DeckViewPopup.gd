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
	
	# Connect to RunState signals
	RunState.deck_changed.connect(_update_display)
	RunState.draw_pile_changed.connect(_update_counts)
	RunState.hand_changed.connect(_update_counts)
	RunState.discard_pile_changed.connect(_update_counts)
	
	_setup_popup()
	_update_display()

func _setup_popup():
	# Make it a modal-like popup
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add background panel
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 0)
	
	# Center the content with more space
	var content = $VBoxContainer
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.offset_left = -400
	content.offset_top = -300
	content.offset_right = 400
	content.offset_bottom = 300
	
	# Setup grid
	card_grid.columns = 3

func _update_display():
	_update_card_grid()
	_update_counts()

func _update_card_grid():
	if not card_grid:
		return
	# Clear existing cards
	for child in card_grid.get_children():
		child.queue_free()
	
	# Add card visuals for each card in deck
	for deck_card in RunState.deck:
		if deck_card is DeckCardData:
			var card_visual = _create_card_visual(deck_card)
			card_grid.add_child(card_visual)

func _create_card_visual(deck_card: DeckCardData) -> Control:
	# Create a placeholder card visual
	var card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(120, 160)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 5
	vbox.offset_top = 5
	vbox.offset_right = -5
	vbox.offset_bottom = -5
	card_panel.add_child(vbox)
	
	# Card name
	var name_label = Label.new()
	name_label.text = deck_card.card_id
	name_label.clip_contents = true
	name_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_label)
	
	# Owner info
	if deck_card.owner_character_id:
		var owner_label = Label.new()
		owner_label.text = "Owner: " + DataRegistry.get_character_display_name(deck_card.owner_character_id)
		owner_label.add_theme_font_size_override("font_size", 10)
		owner_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
		vbox.add_child(owner_label)
	
	# Upgrades info
	if deck_card.applied_upgrades.size() > 0:
		var upgrades_label = Label.new()
		upgrades_label.text = "Upgrades: " + str(deck_card.applied_upgrades.size())
		upgrades_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(upgrades_label)
	
	# Transcend indicator
	if deck_card.is_transcended:
		var trans_label = Label.new()
		trans_label.text = "Transcended!"
		trans_label.add_theme_color_override("font_color", Color.GOLD)
		trans_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(trans_label)
	
	return card_panel

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
