extends RefCounted
class_name QuestState

## Runtime quest state object (immutable template is QuestData)

var quest_id: String = ""
var character_id: String = ""
var title: String = ""
var description: String = ""
var progress: int = 0
var progress_max: int = 0
var tracking_type: String = ""
var params: Dictionary = {}
var is_complete: bool = false

func _init(p_quest_id: String = "", p_character_id: String = "", p_title: String = "", p_description: String = "", p_progress_max: int = 0, p_tracking_type: String = "", p_params: Dictionary = {}):
	quest_id = p_quest_id
	character_id = p_character_id
	title = p_title
	description = p_description
	progress = 0
	progress_max = p_progress_max
	tracking_type = p_tracking_type
	params = p_params.duplicate()
	is_complete = false
	_update_completion()

func set_progress(value: int) -> void:
	## Set progress and update completion status
	progress = clamp(value, 0, progress_max)
	_update_completion()

func add_progress(amount: int) -> void:
	## Add to progress and update completion status
	progress = clamp(progress + amount, 0, progress_max)
	_update_completion()

func _update_completion() -> void:
	## Update is_complete based on progress
	is_complete = (progress >= progress_max)

func to_dict() -> Dictionary:
	## Serialize to dictionary for save/load
	return {
		"quest_id": quest_id,
		"character_id": character_id,
		"title": title,
		"description": description,
		"progress": progress,
		"progress_max": progress_max,
		"tracking_type": tracking_type,
		"params": params.duplicate(),
		"is_complete": is_complete
	}

static func from_dict(d: Dictionary) -> QuestState:
	## Deserialize from dictionary (supports both new QuestState format and legacy raw dicts)
	var quest = QuestState.new()
	
	# Handle both new format and legacy format
	if d.has("quest_id"):
		quest.quest_id = d.get("quest_id", "")
	if d.has("character_id"):
		quest.character_id = d.get("character_id", "")
	if d.has("title"):
		quest.title = d.get("title", "")
	if d.has("description"):
		quest.description = d.get("description", "")
	if d.has("progress"):
		quest.progress = d.get("progress", 0)
	if d.has("progress_max"):
		quest.progress_max = d.get("progress_max", 0)
	if d.has("tracking_type"):
		quest.tracking_type = d.get("tracking_type", "")
	if d.has("params"):
		var params_data = d.get("params", {})
		if params_data is Dictionary:
			quest.params = params_data.duplicate()
		else:
			quest.params = {}
	if d.has("is_complete"):
		quest.is_complete = d.get("is_complete", false)
	
	# Ensure progress is clamped and completion is updated
	quest.progress = clamp(quest.progress, 0, quest.progress_max)
	quest._update_completion()
	
	return quest

