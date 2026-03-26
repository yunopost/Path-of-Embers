extends Node

## Autoload singleton — difficulty modifier system for Path of Embers.
##
## Players toggle modifiers before a run starts (LoadoutScreen).
## Active modifiers are locked in at run start and queried during combat.
##
## Score multiplier per design doc:
##   final_score = base × (1 + 0.10 × active_modifier_count)
##
## Modifier IDs and their intended gameplay effects:
##   reduced_hp         — Player max HP is 25% lower.
##   tougher_enemies    — All enemies have 25% more HP.
##   tougher_bosses     — Boss enemies have 50% more HP.
##   advanced_enemies_1 — Enemies use enhanced attack patterns (higher per-phase threat).
##   advanced_enemies_2 — Enemies deal 25% more damage.
##   advanced_enemies_3 — Enemies deal 50% more damage and have 25% more HP.

signal modifiers_changed

## Modifier definitions. All currently always available; unlock_milestone is reserved
## for future gating once milestone .tres files are authored.
const MODIFIERS: Array = [
	{
		"id": "reduced_hp",
		"name": "Reduced HP Pool",
		"description": "Your party's maximum HP is reduced by 25%.",
		"unlock_milestone": ""
	},
	{
		"id": "tougher_enemies",
		"name": "Tougher Enemies",
		"description": "All non-boss enemies have 25% more HP.",
		"unlock_milestone": ""
	},
	{
		"id": "tougher_bosses",
		"name": "Tougher Bosses",
		"description": "Boss enemies have 50% more HP.",
		"unlock_milestone": ""
	},
	{
		"id": "advanced_enemies_1",
		"name": "Advanced Enemies I",
		"description": "Enemies move faster — timer intervals are 20% shorter.",
		"unlock_milestone": ""
	},
	{
		"id": "advanced_enemies_2",
		"name": "Advanced Enemies II",
		"description": "Enemies deal 25% more damage.",
		"unlock_milestone": ""
	},
	{
		"id": "advanced_enemies_3",
		"name": "Advanced Enemies III",
		"description": "Enemies deal 50% more damage and have 25% more HP.",
		"unlock_milestone": ""
	},
]

## Modifier IDs toggled on/off in LoadoutScreen (persisted between sessions).
var _selected: Array[String] = []

## Modifier IDs active for the current run (locked in at begin_run).
var _run_active: Array[String] = []

const SAVE_PATH = "user://modifier_settings.json"

func _ready() -> void:
	_load()


# ── Selection API (pre-run) ────────────────────────────────────────────────────

func get_all_modifiers() -> Array:
	## Returns all modifier definition Dictionaries.
	return MODIFIERS


func get_available_modifiers() -> Array:
	## Returns modifiers the player has unlocked (all, until milestone gating is added).
	var result: Array = []
	for mod in MODIFIERS:
		if _is_unlocked(mod):
			result.append(mod)
	return result


func is_selected(modifier_id: String) -> bool:
	## Returns true if modifier_id is currently toggled on.
	return _selected.has(modifier_id)


func toggle_modifier(modifier_id: String) -> void:
	## Toggle a modifier on/off. Persists immediately.
	if _selected.has(modifier_id):
		_selected.erase(modifier_id)
	else:
		_selected.append(modifier_id)
	modifiers_changed.emit()
	_save()


func get_selected_count() -> int:
	## Number of modifiers currently toggled on.
	return _selected.size()


func get_selected_ids() -> Array[String]:
	## Returns a copy of the currently selected modifier ID list.
	return _selected.duplicate()


func get_score_multiplier_preview() -> float:
	## Score multiplier based on current selection (for LoadoutScreen preview).
	return 1.0 + 0.10 * float(_selected.size())


# ── Run lifecycle ──────────────────────────────────────────────────────────────

func begin_run() -> void:
	## Lock in selected modifiers for the run about to start.
	## Call from LoadoutScreen just before navigating to the map.
	_run_active = _selected.duplicate()


func end_run() -> void:
	## Clear active run modifiers when a run ends (victory or defeat).
	## Call from RunState.reset() or equivalent.
	_run_active.clear()


# ── Active run queries (during combat) ────────────────────────────────────────

func get_active_count() -> int:
	## Number of modifiers active in the current run (used for Boss Rush scoring).
	return _run_active.size()


func is_active(modifier_id: String) -> bool:
	## Returns true if the named modifier is active in the current run.
	return _run_active.has(modifier_id)


func get_player_hp_multiplier() -> float:
	## Multiplier applied to player max HP when a run begins.
	## Apply in RunState or ResourceManager at run-start.
	if is_active("reduced_hp"):
		return 0.75
	return 1.0


func get_enemy_hp_multiplier(is_boss: bool = false) -> float:
	## Multiplier for an enemy's base max HP when it spawns.
	## Pass is_boss=true for boss encounters.
	var mult: float = 1.0
	if not is_boss and is_active("tougher_enemies"):
		mult += 0.25
	if is_boss and is_active("tougher_bosses"):
		mult += 0.50
	if is_active("advanced_enemies_3"):
		mult += 0.25
	return mult


func get_enemy_damage_multiplier() -> float:
	## Multiplier applied to all enemy attack damage values.
	var mult: float = 1.0
	if is_active("advanced_enemies_2"):
		mult += 0.25
	if is_active("advanced_enemies_3"):
		mult += 0.50
	return mult


func get_enemy_timer_multiplier() -> float:
	## Multiplier for enemy timer intervals (< 1.0 means faster / more threatening).
	if is_active("advanced_enemies_1") or is_active("advanced_enemies_2") or is_active("advanced_enemies_3"):
		return 0.80
	return 1.0


func uses_advanced_patterns() -> bool:
	## True when enemies should use enhanced behaviour (Advanced Enemies I–III).
	return (is_active("advanced_enemies_1")
		or is_active("advanced_enemies_2")
		or is_active("advanced_enemies_3"))


# ── Unlock helper ──────────────────────────────────────────────────────────────

func _is_unlocked(mod: Dictionary) -> bool:
	var milestone: String = mod.get("unlock_milestone", "")
	if milestone.is_empty():
		return true
	if MilestoneManager:
		return MilestoneManager.is_milestone_complete(milestone)
	return false


# ── Persistence ────────────────────────────────────────────────────────────────

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"selected": Array(_selected)}))
		file.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data = json.data
	if not data is Dictionary:
		return
	var sel = data.get("selected", [])
	_selected.clear()
	for s in sel:
		var sid: String = str(s)
		# Only restore IDs that still exist in MODIFIERS
		for mod in MODIFIERS:
			if mod["id"] == sid:
				_selected.append(sid)
				break
