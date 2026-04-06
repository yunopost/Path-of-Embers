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
		"win_combat":
			_handle_win_combat(q, event_type, payload)
		"deal_damage":
			_handle_deal_damage(q, event_type, payload)
		"block_damage":
			_handle_block_damage(q, event_type, payload)
		"play_cards":
			_handle_play_cards(q, event_type, payload)
		"discard_cards":
			_handle_discard_cards(q, event_type, payload)
		"spend_gold":
			_handle_spend_gold(q, event_type, payload)
		"upgrade_cards":
			_handle_upgrade_cards(q, event_type, payload)
		"kill_enemies":
			_handle_kill_enemies(q, event_type, payload)
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

static func _handle_win_combat(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle win_combat tracking: progress += 1 on COMBAT_VICTORY with FIGHT node
	if event_type == "COMBAT_VICTORY":
		var node_type = payload.get("node_type", -1)
		if node_type == MapNodeData.NodeType.FIGHT:
			q.add_progress(1)

static func _handle_deal_damage(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle deal_damage tracking: progress += amount on DAMAGE_DEALT
	## payload: { "amount": int, "source": "player" }
	if event_type == "DAMAGE_DEALT" and payload.get("source", "") == "player":
		q.add_progress(payload.get("amount", 0))

static func _handle_block_damage(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle block_damage tracking: progress += amount on BLOCK_GAINED
	## payload: { "amount": int }
	if event_type == "BLOCK_GAINED":
		q.add_progress(payload.get("amount", 0))

static func _handle_play_cards(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle play_cards tracking: progress += 1 on CARD_PLAYED
	if event_type == "CARD_PLAYED":
		q.add_progress(1)

static func _handle_discard_cards(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle discard_cards tracking: progress += 1 on CARD_DISCARDED
	if event_type == "CARD_DISCARDED":
		q.add_progress(1)

static func _handle_spend_gold(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle spend_gold tracking: progress += amount on GOLD_SPENT
	## payload: { "amount": int }
	if event_type == "GOLD_SPENT":
		q.add_progress(payload.get("amount", 0))

static func _handle_upgrade_cards(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle upgrade_cards tracking: progress += 1 on CARD_UPGRADED
	if event_type == "CARD_UPGRADED":
		q.add_progress(1)

static func _handle_kill_enemies(q: QuestState, event_type: String, payload: Dictionary) -> void:
	## Handle kill_enemies tracking: progress += 1 on ENEMY_KILLED
	if event_type == "ENEMY_KILLED":
		q.add_progress(1)
