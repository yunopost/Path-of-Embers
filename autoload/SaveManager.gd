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
				"owner_character_id": "",
				"applied_upgrades": [],
				"is_transcended": false,
				"transcendent_card_id": ""
			})
	
	# Convert quests to serializable format (now Dictionary)
	var quests_data = {}
	for key in RunState.quests:
		var quest_state = RunState.quests[key]
		if quest_state is Dictionary:
			quests_data[key] = quest_state
		else:
			# Fallback
			quests_data[key] = {"id": str(quest_state)}
	
	# Convert reward_card_pool to serializable format
	var reward_pool_data = []
	for card_data in RunState.reward_card_pool:
		if card_data is CardData:
			reward_pool_data.append({
				"id": card_data.id,
				"name": card_data.name,
				"cost": card_data.cost
			})
	
	# Serialize map data if present
	var map_data_serialized = null
	if RunState.current_map != null:
		map_data_serialized = RunState.current_map.to_dict()
	
	return {
		"version": 3,  # Bump version for map data
		"party": RunState.party,
		"party_ids": RunState.party_ids,
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
		"current_map": map_data_serialized,
		"current_node_id": RunState.current_node_id,
		"available_next_node_ids": RunState.available_next_node_ids,
		"quests": quests_data,
		"reward_card_pool": reward_pool_data,
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
				# Handle legacy saves that might not have owner_character_id
				if not card_data.has("owner_character_id"):
					card_data["owner_character_id"] = ""
				RunState.deck.append(DeckCardData.from_dict(card_data))
			else:
				# Legacy string format
				RunState.deck.append(DeckCardData.new(str(card_data), ""))
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
	
	# Restore map data (version 3+)
	if save_data.has("current_map") and save_data["current_map"] != null:
		var map_data = MapData.from_dict(save_data["current_map"])
		RunState.set_map_data(map_data)
	if save_data.has("current_node_id"):
		RunState.current_node_id = save_data["current_node_id"]
	if save_data.has("available_next_node_ids"):
		RunState.available_next_node_ids = save_data["available_next_node_ids"]
	
	# Restore party_ids (new in version 2)
	if save_data.has("party_ids"):
		RunState.party_ids = save_data["party_ids"]
	else:
		# Legacy: convert party array to party_ids
		if save_data.has("party"):
			RunState.party_ids = save_data["party"].duplicate()
		RunState.party_changed.emit()
	
	# Restore quests (now Dictionary)
	if save_data.has("quests"):
		if save_data["quests"] is Dictionary:
			RunState.quests = save_data["quests"]
		else:
			# Legacy: convert Array to Dictionary
			RunState.quests = {}
			for quest in save_data["quests"]:
				if quest is Dictionary and quest.has("id"):
					var key = quest.get("character_id", quest.get("id", ""))
					RunState.quests[key] = quest
		RunState.quests_changed.emit()
	
	# Restore reward_card_pool (new in version 2)
	if save_data.has("reward_card_pool"):
		RunState.reward_card_pool.clear()
		for card_data in save_data["reward_card_pool"]:
			if card_data is Dictionary:
				# Reconstruct CardData from saved data
				var card = CardData.new()
				card.id = card_data.get("id", "")
				card.name = card_data.get("name", "")
				card.cost = card_data.get("cost", 1)
				RunState.reward_card_pool.append(card)
	
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
