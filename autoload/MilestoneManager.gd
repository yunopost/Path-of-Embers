extends Node

## Autoload singleton — tracks one-time achievement milestones and manages
## meta-save unlocks (characters, modifiers, boss rush bosses, story beats).
##
## Milestones are never re-evaluated after completion.
## All unlock state is persisted to meta.json via SaveManager.

signal milestone_completed(milestone: MilestoneData)
signal unlocks_changed

# ── Constants ─────────────────────────────────────────────────────────────────

## Characters always available regardless of milestone state.
const ALWAYS_UNLOCKED_CHARACTERS: Array[String] = ["warrior_1", "witch", "living_armor"]

# ── State (loaded from meta save on _ready) ───────────────────────────────────

var completed_milestone_ids: Array[String] = []
var unlocked_characters: Array[String] = []
var unlocked_modifiers: Array[String] = []
var unlocked_boss_rush_bosses: Array[String] = []
var story_progress: Array[String] = []

## Cross-run progress counters for counting milestones (complete_nodes, win_elites, etc.)
## Maps milestone_id -> int
var _progress_counters: Dictionary = {}

## Accumulated gold within the current run (for gain_gold milestones).
var _run_gold_accumulated: int = 0

func _ready() -> void:
	_load_from_meta()

# ── Meta persistence ──────────────────────────────────────────────────────────

func _load_from_meta() -> void:
	if not SaveManager:
		_apply_starting_roster()
		return
	var data: Dictionary = SaveManager.load_milestone_meta()
	completed_milestone_ids.assign(data.get("completed_milestones", []))
	unlocked_characters.assign(data.get("unlocked_characters", []))
	unlocked_modifiers.assign(data.get("unlocked_modifiers", []))
	unlocked_boss_rush_bosses.assign(data.get("unlocked_boss_rush_bosses", []))
	story_progress.assign(data.get("story_progress", []))
	_progress_counters = data.get("milestone_progress", {})
	_apply_starting_roster()

func _save_to_meta() -> void:
	if not SaveManager:
		return
	SaveManager.save_milestone_meta({
		"completed_milestones": completed_milestone_ids,
		"unlocked_characters": unlocked_characters,
		"unlocked_modifiers": unlocked_modifiers,
		"unlocked_boss_rush_bosses": unlocked_boss_rush_bosses,
		"story_progress": story_progress,
		"milestone_progress": _progress_counters,
	})

func _apply_starting_roster() -> void:
	## Ensure the three always-unlocked characters are always present.
	for char_id in ALWAYS_UNLOCKED_CHARACTERS:
		if not unlocked_characters.has(char_id):
			unlocked_characters.append(char_id)

# ── Unlock queries ────────────────────────────────────────────────────────────

func is_unlocked(unlock_type: String, target: String) -> bool:
	## Returns true when the given target is available to the player.
	match unlock_type:
		"character":
			if ALWAYS_UNLOCKED_CHARACTERS.has(target):
				return true
			return unlocked_characters.has(target)
		"modifier":
			return unlocked_modifiers.has(target)
		"boss_rush_boss":
			return unlocked_boss_rush_bosses.has(target)
		"story", "map_path":
			return story_progress.has(target)
	return false

func is_milestone_complete(milestone_id: String) -> bool:
	return completed_milestone_ids.has(milestone_id)

# ── Run lifecycle ─────────────────────────────────────────────────────────────

func reset_run_counters() -> void:
	## Call at the start of each new run (run-scoped counters only).
	_run_gold_accumulated = 0

# ── Event bus ─────────────────────────────────────────────────────────────────

func emit_game_event(event_type: String, payload: Dictionary = {}) -> void:
	## Mirror of QuestManager.emit_game_event — evaluates all incomplete milestones.
	if not DataRegistry:
		return

	# Accumulate gold for gain_gold milestones
	if event_type == "GOLD_GAINED":
		_run_gold_accumulated += int(payload.get("amount", 0))

	var milestones: Array[MilestoneData] = DataRegistry.get_all_milestones()
	for milestone in milestones:
		if completed_milestone_ids.has(milestone.id):
			continue  # Already done — never re-evaluate
		if _check_and_advance(milestone, event_type, payload):
			_complete_milestone(milestone)

func _check_and_advance(milestone: MilestoneData, event_type: String, payload: Dictionary) -> bool:
	## Returns true if the milestone's condition is now fully met.
	## For counting conditions, increments the counter when the event matches.
	match milestone.condition_type:

		"complete_run":
			return event_type == "FINAL_BOSS_DEFEATED"

		"complete_nodes":
			if event_type == "NODE_COMPLETED":
				_progress_counters[milestone.id] = _progress_counters.get(milestone.id, 0) + 1
				return _progress_counters[milestone.id] >= milestone.condition_count
			return false

		"win_elites":
			if event_type == "COMBAT_VICTORY":
				var node_type = payload.get("node_type", -1)
				if node_type == MapNodeData.NodeType.ELITE:
					_progress_counters[milestone.id] = _progress_counters.get(milestone.id, 0) + 1
					return _progress_counters[milestone.id] >= milestone.condition_count
			return false

		"win_boss":
			if event_type == "COMBAT_VICTORY":
				var node_type = payload.get("node_type", -1)
				if node_type == MapNodeData.NodeType.BOSS or node_type == MapNodeData.NodeType.FINAL_BOSS:
					_progress_counters[milestone.id] = _progress_counters.get(milestone.id, 0) + 1
					return _progress_counters[milestone.id] >= milestone.condition_count
			return false

		"gain_relics":
			if event_type == "RELIC_GAINED":
				_progress_counters[milestone.id] = _progress_counters.get(milestone.id, 0) + 1
				return _progress_counters[milestone.id] >= milestone.condition_count
			return false

		"gain_gold":
			# Checked against the running total accumulated this run
			return _run_gold_accumulated >= milestone.condition_count

		"character_used":
			if event_type == "FINAL_BOSS_DEFEATED":
				var required_id: String = milestone.condition_params.get("character_id", "")
				if required_id.is_empty():
					return false
				var party_ids: Array = PartyManager.get_party_ids() if PartyManager else []
				return party_ids.has(required_id)
			return false

		"choose_encounter_option":
			if event_type == "ENCOUNTER_CHOICE":
				var choice_id: String = payload.get("choice_id", "")
				var required: String = milestone.condition_params.get("choice_id", "")
				return not required.is_empty() and choice_id == required
			return false

	return false

# ── Completion ────────────────────────────────────────────────────────────────

func _complete_milestone(milestone: MilestoneData) -> void:
	if completed_milestone_ids.has(milestone.id):
		return

	completed_milestone_ids.append(milestone.id)
	print("MilestoneManager: '%s' completed — unlocking %s '%s'" % [
		milestone.id, milestone.unlock_type, milestone.unlock_target
	])

	match milestone.unlock_type:
		"character":
			if not unlocked_characters.has(milestone.unlock_target):
				unlocked_characters.append(milestone.unlock_target)
		"modifier":
			if not unlocked_modifiers.has(milestone.unlock_target):
				unlocked_modifiers.append(milestone.unlock_target)
		"boss_rush_boss":
			if not unlocked_boss_rush_bosses.has(milestone.unlock_target):
				unlocked_boss_rush_bosses.append(milestone.unlock_target)
		"story", "map_path":
			if not story_progress.has(milestone.unlock_target):
				story_progress.append(milestone.unlock_target)

	_save_to_meta()
	milestone_completed.emit(milestone)
	unlocks_changed.emit()
