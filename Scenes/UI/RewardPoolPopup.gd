extends Control

## Reward pool popup - shows all cards in reward pool with rarity counts

@onready var close_button: Button = $VBoxContainer/CloseButton
@onready var total_cards_label: Label = $VBoxContainer/HeaderContainer/TotalCardsLabel
@onready var rarity_label: Label = $VBoxContainer/RarityLabel
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var card_grid: GridContainer = $VBoxContainer/ScrollContainer/CardGrid

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.z_index = 20  # Ensure close button is above backdrop
	
	_setup_popup()
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
	
	# Add panel behind content for better contrast
	var content_bg = Panel.new()
	content_bg.set_anchors_preset(Control.PRESET_CENTER)
	content_bg.offset_left = -450
	content_bg.offset_top = -350
	content_bg.offset_right = 450
	content_bg.offset_bottom = 350
	content_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_bg)
	move_child(content_bg, 1)
	
	# Center the content with more space
	var content = $VBoxContainer
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.offset_left = -400
	content.offset_top = -300
	content.offset_right = 400
	content.offset_bottom = 300
	content.z_index = 10  # Ensure content is above backdrop
	
	# Setup grid
	card_grid.columns = 3

func _update_display():
	if not card_grid:
		return
	
	# Clear existing cards
	for child in card_grid.get_children():
		child.queue_free()
	
	# Count rarities
	var common_count = 0
	var uncommon_count = 0
	var rare_count = 0
	
	# Add card widgets for each card in reward pool
	for card_data in RunState.reward_card_pool:
		# Count by rarity
		match card_data.rarity:
			CardData.Rarity.COMMON:
				common_count += 1
			CardData.Rarity.UNCOMMON:
				uncommon_count += 1
			CardData.Rarity.RARE:
				rare_count += 1
		
		# Create temporary card instance for display
		var temp_instance = DeckCardData.new(card_data.id, "")
		
		# Create CardWidget for visual display
		var card_widget = CardWidget.new()
		card_widget.setup_card(temp_instance)
		card_widget.custom_minimum_size = Vector2(120, 160)
		card_grid.add_child(card_widget)
	
	# Update labels
	if total_cards_label:
		total_cards_label.text = "Total Cards: %d" % RunState.reward_card_pool.size()
	
	if rarity_label:
		rarity_label.text = "Common: %d | Uncommon: %d | Rare: %d" % [common_count, uncommon_count, rare_count]

func _on_close_pressed():
	visible = false

func _input(event):
	# Close on escape
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

