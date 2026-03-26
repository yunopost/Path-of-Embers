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
	
	# Ensure reward_bundle is valid before accessing its properties
	if not reward_bundle:
		push_error("RewardsScreen: reward_bundle is null after initialization")
		_finish_rewards()
		return
	
	# Initialize claim flags based on bundle state (for reloads after partial claiming)
	# If bundle shows rewards as already claimed (0/empty), mark them as claimed
	gold_claimed = (reward_bundle.gold <= 0)
	card_claimed = (reward_bundle.card_choices.size() == 0)
	relic_claimed = reward_bundle.relic_id.is_empty()
	upgrade_claimed = (reward_bundle.upgrade_count <= 0)
	heal_applied = false  # Heal is auto-applied on display, so reset this

	# Auto-grant upgrade points from this bundle (Phase 4)
	if reward_bundle.upgrade_points > 0 and ResourceManager:
		ResourceManager.add_upgrade_points(reward_bundle.upgrade_points)
		reward_bundle.upgrade_points = 0  # Consume so reloads don't double-grant

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
		# Note: Pity counter is updated by RewardResolver when rewards are generated
	
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
	
	# Create a CardWidget for each card choice
	for card_id in card_ids:
		# Create temporary card instance for display
		var temp_card_instance = DeckCardData.new(card_id, "")
		
		# Create CardWidget for visual display
		var card_widget = CardWidget.new()
		card_widget.setup_card(temp_card_instance)
		card_widget.custom_minimum_size = Vector2(120, 160)
		
		# Make clickable via gui_input
		if not card_claimed:
			card_widget.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed:
					if event.button_index == MOUSE_BUTTON_LEFT and not card_claimed:
						_on_choose_card(card_id)
			)
		
		cards_hbox.add_child(card_widget)
	
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
	# Remove gold from bundle to prevent re-claiming on reload
	reward_bundle.gold = 0
	gold_claimed = true
	_update_continue_button()
	_refresh_reward_sections()

func _on_choose_card(card_id: String):
	## Choose a card reward
	if card_claimed:
		return
	
	# Add card to deck (owner is empty for shared deck rewards)
	RunState.add_card_to_deck_from_reward(card_id, "")
	# Clear card choices from bundle to prevent re-claiming on reload
	reward_bundle.card_choices.clear()
	card_claimed = true
	_update_continue_button()
	_refresh_reward_sections()

func _on_skip_cards():
	## Skip card selection
	if card_claimed:
		return
	
	# Clear card choices from bundle to prevent re-claiming on reload
	reward_bundle.card_choices.clear()
	card_claimed = true
	_update_continue_button()
	_refresh_reward_sections()

func _on_claim_relic(relic_id: String):
	## Claim relic reward
	## PLACEHOLDER FOR FUTURE WORK: Relic storage works, but relic effects are not implemented.
	## Relics are added to RunState.relics but have no gameplay impact.
	if relic_claimed:
		return
	
	# Determine if this is a boss relic (check if current node is boss)
	var is_boss = false
	if RunState.current_map and not RunState.current_node_id.is_empty():
		var node = RunState.current_map.get_node(RunState.current_node_id)
		if node and node.node_type == MapNodeData.NodeType.BOSS:
			is_boss = true
	
	# Add relic to RunState (emits RELIC_GAINED event for quest system)
	RunState.add_relic(relic_id, is_boss)
	
	# Clear relic from bundle
	if reward_bundle:
		reward_bundle.relic_id = ""
	
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
	# Get the selected card instance_id from the panel
	if not upgrade_flow_panel:
		push_error("RewardsScreen: upgrade_flow_panel is null")
		return
	
	# Check if the property exists using get() instead of has()
	var selected_instance_id = upgrade_flow_panel.get("selected_instance_id")
	if selected_instance_id == null or selected_instance_id.is_empty():
		push_error("RewardsScreen: No card selected in upgrade flow panel")
		return
	
	# Apply upgrade using instance_id
	var success = RunState.apply_upgrade_to_instance(selected_instance_id, upgrade_id)
	if not success:
		push_error("Failed to apply upgrade %s to card instance %s" % [upgrade_id, selected_instance_id])
		return

	# Deduct upgrade point cost (Phase 4)
	var card_instance = RunState.deck.get(selected_instance_id)
	if card_instance and ResourceManager:
		# Cost is computed BEFORE the upgrade was applied (size increased by apply_upgrade)
		# so we subtract 1 from applied_upgrades.size() to get the pre-upgrade count
		var pre_upgrade_count = card_instance.applied_upgrades.size() - 1
		var card_data = DataRegistry.get_card_data(card_instance.card_id) if DataRegistry else null
		if card_data:
			var rarity_base: int = UpgradeService.RARITY_BASE_COST.get(card_data.rarity, 1)
			var cost = rarity_base * (pre_upgrade_count + 1)
			ResourceManager.spend_upgrade_points(cost)

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
	## Complete reward flow: clear pending rewards, then either transition act or return to map.
	# Force save before clearing pending rewards (rewards finalized)
	if AutoSaveManager:
		AutoSaveManager.force_save("rewards_finalized")

	# Determine what node type was just completed before clearing state
	var completed_node: MapNodeData = null
	if MapManager and MapManager.current_map and not MapManager.current_node_id.is_empty():
		completed_node = MapManager.current_map.get_node(MapManager.current_node_id)

	# Clear pending rewards
	RunState.clear_pending_rewards()

	# Act transition: completing a BOSS in acts 1-2 advances to the next act
	if completed_node:
		if completed_node.node_type == MapNodeData.NodeType.FINAL_BOSS:
			# Run is over — emit event, offer build save, then go to main menu
			MapManager.run_completed.emit()
			QuestManager.emit_game_event("FINAL_BOSS_DEFEATED", {})
			_offer_build_save()
			return
		elif completed_node.node_type == MapNodeData.NodeType.BOSS and MapManager.act < 3:
			MapManager.transition_to_next_act()
			ScreenManager.go_to_map()
			return

	# Default: return to map
	ScreenManager.go_to_map()

func _offer_build_save() -> void:
	## Show a dialog offering to save the current build for Boss Rush, then go to main menu.
	if not SaveManager:
		ScreenManager.go_to_main_menu()
		return

	var builds: Array = SaveManager.load_boss_rush_builds()

	# Find the oldest (or first empty) slot to offer
	var target_slot: int = 0
	var oldest_date: String = "9999"
	for i in range(builds.size()):
		if builds[i] == null:
			target_slot = i
			oldest_date = ""  # Empty slot found — stop searching
			break
		var b: BuildData = builds[i]
		if b.saved_at < oldest_date:
			oldest_date = b.saved_at
			target_slot = i

	var existing: BuildData = builds[target_slot]
	var slot_desc: String = "Slot %d" % (target_slot + 1)
	if existing != null:
		slot_desc = "Slot %d (overwrites: %s)" % [target_slot + 1, existing.label]

	var dialog = ConfirmationDialog.new()
	dialog.title = "Run Complete!"
	dialog.dialog_text = "Save this build to Boss Rush %s?" % slot_desc
	dialog.ok_button_text = "Save & Exit"
	dialog.cancel_button_text = "Exit Without Saving"
	add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func():
		var build = BuildData.new()
		build.slot_index = target_slot
		build.snapshot_from_run_state()
		SaveManager.save_boss_rush_build(build)
		dialog.queue_free()
		ScreenManager.go_to_main_menu()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
		ScreenManager.go_to_main_menu()
	)
