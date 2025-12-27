extends Node

## Autoload singleton - Manages quest state and progression
## Handles quest evaluation and completion tracking

signal quests_changed

var quests: Dictionary = {}  # Dictionary keyed by character_id, value is QuestState

func _ready():
	quests = {}

func initialize_quests(character_data_list: Array[CharacterData]):
	## Initialize quest state for selected characters
	## character_data_list must be exactly 3 CharacterData resources
	## Creates QuestState objects from QuestData templates
	if character_data_list.size() != 3:
		push_error("initialize_quests requires exactly 3 characters, got %d" % character_data_list.size())
		return
	
	quests.clear()
	
	for char_data in character_data_list:
		if char_data.quest:
			# Create QuestState from QuestData (immutable template)
			var quest_state = QuestState.new(
				char_data.quest.id,
				char_data.id,
				char_data.quest.title,
				char_data.quest.description,
				char_data.quest.progress_max,
				char_data.quest.tracking_type,
				char_data.quest.params.duplicate()
			)
			# Use character_id as key for easy lookup
			quests[char_data.id] = quest_state
	
	quests_changed.emit()

func get_quest(character_id: String) -> QuestState:
	## Get quest state for a character
	return quests.get(character_id, null)

func are_all_party_quests_complete() -> bool:
	## Check if all party member quests are complete
	if quests.is_empty():
		return false
	
	# Check all 3 party members have complete quests
	var party_ids = PartyManager.get_party_ids() if PartyManager else []
	if party_ids.size() != 3:
		return false
	
	for character_id in party_ids:
		var quest = quests.get(character_id)
		if not quest or not quest.is_complete:
			return false
	
	return true

func emit_game_event(event_type: String, payload: Dictionary = {}) -> void:
	## Emit a game event and evaluate all quests
	## This is the single entry point for quest updates
	var any_changed = false
	
	for character_id in quests:
		var quest = quests[character_id]
		if quest and quest is QuestState:
			var changed = QuestSystem.evaluate(quest, event_type, payload)
			if changed:
				any_changed = true
	
	if any_changed:
		quests_changed.emit()

func clear_quests():
	## Clear all quests
	quests.clear()
	quests_changed.emit()

