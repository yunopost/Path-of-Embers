extends Control

## Rewards screen - displays and allows player to claim rewards

@onready var title_label: Label = $CenterPanel/VBoxContainer/TitleLabel
@onready var rewards_container: VBoxContainer = $CenterPanel/VBoxContainer/RewardsContainer
@onready var continue_button: Button = $CenterPanel/VBoxContainer/ContinueButton
var upgrade_flow_panel: Panel = null
var upgrade_flow_container: Control = null
var upgrade_card_grid: GridContainer = null  # Store reference to card grid
var upgrade_scroll: ScrollContainer = null  # Store reference to scroll container

var reward_bundle: RewardBundle = null
var gold_claimed: bool = false
var card_claimed: bool = false
var relic_claimed: bool = false
var upgrade_claimed: bool = false
var heal_applied: bool = false

# Upgrade flow state
var upgrade_step: String = ""  # "choose_card" or "choose_upgrade"
var selected_card_index: int = -1
var current_upgrade_options: Array[String] = []

func _ready():
	# Get pending rewards from RunState
	if not RunState.pending_rewards:
		push_warning("RewardsScreen: No pending rewards, returning to map")
		_finish_rewards()
		return
	
	reward_bundle = RunState.pending_rewards
	
	# Setup UI
	_setup_ui()
	
	# Create upgrade flow panel (hidden by default)
	_create_upgrade_flow_panel()
	
	# Display rewards
	_display_rewards()
	
	# Upgrade flow is now triggered by button, not automatically
	if upgrade_flow_container:
		upgrade_flow_container.visible = false

func _setup_ui():
	## Setup UI labels and buttons
	if title_label:
		title_label.text = "Rewards"
	
	if continue_button:
		continue_button.text = "Continue"
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.disabled = true  # Disabled until all rewards resolved

func _display_rewards():
	## Display all rewards from bundle
	if not rewards_container:
		return
	
	# Clear existing reward sections
	for child in rewards_container.get_children():
		child.queue_free()
	
	# Gold section
	if reward_bundle.gold > 0:
		_create_gold_section(reward_bundle.gold)
	
	# Card choices section
	if reward_bundle.card_choices.size() > 0:
		_create_card_choices_section(reward_bundle.card_choices)
	
	# Relic section
	if not reward_bundle.relic_id.is_empty():
		_create_relic_section(reward_bundle.relic_id)
	
	# Upgrade section
	if reward_bundle.upgrade_count > 0:
		_create_upgrade_section(reward_bundle.upgrade_count)
	
	# Heal section
	if reward_bundle.heal_amount > 0:
		_create_heal_section(reward_bundle.heal_amount)

func _create_gold_section(amount: int):
	## Create gold reward section
	var section = Panel.new()
	section.custom_minimum_size = Vector2(0, 60)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	section.add_child(hbox)
	
	var label = Label.new()
	label.text = "Gold: %d" % amount
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	var claim_btn = Button.new()
	claim_btn.text = "Claim Gold"
	claim_btn.pressed.connect(_on_claim_gold.bind(amount))
	claim_btn.disabled = gold_claimed
	hbox.add_child(claim_btn)
	
	rewards_container.add_child(section)

func _create_card_choices_section(card_ids: Array[String]):
	## Create card choice section
	var section = Panel.new()
	section.custom_minimum_size = Vector2(0, 120)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	section.add_child(vbox)
	
	var label = Label.new()
	label.text = "Choose a card:"
	vbox.add_child(label)
	
	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(cards_hbox)
	
	# Create a button for each card choice
	for card_id in card_ids:
		var card_btn = Button.new()
		card_btn.text = card_id  # Placeholder - can show card name later
		card_btn.custom_minimum_size = Vector2(150, 60)
		card_btn.pressed.connect(_on_choose_card.bind(card_id))
		card_btn.disabled = card_claimed
		cards_hbox.add_child(card_btn)
	
	# Add skip option
	if reward_bundle.skip_allowed:
		var skip_btn = Button.new()
		skip_btn.text = "Skip"
		skip_btn.pressed.connect(_on_skip_cards)
		skip_btn.disabled = card_claimed
		cards_hbox.add_child(skip_btn)
	
	rewards_container.add_child(section)

func _create_relic_section(relic_id: String):
	## Create relic reward section (placeholder)
	var section = Panel.new()
	section.custom_minimum_size = Vector2(0, 60)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	section.add_child(hbox)
	
	var label = Label.new()
	label.text = "Relic: %s" % relic_id  # Placeholder
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	var claim_btn = Button.new()
	claim_btn.text = "Claim Relic"
	claim_btn.pressed.connect(_on_claim_relic.bind(relic_id))
	claim_btn.disabled = relic_claimed
	hbox.add_child(claim_btn)
	
	rewards_container.add_child(section)

func _create_upgrade_section(count: int):
	## Create upgrade reward section with button to start upgrade flow
	var section = Panel.new()
	section.custom_minimum_size = Vector2(0, 60)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	section.add_child(hbox)
	
	var label = Label.new()
	label.text = "Upgrades remaining: %d" % reward_bundle.upgrade_count
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade a card"
	upgrade_btn.pressed.connect(_on_upgrade_button_pressed)
	upgrade_btn.disabled = upgrade_claimed or reward_bundle.upgrade_count <= 0
	hbox.add_child(upgrade_btn)
	
	rewards_container.add_child(section)

func _create_heal_section(amount: int):
	## Create heal reward section (auto-applied)
	var section = Panel.new()
	section.custom_minimum_size = Vector2(0, 60)
	var label = Label.new()
	label.text = "Heal: +%d HP (auto-applied)" % amount
	section.add_child(label)
	
	# Auto-apply heal
	if not heal_applied:
		_apply_heal(amount)
	
	rewards_container.add_child(section)

func _on_claim_gold(amount: int):
	## Claim gold reward
	if gold_claimed:
		return
	
	RunState.set_gold(RunState.gold + amount)
	gold_claimed = true
	_update_continue_button()
	_refresh_reward_sections()

func _on_choose_card(card_id: String):
	## Choose a card reward
	if card_claimed:
		return
	
	# Add card to deck (owner is empty for shared deck rewards)
	RunState.add_card_to_deck_from_reward(card_id, "")
	card_claimed = true
	_update_continue_button()
	_refresh_reward_sections()

func _on_skip_cards():
	## Skip card selection
	if card_claimed:
		return
	
	card_claimed = true
	_update_continue_button()
	_refresh_reward_sections()

func _on_claim_relic(relic_id: String):
	## Claim relic reward (placeholder)
	if relic_claimed:
		return
	
	# TODO: Implement relic adding to RunState
	# RunState.add_relic(relic_id)
	print("Relic claimed: ", relic_id)  # Placeholder
	relic_claimed = true
	_update_continue_button()
	_refresh_reward_sections()

func _start_upgrade_flow():
	## Start the upgrade selection flow
	if not upgrade_flow_panel:
		_create_upgrade_flow_panel()
	
	# Show the container (which includes background and panel)
	if upgrade_flow_container:
		upgrade_flow_container.visible = true
	# Explicitly show the panel
	if upgrade_flow_panel:
		upgrade_flow_panel.visible = true
	
	# Wait for scene tree to update - wait multiple frames to ensure everything is ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Debug: Check if panel is in tree
	if upgrade_flow_panel:
		print("RewardsScreen: Panel in tree: ", upgrade_flow_panel.is_inside_tree())
		print("RewardsScreen: Panel children after wait: ", upgrade_flow_panel.get_children())
	
	upgrade_step = "choose_card"
	_show_upgrade_card_selection()

func _create_upgrade_flow_panel():
	## Create the upgrade flow panel if it doesn't exist
	if upgrade_flow_panel:
		return
	
	# Create background overlay
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = 0
	
	var panel = Panel.new()
	panel.name = "UpgradeFlowPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -500
	panel.offset_top = -400
	panel.offset_right = 500
	panel.offset_bottom = 400
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = true  # Panel should be visible when container is shown
	panel.z_index = 1  # Ensure panel is above background
	
	# Add a visible background style to the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 1.0)  # Dark gray-blue background
	style.border_color = Color(0.5, 0.5, 0.6, 1.0)  # Lighter border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	# Add background and panel to a container
	var container = Control.new()
	container.name = "UpgradeFlowContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.visible = false
	container.add_child(bg)
	container.add_child(panel)
	# Ensure panel is rendered after background
	container.move_child(panel, container.get_child_count() - 1)
	add_child(container)
	upgrade_flow_container = container
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"  # Explicitly name it
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	
	var title = Label.new()
	title.name = "UpgradeTitle"
	title.text = "Choose a card to upgrade:"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"  # Explicitly name it
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(scroll)
	upgrade_scroll = scroll  # Store reference
	
	# ScrollContainer needs a single child container for proper scrolling
	# We'll swap between card grid and upgrade content
	# Use GridContainer for card selection (like DeckViewPopup)
	var card_grid = GridContainer.new()
	card_grid.name = "UpgradeCardGrid"
	card_grid.columns = 3
	card_grid.add_theme_constant_override("separation", 10)
	card_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_grid.visible = true
	scroll.add_child(card_grid)
	upgrade_card_grid = card_grid  # Store reference
	
	# Use VBoxContainer for upgrade options (we'll add/remove it as needed)
	# Store reference but don't add it yet
	# We'll create it dynamically when needed
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_upgrade_flow_close)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(close_btn)
	
	upgrade_flow_panel = panel
	
	# Debug: Verify structure
	print("RewardsScreen: Created upgrade flow panel. Panel children: ", panel.get_children())
	if vbox:
		print("RewardsScreen: VBoxContainer children: ", vbox.get_children())
	if scroll:
		print("RewardsScreen: ScrollContainer children: ", scroll.get_children())

func _on_upgrade_button_pressed():
	## Handle upgrade button press - start upgrade flow
	if reward_bundle.upgrade_count <= 0:
		return
	
	_start_upgrade_flow()

func _on_upgrade_flow_close():
	## Close the upgrade flow panel
	if upgrade_flow_container:
		upgrade_flow_container.visible = false
	if upgrade_flow_panel:
		upgrade_flow_panel.visible = false

func _show_upgrade_card_selection():
	## Show the card selection step - displays all cards like DeckViewPopup
	if not upgrade_flow_panel:
		push_error("RewardsScreen: upgrade_flow_panel is null")
		return
	
	# Use stored references if available, otherwise try to find nodes
	var scroll = upgrade_scroll
	var card_grid = upgrade_card_grid
	
	# Fallback: try to find nodes if references aren't set
	if not scroll:
		scroll = upgrade_flow_panel.get_node_or_null("VBoxContainer/ScrollContainer")
		if not scroll:
			scroll = upgrade_flow_panel.find_child("ScrollContainer", true, false)
	
	if not card_grid:
		card_grid = upgrade_flow_panel.get_node_or_null("VBoxContainer/ScrollContainer/UpgradeCardGrid")
		if not card_grid:
			card_grid = upgrade_flow_panel.find_child("UpgradeCardGrid", true, false)
	
	if not scroll:
		push_error("RewardsScreen: Could not find ScrollContainer")
		# Debug: print structure
		print("RewardsScreen: upgrade_flow_panel children: ", upgrade_flow_panel.get_children())
		var vbox = upgrade_flow_panel.get_node_or_null("VBoxContainer")
		if vbox:
			print("RewardsScreen: VBoxContainer children: ", vbox.get_children())
		return
	
	if not card_grid:
		push_error("RewardsScreen: Could not find UpgradeCardGrid")
		return
	
	# Remove upgrade content if it exists (from previous upgrade selection)
	if scroll:
		var existing_content = scroll.get_node_or_null("UpgradeContent")
		if existing_content:
			existing_content.queue_free()
	
	# Show card grid
	if card_grid:
		card_grid.visible = true
	
	# Clear previous content
	for child in card_grid.get_children():
		child.queue_free()
	
	var title = upgrade_flow_panel.get_node_or_null("VBoxContainer/UpgradeTitle")
	if title:
		title.text = "Choose a card to upgrade (%d remaining):" % reward_bundle.upgrade_count
	
	# Debug: Check deck size
	print("RewardsScreen: Displaying cards. Deck size: ", RunState.deck.size())
	
	# Display ALL cards in deck (like DeckViewPopup), not just upgradeable ones
	# But we'll highlight which ones can be upgraded
	var cards_added = 0
	for deck_index in range(RunState.deck.size()):
		var card_instance = RunState.deck[deck_index]
		if not card_instance is DeckCardData:
			print("RewardsScreen: Card at index ", deck_index, " is not DeckCardData, skipping")
			continue
		
		# Create card visual using same style as DeckViewPopup
		var card_visual = _create_card_visual_for_upgrade(card_instance, deck_index)
		card_visual.visible = true
		card_grid.add_child(card_visual)
		cards_added += 1
	
	print("RewardsScreen: Added ", cards_added, " cards to upgrade grid. Grid children: ", card_grid.get_child_count())
	
	# Force layout update
	await get_tree().process_frame
	if card_grid:
		print("RewardsScreen: Grid visible: ", card_grid.visible, ", size: ", card_grid.size, ", children: ", card_grid.get_child_count())

func _create_card_visual_for_upgrade(deck_card: DeckCardData, deck_index: int) -> Control:
	## Create a card visual matching DeckViewPopup style, but clickable for upgrade
	# Check if this card can be upgraded
	var can_upgrade = RunState.can_upgrade_card_at(deck_index)
	
	# Use Button as base for clickability, or Panel if can't upgrade
	var card_panel: Control
	if can_upgrade:
		var card_btn = Button.new()
		card_btn.flat = true  # Make it look like a panel
		card_btn.pressed.connect(_on_upgrade_card_selected.bind(deck_index))
		card_panel = card_btn
	else:
		card_panel = Panel.new()
	
	card_panel.custom_minimum_size = Vector2(120, 160)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.visible = true
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 5
	vbox.offset_top = 5
	vbox.offset_right = -5
	vbox.offset_bottom = -5
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		var upgrade_text = ""
		for upgrade_id in deck_card.applied_upgrades:
			var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
			if upgrade_text != "":
				upgrade_text += ", "
			upgrade_text += upgrade_def.get("title", upgrade_id)
		upgrades_label.text = "Upgrades: " + upgrade_text
		upgrades_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(upgrades_label)
	
	# Visual feedback for non-upgradeable cards
	if not can_upgrade:
		# Gray out cards that can't be upgraded
		card_panel.modulate = Color(0.5, 0.5, 0.5, 0.7)
		var disabled_label = Label.new()
		disabled_label.text = "(Cannot upgrade)"
		disabled_label.add_theme_font_size_override("font_size", 10)
		disabled_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(disabled_label)
	
	# Transcend indicator
	if deck_card.is_transcended:
		var trans_label = Label.new()
		trans_label.text = "Transcended!"
		trans_label.add_theme_color_override("font_color", Color.GOLD)
		trans_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(trans_label)
	
	return card_panel

func _on_upgrade_card_selected(deck_index: int):
	## Handle card selection for upgrade
	selected_card_index = deck_index
	var card_instance = RunState.deck[deck_index]
	
	# Roll upgrade options
	current_upgrade_options = UpgradeService.roll_upgrade_options_for_card(card_instance, 3)
	
	# Show upgrade selection
	upgrade_step = "choose_upgrade"
	_show_upgrade_selection()

func _show_upgrade_selection():
	## Show the upgrade option selection step
	if not upgrade_flow_panel:
		return
	
	# Use stored reference if available
	var scroll = upgrade_scroll
	if not scroll:
		scroll = upgrade_flow_panel.get_node_or_null("VBoxContainer/ScrollContainer")
		if not scroll:
			scroll = upgrade_flow_panel.find_child("ScrollContainer", true, false)
	
	if not scroll:
		return
	
	# Hide card grid
	var card_grid = upgrade_card_grid
	if not card_grid:
		card_grid = upgrade_flow_panel.get_node_or_null("VBoxContainer/ScrollContainer/UpgradeCardGrid")
		if not card_grid:
			card_grid = upgrade_flow_panel.find_child("UpgradeCardGrid", true, false)
	
	if card_grid:
		card_grid.visible = false
	
	# Remove existing upgrade content if it exists
	var existing_content = scroll.get_node_or_null("UpgradeContent")
	if existing_content:
		existing_content.queue_free()
	
	# Create new upgrade content
	var upgrade_content = VBoxContainer.new()
	upgrade_content.name = "UpgradeContent"
	upgrade_content.add_theme_constant_override("separation", 10)
	upgrade_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_content.visible = true
	scroll.add_child(upgrade_content)
	
	var title = upgrade_flow_panel.get_node_or_null("VBoxContainer/UpgradeTitle")
	if title:
		var card_instance = RunState.deck[selected_card_index]
		var card_name = card_instance.card_id.replace("_", " ").capitalize()
		title.text = "Choose upgrade for %s:" % card_name
	
	# Create buttons for each upgrade option
	for upgrade_id in current_upgrade_options:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		var title_text = upgrade_def.get("title", upgrade_id)
		var desc_text = upgrade_def.get("description", "")
		
		var upgrade_btn = Button.new()
		upgrade_btn.text = "%s: %s" % [title_text, desc_text]
		upgrade_btn.custom_minimum_size = Vector2(0, 60)
		upgrade_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_btn.pressed.connect(_on_upgrade_option_selected.bind(upgrade_id))
		upgrade_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		upgrade_content.add_child(upgrade_btn)

func _on_upgrade_option_selected(upgrade_id: String):
	## Handle upgrade option selection
	if selected_card_index < 0:
		return
	
	# Apply upgrade
	var success = RunState.apply_upgrade_to_card_at(selected_card_index, upgrade_id)
	if not success:
		push_error("Failed to apply upgrade %s to card at index %d" % [upgrade_id, selected_card_index])
		return
	
	# Decrement upgrade count
	reward_bundle.upgrade_count -= 1
	
	# Reset selection state
	selected_card_index = -1
	current_upgrade_options.clear()
	
	# Check if more upgrades needed
	if reward_bundle.upgrade_count <= 0:
		# Done with upgrades
		upgrade_claimed = true
		if upgrade_flow_container:
			upgrade_flow_container.visible = false
		if upgrade_flow_panel:
			upgrade_flow_panel.visible = false
		_update_continue_button()
		_refresh_reward_sections()
	else:
		# More upgrades to apply, go back to card selection
		upgrade_step = "choose_card"
		_show_upgrade_card_selection()

func _apply_heal(amount: int):
	## Apply healing
	if heal_applied:
		return
	
	var new_hp = min(RunState.current_hp + amount, RunState.max_hp)
	RunState.set_hp(new_hp, RunState.max_hp)
	heal_applied = true
	_update_continue_button()

func _refresh_reward_sections():
	## Refresh reward sections to update button states
	_display_rewards()

func _update_continue_button():
	## Update continue button enabled state
	if not continue_button:
		return
	
	# Check if all rewards are resolved
	var all_resolved = true
	
	if reward_bundle.gold > 0 and not gold_claimed:
		all_resolved = false
	
	if reward_bundle.card_choices.size() > 0 and not card_claimed:
		all_resolved = false
	
	if not reward_bundle.relic_id.is_empty() and not relic_claimed:
		all_resolved = false
	
	if reward_bundle.upgrade_count > 0:
		all_resolved = false
	
	continue_button.disabled = not all_resolved

func _on_continue_pressed():
	## Finish rewards and return to map
	_finish_rewards()

func _finish_rewards():
	## Complete reward flow: clear pending rewards, return to map
	# Note: Node is already marked as completed when set_current_node was called in MapScreen
	# Available nodes were already updated at that time
	# We just need to clear pending rewards and return
	
	# Clear pending rewards
	RunState.clear_pending_rewards()
	
	# Return to map (map will show the node as completed and available next nodes updated)
	SceneRouter.change_scene("map")
