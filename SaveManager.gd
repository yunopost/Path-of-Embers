extends Node

## Autoload singleton - Handles save/load of game state
## Serializes RunState to JSON and saves/loads from user://save_run.json

const SAVE_PATH = "user://save_run.json"

signal save_completed
signal load_completed
signal save_failed(error_message: String)
signal load_failed(error_message: String)

func save_game() -> bool:
	var save_data = _serialize_run_state()
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var error_msg = "Failed to open save file for writing: " + SAVE_PATH
		push_error(error_msg)
		save_failed.emit(error_msg)
		return false
	
	file.store_string(JSON.stringify(save_data))
	file.close()
	
	save_completed.emit()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("Save file does not exist: " + SAVE_PATH)
		load_failed.emit("Save file does not exist")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		var error_msg = "Failed to open save file for reading: " + SAVE_PATH
		push_error(error_msg)
		load_failed.emit(error_msg)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		var error_msg = "Failed to parse JSON: %s" % json.get_error_message()
		push_error(error_msg)
		load_failed.emit(error_msg)
		return false
	
	var save_data = json.data
	_deserialize_run_state(save_data)
	
	load_completed.emit()
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save_file() -> bool:
	if not has_save_file():
		return true
	
	var dir = DirAccess.open("user://")
	if dir == null:
		return false
	
	return dir.remove(SAVE_PATH.get_file()) == OK

func _serialize_run_state() -> Dictionary:
	# Convert deck to serializable format
	var deck_data = []
	for deck_card in RunState.deck:
		if deck_card is DeckCardData:
			deck_data.append(deck_card.to_dict())
		else:
			# Fallback for legacy string format
			deck_data.append({
				"card_id": str(deck_card),
				"applied_upgrades": [],
				"is_transcended": false,
				"transcendent_card_id": ""
			})
	
	# Convert quests to serializable format
	var quests_data = []
	for quest in RunState.quests:
		if quest is Dictionary:
			quests_data.append(quest)
		elif quest is QuestData:
			quests_data.append({
				"id": quest.id,
				"name": quest.name,
				"description": quest.description,
				"progress_fields": quest.progress_fields,
				"completion_condition": quest.completion_condition,
				"is_complete": quest.is_complete
			})
		else:
			# Fallback for string/other formats
			quests_data.append({"id": str(quest)})
	
	return {
		"version": 1,
		"party": RunState.party,
		"deck": deck_data,
		"relics": RunState.relics,
		"gold": RunState.gold,
		"current_hp": RunState.current_hp,
		"max_hp": RunState.max_hp,
		"block": RunState.block,
		"energy": RunState.energy,
		"max_energy": RunState.max_energy,
		"act": RunState.act,
		"map": RunState.map,
		"node_position": RunState.node_position,
		"quests": quests_data,
		"buffs": RunState.buffs,
		"tap_to_play": RunState.tap_to_play
	}

func _deserialize_run_state(save_data: Dictionary):
	# Restore party
	if save_data.has("party"):
		RunState.party = save_data["party"]
	
	# Restore deck with DeckCardData
	if save_data.has("deck"):
		RunState.deck.clear()
		for card_data in save_data["deck"]:
			if card_data is Dictionary:
				RunState.deck.append(DeckCardData.from_dict(card_data))
			else:
				# Legacy string format
				RunState.deck.append(DeckCardData.new(str(card_data)))
		# Reinitialize deck piles from loaded deck
		RunState._initialize_deck_piles()
		RunState.deck_changed.emit()
	
	# Restore relics
	if save_data.has("relics"):
		RunState.relics = save_data["relics"]
		RunState.relics_changed.emit()
	
	# Restore resources
	if save_data.has("gold"):
		RunState.set_gold(save_data["gold"])
	if save_data.has("current_hp"):
		RunState.current_hp = save_data["current_hp"]
	if save_data.has("max_hp"):
		RunState.max_hp = save_data["max_hp"]
	if save_data.has("block"):
		RunState.set_block(save_data["block"])
	if save_data.has("energy"):
		RunState.energy = save_data["energy"]
	if save_data.has("max_energy"):
		RunState.max_energy = save_data["max_energy"]
	
	# Restore map/progress
	if save_data.has("act"):
		RunState.set_act(save_data["act"])
	if save_data.has("map"):
		RunState.set_map(save_data["map"])
	if save_data.has("node_position"):
		RunState.set_node_position(save_data["node_position"])
	
	# Restore quests
	if save_data.has("quests"):
		RunState.quests = save_data["quests"]
		RunState.quests_changed.emit()
	
	# Restore buffs
	if save_data.has("buffs"):
		RunState.buffs = save_data["buffs"]
		RunState.buffs_changed.emit()
	
	# Restore settings
	if save_data.has("tap_to_play"):
		RunState.tap_to_play = save_data["tap_to_play"]
	
	# Emit signals for UI updates
	RunState.hp_changed.emit()
	RunState.energy_changed.emit()

