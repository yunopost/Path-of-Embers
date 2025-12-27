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
	# Only serialize valid cards - reject invalid ones
	for instance_id in RunState.deck_order:
		var deck_card = RunState.deck.get(instance_id)
		if deck_card and deck_card is DeckCardData:
			# Validate before serializing
			if CardValidation.validate_card_instance(deck_card, "SaveManager.save"):
				deck_dict[instance_id] = deck_card.to_dict()
			else:
				push_error("SaveManager: Skipping invalid card during save. instance_id=%s" % instance_id)
		else:
			# Missing/invalid card - log error and skip (don't create empty card)
			push_error("SaveManager: Missing or invalid DeckCardData for instance_id=%s. Skipping save." % instance_id)
	
	# Convert quests to serializable format (QuestState objects)
	var quests_data = {}
	if QuestManager:
		for character_id in QuestManager.quests:
			var quest_state = QuestManager.quests[character_id]
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
				"cost": card_data.cost,
				"rarity": card_data.rarity
			})
	
	# Serialize map data if present
	var map_data_serialized = null
	if MapManager and MapManager.current_map != null:
		map_data_serialized = MapManager.current_map.to_dict()
	
	# Serialize pending rewards if present
	var pending_rewards_serialized = null
	if RunState.pending_rewards:
		pending_rewards_serialized = RunState.pending_rewards.to_dict()
	
	return {
		"version": 5,  # Bump version for rare_pity_counter and rarity in reward_card_pool
		"party_ids": PartyManager.party_ids.duplicate() if PartyManager else [],
		"deck": deck_dict,  # Dictionary keyed by instance_id
		"deck_order": deck_order_data,  # Stable ordering array
		"relics": RunState.relics,
		"gold": ResourceManager.gold if ResourceManager else 0,
		"current_hp": ResourceManager.current_hp if ResourceManager else 50,
		"max_hp": ResourceManager.max_hp if ResourceManager else 50,
		"block": ResourceManager.block if ResourceManager else 0,
		"energy": ResourceManager.energy if ResourceManager else 3,
		"max_energy": ResourceManager.max_energy if ResourceManager else 3,
		"act": MapManager.act if MapManager else 1,
		"map": MapManager.map if MapManager else "Act1",
		"node_position": MapManager.node_position if MapManager else 0,
		"current_map": map_data_serialized,
		"current_node_id": MapManager.current_node_id if MapManager else "",
		"available_next_node_ids": MapManager.available_next_node_ids.duplicate() if MapManager else [],
		"quests": quests_data,
		"reward_card_pool": reward_pool_data,
		"rare_pity_counter": RunState.rare_pity_counter,
		"buffs": RunState.buffs,
		"tap_to_play": RunState.tap_to_play,
		"pending_rewards": pending_rewards_serialized
	}

func _deserialize_run_state(save_data: Dictionary):
	# Restore party
	if save_data.has("party_ids"):
		var party_ids_data = save_data["party_ids"]
		if party_ids_data is Array:
			# Convert to typed array
			var typed_party_ids: Array[String] = []
			for id in party_ids_data:
				typed_party_ids.append(str(id))
			if PartyManager:
				PartyManager.set_party(typed_party_ids)
	elif save_data.has("party"):
		# Legacy format - convert to party_ids if possible
		var party_data = save_data["party"]
		if party_data is Array:
			var typed_party_ids: Array[String] = []
			for id in party_data:
				typed_party_ids.append(str(id))
			if PartyManager:
				PartyManager.set_party(typed_party_ids)
	
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
					# Validate before adding to deck
					if CardValidation.validate_card_instance(deck_card, "SaveManager.load (Dictionary)"):
						RunState.deck[instance_id] = deck_card
					else:
						push_error("SaveManager: Skipping invalid card instance_id=%s" % instance_id)
			
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
					# Validate before adding to deck
					if CardValidation.validate_card_instance(deck_card, "SaveManager.load (Array/Dictionary)"):
						RunState.deck[deck_card.instance_id] = deck_card
						RunState.deck_order.append(deck_card.instance_id)
					else:
						push_error("SaveManager: Skipping invalid card instance_id=%s" % deck_card.instance_id)
				else:
					# Legacy string format - REJECT instead of creating invalid card
					push_error("SaveManager: Rejecting legacy string format card_data. Cannot determine valid card_id. data=%s" % str(card_data))
		
		# Reinitialize deck piles from loaded deck
		RunState._initialize_deck_piles()
		RunState.deck_changed.emit()
	
	# Restore relics
	if save_data.has("relics"):
		RunState.relics = save_data["relics"]
		RunState.relics_changed.emit()
	
	# Restore resources
	if ResourceManager:
		if save_data.has("gold"):
			ResourceManager.set_gold(save_data["gold"])
		if save_data.has("current_hp") and save_data.has("max_hp"):
			ResourceManager.set_hp(save_data["current_hp"], save_data["max_hp"])
		elif save_data.has("current_hp"):
			ResourceManager.set_hp(save_data["current_hp"])
		if save_data.has("block"):
			ResourceManager.set_block(save_data["block"])
		if save_data.has("energy") and save_data.has("max_energy"):
			ResourceManager.set_energy(save_data["energy"], save_data["max_energy"])
		elif save_data.has("energy"):
			ResourceManager.set_energy(save_data["energy"])
	
	# Restore map/progress
	if MapManager:
		if save_data.has("act"):
			MapManager.set_act(save_data["act"])
		if save_data.has("map"):
			MapManager.set_map(save_data["map"])
		if save_data.has("node_position"):
			MapManager.set_node_position(save_data["node_position"])
		
		# Restore map data (version 3+)
		if save_data.has("current_map") and save_data["current_map"] != null:
			var map_data = MapData.from_dict(save_data["current_map"])
			MapManager.set_map_data(map_data)
		if save_data.has("current_node_id"):
			MapManager.set_current_node(save_data["current_node_id"])
		if save_data.has("available_next_node_ids"):
			var next_nodes_array = save_data["available_next_node_ids"]
			MapManager.available_next_node_ids.clear()
			for item in next_nodes_array:
				MapManager.available_next_node_ids.append(str(item))
	
	# Restore quests (convert dictionaries to QuestState objects)
	if save_data.has("quests") and QuestManager:
		QuestManager.quests.clear()
		if save_data["quests"] is Dictionary:
			# New format: Dictionary keyed by character_id
			for character_id in save_data["quests"]:
				var quest_data = save_data["quests"][character_id]
				if quest_data is Dictionary:
					# Convert dictionary to QuestState (handles both new and legacy formats)
					var quest_state = QuestState.from_dict(quest_data)
					QuestManager.quests[character_id] = quest_state
				elif quest_data is QuestState:
					# Already a QuestState (shouldn't happen in saves, but handle it)
					QuestManager.quests[character_id] = quest_data
		elif save_data["quests"] is Array:
			# Legacy: convert Array to Dictionary of QuestState objects
			for quest in save_data["quests"]:
				if quest is Dictionary:
					var character_id = quest.get("character_id", quest.get("id", ""))
					if not character_id.is_empty():
						var quest_state = QuestState.from_dict(quest)
						QuestManager.quests[character_id] = quest_state
		QuestManager.quests_changed.emit()
	
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
				# Restore rarity if present, default to COMMON for legacy saves
				if card_data.has("rarity"):
					card.rarity = card_data.get("rarity", CardData.Rarity.COMMON)
				else:
					card.rarity = CardData.Rarity.COMMON
				RunState.reward_card_pool.append(card)
	
	# Restore rare_pity_counter (new in version 5)
	if save_data.has("rare_pity_counter"):
		RunState.rare_pity_counter = int(save_data["rare_pity_counter"])
	else:
		# Legacy: initialize to -2 if not present
		RunState.rare_pity_counter = -2
	
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
