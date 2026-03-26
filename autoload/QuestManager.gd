extends Node

## Autoload singleton - Manages quest state and progression
## Handles quest evaluation, completion tracking, and reward dispatch

signal quests_changed
signal quest_completed(character_id: String, quest_state: QuestState)

var quests: Dictionary = {}  # Dictionary[String, QuestState] keyed by character_id

func _ready():
	quests = {}

func initialize_quests(character_data_list: Array[CharacterData]):
	## Initialize quest state for selected characters.
	## Randomly picks one QuestData from each character's quests pool (Phase 3).
	## character_data_list must be exactly 3 CharacterData resources.
	if character_data_list.size() != 3:
		push_error("initialize_quests requires exactly 3 characters, got %d" % character_data_list.size())
		return

	quests.clear()

	for char_data in character_data_list:
		if char_data.quests.is_empty():
			push_warning("QuestManager: character '%s' has no quests in pool" % char_data.id)
			continue

		# Pick one quest at random from the pool
		var chosen: QuestData = char_data.quests[randi() % char_data.quests.size()]
		var quest_state = QuestState.new(
			chosen.id,
			char_data.id,
			chosen.title,
			chosen.description,
			chosen.progress_max,
			chosen.tracking_type,
			chosen.params.duplicate()
		)
		quests[char_data.id] = quest_state

	quests_changed.emit()

func get_quest(character_id: String) -> QuestState:
	## Get the active quest state for a character.
	return quests.get(character_id, null)

func are_all_party_quests_complete() -> bool:
	## Check if all party member quests are complete.
	if quests.is_empty():
		return false

	var party_ids = PartyManager.get_party_ids() if PartyManager else []
	if party_ids.size() != 3:
		return false

	for character_id in party_ids:
		var quest = quests.get(character_id)
		if not quest or not quest.is_complete:
			return false

	return true

func emit_game_event(event_type: String, payload: Dictionary = {}) -> void:
	## Emit a game event, evaluate all quests, and forward to MilestoneManager.
	## Detects newly completed quests and dispatches their rewards.
	if MilestoneManager:
		MilestoneManager.emit_game_event(event_type, payload)

	var any_changed = false

	for character_id in quests:
		var quest = quests[character_id]
		if not quest or not quest is QuestState:
			continue
		if quest.is_complete:
			continue  # Already done — don't re-evaluate or re-dispatch

		var was_complete = quest.is_complete
		var changed = QuestSystem.evaluate(quest, event_type, payload)
		if changed:
			any_changed = true
			if quest.is_complete and not was_complete:
				_on_quest_newly_completed(character_id, quest)

	if any_changed:
		quests_changed.emit()

func clear_quests():
	## Clear all quests.
	quests.clear()
	quests_changed.emit()

# ── Private helpers ──────────────────────────────────────────────────────────

func _on_quest_newly_completed(character_id: String, quest_state: QuestState) -> void:
	## Called the moment a quest transitions to complete.
	## Dispatches the quest's reward and emits the quest_completed signal.
	print("QuestManager: Quest '%s' completed for character '%s'" % [quest_state.quest_id, character_id])

	# Dispatch reward from the QuestData definition
	var char_data = DataRegistry.get_character(character_id) if DataRegistry else null
	if char_data:
		for quest_def in char_data.quests:
			if quest_def.id == quest_state.quest_id and not quest_def.reward.is_empty():
				_dispatch_reward(quest_def.reward)
				break

	quest_completed.emit(character_id, quest_state)

func _dispatch_reward(reward: Dictionary) -> void:
	## Apply a quest reward immediately.
	## Supported keys: "gold", "upgrade_count", "heal_amount", "relic_id"
	var gold = int(reward.get("gold", 0))
	if gold > 0 and ResourceManager:
		ResourceManager.set_gold(ResourceManager.gold + gold)
		print("QuestManager: Quest reward — +%d gold" % gold)

	var heal = int(reward.get("heal_amount", 0))
	if heal > 0 and ResourceManager:
		var new_hp = min(ResourceManager.current_hp + heal, ResourceManager.max_hp)
		ResourceManager.set_hp(new_hp, ResourceManager.max_hp)
		print("QuestManager: Quest reward — +%d HP" % heal)

	var upgrades = int(reward.get("upgrade_count", 0))
	if upgrades > 0 and ResourceManager:
		ResourceManager.add_upgrade_points(upgrades)
		print("QuestManager: Quest reward — +%d upgrade point(s)" % upgrades)

	var relic_id: String = reward.get("relic_id", "")
	if not relic_id.is_empty() and RunState:
		RunState.add_relic(relic_id)
		print("QuestManager: Quest reward — relic '%s'" % relic_id)
