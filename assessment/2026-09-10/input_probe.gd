extends Node

func _ready():
	call_deferred("test_input")

func settle():
	for i in range(10): await get_tree().process_frame

func motion(pos: Vector2):
	var event = InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event,true)
	await settle()

func button(pos: Vector2,pressed: bool):
	var event = InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_viewport().push_input(event,true)
	await settle()

func test_input():
	get_tree().root.size=Vector2i(1920,1080)
	var dummy=Node.new()
	get_tree().root.add_child(dummy)
	ScreenManager.current_scene=dummy
	PartyManager.party_ids=["warrior_1","witch","living_armor"]
	var chars: Array[CharacterData]=[]
	for id in PartyManager.party_ids: chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)
	QuestManager.initialize_quests(chars)
	MapManager.set_map_data(MapGenerator.new().generate_map(1))
	MapManager.set_current_node(MapManager.current_map.start_node_ids[0])
	ScreenManager.go_to_combat({"enemies":[{"enemy_id":"ash_man","count":1}]})
	await settle()
	var s=ScreenManager.current_scene
	var cc=s.combat_controller
	print("INPUT PROBE initial hand=",RunState.deck_model.hand.size()," energy=",cc.current_energy)
	var card=null
	for candidate in s.card_ui_instances:
		if candidate.card_data.targeting_mode != CardData.TargetingMode.ENEMY:
			card=candidate
			break
	if not card:
		card=s.card_ui_instances[0]
	var start=card.get_global_rect().get_center()
	var end=start-Vector2(0,350)
	if card.card_data.targeting_mode == CardData.TargetingMode.ENEMY:
		end=s.enemy_displays[0].get_global_rect().get_center()
	await motion(start)
	var hovered=get_viewport().gui_get_hovered_control()
	print("INPUT PROBE hovered=",hovered," card=",card," rect=",card.get_global_rect()," mouse=",card.get_local_mouse_position())
	await button(start,true)
	print("INPUT PROBE after press dragging=",card.is_dragging)
	await motion(end)
	await button(end,false)
	print("INPUT PROBE after drag hand=",RunState.deck_model.hand.size()," energy=",cc.current_energy," ticks=",cc.total_ticks)
	var hud=ScreenManager.ui_root.find_child("PartyHUD",true,false)
	if hud:
		for block in hud._character_hud_blocks:
			print("INPUT PROBE HUD ",block._character_id," name=",block.name_label.text," portrait=",block.portrait.texture != null)
	get_tree().quit()
