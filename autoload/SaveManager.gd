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

func has_save() -> bool:
	## Alias for has_save_file() for consistency
	return has_save_file()

func delete_save_file() -> bool:
	if not has_save_file():
		return true
	
	var dir = DirAccess.open("user://")
	if dir == null:
		return false
	
	return dir.remove(SAVE_PATH.get_file()) == OK

func _serialize_run_state() -> Dictionary:
	# Convert deck to serializable format (dictionary keyed by instance_id)
	var deck_dict = {}
	var deck_order_data = RunState.deck_order.duplicate()
	
	# Serialize each card instance by instance_id
	for instance_id in RunState.deck_order:
		var deck_card = RunState.deck.get(instance_id)
		if deck_card and deck_card is DeckCardData:
			deck_dict[instance_id] = deck_card.to_dict()
		else:
			# Fallback for missing/invalid cards
			deck_dict[instance_id] = {
				"instance_id": instance_id,
				"card_id": "",
				"owner_character_id": "",
				"applied_upgrades": [],
				"is_transcended": false,
				"transcendent_card_id": ""
			}
	
	# Convert quests to serializable format (QuestState objects)
	var quests_data = {}
	for character_id in RunState.quests:
		var quest_state = RunState.quests[character_id]
		if quest_state and quest_state is QuestState:
			quests_data[character_id] = quest_state.to_dict()
		elif quest_state is Dictionary:
			# Legacy format - keep as-is for backward compatibility
			quests_data[character_id] = quest_state
		else:
			# Fallback
			quests_data[character_id] = {"id": str(quest_state)}
	
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
	
	# Serialize pending rewards if present
	var pending_rewards_serialized = null
	if RunState.pending_rewards:
		pending_rewards_serialized = RunState.pending_rewards.to_dict()
	
	return {
		"version": 4,  # Bump version for instance_id deck structure
		"party": RunState.party,
		"party_ids": RunState.party_ids,
		"deck": deck_dict,  # Dictionary keyed by instance_id
		"deck_order": deck_order_data,  # Stable ordering array
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
		"tap_to_play": RunState.tap_to_play,
		"pending_rewards": pending_rewards_serialized
	}

func _deserialize_run_state(save_data: Dictionary):
	# Restore party
	if save_data.has("party"):
		RunState.party = save_data["party"]
	
	# Restore deck with DeckCardData (new instance_id-based structure)
	if save_data.has("deck"):
		RunState.deck.clear()
		RunState.deck_order.clear()
		
		# Check for new structure (Dictionary) or legacy structure (Array)
		var deck_data = save_data["deck"]
		
		if deck_data is Dictionary:
			# New structure: Dictionary keyed by instance_id
			for instance_id in deck_data:
				var card_data = deck_data[instance_id]
				if card_data is Dictionary:
					# Ensure instance_id matches key
					card_data["instance_id"] = instance_id
					var deck_card = DeckCardData.from_dict(card_data)
					RunState.deck[instance_id] = deck_card
			
			# Restore deck_order (convert to typed array)
			if save_data.has("deck_order"):
				var order_array = save_data["deck_order"]
				RunState.deck_order.clear()
				for item in order_array:
					RunState.deck_order.append(str(item))
			else:
				# Fallback: use dictionary keys as order
				RunState.deck_order.clear()
				for key in deck_data.keys():
					RunState.deck_order.append(str(key))
		
		elif deck_data is Array:
			# Legacy structure: Array of DeckCardData dicts
			for card_data in deck_data:
				if card_data is Dictionary:
					# Handle legacy saves that might not have owner_character_id or instance_id
					if not card_data.has("owner_character_id"):
						card_data["owner_character_id"] = ""
					if not card_data.has("instance_id"):
						# Generate new instance_id for legacy cards
						var legacy_card = DeckCardData.from_dict(card_data)
						card_data["instance_id"] = legacy_card.instance_id
					
					var deck_card = DeckCardData.from_dict(card_data)
					RunState.deck[deck_card.instance_id] = deck_card
					RunState.deck_order.append(deck_card.instance_id)
				else:
					# Legacy string format
					var legacy_card = DeckCardData.new(str(card_data), "")
					RunState.deck[legacy_card.instance_id] = legacy_card
					RunState.deck_order.append(legacy_card.instance_id)
		
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
		# Convert to typed array
		var next_nodes_array = save_data["available_next_node_ids"]
		RunState.available_next_node_ids.clear()
		for item in next_nodes_array:
			RunState.available_next_node_ids.append(str(item))
	
	# Restore party_ids (new in version 2) - convert to typed array
	if save_data.has("party_ids"):
		var party_ids_array = save_data["party_ids"]
		RunState.party_ids.clear()
		for item in party_ids_array:
			RunState.party_ids.append(str(item))
	else:
		# Legacy: convert party array to party_ids
		if save_data.has("party"):
			RunState.party_ids.clear()
			for item in save_data["party"]:
				RunState.party_ids.append(str(item))
		RunState.party_changed.emit()
	
	# Restore quests (convert dictionaries to QuestState objects)
	if save_data.has("quests"):
		RunState.quests.clear()
		if save_data["quests"] is Dictionary:
			# New format: Dictionary keyed by character_id
			for character_id in save_data["quests"]:
				var quest_data = save_data["quests"][character_id]
				if quest_data is Dictionary:
					# Convert dictionary to QuestState (handles both new and legacy formats)
					var quest_state = QuestState.from_dict(quest_data)
					RunState.quests[character_id] = quest_state
				elif quest_data is QuestState:
					# Already a QuestState (shouldn't happen in saves, but handle it)
					RunState.quests[character_id] = quest_data
		elif save_data["quests"] is Array:
			# Legacy: convert Array to Dictionary of QuestState objects
			for quest in save_data["quests"]:
				if quest is Dictionary:
					var character_id = quest.get("character_id", quest.get("id", ""))
					if not character_id.is_empty():
						var quest_state = QuestState.from_dict(quest)
						RunState.quests[character_id] = quest_state
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
	
	# Restore pending_rewards (if present)
	if save_data.has("pending_rewards") and save_data["pending_rewards"] != null:
		var pending_rewards_data = save_data["pending_rewards"]
		if pending_rewards_data is Dictionary:
			RunState.pending_rewards = RewardBundle.from_dict(pending_rewards_data)
		else:
			RunState.pending_rewards = null
	else:
		RunState.pending_rewards = null
	
	# Emit signals for UI updates
	RunState.hp_changed.emit()
	RunState.energy_changed.emit()
