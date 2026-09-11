extends Node
## Presentation only: no combat mutations or save state.
var screen: Control
var party_art: Control
var actions: VBoxContainer
var draw_panel: PanelContainer
var discard_panel: PanelContainer
var help_button: Button
var energy_panel: PanelContainer
var ability_sources: Array[Button] = []
var ability_copies: Array[Button] = []
var compact_blocks: Array[Control] = []
var last_hp := 0
var last_block := 0

func setup(owner_screen: Control) -> void:
	screen = owner_screen
	screen.player_area.visible = false
	screen.get_node("HandArea/HandLabel").hide()
	actions = VBoxContainer.new()
	actions.name = "LeftActions"
	actions.add_theme_constant_override("separation", 8)
	screen.add_child(actions)
	for button in screen.ability_bar.get_children():
		if button.name == "CombatGuideButton":
			help_button = button
			button.reparent(screen)
			button.custom_minimum_size = Vector2(124, 30)
			button.text = "How to Play"
			var help_style := StyleBoxFlat.new()
			help_style.bg_color = Color("202b35ee")
			help_style.border_color = Color("657783")
			help_style.set_border_width_all(1)
			help_style.set_corner_radius_all(4)
			help_style.content_margin_top = 6
			help_style.content_margin_bottom = 6
			button.add_theme_stylebox_override("normal", help_style)
			button.add_theme_stylebox_override("hover", help_style)
			button.add_theme_color_override("font_color", Color("d2dcdf"))
		else:
			button.reparent(actions)
			button.custom_minimum_size = Vector2(116, 54)
	# Pile labels remain the same live signal subscribers after reparenting.
	draw_panel = _pile_panel(screen.draw_pile_label)
	discard_panel = _pile_panel(screen.discard_pile_label)
	energy_panel = _pile_panel(screen.energy_label)
	energy_panel.z_index = 120
	energy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var energy_style := energy_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	energy_style.bg_color = Color("17292fff")
	energy_style.border_color = Color("7cabb3")
	energy_style.content_margin_top = 7
	energy_style.content_margin_bottom = 7
	energy_panel.add_theme_stylebox_override("panel", energy_style)
	party_art = Control.new()
	party_art.name = "BattlefieldParty"
	party_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(party_art)
	for id in PartyManager.party_ids:
		var character := DataRegistry.get_character(id)
		var sprite := TextureRect.new()
		var path: String = character.fullbody_path if not character.fullbody_path.is_empty() else character.portrait_path
		if ResourceLoader.exists(path):
			sprite.texture = load(path)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		party_art.add_child(sprite)
	screen.resized.connect(layout)
	last_hp = screen.combat_controller.player_stats.current_hp
	last_block = screen.combat_controller.player_stats.block
	screen.combat_controller.player_stats.hp_changed.connect(func(hp: int):
		var delta := hp - last_hp
		if delta != 0:
			feedback(("+" if delta > 0 else "") + str(delta), Color("8ed6ac") if delta > 0 else Color("ff9b74"), party_art.position + party_art.size * 0.5)
		last_hp = hp)
	screen.combat_controller.player_stats.block_changed.connect(func(block: int):
		if block > last_block:
			feedback("+%d Block" % (block - last_block), Color("b3ccde"), party_art.position + party_art.size * 0.5)
		last_block = block)
	call_deferred("_compact_hud")
	layout()

func feedback(text: String, color: Color, at_position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at_position
	label.z_index = 220
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("171311"))
	label.add_theme_constant_override("outline_size", 5)
	screen.add_child(label)
	var motion := label.create_tween().set_parallel(true)
	motion.tween_property(label, "position:y", at_position.y - 45, 0.6)
	motion.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.3)
	motion.chain().tween_callback(label.queue_free)

func _compact_hud() -> void:
	var hud = screen._get_party_hud()
	if not hud:
		return
	for block in hud._character_hud_blocks:
		compact_blocks.append(block)
		block.set_compact(true)
		var source: Button = block.ability_button
		var button := Button.new()
		button.custom_minimum_size = Vector2(116, 46)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		screen._style_ability_button(button)
		button.pressed.connect(func(): source.pressed.emit())
		actions.add_child(button)
		ability_sources.append(source)
		ability_copies.append(button)
	refresh()

func refresh() -> void:
	for i in range(ability_sources.size()):
		if is_instance_valid(ability_sources[i]):
			ability_copies[i].text = ability_sources[i].text
			ability_copies[i].tooltip_text = ability_sources[i].tooltip_text
			ability_copies[i].disabled = ability_sources[i].disabled

func _exit_tree() -> void:
	for block in compact_blocks:
		if is_instance_valid(block):
			block.set_compact(false)

func _pile_panel(label: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	screen.add_child(panel)
	label.reparent(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171311ee")
	style.border_color = Color("9e7748")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	return panel

func layout() -> void:
	var extent := screen.size
	actions.position = Vector2(20, 180)
	if is_instance_valid(help_button):
		help_button.position = Vector2(extent.x - 144, 112)
	draw_panel.position = Vector2(20, extent.y - 94)
	discard_panel.position = Vector2(extent.x - 146, extent.y - 94)
	var hand := screen.get_node("HandArea") as Control
	hand.offset_left = -(extent.x - 340) * 0.5
	hand.offset_right = (extent.x - 340) * 0.5
	hand.offset_top = -clampf(extent.y * 0.235, 170, 240)
	hand.offset_bottom = 110
	party_art.position = Vector2(extent.x * 0.13, extent.y * 0.38)
	party_art.size = Vector2(extent.x * 0.36, extent.y * 0.30)
	var count := party_art.get_child_count()
	for i in range(count):
		var sprite := party_art.get_child(i) as TextureRect
		if sprite.texture:
			var source_size := sprite.texture.get_size()
			var factor := minf(party_art.size.y / source_size.y, (party_art.size.x / count + 22) / source_size.x)
			sprite.size = source_size * factor
			sprite.position = Vector2((i + 0.5) * party_art.size.x / count - sprite.size.x * 0.5, party_art.size.y - sprite.size.y)
	var bottom := screen.get_node("BottomUI") as Control
	bottom.offset_left = -extent.x * 0.5 - 90
	bottom.offset_right = -extent.x * 0.5 + 90
	bottom.offset_top = -28
	bottom.offset_bottom = 0
	screen.energy_label.add_theme_font_size_override("font_size", 20)
	energy_panel.position = Vector2(extent.x * 0.5 - 65, extent.y - 45)
	energy_panel.custom_minimum_size = Vector2(130, 42)
