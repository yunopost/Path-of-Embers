extends Node
var passed := 0
var failed := 0

func check(value: bool, message: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(message)

func _ready() -> void:
	call_deferred("probe")

func probe() -> void:
	for i in range(5):
		await get_tree().process_frame
	RunState.reset_run()
	PartyManager.set_party(["warrior_1", "witch", "living_armor"])
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	ScreenManager.current_scene = dummy
	ScreenManager.go_to_combat()
	for i in range(5):
		await get_tree().process_frame
	var screen = ScreenManager.current_scene
	var guide = screen.combat_guide
	var settings := ConfigFile.new()
	settings.set_value("guide", "seen", false)
	settings.save(guide.SETTINGS_PATH)
	guide.show_if_new()
	check(guide.visible and guide.exclusive, "First-fight guide must be modal")
	var ticks: int = screen.combat_controller.get_total_ticks()
	var energy: int = ResourceManager.energy
	for key in [KEY_SPACE, KEY_F]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		screen._unhandled_input(event)
	check(screen.combat_controller.get_total_ticks() == ticks, "Guide leaked a clock action")
	check(ResourceManager.energy == energy, "Guide leaked an energy action")
	guide.confirmed.emit()
	guide.hide()
	guide.show_if_new()
	check(not guide.visible, "Acknowledged guide should not repeat")
	screen.ability_bar.get_node("CombatGuideButton").pressed.emit()
	check(guide.visible, "Rules must be reopenable")
	guide.canceled.emit()
	guide.hide()
	check(screen.combat_controller.get_total_ticks() == ticks, "Closing rules spent time")
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	screen._unhandled_input(event)
	check(screen.combat_controller.get_total_ticks() == ticks + 1, "Input did not resume after rules closed")
	for i in range(5):
		await get_tree().process_frame
	var card: CardUI = screen.card_ui_instances[0]
	check(not card._get_tooltip(Vector2.ZERO).is_empty(), "Full card tooltip missing")
	print("--- combat_guide summary: %d passed, %d failed ---" % [passed, failed])
	get_tree().quit(1 if failed else 0)

