extends Control

## Boss Rush screen — select a saved build, pick an unlocked boss, see the
## leaderboard for that boss, then challenge it.
##
## Layout (built in code):
##   Title
##   ── Build selection (3 slots) ──────────────────────────────────────────
##   ── Boss selection (unlocked bosses) ───────────────────────────────────
##   ── Leaderboard for selected boss ──────────────────────────────────────
##   [Challenge] [Back]

# ── State ─────────────────────────────────────────────────────────────────────

var _builds: Array = []            # Array[BuildData|null], length 3
var _selected_build_idx: int = -1
var _selected_boss_id: String = ""

# Hardcoded boss list — in Phase 9 this will come from EnemyData/MilestoneManager
# Each entry: { "id": String, "name": String }
const BOSS_DEFINITIONS: Array = [
	{ "id": "boss_act1",    "name": "Act I Boss"    },
	{ "id": "boss_act2",    "name": "Act II Boss"   },
	{ "id": "boss_act3",    "name": "Final Boss"    },
]

# ── UI refs ───────────────────────────────────────────────────────────────────

var _build_buttons: Array = []     # Array[Button], length 3
var _boss_buttons: Array = []      # Array[Button]
var _leaderboard_container: VBoxContainer = null
var _challenge_btn: Button = null
var _status_label: Label = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_builds = SaveManager.load_boss_rush_builds() if SaveManager else [null, null, null]
	_build_ui()
	_refresh()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	# Title
	var title = Label.new()
	title.text = "Boss Rush"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	# ── Build selection ──
	var build_hdr = Label.new()
	build_hdr.text = "Select Build"
	build_hdr.add_theme_font_size_override("font_size", 16)
	root.add_child(build_hdr)

	var build_row = HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 10)
	root.add_child(build_row)

	for i in range(SaveManager.MAX_BUILD_SLOTS if SaveManager else 3):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(220, 70)
		btn.pressed.connect(_on_build_selected.bind(i))
		build_row.add_child(btn)
		_build_buttons.append(btn)

	# ── Boss selection ──
	var boss_hdr = Label.new()
	boss_hdr.text = "Select Boss"
	boss_hdr.add_theme_font_size_override("font_size", 16)
	root.add_child(boss_hdr)

	var boss_row = HBoxContainer.new()
	boss_row.add_theme_constant_override("separation", 10)
	root.add_child(boss_row)

	for boss in _unlocked_bosses():
		var btn = Button.new()
		btn.text = boss["name"]
		btn.custom_minimum_size = Vector2(160, 50)
		btn.pressed.connect(_on_boss_selected.bind(boss["id"]))
		boss_row.add_child(btn)
		_boss_buttons.append(btn)

	if _boss_buttons.is_empty():
		var lbl = Label.new()
		lbl.text = "No bosses unlocked yet. Complete runs to unlock Boss Rush bosses."
		boss_row.add_child(lbl)

	# ── Leaderboard ──
	var lb_hdr = Label.new()
	lb_hdr.text = "Leaderboard"
	lb_hdr.add_theme_font_size_override("font_size", 16)
	root.add_child(lb_hdr)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_leaderboard_container = VBoxContainer.new()
	_leaderboard_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_leaderboard_container)

	# ── Status + buttons ──
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(1.0, 0.6, 0.4)
	root.add_child(_status_label)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(btn_row)

	_challenge_btn = Button.new()
	_challenge_btn.text = "Challenge Boss"
	_challenge_btn.custom_minimum_size = Vector2(200, 50)
	_challenge_btn.pressed.connect(_on_challenge_pressed)
	btn_row.add_child(_challenge_btn)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 50)
	back_btn.pressed.connect(_on_back_pressed)
	btn_row.add_child(back_btn)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _unlocked_bosses() -> Array:
	## Return BOSS_DEFINITIONS entries that the player has unlocked.
	var result: Array = []
	for boss in BOSS_DEFINITIONS:
		var unlocked: bool = true
		if MilestoneManager:
			unlocked = MilestoneManager.is_unlocked("boss_rush_boss", boss["id"])
		if unlocked:
			result.append(boss)
	return result

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_refresh_build_buttons()
	_refresh_boss_buttons()
	_refresh_leaderboard()
	_refresh_challenge_button()

func _refresh_build_buttons() -> void:
	for i in range(_build_buttons.size()):
		var btn: Button = _build_buttons[i]
		var build: BuildData = _builds[i] if i < _builds.size() else null
		if build == null:
			btn.text = "Slot %d\n(empty)" % (i + 1)
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.text = "Slot %d\n%s\n%s" % [i + 1, build.label, build.saved_at]
			btn.disabled = false
			btn.modulate = Color(0.7, 1.0, 0.7) if _selected_build_idx == i else Color.WHITE

func _refresh_boss_buttons() -> void:
	var unlocked = _unlocked_bosses()
	for j in range(_boss_buttons.size()):
		if j >= unlocked.size():
			break
		var btn: Button = _boss_buttons[j]
		var boss_id: String = unlocked[j]["id"]
		btn.modulate = Color(1.0, 0.85, 0.3) if _selected_boss_id == boss_id else Color.WHITE
		# Show personal best in button text
		var pb: int = LeaderboardManager.get_personal_best(boss_id) if LeaderboardManager else 0
		var pb_str: String = "  PB: %d" % pb if pb > 0 else ""
		btn.text = unlocked[j]["name"] + pb_str

func _refresh_leaderboard() -> void:
	for child in _leaderboard_container.get_children():
		_leaderboard_container.remove_child(child)
		child.queue_free()

	if _selected_boss_id.is_empty():
		var lbl = Label.new()
		lbl.text = "Select a boss to see its leaderboard."
		_leaderboard_container.add_child(lbl)
		return

	var entries: Array = LeaderboardManager.get_leaderboard(_selected_boss_id) if LeaderboardManager else []
	if entries.is_empty():
		var lbl = Label.new()
		lbl.text = "No scores recorded yet."
		_leaderboard_container.add_child(lbl)
		return

	# Header
	var hdr = Label.new()
	hdr.text = "%-4s  %-8s  %-30s  %s" % ["#", "Score", "Build", "Date"]
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.modulate = Color(0.7, 0.9, 1.0)
	_leaderboard_container.add_child(hdr)

	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var row = Label.new()
		row.text = "%-4d  %-8d  %-30s  %s" % [
			i + 1,
			int(e.get("score", 0)),
			str(e.get("label", "")).left(30),
			str(e.get("saved_at", "")).left(16),
		]
		row.add_theme_font_size_override("font_size", 11)
		_leaderboard_container.add_child(row)

func _refresh_challenge_button() -> void:
	var can_challenge: bool = _selected_build_idx >= 0 and not _selected_boss_id.is_empty()
	if _challenge_btn:
		_challenge_btn.disabled = not can_challenge
	if _status_label:
		if _selected_build_idx < 0 and _selected_boss_id.is_empty():
			_status_label.text = "Select a build and a boss."
		elif _selected_build_idx < 0:
			_status_label.text = "Select a build."
		elif _selected_boss_id.is_empty():
			_status_label.text = "Select a boss."
		else:
			_status_label.text = ""

# ── Interaction ───────────────────────────────────────────────────────────────

func _on_build_selected(idx: int) -> void:
	if _builds[idx] == null:
		return
	_selected_build_idx = idx
	_refresh()

func _on_boss_selected(boss_id: String) -> void:
	_selected_boss_id = boss_id
	_refresh()

func _on_challenge_pressed() -> void:
	if _selected_build_idx < 0 or _selected_boss_id.is_empty():
		return
	var build: BuildData = _builds[_selected_build_idx]
	if build == null:
		return

	# Load build into RunState
	RunState.load_from_build_data(build)
	RunState.boss_rush_boss_id = _selected_boss_id

	# Reset per-run milestone counters
	if MilestoneManager:
		MilestoneManager.reset_run_counters()

	# Navigate to combat with the boss enemy
	# Boss enemy_id matches boss_id by convention — content phase will create matching EnemyData
	var encounter_data: Dictionary = {
		"enemies": [{ "enemy_id": _selected_boss_id, "count": 1 }],
		"node_type": MapNodeData.NodeType.BOSS,
	}
	ScreenManager.go_to_combat(encounter_data)

func _on_back_pressed() -> void:
	# Clear boss rush flag before returning
	if RunState:
		RunState.is_boss_rush = false
		RunState.boss_rush_boss_id = ""
	ScreenManager.go_to_main_menu()
