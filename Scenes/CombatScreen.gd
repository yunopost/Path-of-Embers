extends Control

## Combat screen with full combat implementation

@onready var combat_controller: CombatController = $CombatController
@onready var player_slots: HBoxContainer = $CombatArea/PlayerArea/PlayerSlots
@onready var enemy_slots: HBoxContainer = $CombatArea/EnemyArea/EnemySlots
@onready var hand_container: HBoxContainer = $HandArea/HandContainer
@onready var draw_pile_label: Label = $BottomUI/DrawPileArea/DrawPileLabel
@onready var energy_label: Label = $BottomUI/EnergyArea/EnergyLabel
@onready var discard_pile_label: Label = $BottomUI/DiscardPileArea/DiscardPileLabel
@onready var end_turn_button: Button = $BottomUI/EndTurnButton
@onready var play_area: ColorRect = $PlayArea
@onready var player_hp_label: Label = $CombatArea/PlayerArea/PlayerHPLabel

var card_ui_instances: Array[CardUI] = []

var enemy_displays: Array[Control] = []

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
	
	# Start combat with placeholder enemies
	_start_combat()

func _start_combat():
	## Initialize combat
	var enemy_data = [
		{"id": "enemy1", "name": "Test Enemy", "max_hp": 50}
	]
	combat_controller.start_combat(enemy_data)
	_setup_enemies()
	_update_hand()
	_update_draw_pile_count()
	_update_discard_pile_count()
	_update_energy()

func _setup_enemies():
	## Create enemy displays
	# Clear existing
	for child in enemy_slots.get_children():
		child.queue_free()
	enemy_displays.clear()
	
	for enemy in combat_controller.get_enemies():
		var enemy_display = _create_enemy_display(enemy)
		enemy_slots.add_child(enemy_display)
		enemy_displays.append(enemy_display)

func _create_enemy_display(enemy: CombatEnemy) -> Control:
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
	
	var name_label = Label.new()
	name_label.text = enemy.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "HP: %d/%d" % [enemy.stats.current_hp, enemy.stats.max_hp]
	vbox.add_child(hp_label)
	
	# Connect to stats signals
	enemy.stats.hp_changed.connect(func(hp): hp_label.text = "HP: %d/%d" % [hp, enemy.stats.max_hp])
	
	# Store enemy reference in metadata for targeting
	
	return enemy_panel

func _update_hand():
	## Update hand UI with current cards
	# Clear existing
	for card_ui in card_ui_instances:
		card_ui.queue_free()
	card_ui_instances.clear()
	
	# Wait for layout to update
	await get_tree().process_frame
	
	# Create card UIs for each card in hand
	for deck_card in RunState.hand:
		var card_ui = CardUI.new()
		hand_container.add_child(card_ui)
		card_ui.setup_card(deck_card)
		card_ui.card_played.connect(_on_card_played)
		
		# Set valid targets (enemies) - do this before waiting
		card_ui.valid_targets = enemy_displays
		
		card_ui_instances.append(card_ui)
		
		# Wait for card to be ready
		await get_tree().process_frame
		
		# Set play area after layout updates
		if play_area:
			var play_area_rect = Rect2(play_area.global_position, play_area.size)
			card_ui.play_area = play_area_rect

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

func _on_turn_ended():
	_update_player_hp()

func _on_end_turn_pressed():
	combat_controller.end_player_turn()
