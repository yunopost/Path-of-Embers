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
	ResourceManager.energy_changed.connect(_update_energy)
	ResourceManager.hp_changed.connect(_update_player_hp)
	
	# Connect combat controller signals
	combat_controller.combat_started.connect(_on_combat_started)
	combat_controller.turn_ended.connect(_on_turn_ended)
	
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
		end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP

	# Setup play area (invisible but detects drops)
	if play_area:
		play_area.color = Color(1, 1, 1, 0.08)  # Subtle guide — brightens green when card is dragged
		play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_apply_combat_ui_style()

	# Initialize screen (architecture rule 2.1)
	initialize()

func _apply_combat_ui_style() -> void:
	## Apply visual styling to combat screen elements

	# Hand tray: reduce overlap, add subtle background panel
	if hand_container:
		hand_container.add_theme_constant_override("separation", -30)
		var hand_area = hand_container.get_parent()
		if hand_area:
			var tray = Panel.new()
			tray.name = "HandTray"
			tray.set_anchors_preset(Control.PRESET_FULL_RECT)
			tray.z_index = -1
			tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tray_style = StyleBoxFlat.new()
			tray_style.bg_color = Color(0.08, 0.08, 0.10, 0.75)
			tray_style.corner_radius_top_left = 8
			tray_style.corner_radius_top_right = 8
			tray_style.border_color = Color(0.25, 0.20, 0.15, 0.6)
			tray_style.border_width_top = 1
			tray_style.border_width_left = 1
			tray_style.border_width_right = 1
			hand_area.add_child(tray)
			hand_area.move_child(tray, 0)

	# End Turn button: ember-themed styling
	if end_turn_button:
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color("#1A0808")
		btn_normal.border_color = Color("#8B2020")
		btn_normal.border_width_left = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_bottom = 2
		btn_normal.corner_radius_top_left = 4
		btn_normal.corner_radius_top_right = 4
		btn_normal.corner_radius_bottom_left = 4
		btn_normal.corner_radius_bottom_right = 4
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color("#2D0F0F")
		btn_hover.border_color = Color("#CC3333")
		var btn_pressed = btn_normal.duplicate()
		btn_pressed.bg_color = Color("#400808")
		end_turn_button.add_theme_stylebox_override("normal", btn_normal)
		end_turn_button.add_theme_stylebox_override("hover", btn_hover)
		end_turn_button.add_theme_stylebox_override("pressed", btn_pressed)
		end_turn_button.add_theme_color_override("font_color", Color("#FFD0A0"))
		end_turn_button.add_theme_font_size_override("font_size", 14)
		end_turn_button.text = "END TURN"

func initialize(encounter_data: Dictionary = {}):
	## Initialize the screen with encounter data
	## Must be called after instantiation, before use (architecture rule 2.1)
	# For now, use placeholder enemies if no data provided
	if encounter_data.is_empty():
		_start_combat()
	else:
		_start_combat_with_data(encounter_data)

func refresh_from_state():
	## Refresh UI from managers (architecture rule 11.2)
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
	_setup_character_portrait()
	# Note: _update_hand() will be called automatically via hand_changed signal when draw_cards() is called
	# Similarly, other updates will be triggered by their respective signals
	refresh_from_state()

## Role-based placeholder colors (mirrors CharacterEntry)
const PORTRAIT_ROLE_COLORS = {
	"Warrior":  Color("#5A2010"),
	"Healer":   Color("#14451E"),
	"Defender": Color("#102050"),
}
const PORTRAIT_ROLE_ICONS = {"Warrior": "⚔", "Healer": "✦", "Defender": "◈"}

func _setup_character_portrait() -> void:
	## Add a small character portrait panel above the player HP area
	if not player_area:
		return

	# Avoid duplicating on re-initialization
	var existing = player_area.get_node_or_null("CharacterPortrait")
	if existing:
		existing.queue_free()

	# Resolve the first party character
	var char_data: CharacterData = null
	if PartyManager and not PartyManager.party_ids.is_empty():
		var cid = PartyManager.party_ids[0]
		char_data = DataRegistry.get_character(cid) if DataRegistry else null

	# Portrait container (80×100px)
	var portrait_panel = Panel.new()
	portrait_panel.name = "CharacterPortrait"
	portrait_panel.custom_minimum_size = Vector2(80, 100)
	portrait_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Role border color
	var role_color = Color("#5A2010")  # default Warrior
	if char_data:
		role_color = PORTRAIT_ROLE_COLORS.get(char_data.role, role_color)
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = role_color.darkened(0.4)
	frame_style.border_color = role_color
	frame_style.border_width_left = 2
	frame_style.border_width_right = 2
	frame_style.border_width_top = 2
	frame_style.border_width_bottom = 2
	frame_style.corner_radius_top_left = 3
	frame_style.corner_radius_top_right = 3
	frame_style.corner_radius_bottom_left = 3
	frame_style.corner_radius_bottom_right = 3
	portrait_panel.add_theme_stylebox_override("panel", frame_style)

	# Try to load portrait texture
	var texture: Texture2D = null
	if char_data:
		var portrait_key = char_data.display_name.replace(" ", "%20")  # not needed, just use display_name
		if char_data.display_name == "Monster Hunter":
			texture = load("res://Path-of-Embers/Art Assets/Monster Hunter/Monster Hunter 2.png") \
				if ResourceLoader.exists("res://Path-of-Embers/Art Assets/Monster Hunter/Monster Hunter 2.png") else null
		elif char_data.display_name == "Witch":
			texture = load("res://Path-of-Embers/Art Assets/Witch/Witch 2.png") \
				if ResourceLoader.exists("res://Path-of-Embers/Art Assets/Witch/Witch 2.png") else null

	if texture:
		var tex_rect = TextureRect.new()
		tex_rect.texture = texture
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_panel.add_child(tex_rect)
	elif char_data:
		# Placeholder: role color + initials
		var words = char_data.display_name.split(" ")
		var initials = ""
		for w in words:
			if w.length() > 0:
				initials += w[0].to_upper()
		var init_lbl = Label.new()
		init_lbl.text = initials
		init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		init_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		init_lbl.add_theme_font_size_override("font_size", 32)
		init_lbl.modulate = Color(1, 1, 1, 0.7)
		init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_panel.add_child(init_lbl)

		var icon_lbl = Label.new()
		icon_lbl.text = PORTRAIT_ROLE_ICONS.get(char_data.role, "?")
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		icon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_lbl.offset_right = -4
		icon_lbl.offset_bottom = -4
		icon_lbl.add_theme_font_size_override("font_size", 14)
		icon_lbl.modulate = Color(1, 1, 1, 0.6)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_panel.add_child(icon_lbl)

	# Insert at top of player_area before other widgets
	player_area.add_child(portrait_panel)
	player_area.move_child(portrait_panel, 0)

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
	var health_bar_scene = load("res://Path-of-Embers/scenes/ui/HealthBar.tscn")
	if health_bar_scene:
		var health_bar = health_bar_scene.instantiate()
		health_bar.setup(enemy.stats)
		vbox.add_child(health_bar)
	
	# Status effect indicators (below health bar)
	var status_indicator_scene = load("res://Path-of-Embers/scenes/ui/StatusEffectIndicator.tscn")
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
			card_ui.play_area = Rect2(play_area.global_position, play_area.size)
			card_ui.play_area_node = play_area
	
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
		energy_label.text = "Energy: %d/%d" % [ResourceManager.energy, ResourceManager.max_energy]

func _update_player_hp():
	if player_hp_label:
		player_hp_label.text = "HP: %d/%d" % [ResourceManager.current_hp, ResourceManager.max_hp]
	if combat_controller and combat_controller.player_stats:
		combat_controller.player_stats.current_hp = ResourceManager.current_hp
	# Check for player defeat
	if ResourceManager.current_hp <= 0 and combat_controller and combat_controller.combat_active:
		_on_player_defeated()

func _on_player_defeated():
	## Handle player HP reaching zero — end combat and go to game over.
	if combat_ending:
		return
	combat_ending = true
	if combat_controller:
		combat_controller.combat_active = false
		combat_controller.end_combat(false)
	ScreenManager.go_to_game_over()

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
	var status_indicator_scene = load("res://Path-of-Embers/scenes/ui/StatusEffectIndicator.tscn")
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
	## End combat and transition to rewards screen (or back to Boss Rush screen).
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

	# Boss Rush: score is computed and submitted inside end_combat(); just navigate back
	if RunState and RunState.is_boss_rush:
		if combat_controller:
			combat_controller.end_combat(true)  # emits boss_rush_combat_finished + scores
		ScreenManager.go_to_boss_rush()
		return

	# Emit COMBAT_VICTORY event for quest system (before marking node completed)
	if QuestManager:
		QuestManager.emit_game_event("COMBAT_VICTORY", {
			"node_id": MapManager.current_node_id if MapManager else "",
			"node_type": MapManager.get_current_node_type() if MapManager else MapNodeData.NodeType.FIGHT
		})

	# Mark node as completed (this also emits NODE_COMPLETED event)
	if MapManager:
		MapManager.mark_current_node_completed()

	# Compute rewards based on node's reward flags
	var current_node = null
	if MapManager and MapManager.current_map:
		current_node = MapManager.current_map.get_node(MapManager.current_node_id)
	var bundle = RewardResolver.build_rewards_for_node(current_node)

	var node_type_str = "Unknown"
	if current_node:
		node_type_str = MapNodeData.NodeType.keys()[current_node.node_type]

	print("Combat ended: all enemies dead. NodeType=%s, Rewards: gold=%d, cards=%d, upgrades=%d" % [
		node_type_str, bundle.gold, bundle.card_choices.size(), bundle.upgrade_count
	])

	# Set pending rewards
	RunState.set_pending_rewards(bundle)

	# Transition to rewards screen
	ScreenManager.go_to_rewards(bundle)
