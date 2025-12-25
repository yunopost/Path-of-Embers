extends RefCounted
class_name QuestSystem

## Static quest evaluation system
## Evaluates quest progress based on game events

static func evaluate(q: QuestState, event_type: String, payload: Dictionary) -> bool:
	## Evaluate a quest against an event
	## Returns true if quest state changed (progress or completion)
	## Returns false if no change
	
	if not q or not q is QuestState:
		return false
	
	var old_progress = q.progress
	var old_complete = q.is_complete
	
	match q.tracking_type:
		"complete_nodes":
			_handle_complete_nodes(q, event_type, payload)
		
		"win_elites":
			_handle_win_elites(q, event_type, payload)
		
		"choose_encounter_option":
			_handle_choose_encounter_option(q, event_type, payload)
		
		"gain_relics":
			_handle_gain_relics(q, event_type, payload)
		
		_:
			# Unknown tracking_type - no-op
			pass
	
	# Return true if anything changed
	return (q.progress != old_progress) or (q.is_complete != old_complete)

static func _handle_complete_nodes(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle complete_nodes tracking: progress += 1 on NODE_COMPLETED
	if event_type == "NODE_COMPLETED":
		q.add_progress(1)

static func _handle_win_elites(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle win_elites tracking: progress += 1 on COMBAT_VICTORY with ELITE node
	if event_type == "COMBAT_VICTORY":
		var node_type = payload.get("node_type", -1)
		if node_type == MapNodeData.NodeType.ELITE:
			q.add_progress(1)

static func _handle_choose_encounter_option(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle choose_encounter_option tracking: complete if choice_id matches params
	if event_type == "ENCOUNTER_CHOICE":
		var choice_id = payload.get("choice_id", "")
		var required_choice = q.params.get("choice_id", "")
		if choice_id == required_choice:
			# Set progress to max to complete
			q.set_progress(q.progress_max)

static func _handle_gain_relics(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle gain_relics tracking: progress += 1 on RELIC_GAINED
	if event_type == "RELIC_GAINED":
		q.add_progress(1)
