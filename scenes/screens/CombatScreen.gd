extends Control

## Preloaded rather than referenced by class_name: a missing .uid meant Godot
## never registered the global class and the screen failed to parse at runtime.
const DEBUG_PANEL_SCRIPT = preload("res://scenes/ui/debug/DebugPanel.gd")
const COMBAT_GUIDE_SCRIPT = preload("res://scenes/ui/CombatGuide.gd")
const PRESENTATION_SCRIPT = preload("res://scenes/ui/CombatPresentation.gd")
var presentation: Node
var combat_guide: AcceptDialog

## Combat screen with full combat implementation

@onready var combat_controller: CombatController = $CombatController
@onready var player_slots: HBoxContainer = $CombatArea/PlayerAnchor/PlayerArea/PlayerSlots
@onready var enemy_slots: HBoxContainer = $CombatArea/EnemyAnchor/EnemyArea/EnemySlots
@onready var hand_container: HBoxContainer = $HandArea/HandContainer
@onready var draw_pile_label: Label = $CombatArea/PlayerAnchor/PlayerArea/DrawPileArea/DrawPileLabel
@onready var energy_label: Label = $BottomUI/EnergyArea/EnergyLabel
@onready var discard_pile_label: Label = $BottomUI/DiscardPileArea/DiscardPileLabel
@onready var ability_bar: HBoxContainer = $BottomUI/AbilityBar
@onready var tick_label: Label = $CombatArea/EnemyAnchor/EnemyArea/TickLabel
@onready var play_area: ColorRect = $PlayArea
@onready var player_hp_label: Label = $CombatArea/PlayerAnchor/PlayerArea/PlayerHPLabel
@onready var player_area: VBoxContainer = $CombatArea/PlayerAnchor/PlayerArea

var card_ui_instances: Array[CardUI] = []
var player_status_indicator: StatusEffectIndicator = null
var is_updating_hand: bool = false
var _hand_update_pending: bool = false  # a hand_changed that arrived mid-rebuild; replayed on completion

var enemy_displays: Array[Control] = []
var alive_enemy_ids: Array[String] = []
var combat_ending: bool = false

# Ability Bar (Card-Clock Combat spec §8/§10.8)
var ability_button_char_ids: Array[String] = []  # index -> character_id ("" = no ability / Focus slot)
var pending_ability_character_id: String = ""    # "" when not in ability target-select mode
var player_block_label: Label = null

# Enemy timer "act now" pulse (spec §8: pulse when a timer is at 1)
var enemy_pulse_tweens: Dictionary = {}  # enemy_id -> Tween

var _preview_refresh_accum: float = 0.0
const PREVIEW_REFRESH_INTERVAL: float = 0.15  # live card numbers (Strength/equipment/statuses/piles)

func _ready():
	# Connect signals
	RunState.hand_changed.connect(_update_hand)
	RunState.draw_pile_changed.connect(_update_draw_pile_count)
	RunState.discard_pile_changed.connect(_update_discard_pile_count)
	ResourceManager.energy_changed.connect(_update_energy)
	ResourceManager.hp_changed.connect(_update_player_hp)
	
	# Connect combat controller signals
	combat_controller.combat_started.connect(_on_combat_started)
	combat_controller.resource_action_taken.connect(_on_resource_action_taken)

	set_process_unhandled_input(true)
	set_process(true)

	# Setup play area (invisible but detects drops)
	if play_area:
		play_area.color = Color.TRANSPARENT  # The play zone appears only during a drag.
		play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_apply_combat_ui_style()
	resized.connect(_update_hand)
	resized.connect(_layout_combat)
	enemy_slots.minimum_size_changed.connect(_layout_combat)

	# Initialize screen (architecture rule 2.1)
	initialize()
	_layout_combat.call_deferred()
	combat_guide = AcceptDialog.new()
	combat_guide.set_script(COMBAT_GUIDE_SCRIPT)
	add_child(combat_guide)
	presentation = Node.new()
	presentation.set_script(PRESENTATION_SCRIPT)
	add_child(presentation)
	presentation.setup(self)
	if MapManager.current_map != null:
		combat_guide.call_deferred("show_if_new")

func _layout_combat() -> void:
	var floor_y := size.y * 0.68
	var anchor := $CombatArea/EnemyAnchor
	for display in enemy_displays:
		var sprite := display.find_child("EnemySprite", true, false) as TextureRect
		if sprite:
			var enemy: Enemy = display.get_meta("enemy")
			var boss := enemy.enemy_data.enemy_type == EnemyData.EnemyType.BOSS
			sprite.custom_minimum_size.y = minf(size.y * (0.34 if boss else 0.26), floor_y - (250 if boss else 290))
			display.custom_minimum_size.x = size.y * 0.40 if boss else 150
	for i in range(2):
		await get_tree().process_frame
	if not is_inside_tree():
		return
	var area := $CombatArea/EnemyAnchor/EnemyArea as VBoxContainer
	anchor.offset_top = floor_y - area.get_combined_minimum_size().y - size.y * 0.5
	anchor.offset_bottom = floor_y - size.y * 0.5

func _apply_combat_ui_style() -> void:
	## Apply visual styling to combat screen elements

	# Hand tray: reduce overlap, add subtle background panel
	if hand_container:
		hand_container.add_theme_constant_override("separation", 8)
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

	# Ability Bar buttons get the same ember theme as the old End Turn button.
	pass

func _style_ability_button(btn: Button) -> void:
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
	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color("#141414")
	btn_disabled.border_color = Color("#3A3A3A")
	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_pressed)
	btn.add_theme_stylebox_override("disabled", btn_disabled)
	btn.add_theme_color_override("font_color", Color("#FFD0A0"))
	btn.add_theme_color_override("font_color_disabled", Color("#707070"))
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(96, 44)

func initialize(encounter_data: Dictionary = {}):
	## Initialize the screen with encounter data
	## Must be called after instantiation, before use (architecture rule 2.1)
	_setup_background()
	# For now, use placeholder enemies if no data provided
	if encounter_data.is_empty():
		_start_combat()
	else:
		_start_combat_with_data(encounter_data)

func _setup_background() -> void:
	## Full-rect background behind all combat UI: boss art for BOSS/FINAL_BOSS
	## nodes, one of two standard combat backgrounds otherwise (picked
	## deterministically from the current map node id so it stays stable on
	## rebuild, but varies fight-to-fight).
	var node_type: int = MapNodeData.NodeType.FIGHT
	if MapManager and MapManager.has_method("get_current_node_type"):
		node_type = MapManager.get_current_node_type()

	var bg_path := "res://art/backgrounds/combat_courtyard_v2.png"
	if node_type == MapNodeData.NodeType.BOSS or node_type == MapNodeData.NodeType.FINAL_BOSS:
		bg_path = "res://art/backgrounds/boss_courtyard_v2.png"
	else:
		var seed_str: String = MapManager.current_node_id if MapManager else ""
		if seed_str.hash() % 2 == 1:
			bg_path = "res://art/backgrounds/combat_courtyard_v2.png"

	if not ResourceLoader.exists(bg_path):
		return
	var bg_tex = load(bg_path)
	if not bg_tex:
		return

	var bg_rect := TextureRect.new()
	bg_rect.name = "CombatBackground"
	bg_rect.texture = bg_tex
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_rect.z_index = -100
	add_child(bg_rect)
	move_child(bg_rect, 0)

func refresh_from_state():
	## Refresh UI from managers (architecture rule 11.2)
	_update_hand()
	_update_draw_pile_count()
	_update_discard_pile_count()
	_update_energy()
	_update_player_hp()

func _start_combat():
	## Build an encounter from the current map node (act + node type).
	if not SaveManager.combat_checkpoint.is_empty():
		_start_combat_with_data(SaveManager.combat_checkpoint["encounter"])
		return
	var act: int = MapManager.act if MapManager else 1
	var node_type: int = MapNodeData.NodeType.FIGHT
	if MapManager and MapManager.has_method("get_current_node_type"):
		node_type = MapManager.get_current_node_type()
	var encounter: Dictionary = EncounterDirector.build_encounter(act, node_type)
	_start_combat_with_data(encounter)

func _start_combat_with_data(encounter_data: Dictionary):
	## Initialize combat with provided encounter data
	var enemy_data = encounter_data.get("enemies", [])
	if enemy_data.is_empty():
		# Fallback: single standard enemy
		enemy_data = [
			{"enemy_id": "ash_man", "count": 1}
		]
	
	if MapManager.current_map and not RunState.is_boss_rush:
		ResourceManager.sync_equipment_hp()
		SaveManager.begin_combat_checkpoint({"enemies": enemy_data})
	combat_controller.start_combat(enemy_data)
	_setup_enemies()
	_setup_character_portrait()
	_setup_player_block_label()
	_setup_ability_bar()
	_update_tick_counter()
	# Note: _update_hand() will be called automatically via hand_changed signal when draw_cards() is called
	# Similarly, other updates will be triggered by their respective signals
	refresh_from_state()
	_setup_debug_panel()

func _setup_debug_panel() -> void:
	## Addendum §6: debug mode's Instant Win button. Resolves as a normal
	## victory (same path as beating every enemy) so rewards/quests/milestones
	## all fire correctly. Uses the shared DebugPanel.attach_to() helper so the
	## "already added" / debug-mode-off guards live in one place.
	var panel = DEBUG_PANEL_SCRIPT.attach_to(self, "combat")
	if panel:
		panel.instant_win_pressed.connect(_on_debug_instant_win)

func _on_debug_instant_win() -> void:
	if combat_ending:
		return
	_end_combat_and_transition()

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

	# Try to load portrait texture from CharacterData.portrait_path — one path for all characters.
	var texture: Texture2D = null
	if char_data and char_data.portrait_path != "" and ResourceLoader.exists(char_data.portrait_path):
		texture = load(char_data.portrait_path)

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

# -- Player Block tooltip (spec S8) --------------------------------------------

func _setup_player_block_label() -> void:
	if not player_area or not combat_controller or not combat_controller.player_stats:
		return
	if player_block_label and is_instance_valid(player_block_label):
		player_block_label.queue_free()
		player_block_label = null

	player_block_label = Label.new()
	player_block_label.name = "PlayerBlockLabel"
	player_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_block_label.tooltip_text = "Block absorbs damage and remains until damage consumes it."
	player_block_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_player_block_label(combat_controller.player_stats.block)

	var hp_label_index = player_area.get_child_count()
	for i in range(player_area.get_child_count()):
		if player_area.get_child(i) == player_hp_label:
			hp_label_index = i + 1
			break
	player_area.add_child(player_block_label)
	player_area.move_child(player_block_label, hp_label_index)

	if not combat_controller.player_stats.block_changed.is_connected(_update_player_block_label):
		combat_controller.player_stats.block_changed.connect(_update_player_block_label)

func _update_player_block_label(new_block: int) -> void:
	if not player_block_label or not is_instance_valid(player_block_label):
		return
	player_block_label.text = "Block: %d" % new_block if new_block > 0 else ""

# -- Ability Bar (spec S8/S10.8) -----------------------------------------------
## Breathe and Focus replace End Turn. Space = Breathe, F = Focus.
## ENEMY-targeted abilities enter target-select (click an enemy to confirm, Escape cancels).

func _setup_ability_bar() -> void:
	## Addendum §4 item 1: the bottom bar keeps only Breathe and Focus. Each
	## character's ability button now lives under their portrait in the party
	## HUD (see _bind_party_hud_abilities / CharacterHUDBlock).
	if not ability_bar:
		return
	for child in ability_bar.get_children():
		child.queue_free()
	ability_button_char_ids.clear()
	pending_ability_character_id = ""

	var breathe_btn = Button.new()
	breathe_btn.name = "BreatheButton"
	breathe_btn.text = "BREATHE\n[Space]"
	breathe_btn.tooltip_text = "Breathe: +1 Energy (no upper cap). 1 tick. No cooldown."
	breathe_btn.pressed.connect(_on_breathe_pressed)
	_style_ability_button(breathe_btn)
	ability_bar.add_child(breathe_btn)

	var focus_btn = Button.new()
	focus_btn.name = "FocusButton"
	focus_btn.text = "FOCUS\n[F]"
	focus_btn.tooltip_text = "Focus: draw 2. 1 tick. No cooldown."
	focus_btn.pressed.connect(_on_focus_pressed)
	_style_ability_button(focus_btn)
	ability_bar.add_child(focus_btn)
	var guide_btn := Button.new()
	guide_btn.name = "CombatGuideButton"
	guide_btn.text = "HOW TO\nPLAY"
	guide_btn.pressed.connect(func():
		_cancel_ability_targeting()
		combat_guide.show_guide())
	_style_ability_button(guide_btn)
	ability_bar.add_child(guide_btn)

	_bind_party_hud_abilities()
	_refresh_ability_bar()

func _bind_party_hud_abilities() -> void:
	## Wire the party HUD's per-character ability buttons (Addendum §4 item 1)
	## to this combat, and listen for presses.
	var party_hud := _get_party_hud()
	if not party_hud:
		return
	party_hud.bind_combat(combat_controller)
	if not party_hud.ability_pressed.is_connected(_on_ability_button_pressed):
		party_hud.ability_pressed.connect(_on_ability_button_pressed)

func _unbind_party_hud_abilities() -> void:
	var party_hud := _get_party_hud()
	if not party_hud:
		return
	if party_hud.ability_pressed.is_connected(_on_ability_button_pressed):
		party_hud.ability_pressed.disconnect(_on_ability_button_pressed)
	party_hud.unbind_combat()

func _get_party_hud() -> Control:
	if not ScreenManager or not ScreenManager.ui_root:
		return null
	return ScreenManager.ui_root.party_hud

func _refresh_ability_bar() -> void:
	var party_hud := _get_party_hud()
	if party_hud:
		party_hud.refresh_ability_states()
	if presentation:
		presentation.refresh()

func _on_breathe_pressed() -> void:
	_cancel_ability_targeting()
	combat_controller.breathe()
	_check_combat_end()
	_refresh_ability_bar()
	_update_tick_counter()

func _on_focus_pressed() -> void:
	_cancel_ability_targeting()
	combat_controller.focus()
	_check_combat_end()
	_refresh_ability_bar()
	_update_tick_counter()

func _on_ability_button_pressed(character_id: String) -> void:
	if not combat_controller.can_use_ability(character_id):
		return
	var char_data: CharacterData = DataRegistry.get_character(character_id)
	var ability: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id)
	if ability.targeting_mode == CardData.TargetingMode.ENEMY:
		_begin_ability_targeting(character_id)
	else:
		combat_controller.use_ability(character_id, null)
		_check_combat_end()
		_refresh_ability_bar()
		_update_tick_counter()

func _begin_ability_targeting(character_id: String) -> void:
	pending_ability_character_id = character_id
	_refresh_ability_bar()

func _cancel_ability_targeting() -> void:
	if pending_ability_character_id.is_empty():
		return
	pending_ability_character_id = ""
	_refresh_ability_bar()

func _on_enemy_panel_gui_input(event: InputEvent, enemy_panel: Control) -> void:
	if pending_ability_character_id.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var character_id := pending_ability_character_id
		pending_ability_character_id = ""
		var ok: bool = combat_controller.use_ability(character_id, enemy_panel)
		if ok:
			_check_combat_end()
		_refresh_ability_bar()
		_update_tick_counter()

func _unhandled_input(event: InputEvent) -> void:
	if combat_guide and combat_guide.visible:
		return
	if not combat_controller or not combat_controller.combat_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_breathe_pressed()
				get_viewport().set_input_as_handled()
			KEY_F:
				_on_focus_pressed()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if not pending_ability_character_id.is_empty():
					_cancel_ability_targeting()
					get_viewport().set_input_as_handled()

func _update_tick_counter() -> void:
	if tick_label and combat_controller:
		tick_label.text = "Tick %d" % combat_controller.get_total_ticks()

# -- Enemy timer "act now" pulse (spec S8) -------------------------------------

func _update_enemy_pulse(enemy: Enemy, timer_label: Label, current: int) -> void:
	var should_pulse: bool = current == 1 and enemy.stats.is_alive()
	var existing: Tween = enemy_pulse_tweens.get(enemy.enemy_id, null)
	if should_pulse:
		if existing and existing.is_valid():
			return  # already pulsing
		var tween := create_tween().set_loops()
		tween.tween_property(timer_label, "modulate", Color(1.0, 0.35, 0.2, 1.0), 0.35)
		tween.tween_property(timer_label, "modulate", Color(1, 1, 1, 1), 0.35)
		enemy_pulse_tweens[enemy.enemy_id] = tween
	else:
		if existing and existing.is_valid():
			existing.kill()
		enemy_pulse_tweens.erase(enemy.enemy_id)
		if is_instance_valid(timer_label):
			timer_label.modulate = Color(1, 1, 1, 1)

# -- Enemy timer ghost preview on card hover (spec S8) -------------------------

func _process(delta: float) -> void:
	## Keep every hand card's displayed numbers live (Job: real-time card
	## numbers) -- Strength/Dexterity/Faith, equipment, Vulnerable/Weakness/
	## Agility and pile sizes all change without any card ever moving, so a
	## card sitting still in hand still needs to be re-previewed periodically
	## rather than only on setup/hover/drag.
	_preview_refresh_accum += delta
	if _preview_refresh_accum < PREVIEW_REFRESH_INTERVAL:
		return
	_preview_refresh_accum = 0.0
	for card_ui in card_ui_instances:
		if is_instance_valid(card_ui):
			card_ui.refresh_preview()
	_refresh_ability_bar()  # also keeps each party member's stat readout (STR/DEF/SPI/HP) live

func _on_card_hover_start(card_ui: CardUI) -> void:
	if not card_ui or not card_ui.deck_card_data or not combat_controller:
		return
	var instance_id: String = str(card_ui.deck_card_data.instance_id)
	var predicted: int = RunState.predict_timer_tick_amount_for_card(instance_id)
	for enemy in combat_controller.get_enemies():
		if not enemy.stats.is_alive():
			continue
		var ghost_value: int = max(0, enemy.time_current - predicted)
		_set_enemy_ghost(enemy, ghost_value, predicted)

func _on_card_hover_end(_card_ui: CardUI = null) -> void:
	if not combat_controller:
		return
	for enemy in combat_controller.get_enemies():
		_set_enemy_ghost(enemy, -1, 0)

func _set_enemy_ghost(enemy: Enemy, ghost_value: int, predicted: int) -> void:
	var panel: Control = null
	for d in enemy_displays:
		if is_instance_valid(d) and d.get_meta("enemy", null) == enemy:
			panel = d
			break
	if not panel:
		return
	var ghost_label: Label = panel.find_child("GhostLabel", true, false)
	if not ghost_label:
		return
	if ghost_value < 0:
		ghost_label.visible = false
		ghost_label.text = ""
	else:
		ghost_label.visible = true
		ghost_label.text = "-> %d" % ghost_value if predicted > 0 else "(no change -- Haste)"

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

# -- Enemy intent rendering from effects (Addendum §4 item 4) -----------------
## Six intent icons exist at art/ui/icon_intent_*.png: attack, defend,
## buff, debuff, heal, multi. There is NO icon_intent_special.png in the asset
## drop despite the spec calling for a "special" fallback -- "multi" is used
## as the generic fallback instead (closest existing icon); flagged for
## Director/Art follow-up rather than guessed at further.
const INTENT_ICON_PATHS := {
	"attack": "res://art/ui/icon_intent_attack.png",
	"defend": "res://art/ui/icon_intent_defend.png",
	"buff": "res://art/ui/icon_intent_buff.png",
	"debuff": "res://art/ui/icon_intent_debuff.png",
	"heal": "res://art/ui/icon_intent_heal.png",
	"multi": "res://art/ui/icon_intent_multi.png",
}
var _intent_icon_cache: Dictionary = {}

func _get_intent_icon(icon_key: String) -> Texture2D:
	if _intent_icon_cache.has(icon_key):
		return _intent_icon_cache[icon_key]
	var path: String = INTENT_ICON_PATHS.get(icon_key, INTENT_ICON_PATHS["multi"])
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_intent_icon_cache[icon_key] = tex
	return tex

func _intent_icon_key_for_effect(effect_type: String) -> String:
	match effect_type:
		EffectType.DAMAGE, EffectType.DAMAGE_EQUAL_TO_BLOCK, EffectType.DAMAGE_PER_CURSE, \
		EffectType.DAMAGE_CONDITIONAL_ELITE, EffectType.DAMAGE_SPITE, EffectType.DAMAGE_SEQUENCING, \
		EffectType.DAMAGE_CONDITIONAL_TOP_CARD, EffectType.DELAYED_DAMAGE:
			return "attack"
		EffectType.BLOCK, EffectType.BLOCK_ON_ENEMY_ACT:
			return "defend"
		EffectType.VULNERABLE, EffectType.VULNERABLE_ALL_ENEMIES, EffectType.WEAKNESS:
			return "debuff"
		EffectType.STRENGTH, EffectType.DEXTERITY, EffectType.FAITH:
			return "buff"
		EffectType.HEAL:
			return "heal"
		_:
			return "multi"

func _intent_effect_value_text(effect: EffectData) -> String:
	var p: Dictionary = effect.params
	match effect.effect_type:
		EffectType.DAMAGE, EffectType.DAMAGE_EQUAL_TO_BLOCK, EffectType.DAMAGE_PER_CURSE, \
		EffectType.DAMAGE_CONDITIONAL_ELITE, EffectType.DAMAGE_SPITE, EffectType.DAMAGE_SEQUENCING, \
		EffectType.DAMAGE_CONDITIONAL_TOP_CARD, EffectType.DELAYED_DAMAGE:
			var amt: int = int(p.get("amount", 0))
			var hits: int = int(p.get("hit_count", 1))
			return "%dx%d" % [amt, hits] if hits > 1 else str(amt)
		EffectType.BLOCK:
			return str(int(p.get("amount", 0)))
		EffectType.VULNERABLE, EffectType.VULNERABLE_ALL_ENEMIES, EffectType.WEAKNESS:
			return "%d" % int(p.get("duration", 0))
		EffectType.HEAL:
			return str(int(p.get("amount", 0)))
		EffectType.STRENGTH, EffectType.DEXTERITY, EffectType.FAITH:
			return "+%d" % int(p.get("amount", 0))
		_:
			return ""

func _build_intent_entries(intent: IntentData) -> Array:
	## Walk the intent's effects (not telegraph_text) to build one
	## {icon_key, value_text} entry per effect. Handles the legacy dummy-enemy
	## fallback (values={"damage":N}, no move_data) too.
	var entries: Array = []
	if intent == null:
		return entries
	var move_data = intent.values.get("move_data", null)
	if move_data is Dictionary and move_data.has("effects"):
		for effect in move_data.get("effects", []):
			if not (effect is EffectData):
				continue
			entries.append({
				"icon_key": _intent_icon_key_for_effect(effect.effect_type),
				"value_text": _intent_effect_value_text(effect),
			})
	elif intent.values.has("damage"):
		entries.append({"icon_key": "attack", "value_text": str(int(intent.values.get("damage", 0)))})
	return entries

func _populate_intent_row(intent_row: HBoxContainer, intent: IntentData) -> void:
	if not is_instance_valid(intent_row):
		return
	for child in intent_row.get_children():
		child.queue_free()
	intent_row.tooltip_text = intent.telegraph_text if intent else ""

	var entries: Array = _build_intent_entries(intent)
	if entries.is_empty():
		var none_label = Label.new()
		none_label.text = "--"
		intent_row.add_child(none_label)
		return

	for entry in entries:
		var item = HBoxContainer.new()
		item.add_theme_constant_override("separation", 2)
		var icon_tex := _get_intent_icon(entry.icon_key)
		if icon_tex:
			var icon_rect = TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.custom_minimum_size = Vector2(16, 16)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			item.add_child(icon_rect)
		if not entry.value_text.is_empty():
			var val_label = Label.new()
			val_label.text = entry.value_text
			val_label.add_theme_font_size_override("font_size", 13)
			item.add_child(val_label)
		intent_row.add_child(item)

func _create_enemy_display(enemy: Enemy) -> Control:
	var enemy_panel = PanelContainer.new()
	enemy_panel.custom_minimum_size = Vector2(150, 200)
	enemy_panel.name = "Enemy_" + enemy.enemy_id
	enemy_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	enemy_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	# Store reference to enemy for targeting
	enemy_panel.set_meta("enemy", enemy)
	
	var vbox = VBoxContainer.new()
	enemy_panel.add_child(vbox)
	
	# Sprite (above name/timer/intent), sized to fit the panel
	var enemy_blueprint: EnemyData = enemy.enemy_data if enemy.enemy_data else (DataRegistry.get_enemy(enemy.enemy_id) if DataRegistry else null)
	if enemy_blueprint and enemy_blueprint.sprite_path != "" and ResourceLoader.exists(enemy_blueprint.sprite_path):
		var sprite_tex = load(enemy_blueprint.sprite_path)
		if sprite_tex:
			var sprite_rect = TextureRect.new()
			sprite_rect.name = "EnemySprite"
			sprite_rect.texture = sprite_tex
			sprite_rect.custom_minimum_size = Vector2(0, 110)
			sprite_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(sprite_rect)
	
	# Health bar (at top)
	var health_bar_scene = load("res://scenes/ui/HealthBar.tscn")
	if health_bar_scene:
		var health_bar = health_bar_scene.instantiate()
		health_bar.setup(enemy.stats)
		vbox.add_child(health_bar)
	
	# Status effect indicators (below health bar)
	var status_indicator_scene = load("res://scenes/ui/StatusEffectIndicator.tscn")
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

	# Ghost preview label (spec §8): dimmed "-> N" showing where this enemy's timer
	# lands after the hovered card resolves. Hidden except during a hover.
	var ghost_label = Label.new()
	ghost_label.name = "GhostLabel"
	ghost_label.text = ""
	ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost_label.modulate = Color(1, 1, 1, 0.55)
	ghost_label.add_theme_font_size_override("font_size", 12)
	ghost_label.visible = false
	vbox.add_child(ghost_label)
	
	# Intent row (Addendum §4 item 4): icon + value per effect the intent
	# resolves to, derived from the move's `effects` array (not telegraph_text).
	# telegraph_text is kept only as the row's tooltip/flavour.
	var intent_row = HBoxContainer.new()
	intent_row.name = "IntentRow"
	intent_row.alignment = BoxContainer.ALIGNMENT_CENTER
	intent_row.add_theme_constant_override("separation", 6)
	intent_row.custom_minimum_size = Vector2(0, 24)
	intent_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(intent_row)
	_populate_intent_row(intent_row, enemy.intent)
	var battle_sprite := vbox.get_node_or_null("EnemySprite")
	if battle_sprite:
		vbox.move_child(battle_sprite, vbox.get_child_count() - 1)

	# Connect to timer and intent signals
	enemy.time_changed.connect(func(current, max_time):
		timer_label.text = "Timer: %d/%d" % [current, max_time]
		_update_enemy_pulse(enemy, timer_label, current))
	enemy.intent_changed.connect(func(new_intent): _populate_intent_row(intent_row, new_intent))
	_update_enemy_pulse(enemy, timer_label, enemy.time_current)

	# Click-to-target for ability target-select mode (spec §8: click an enemy to confirm)
	enemy_panel.gui_input.connect(_on_enemy_panel_gui_input.bind(enemy_panel))
	
	return enemy_panel

func _update_hand():
	if is_updating_hand:
		_hand_update_pending = true
		return
	is_updating_hand = true
	_hand_update_pending = false
	var hand_cards: Array[DeckCardData] = RunState.deck_model.get_hand_cards()
	var existing := {}
	for ui in card_ui_instances:
		if is_instance_valid(ui):
			existing[ui.deck_card_data.instance_id] = ui
	var next_cards: Array[CardUI] = []
	var newcomers: Array[CardUI] = []
	var available_width := maxf(size.x, get_viewport_rect().size.x)
	var width := 210.0
	var separation := minf(8.0, (available_width - 340.0 - width * hand_cards.size()) / max(1, hand_cards.size() - 1))
	hand_container.add_theme_constant_override("separation", int(separation))
	for card in hand_cards:
		var ui: CardUI = existing.get(card.instance_id)
		if ui:
			existing.erase(card.instance_id)
		else:
			ui = CardUI.new()
			ui.card_width = width
			hand_container.add_child(ui)
			ui.setup_card(card)
			ui.set_combat_controller(combat_controller)
			ui.card_played.connect(_on_card_played)
			ui.mouse_entered.connect(_on_card_hover_start.bind(ui))
			ui.mouse_exited.connect(_on_card_hover_end.bind(ui))
			newcomers.append(ui)
		ui.custom_minimum_size.x = width
		ui.resting_rotation = deg_to_rad((float(next_cards.size()) / maxf(1, hand_cards.size() - 1) - 0.5) * 7.0)
		ui.card_panel.pivot_offset = Vector2(width * 0.5, 280)
		ui.card_panel.rotation = ui.resting_rotation
		ui.card_widget.custom_minimum_size.x = width
		ui.card_width = width
		ui.valid_targets = enemy_displays
		hand_container.move_child(ui, next_cards.size())
		next_cards.append(ui)
	for ui in existing.values():
		hand_container.remove_child(ui)
		ui.queue_free()
	card_ui_instances = next_cards
	await get_tree().process_frame
	await get_tree().process_frame
	for ui in card_ui_instances:
		ui.play_area = Rect2(play_area.global_position, play_area.size)
		ui.play_area_node = play_area
		ui.refresh_preview()
	for i in range(newcomers.size()):
		var ui := newcomers[i]
		if is_instance_valid(ui):
			ui.animate_draw(draw_pile_label.global_position, i * 0.035)
	is_updating_hand = false
	if _hand_update_pending:
		await _update_hand()

func _on_card_played(card_ui: CardUI, target: Node = null):
	## Handle card being played
	var deck_card = card_ui.deck_card_data
	if not deck_card:
		return
	var ghost := CardWidget.new()
	ghost.name = "PlayedCardMotion"
	ghost.card_width = card_ui.card_width
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 200
	add_child(ghost)
	ghost.setup_card(deck_card)
	ghost.position = card_ui.global_position - global_position
	var start := ghost.position
	
	_on_card_hover_end()  # card is leaving the hand either way; drop any ghost preview
	var success = combat_controller.play_card(deck_card, target)
	if not success:
		# Card couldn't be played (not enough energy)
		card_ui._snap_back()
		ghost.queue_free()
	else:
		var motion := create_tween()
		motion.tween_property(ghost, "position", start + Vector2(0, -80), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		motion.tween_interval(0.08)
		if card_ui.card_data.keywords.has("Exhaust"):
			motion.tween_property(ghost, "modulate", Color(1, 0.35, 0.05, 0), 0.22)
		else:
			motion.set_parallel(true)
			motion.tween_property(ghost, "position", discard_pile_label.global_position - global_position, 0.28).set_delay(0.20)
			motion.tween_property(ghost, "scale", Vector2(0.15, 0.15), 0.28).set_delay(0.20)
			motion.tween_property(ghost, "modulate:a", 0.0, 0.28).set_delay(0.20)
		motion.chain().tween_callback(ghost.queue_free)
		if is_instance_valid(target) and target is Control:
			var flash := create_tween()
			flash.tween_property(target, "modulate", Color(1.4, 0.7, 0.4), 0.06)
			flash.tween_property(target, "modulate", Color.WHITE, 0.18)
	_refresh_ability_bar()
	_update_tick_counter()

func _update_draw_pile_count():
	if draw_pile_label:
		draw_pile_label.text = "Draw: %d" % RunState.get_draw_pile_count()

func _update_discard_pile_count():
	if discard_pile_label:
		discard_pile_label.text = "Discard: %d" % RunState.get_discard_pile_count()

func _update_energy():
	## Energy has no maximum (Design ruling, 10 Sep 2026) — show the current value only.
	if energy_label:
		energy_label.text = "Energy: %d" % ResourceManager.energy

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
	_unbind_party_hud_abilities()
	# Addendum B §2: run loss -- only the backpack's safe-slot item survives
	# to the persistent stash. Must happen before GameOverScreen's "New Run" /
	# "Main Menu" buttons call RunState.reset_run() and wipe the backpack.
	if RunState:
		RunState.settle_backpack_on_loss()
	SaveManager.clear_combat_checkpoint()
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
	var status_indicator_scene = load("res://scenes/ui/StatusEffectIndicator.tscn")
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

func _on_resource_action_taken():
	_update_player_hp()
	_refresh_ability_bar()
	_update_tick_counter()
	# Check for combat end after turn (enemies may have died during enemy actions)
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
	_unbind_party_hud_abilities()

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
			"act": MapManager.act,
			"node_id": MapManager.current_node_id if MapManager else "",
			"node_type": MapManager.get_current_node_type() if MapManager else MapNodeData.NodeType.FIGHT
		})

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
	# Completion and rewards are saved together; no completed-boss save may
	# exist without its rewards or with an obsolete pre-fight checkpoint.
	SaveManager.clear_combat_checkpoint()
	if MapManager:
		MapManager.mark_current_node_completed()

	# Transition to rewards screen
	ScreenManager.go_to_rewards(bundle)
