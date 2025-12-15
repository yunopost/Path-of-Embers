extends Control

## Upgrade flow panel - scene-based implementation
## Scene-based widget - instantiate via scene, not class_name
## Follows architecture: scene-based, uses setup() method

signal upgrade_card_selected(deck_index: int)
signal upgrade_option_selected(upgrade_id: String)
signal flow_closed()

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var scroll_container: ScrollContainer = $Panel/VBoxContainer/ScrollContainer
@onready var card_grid: GridContainer = $Panel/VBoxContainer/ScrollContainer/CardGrid
@onready var upgrade_content: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/UpgradeContent
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var reward_bundle: RewardBundle = null
var selected_instance_id: String = ""  # Selected card instance_id
var current_upgrade_options: Array[String] = []

func setup(p_reward_bundle: RewardBundle):
	## Initialize the panel with reward bundle
	## Must be called after instantiation, before use
	reward_bundle = p_reward_bundle
	_show_card_selection()

func _show_card_selection():
	## Show card selection step
	if not card_grid:
		return
	
	# Hide upgrade content, show card grid
	if upgrade_content:
		upgrade_content.visible = false
	if card_grid:
		card_grid.visible = true
	
	# Clear previous cards
	for child in card_grid.get_children():
		child.queue_free()
	
	# Update title
	if title_label:
		title_label.text = "Choose a card to upgrade (%d remaining):" % reward_bundle.upgrade_count
	
	# Load card widget scene
	var card_widget_scene = load("res://Path-of-Embers/scenes/ui/cards/DeckCardWidget.tscn")
	if not card_widget_scene:
		push_error("UpgradeFlowPanel: Could not load DeckCardWidget scene")
		return
	
	# Create card widgets for all cards in deck (using deck_order for stable ordering)
	for deck_index in range(RunState.deck_order.size()):
		var instance_id = RunState.deck_order[deck_index]
		var card_instance = RunState.deck.get(instance_id)
		if not card_instance:
			continue
		
		var card_widget = card_widget_scene.instantiate()
		card_widget.setup(card_instance, deck_index, true)  # clickable = true, deck_index for display only
		card_widget.card_clicked.connect(_on_card_widget_clicked.bind(instance_id))
		card_grid.add_child(card_widget)

func _show_upgrade_selection():
	## Show upgrade option selection step
	if not upgrade_content:
		return
	
	# Hide card grid, show upgrade content
	if card_grid:
		card_grid.visible = false
	if upgrade_content:
		upgrade_content.visible = true
	
	# Clear previous options
	for child in upgrade_content.get_children():
		child.queue_free()
	
	# Update title
	if title_label and not selected_instance_id.is_empty():
		var card_instance = RunState.deck.get(selected_instance_id)
		if card_instance:
			var card_name = card_instance.card_id.replace("_", " ").capitalize()
			title_label.text = "Choose upgrade for %s:" % card_name
	
	# Create buttons for each upgrade option
	for upgrade_id in current_upgrade_options:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		var title_text = upgrade_def.get("title", upgrade_id)
		var desc_text = upgrade_def.get("description", "")
		
		var upgrade_btn = Button.new()
		upgrade_btn.text = "%s: %s" % [title_text, desc_text]
		upgrade_btn.custom_minimum_size = Vector2(0, 60)
		upgrade_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_btn.pressed.connect(_on_upgrade_button_pressed.bind(upgrade_id))
		upgrade_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		upgrade_content.add_child(upgrade_btn)

func _on_card_widget_clicked(instance_id: String):
	## Handle card selection by instance_id
	selected_instance_id = instance_id
	var card_instance = RunState.deck.get(instance_id)
	if not card_instance:
		return
	
	# Roll upgrade options
	current_upgrade_options = UpgradeService.roll_upgrade_options_for_card(card_instance, 3)
	
	# Show upgrade selection
	_show_upgrade_selection()
	
	# Emit signal with instance_id (signal signature may need updating)
	upgrade_card_selected.emit(-1)  # Legacy signal - instance_id passed via selected_instance_id

func _on_upgrade_button_pressed(upgrade_id: String):
	## Handle upgrade option selection
	upgrade_option_selected.emit(upgrade_id)

func _ready():
	## Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

func _on_close_button_pressed():
	## Handle close button
	flow_closed.emit()

func refresh_after_upgrade():
	## Refresh display after an upgrade is applied
	selected_instance_id = ""
	current_upgrade_options.clear()
	
	# Update reward bundle count (it's passed by reference)
	if reward_bundle and reward_bundle.upgrade_count > 0:
		_show_card_selection()
	else:
		flow_closed.emit()
