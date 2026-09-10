extends Node

## Autoload singleton — local leaderboard for Boss Rush scores.
##
## One leaderboard per boss_id. Scores are sorted descending (highest first).
## Persisted to user://leaderboard.json.
##
## Scoring formula (from design doc):
##   base = (10000 ÷ seconds) × 100
##          + damage_dealt ÷ 10
##          + (hp_remaining ÷ max_hp) × 500
##          + 1000 ÷ cards_played
##   final = base × (1 + 0.10 × active_modifier_count)

const LEADERBOARD_PATH = "user://leaderboard.json"
const MAX_ENTRIES_PER_BOSS: int = 10

## _scores[boss_id] = Array of { score, label, saved_at, seconds, damage, hp_frac, cards }
var _scores: Dictionary = {}

func _ready() -> void:
	_load()

# ── Score calculation ─────────────────────────────────────────────────────────

func calculate_score(
		combat_seconds: float,
		damage_dealt: int,
		hp_remaining: int,
		max_hp: int,
		cards_played: int,
		active_modifier_count: int = 0
) -> int:
	if combat_seconds <= 0.0:
		combat_seconds = 1.0
	if cards_played <= 0:
		cards_played = 1
	if max_hp <= 0:
		max_hp = 1
	var base: float = (
		(10000.0 / combat_seconds) * 100.0
		+ damage_dealt / 10.0
		+ (float(hp_remaining) / float(max_hp)) * 500.0
		+ 1000.0 / float(cards_played)
	)
	return int(base * (1.0 + 0.10 * float(active_modifier_count)))

# ── Submission ────────────────────────────────────────────────────────────────

func submit_score(
		boss_id: String,
		score: int,
		label: String,
		combat_seconds: float,
		damage_dealt: int,
		hp_frac: float,
		cards_played: int
) -> void:
	## Add a score entry and persist. Keeps top MAX_ENTRIES_PER_BOSS.
	if not _scores.has(boss_id):
		_scores[boss_id] = []

	_scores[boss_id].append({
		"score":    score,
		"label":    label,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"seconds":  snapped(combat_seconds, 0.1),
		"damage":   damage_dealt,
		"hp_frac":  snapped(hp_frac, 0.01),
		"cards":    cards_played,
	})

	# Sort descending by score
	_scores[boss_id].sort_custom(func(a, b): return a["score"] > b["score"])

	# Trim to max entries
	while _scores[boss_id].size() > MAX_ENTRIES_PER_BOSS:
		_scores[boss_id].pop_back()

	_save()

# ── Queries ───────────────────────────────────────────────────────────────────

func get_leaderboard(boss_id: String) -> Array:
	## Returns sorted Array of score entries for the given boss (may be empty).
	return _scores.get(boss_id, [])

func get_personal_best(boss_id: String) -> int:
	## Returns the highest score for a boss, or 0 if none.
	var board: Array = get_leaderboard(boss_id)
	if board.is_empty():
		return 0
	return int(board[0]["score"])

# ── Persistence ───────────────────────────────────────────────────────────────

func _save() -> void:
	var file = FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_scores))
		file.close()

func _load() -> void:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return
	var file = FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data = json.data
	if data is Dictionary:
		_scores = data
