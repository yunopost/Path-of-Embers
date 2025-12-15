extends Control

## Rewards screen - displays and allows player to claim rewards

@onready var title_label: Label = $CenterPanel/VBoxContainer/TitleLabel
@onready var rewards_container: VBoxContainer = $CenterPanel/VBoxContainer/RewardsContainer
@onready var continue_button: Button = $CenterPanel/VBoxContainer/ContinueButton

var upgrade_flow_panel: Control = null  # UpgradeFlowPanel scene instance
var reward_bundle: RewardBundle = null
var gold_claimed: bool = false
var card_claimed: bool = false
var relic_claimed: bool = false
var upgrade_claimed: bool = false
var heal_applied: bool = false

func _ready():
	# Initialize screen (architecture rule 2.1)
	initialize()

func initialize(reward_data: RewardBundle = null):
	## Initialize the screen with reward data
	## Must be called after instantiation, before use (architecture rule 2.1)
	# Get pending rewards from RunState if not provided
	if reward_data:
		reward_bundle = reward_data
	else:
		if not RunState.pending_rewards:
			push_warning("RewardsScreen: No pending rewards, returning to map")
			_finish_rewards()
			return
		reward_bundle = RunState.pending_rewards
	
	# Setup UI
	_setup_ui()
	
	# Load and instantiate upgrade flow panel scene
	_create_upgrade_flow_panel()
	
	# Display rewards
	refresh_from_state()

func refresh_from_state():
	## Refresh UI from RunState (architecture rule 11.2)
	_display_rewards()
	_update_continue_button()

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
	
	# Setup and show the panel
	if upgrade_flow_panel:
		upgrade_flow_panel.setup(reward_bundle)
		upgrade_flow_panel.visible = true

func _create_upgrade_flow_panel():
	## Load and instantiate the upgrade flow panel scene
	if upgrade_flow_panel:
		return
	
	var upgrade_flow_scene = load("res://Path-of-Embers/scenes/ui/rewards/UpgradeFlowPanel.tscn")
	if not upgrade_flow_scene:
		push_error("RewardsScreen: Could not load UpgradeFlowPanel scene")
		return
	
	upgrade_flow_panel = upgrade_flow_scene.instantiate()
	upgrade_flow_panel.visible = false
	add_child(upgrade_flow_panel)
	
	# Connect signals
	upgrade_flow_panel.upgrade_card_selected.connect(_on_upgrade_card_selected)
	upgrade_flow_panel.upgrade_option_selected.connect(_on_upgrade_option_selected)
	upgrade_flow_panel.flow_closed.connect(_on_upgrade_flow_close)

func _on_upgrade_button_pressed():
	## Handle upgrade button press - start upgrade flow
	if reward_bundle.upgrade_count <= 0:
		return
	
	_start_upgrade_flow()

func _on_upgrade_flow_close():
	## Close the upgrade flow panel
	if upgrade_flow_panel:
		upgrade_flow_panel.visible = false

# Upgrade flow is now handled by UpgradeFlowPanel scene
# These methods are called via signals from the panel

func _on_upgrade_card_selected(deck_index: int):
	## Handle card selection signal from UpgradeFlowPanel
	# The panel handles showing upgrade options internally
	pass

func _on_upgrade_option_selected(upgrade_id: String):
	## Handle upgrade option selection from UpgradeFlowPanel
	# Get the selected instance_id from the panel
	var selected_instance_id = upgrade_flow_panel.selected_instance_id
	if selected_instance_id.is_empty():
		return
	
	# Apply upgrade by instance_id
	var success = RunState.apply_upgrade_to_instance(selected_instance_id, upgrade_id)
	if not success:
		push_error("Failed to apply upgrade %s to instance %s" % [upgrade_id, selected_instance_id])
		return
	
	# Decrement upgrade count
	reward_bundle.upgrade_count -= 1
	
	# Check if more upgrades needed
	if reward_bundle.upgrade_count <= 0:
		# Done with upgrades
		upgrade_claimed = true
		if upgrade_flow_panel:
			upgrade_flow_panel.visible = false
		_update_continue_button()
		_refresh_reward_sections()
	else:
		# More upgrades to apply, refresh the panel
		if upgrade_flow_panel:
			upgrade_flow_panel.refresh_after_upgrade()

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
	ScreenManager.go_to_map()
