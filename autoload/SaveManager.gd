extends Node

## Autoload singleton - Handles save/load of game state
## Run save:  user://save_run.json  — full current-run state
## Meta save: user://meta.json      — persistent cross-run data (equipment stash)

const SAVE_PATH = "user://save_run.json"
const META_SAVE_PATH = "user://meta.json"

## Resume contract: unfinished combat restarts from its pre-fight run state.
## The live save may change during combat; this checkpoint remains immutable.
var combat_checkpoint: Dictionary = {}

func begin_combat_checkpoint(encounter: Dictionary) -> void:
	if RunState.is_boss_rush or not combat_checkpoint.is_empty():
		return
	combat_checkpoint = {"run": _serialize_run_state().duplicate(true), "encounter": encounter.duplicate(true)}
	AutoSaveManager.force_save("combat_checkpoint")

func clear_combat_checkpoint() -> void:
	combat_checkpoint.clear()

signal save_completed
signal load_completed
signal save_failed(error_message: String)
signal load_failed(error_message: String)

func save_game() -> bool:
	var save_data = _serialize_run_state()
	if not combat_checkpoint.is_empty():
		save_data["combat_checkpoint"] = combat_checkpoint.duplicate(true)
	
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
	if not save_data is Dictionary:
		load_failed.emit("Save must contain an object")
		return false
	combat_checkpoint = save_data.get("combat_checkpoint", {}).duplicate(true)
	if not combat_checkpoint.is_empty():
		save_data = combat_checkpoint["run"]
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
		"version": 12,  # v12: pre-combat checkpoint and applied equipment HP bonus.
		"party_ids": PartyManager.party_ids.duplicate() if PartyManager else [],
		"deck": deck_dict,  # Dictionary keyed by instance_id
		"deck_order": deck_order_data,  # Stable ordering array
		"gold": ResourceManager.gold if ResourceManager else 0,
		"current_hp": ResourceManager.current_hp if ResourceManager else 50,
		"max_hp": ResourceManager.max_hp if ResourceManager else 50,
		"equipment_hp_bonus": ResourceManager.equipment_hp_bonus,
		"block": ResourceManager.block if ResourceManager else 0,
		"energy": ResourceManager.energy if ResourceManager else 3,  # No max_energy: energy has no ceiling (Design ruling, 10 Sep 2026).
		"upgrade_points": ResourceManager.upgrade_points if ResourceManager else 0,
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
		"pending_rewards": pending_rewards_serialized,
		"equipment_slots": RunState.equipment_slots,
		"run_stash": RunState.run_stash.duplicate(),
		"backpack": RunState.backpack.duplicate(),
		"pending_backpack_drop": RunState.pending_backpack_drop,
		"active_modifiers": Array(ModifierManager._run_active) if ModifierManager else []
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
	
	# Rebuild reward_card_pool from party character data now that party_ids are restored.
	# Characters are always registered in DataRegistry._ready(), so this works even when
	# loading a save that bypasses the CharacterSelect screen.
	if RunState:
		RunState.rebuild_reward_pool_from_party()

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
		if save_data.has("energy"):
			# Energy has no ceiling (Design ruling, 10 Sep 2026). Older saves may still
			# carry a "max_energy" key — it is deliberately ignored here so loading one
			# never reintroduces a cap.
			ResourceManager.set_energy(save_data["energy"])
		if save_data.has("upgrade_points"):
			ResourceManager.set_upgrade_points(int(save_data["upgrade_points"]))
		else:
			ResourceManager.set_upgrade_points(0)  # Legacy saves start with 0 pts
	
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
	
	# Restore rare_pity_counter (added in version 5; per-character stats are derived from
	# CharacterData at combat start — no extra fields needed for version 6 upgrade)
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

	# Restore equipment state (Phase 6)
	RunState.equipment_slots.clear()
	if save_data.has("equipment_slots") and save_data["equipment_slots"] is Dictionary:
		for char_id in save_data["equipment_slots"]:
			var slots_data = save_data["equipment_slots"][char_id]
			if slots_data is Dictionary:
				RunState.equipment_slots[str(char_id)] = {}
				for slot_name in slots_data:
					RunState.equipment_slots[str(char_id)][str(slot_name)] = str(slots_data[slot_name])

	RunState.run_stash.clear()
	if save_data.has("run_stash") and save_data["run_stash"] is Array:
		for item in save_data["run_stash"]:
			RunState.run_stash.append(str(item))

	RunState.backpack.clear()
	if save_data.has("backpack") and save_data["backpack"] is Array:
		for item in save_data["backpack"]:
			RunState.backpack.append(str(item))
	RunState.pending_backpack_drop = str(save_data.get("pending_backpack_drop", ""))

	RunState.equipment_changed.emit()
	RunState.backpack_changed.emit()

	# Restore active difficulty modifiers
	if ModifierManager and save_data.has("active_modifiers") and save_data["active_modifiers"] is Array:
		ModifierManager._run_active.clear()
		for m in save_data["active_modifiers"]:
			ModifierManager._run_active.append(str(m))

	if save_data.has("equipment_hp_bonus"):
		ResourceManager.equipment_hp_bonus = int(save_data["equipment_hp_bonus"])
	else:
		# v11 had no permanent max-HP rewards. Treat excess above party base
		# as the old equipment contribution, including accidental accumulation.
		var base_hp := 0
		for character_id in PartyManager.party_ids:
			var character = DataRegistry.get_character(character_id)
			if character:
				base_hp += character.hp_base
		base_hp = int(float(base_hp) * ModifierManager.get_player_hp_multiplier())
		ResourceManager.equipment_hp_bonus = maxi(0, ResourceManager.max_hp - base_hp) if base_hp > 0 else 0
	# Recompute only after quests are restored; never trust stale serialized edges.
	MapManager._update_available_nodes()

# ── Meta save (user://meta.json) ──────────────────────────────────────────────
# Stores persistent cross-run data: equipment stash, milestones, and unlocks.
# v1: { "version": 1, "persistent_stash": [...] }
# v2: adds "completed_milestones", "unlocked_characters", "unlocked_modifiers",
#     "unlocked_boss_rush_bosses", "story_progress", "milestone_progress"

func save_meta_game() -> bool:
	## Write the full meta save preserving all fields.
	var meta_data = _load_raw_meta()
	meta_data["version"] = 2
	return _write_raw_meta(meta_data)

## Starter equipment granted to brand-new players (first launch, no meta save yet)
const STARTER_EQUIPMENT: Array[String] = ["iron_helm", "chain_mail", "swift_boots"]

func archive_legacy_stash() -> void:
	var data := _load_raw_meta()
	if data.has("equipment_policy"):
		return
	# Keep a recoverable copy; leave milestones and other meta fields untouched.
	if FileAccess.file_exists(META_SAVE_PATH):
		var backup_path := "user://meta-before-equipment-reset.json"
		if not FileAccess.file_exists(backup_path):
			var backup := FileAccess.open(backup_path, FileAccess.WRITE)
			if not backup:
				push_warning("Could not back up legacy equipment; migration deferred.")
				return
			backup.store_string(JSON.stringify(data, "  "))
			backup.close()
	data["equipment_policy"] = "fresh_starters_per_run"
	_write_raw_meta(data)

func load_persistent_stash() -> Array[String]:
	## Return the persistent equipment stash from meta.json.
	## On a fresh profile (no stash key at all), seed 3 common starter items
	## so the Loadout screen has something to equip.
	var data = _load_raw_meta()
	# Equipment can currently only be gained, never lost — an empty stash means
	# a fresh profile, so seeding on empty is safe.
	if not data.has("persistent_stash") or (data["persistent_stash"] is Array and data["persistent_stash"].is_empty()):
		data["persistent_stash"] = STARTER_EQUIPMENT.duplicate()
		data["version"] = 2
		_write_raw_meta(data)
	var raw = data.get("persistent_stash", [])
	var result: Array[String] = []
	for item in raw:
		result.append(str(item))
	return result

func add_to_persistent_stash(equipment_id: String) -> void:
	## Append an equipment_id to the persistent stash and immediately save meta.
	if equipment_id.is_empty():
		return
	var meta_data = _load_raw_meta()
	var stash: Array = meta_data.get("persistent_stash", [])
	if not stash.has(equipment_id):
		stash.append(equipment_id)
	meta_data["persistent_stash"] = stash
	meta_data["version"] = 2
	_write_raw_meta(meta_data)

func load_milestone_meta() -> Dictionary:
	## Return all milestone-related fields from meta.json.
	var data = _load_raw_meta()
	return {
		"completed_milestones":    data.get("completed_milestones", []),
		"unlocked_characters":     data.get("unlocked_characters", []),
		"unlocked_modifiers":      data.get("unlocked_modifiers", []),
		"unlocked_boss_rush_bosses": data.get("unlocked_boss_rush_bosses", []),
		"story_progress":          data.get("story_progress", []),
		"milestone_progress":      data.get("milestone_progress", {}),
	}

func save_milestone_meta(milestone_data: Dictionary) -> void:
	## Merge milestone fields into meta.json and write to disk.
	var meta_data = _load_raw_meta()
	for key in milestone_data:
		meta_data[key] = milestone_data[key]
	meta_data["version"] = 2
	_write_raw_meta(meta_data)

func _load_raw_meta() -> Dictionary:
	## Internal helper — returns the full meta.json dictionary, or {} if missing/corrupt.
	if not FileAccess.file_exists(META_SAVE_PATH):
		return {}
	var file = FileAccess.open(META_SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {}
	var data = json.data
	if data is Dictionary:
		return data
	return {}

func _write_raw_meta(meta_data: Dictionary) -> bool:
	## Internal helper — write meta_data to META_SAVE_PATH as JSON.
	var file = FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open meta save for writing: " + META_SAVE_PATH)
		return false
	file.store_string(JSON.stringify(meta_data))
	file.close()
	return true

# ── Boss Rush build slots (user://boss_rush_builds.json) ──────────────────────
# Stores up to 3 BuildData snapshots from completed runs.

const BOSS_RUSH_SAVE_PATH = "user://boss_rush_builds.json"
const MAX_BUILD_SLOTS: int = 3

func load_boss_rush_builds() -> Array:
	## Returns an Array[BuildData] of length MAX_BUILD_SLOTS.
	## Empty slots are null.
	var result: Array = []
	for i in range(MAX_BUILD_SLOTS):
		result.append(null)

	if not FileAccess.file_exists(BOSS_RUSH_SAVE_PATH):
		return result
	var file = FileAccess.open(BOSS_RUSH_SAVE_PATH, FileAccess.READ)
	if file == null:
		return result
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return result
	file.close()
	var data = json.data
	if not data is Array:
		return result
	for entry in data:
		if entry is Dictionary:
			var b = BuildData.from_dict(entry)
			var idx: int = clamp(b.slot_index, 0, MAX_BUILD_SLOTS - 1)
			result[idx] = b
	return result

func save_boss_rush_build(build: BuildData) -> void:
	## Write a BuildData into its slot, persisting all 3 slots.
	var builds: Array = load_boss_rush_builds()
	var idx: int = clamp(build.slot_index, 0, MAX_BUILD_SLOTS - 1)
	builds[idx] = build

	var arr: Array = []
	for b in builds:
		if b != null:
			arr.append(b.to_dict())
	var file = FileAccess.open(BOSS_RUSH_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(arr))
		file.close()

func has_any_boss_rush_build() -> bool:
	## Returns true if at least one build slot is occupied.
	for b in load_boss_rush_builds():
		if b != null:
			return true
	return false
