extends Control

## Combat screen with full combat implementation

@onready var combat_controller: CombatController = $CombatController
@onready var player_slots: HBoxContainer = $CombatArea/PlayerAnchor/PlayerArea/PlayerSlots
@onready var enemy_slots: HBoxContainer = $CombatArea/EnemyAnchor/EnemyArea/EnemySlots
@onready var hand_container: HBoxContainer = $HandArea/HandContainer
@onready var draw_pile_label: Label = $CombatArea/PlayerAnchor/PlayerArea/DrawPileArea/DrawPileLabel
@onready var energy_label: Label = $BottomUI/EnergyArea/EnergyLabel
@onready var discard_pile_label: Label = $BottomUI/DiscardPileArea/DiscardPileLabel
@onready var end_turn_button: Button = $BottomUI/EndTurnButton
@onready var play_area: ColorRect = $PlayArea
@onready var player_hp_label: Label = $CombatArea/PlayerAnchor/PlayerArea/PlayerHPLabel
@onready var player_area: VBoxContainer = $CombatArea/PlayerAnchor/PlayerArea

var card_ui_instances: Array[CardUI] = []
var player_status_indicator: StatusEffectIndicator = null
var is_updating_hand: bool = false

var enemy_displays: Array[Control] = []
var alive_enemy_ids: Array[String] = []
var combat_ending: bool = false

func _ready():
	# Connect signals
	RunState.hand_changed.connect(_update_hand)
	RunState.draw_pile_changed.connect(_update_draw_pile_count)
	RunState.discard_pile_changed.connect(_update_discard_pile_count)
	RunState.energy_changed.connect(_update_energy)
	RunState.hp_changed.connect(_update_player_hp)
	
	# Connect combat controller signals
	combat_controller.combat_started.connect(_on_combat_started)
	combat_controller.turn_ended.connect(_on_turn_ended)
	
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
		end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Setup play area (invisible but detects drops)
	if play_area:
		play_area.color = Color(1, 1, 1, 0.1)  # Slightly visible for debugging
		play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Initialize screen (architecture rule 2.1)
	initialize()

func initialize(encounter_data: Dictionary = {}):
	## Initialize the screen with encounter data
	## Must be called after instantiation, before use (architecture rule 2.1)
	# For now, use placeholder enemies if no data provided
	if encounter_data.is_empty():
		_start_combat()
	else:
		_start_combat_with_data(encounter_data)

func refresh_from_state():
	## Refresh UI from RunState (architecture rule 11.2)
	_update_hand()
	_update_draw_pile_count()
	_update_discard_pile_count()
	_update_energy()
	_update_player_hp()

func _start_combat():
	## Initialize combat with test enemies (default for testing)
	## Using new enemy system: 3 Ash Men
	var enemy_data = [
		{"enemy_id": "ash_man", "count": 3}
	]
	_start_combat_with_data({"enemies": enemy_data})

func _start_combat_with_data(encounter_data: Dictionary):
	## Initialize combat with provided encounter data
	var enemy_data = encounter_data.get("enemies", [])
	if enemy_data.is_empty():
		# Fallback to test enemies: 3 Ash Men
		enemy_data = [
			{"enemy_id": "ash_man", "count": 3}
		]
	
	combat_controller.start_combat(enemy_data)
	_setup_enemies()
	# Note: _update_hand() will be called automatically via hand_changed signal when draw_cards() is called
	# Similarly, other updates will be triggered by their respective signals
	refresh_from_state()

func _setup_enemies():
	## Create enemy displays
	# Clear existing
	for child in enemy_slots.get_children():
		child.queue_free()
	enemy_displays.clear()
	alive_enemy_ids.clear()
	combat_ending = false
	
	for enemy in combat_controller.get_enemies():
		# Track alive enemies
		alive_enemy_ids.append(enemy.enemy_id)
		
		# Connect to died signal
		enemy.died.connect(_on_enemy_died.bind(enemy.enemy_id))
		
		var enemy_display = _create_enemy_display(enemy)
		enemy_slots.add_child(enemy_display)
		enemy_displays.append(enemy_display)

func _create_enemy_display(enemy: Enemy) -> Control:
	var enemy_panel = Panel.new()
	enemy_panel.custom_minimum_size = Vector2(150, 200)
	enemy_panel.name = "Enemy_" + enemy.enemy_id
	enemy_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store reference to enemy for targeting
	enemy_panel.set_meta("enemy", enemy)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 5
	vbox.offset_top = 5
	vbox.offset_right = -5
	vbox.offset_bottom = -5
	enemy_panel.add_child(vbox)
	
	# Health bar (at top)
	var health_bar_scene = load("res://Path-of-Embers/Scenes/UI/HealthBar.tscn")
	if health_bar_scene:
		var health_bar = health_bar_scene.instantiate()
		health_bar.setup(enemy.stats)
		vbox.add_child(health_bar)
	
	# Status effect indicators (below health bar)
	var status_indicator_scene = load("res://Path-of-Embers/Scenes/UI/StatusEffectIndicator.tscn")
	if status_indicator_scene:
		var status_indicator = status_indicator_scene.instantiate()
		status_indicator.setup(enemy.stats)
		vbox.add_child(status_indicator)
	
	# Name label with text wrapping
	var name_label = Label.new()
	name_label.text = enemy.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_contents = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(0, 20)  # Minimum height for wrapped text
	vbox.add_child(name_label)
	
	# Timer label with text wrapping
	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "Timer: %d/%d" % [enemy.time_current, enemy.time_max]
	timer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timer_label.clip_contents = true
	timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_label.custom_minimum_size = Vector2(0, 20)  # Minimum height for wrapped text
	vbox.add_child(timer_label)
	
	# Intent label with text wrapping
	var intent_label = Label.new()
	intent_label.name = "IntentLabel"
	intent_label.text = "Intent: %s" % (enemy.intent.telegraph_text if enemy.intent else "None")
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_label.clip_contents = true
	intent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intent_label.custom_minimum_size = Vector2(0, 20)  # Minimum height for wrapped text
	vbox.add_child(intent_label)
	
	# Connect to timer and intent signals
	enemy.time_changed.connect(func(current, max_time): timer_label.text = "Timer: %d/%d" % [current, max_time])
	enemy.intent_changed.connect(func(new_intent): intent_label.text = "Intent: %s" % (new_intent.telegraph_text if new_intent else "None"))
	
	# Store enemy reference in metadata for targeting
	
	return enemy_panel

func _update_hand():
	## Update hand UI with current cards
	# Prevent concurrent updates
	if is_updating_hand:
		return
	is_updating_hand = true
	
	# Immediately remove all existing card UIs from container
	for card_ui in card_ui_instances:
		if is_instance_valid(card_ui) and card_ui.get_parent():
			card_ui.get_parent().remove_child(card_ui)
		card_ui.queue_free()
	card_ui_instances.clear()
	
	# Wait for layout to update and nodes to be freed
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Create card UIs for each card in hand
	# Use deck_model.get_hand_cards() which handles instance_id lookup
	var hand_cards: Array[DeckCardData] = RunState.deck_model.get_hand_cards()
	
	for deck_card in hand_cards:
		# Double-check type before calling setup_card
		if not deck_card is DeckCardData:
			push_error("CombatScreen: Expected DeckCardData but got %s" % typeof(deck_card))
			continue
		var card_ui = CardUI.new()
		hand_container.add_child(card_ui)
		card_ui.setup_card(deck_card)
		card_ui.card_played.connect(_on_card_played)
		
		# Set valid targets (enemies) - do this before waiting
		card_ui.valid_targets = enemy_displays
		
		card_ui_instances.append(card_ui)
		
		# Wait for layout to update so card has proper size
		await get_tree().process_frame
		await get_tree().process_frame  # Extra frame for layout
		
		# Ensure card is properly set up
		card_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		card_ui.visible = true
		
		# Force minimum size if card still has no size
		if card_ui.size == Vector2.ZERO:
			card_ui.custom_minimum_size = Vector2(120, 160)
			card_ui.size = Vector2(120, 160)
		
		# Set play area after layout updates
		if play_area:
			var play_area_rect = Rect2(play_area.global_position, play_area.size)
			card_ui.play_area = play_area_rect
	
	is_updating_hand = false

func _on_card_played(card_ui: CardUI, target: Node = null):
	## Handle card being played
	var deck_card = card_ui.deck_card_data
	if not deck_card:
		return
	
	var success = combat_controller.play_card(deck_card, target)
	if not success:
		# Card couldn't be played (not enough energy)
		card_ui._snap_back()

func _update_draw_pile_count():
	if draw_pile_label:
		draw_pile_label.text = "Draw: %d" % RunState.get_draw_pile_count()

func _update_discard_pile_count():
	if discard_pile_label:
		discard_pile_label.text = "Discard: %d" % RunState.get_discard_pile_count()

func _update_energy():
	if energy_label:
		energy_label.text = "Energy: %d/%d" % [RunState.energy, RunState.max_energy]

func _update_player_hp():
	if player_hp_label:
		player_hp_label.text = "HP: %d/%d" % [RunState.current_hp, RunState.max_hp]
	if combat_controller and combat_controller.player_stats:
		combat_controller.player_stats.current_hp = RunState.current_hp

func _on_combat_started():
	_update_player_hp()
	_setup_player_status_indicator()

func _setup_player_status_indicator():
	## Set up status effect indicator for player
	if not player_area or not combat_controller or not combat_controller.player_stats:
		return
	
	# Remove existing indicator if present
	if player_status_indicator and is_instance_valid(player_status_indicator):
		player_status_indicator.queue_free()
		player_status_indicator = null
	
	# Create and add status indicator
	var status_indicator_scene = load("res://Path-of-Embers/Scenes/UI/StatusEffectIndicator.tscn")
	if status_indicator_scene:
		player_status_indicator = status_indicator_scene.instantiate()
		player_status_indicator.setup(combat_controller.player_stats)
		# Insert after PlayerHPLabel (or find appropriate position)
		var hp_label_index = player_area.get_child_count()
		for i in range(player_area.get_child_count()):
			if player_area.get_child(i) == player_hp_label:
				hp_label_index = i + 1
				break
		player_area.add_child(player_status_indicator)
		player_area.move_child(player_status_indicator, hp_label_index)

func _on_turn_ended():
	_update_player_hp()
	# Check for combat end after turn (enemies may have died during enemy actions)
	_check_combat_end()

func _on_end_turn_pressed():
	combat_controller.end_player_turn()
	# Check for combat end after turn (in case enemies died during turn resolution)
	_check_combat_end()

func _on_enemy_died(enemy_id: String):
	## Handle enemy death
	if enemy_id in alive_enemy_ids:
		alive_enemy_ids.erase(enemy_id)
		print("CombatScreen: Enemy %s died. Alive enemies: %d" % [enemy_id, alive_enemy_ids.size()])
		_check_combat_end()

func _check_combat_end():
	## Check if all enemies are dead and end combat if so
	if combat_ending:
		return  # Already ending combat, prevent duplicate calls
	
	# Check if all enemies are dead
	if alive_enemy_ids.is_empty():
		print("CombatScreen: All enemies dead, ending combat")
		_end_combat_and_transition()

func _end_combat_and_transition():
	## End combat and transition to rewards screen
	if combat_ending:
		return  # Guard against duplicate calls
	
	combat_ending = true
	
	# Stop combat in controller, clear combat status effects, and remove temporary cards
	if combat_controller:
		combat_controller.combat_active = false
		# Clear stacking status effects (Strength, Dexterity, Faith)
		combat_controller.player_stats.clear_combat_status_effects()
		# Remove temporary cards
		combat_controller._remove_temporary_cards()
	
	# Emit COMBAT_VICTORY event for quest system (before marking node completed)
	RunState.emit_game_event("COMBAT_VICTORY", {
		"node_id": RunState.current_node_id,
		"node_type": RunState.get_current_node_type()
	})
	
	# Mark node as completed (this also emits NODE_COMPLETED event)
	RunState.mark_current_node_completed()
	
	# Compute rewards based on node's reward flags
	var current_node = RunState.current_map.get_node(RunState.current_node_id) if RunState.current_map else null
	var bundle = RewardResolver.build_rewards_for_node(current_node)
	
	var node_type_str = "Unknown"
	if current_node:
		node_type_str = MapNodeData.NodeType.keys()[current_node.node_type]
	
	print("Combat ended: all enemies dead. NodeType=%s, Rewards: gold=%d, cards=%d, upgrades=%d, relic=%s" % [
		node_type_str, bundle.gold, bundle.card_choices.size(), bundle.upgrade_count, bundle.relic_id
	])
	
	# Set pending rewards
	RunState.set_pending_rewards(bundle)
	
	# Transition to rewards screen
	ScreenManager.go_to_rewards(bundle)
