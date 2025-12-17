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
	
	# Check for soft-lock conditions
	if RunState.deck_order.is_empty():
		# Empty deck - show message and close
		if title_label:
			title_label.text = "No cards in deck to upgrade."
		# Auto-mark upgrade as claimed and close
		if reward_bundle:
			reward_bundle.upgrade_count = 0
		call_deferred("flow_closed")
		return
	
	# Check if there are any upgradeable cards
	var upgradeable_ids = RunState.get_upgradeable_instance_ids()
	if upgradeable_ids.is_empty() and not (reward_bundle and reward_bundle.is_transcendence_upgrade):
		# No upgradeable cards (and not transcendence) - show message and close
		if title_label:
			title_label.text = "No cards available for upgrade."
		# Auto-mark upgrade as claimed and close
		if reward_bundle:
			reward_bundle.upgrade_count = 0
		call_deferred("flow_closed")
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
		var upgrade_type_text = "transcend" if (reward_bundle and reward_bundle.is_transcendence_upgrade) else "upgrade"
		title_label.text = "Choose a card to %s (%d remaining):" % [upgrade_type_text, reward_bundle.upgrade_count]
	
	# Load card widget scene
	var card_widget_scene = load("res://Path-of-Embers/scenes/ui/cards/DeckCardWidget.tscn")
	if not card_widget_scene:
		push_error("UpgradeFlowPanel: Could not load DeckCardWidget scene")
		return
	
	# For transcendence, show all cards. For normal upgrades, only show upgradeable cards
	var cards_to_show = RunState.deck_order
	if not (reward_bundle and reward_bundle.is_transcendence_upgrade):
		# Normal upgrade - only show upgradeable cards
		cards_to_show = upgradeable_ids
	
	# Create card widgets for selected cards
	for instance_id in cards_to_show:
		var card_instance = RunState.deck.get(instance_id)
		if not card_instance:
			continue
		
		# Find deck_index for display
		var deck_index = RunState.deck_order.find(instance_id)
		if deck_index < 0:
			deck_index = 0
		
		var card_widget = card_widget_scene.instantiate()
		card_widget.setup(card_instance, deck_index, true)  # clickable = true, deck_index for display only
		card_widget.card_clicked.connect(_on_card_widget_clicked)  # Signal now emits instance_id directly
		card_grid.add_child(card_widget)

func _show_upgrade_selection():
	## Show upgrade option selection step (or transcendence selection if is_transcendence_upgrade)
	if not upgrade_content:
		return
	
	# Hide card grid, show upgrade content
	if card_grid:
		card_grid.visible = false
	if upgrade_content:
		upgrade_content.visible = true
	
	# Clear previous options (remove immediately instead of queue_free to avoid timing issues)
	for child in upgrade_content.get_children():
		upgrade_content.remove_child(child)
		child.queue_free()
	
	# Update title
	if title_label and not selected_instance_id.is_empty():
		var card_instance = RunState.deck.get(selected_instance_id)
		if card_instance:
			var card_name = DataRegistry.get_card_display_name(card_instance.card_id)
			if reward_bundle and reward_bundle.is_transcendence_upgrade:
				title_label.text = "Choose transcendence for %s:" % card_name
			else:
				title_label.text = "Choose upgrade for %s:" % card_name
	
	# Handle transcendence upgrade flow
	if reward_bundle and reward_bundle.is_transcendence_upgrade:
		_show_transcendence_options()
		return
	
	# Normal upgrade flow - create buttons for each upgrade option
	print("UpgradeFlowPanel._show_upgrade_selection: current_upgrade_options.size() = ", current_upgrade_options.size())
	if current_upgrade_options.is_empty():
		# Show error message if no options
		print("UpgradeFlowPanel._show_upgrade_selection: No upgrade options available!")
		var error_label = Label.new()
		error_label.text = "No upgrade options available for this card."
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_content.add_child(error_label)
		return
	
	print("UpgradeFlowPanel._show_upgrade_selection: Creating buttons for ", current_upgrade_options.size(), " upgrades")
	print("UpgradeFlowPanel._show_upgrade_selection: upgrade_content is valid: ", upgrade_content != null, ", visible: ", upgrade_content.visible if upgrade_content else false)
	for upgrade_id in current_upgrade_options:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		var title_text = upgrade_def.get("title", upgrade_id)
		var desc_text = upgrade_def.get("description", "")
		
		var upgrade_btn = Button.new()
		upgrade_btn.text = "%s: %s" % [title_text, desc_text]
		upgrade_btn.custom_minimum_size = Vector2(400, 80)
		upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_btn.pressed.connect(_on_upgrade_button_pressed.bind(upgrade_id))
		upgrade_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		upgrade_btn.visible = true
		upgrade_content.add_child(upgrade_btn)
		print("UpgradeFlowPanel._show_upgrade_selection: Added button for ", upgrade_id, " - button visible: ", upgrade_btn.visible, ", size: ", upgrade_btn.custom_minimum_size)
	
	print("UpgradeFlowPanel._show_upgrade_selection: upgrade_content child count after adding buttons: ", upgrade_content.get_child_count())
	# Force layout update
	if upgrade_content:
		upgrade_content.queue_sort()
		print("UpgradeFlowPanel._show_upgrade_selection: upgrade_content.visible = ", upgrade_content.visible, ", size = ", upgrade_content.size)

func _show_transcendence_options():
	## Show transcendence card selection (3 options from 4 placeholders)
	## PLACEHOLDER FOR FUTURE WORK: This method exists but is not called by the upgrade flow.
	## Transcendence upgrade logic is not implemented - upgrade flow treats all upgrades the same.
	if not upgrade_content:
		return
	
	# Get all transcendent card IDs
	var all_transcend_ids = DataRegistry.get_transcendent_card_ids()
	if all_transcend_ids.is_empty():
		push_error("UpgradeFlowPanel: No transcendent cards available")
		return
	
	# Select exactly 3 options (or all if fewer than 3)
	var selected_transcend_ids: Array[String] = []
	if all_transcend_ids.size() <= 3:
		selected_transcend_ids = all_transcend_ids.duplicate()
	else:
		# Shuffle and take 3
		var shuffled = all_transcend_ids.duplicate()
		shuffled.shuffle()
		for i in range(3):
			selected_transcend_ids.append(shuffled[i])
	
	# Create buttons for each transcendence option
	for transcend_card_id in selected_transcend_ids:
		var transcend_card = DataRegistry.get_transcendent_card(transcend_card_id)
		var card_name = "Transcendent Card"
		if transcend_card:
			card_name = transcend_card.name
		
		var transcend_btn = Button.new()
		transcend_btn.text = "Transform into: %s" % card_name
		transcend_btn.custom_minimum_size = Vector2(0, 60)
		transcend_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		transcend_btn.pressed.connect(_on_transcendence_button_pressed.bind(transcend_card_id))
		transcend_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		upgrade_content.add_child(transcend_btn)

func _on_card_widget_clicked(instance_id: String):
	## Handle card selection by instance_id
	selected_instance_id = instance_id
	var card_instance = RunState.deck.get(instance_id)
	if not card_instance:
		return
	
	# Check if this is a transcendence upgrade
	if reward_bundle and reward_bundle.is_transcendence_upgrade:
		# For transcendence, show transcendence options directly (no rolling)
		_show_upgrade_selection()
		return
	
	# Normal upgrade flow - roll upgrade options
	print("UpgradeFlowPanel._on_card_widget_clicked: Rolling upgrades for card ", card_instance.card_id)
	current_upgrade_options = UpgradeService.roll_upgrade_options_for_card(card_instance, 3)
	print("UpgradeFlowPanel._on_card_widget_clicked: Rolled ", current_upgrade_options.size(), " upgrade options: ", current_upgrade_options)
	
	# Ensure we have at least some options (should always have universal upgrades)
	if current_upgrade_options.is_empty():
		push_warning("UpgradeFlowPanel: No upgrade options available for card %s" % card_instance.card_id)
		print("UpgradeFlowPanel._on_card_widget_clicked: UpgradeService returned empty, trying fallback")
		# Try to get the pool directly as fallback
		var pool = DataRegistry.get_upgrade_pool_for_card(card_instance.card_id)
		if not pool.is_empty():
			# Filter out already applied upgrades
			var available = []
			for upgrade_id in pool:
				if not card_instance.applied_upgrades.has(upgrade_id):
					available.append(upgrade_id)
			# Take up to 3
			if available.size() > 3:
				available.shuffle()
				current_upgrade_options.clear()
				for i in range(min(3, available.size())):
					current_upgrade_options.append(available[i])
			else:
				current_upgrade_options = available
	
	# Show upgrade selection (only if we have options)
	if current_upgrade_options.is_empty():
		push_error("UpgradeFlowPanel: No upgrade options available, cannot show upgrade selection")
		return
	
	_show_upgrade_selection()
	
	# Emit signal with instance_id (signal signature may need updating)
	upgrade_card_selected.emit(-1)  # Legacy signal - instance_id passed via selected_instance_id

func _on_upgrade_button_pressed(upgrade_id: String):
	## Handle upgrade option selection
	upgrade_option_selected.emit(upgrade_id)

func _on_transcendence_button_pressed(transcend_card_id: String):
	## Handle transcendence option selection - directly apply transcendence
	if selected_instance_id.is_empty():
		return
	
	var success = RunState.transcend_card(selected_instance_id, transcend_card_id)
	if not success:
		push_error("UpgradeFlowPanel: Failed to transcend card")
		return
	
	# Decrement upgrade count
	if reward_bundle:
		reward_bundle.upgrade_count -= 1
	
	# Check if more upgrades needed
	if reward_bundle and reward_bundle.upgrade_count > 0:
		# More upgrades to apply, refresh
		refresh_after_upgrade()
	else:
		# Done with upgrades
		flow_closed.emit()

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
