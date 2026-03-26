extends Control

## Game Over screen — shown when the party's HP reaches zero.
## Displays a death message and final run stats, then offers restart or main menu.

# ── Death message pool ────────────────────────────────────────────────────────

# Generic messages by act tier (index 0 = Act 1, 1 = Act 2, 2 = Act 3)
const DEATH_MESSAGES_ACT: Array = [
	# Act 1 — early run
	[
		"The embers faded before they could ignite.",
		"The path ahead was longer than you knew.",
		"Ash and silence. The fire inside you went cold.",
	],
	# Act 2 — mid run
	[
		"You made it further than most. It was not enough.",
		"The heat built, then broke. So did you.",
		"They remember your name in the second ruin. That is something.",
	],
	# Act 3 — late run
	[
		"You stood at the edge of everything and fell.",
		"The Eternal Ember was not ready to be extinguished.",
		"So close. The ash remembers what the flame forgot.",
	],
]

# Per-character death messages: { character_id: [messages] }
const DEATH_MESSAGES_CHARACTER: Dictionary = {
	"warrior_3": [
		"The Revenant could not refuse death forever.",
		"Even the undying must eventually rest.",
	],
	"hollow": [
		"The Hollow found the void it had always sought.",
		"Compression complete. Nothing remains.",
	],
	"grove": [
		"The forest reclaims what it lent.",
		"Every bloom ends. Even Grove's.",
	],
	"witch": [
		"The curse turned inward at last.",
		"She knew the price. She paid it anyway.",
	],
	"living_armor": [
		"Even iron yields, given enough time and force.",
		"The armor fell. What was inside it was never certain.",
	],
}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	# Title
	var title = Label.new()
	title.text = "DEFEATED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)

	# Death message
	var msg_label = Label.new()
	msg_label.text = _pick_death_message()
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 16)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(msg_label)

	# Separator
	var sep = HSeparator.new()
	root.add_child(sep)

	# Stats
	var stats_label = Label.new()
	stats_label.text = _build_stats_text()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 13)
	root.add_child(stats_label)

	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(btn_row)

	var new_run_btn = Button.new()
	new_run_btn.text = "New Run"
	new_run_btn.custom_minimum_size = Vector2(160, 48)
	new_run_btn.pressed.connect(_on_new_run_pressed)
	btn_row.add_child(new_run_btn)

	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(160, 48)
	menu_btn.pressed.connect(_on_main_menu_pressed)
	btn_row.add_child(menu_btn)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _pick_death_message() -> String:
	# Try per-character message first
	if RunState:
		for char_id in RunState.party:
			if DEATH_MESSAGES_CHARACTER.has(char_id):
				var msgs: Array = DEATH_MESSAGES_CHARACTER[char_id]
				if not msgs.is_empty():
					return msgs[randi() % msgs.size()]

	# Fall back to generic act-tier message
	var act: int = 1
	if MapManager and MapManager.current_map:
		act = MapManager.get_current_act() if MapManager.has_method("get_current_act") else 1
	act = clamp(act - 1, 0, DEATH_MESSAGES_ACT.size() - 1)
	var pool: Array = DEATH_MESSAGES_ACT[act]
	return pool[randi() % pool.size()]

func _build_stats_text() -> String:
	var lines: Array = []
	if RunState:
		var party_names: Array = []
		for char_id in RunState.party:
			party_names.append(DataRegistry.get_character_display_name(char_id) if DataRegistry else char_id)
		lines.append("Party: %s" % ", ".join(party_names))
		lines.append("Deck size: %d" % RunState.deck_model.get_deck_size() if RunState.deck_model else "")
	if ResourceManager:
		lines.append("Gold remaining: %d" % ResourceManager.gold)
	if MapManager and MapManager.current_map:
		lines.append("Nodes completed: %d" % MapManager.current_map.get_completed_node_count() if MapManager.current_map.has_method("get_completed_node_count") else "")
	lines = lines.filter(func(l): return not l.is_empty())
	return "\n".join(lines)

# ── Interaction ───────────────────────────────────────────────────────────────

func _on_new_run_pressed() -> void:
	if RunState:
		RunState.reset_run()
	ScreenManager.go_to_character_select()

func _on_main_menu_pressed() -> void:
	if RunState:
		RunState.reset_run()
	ScreenManager.go_to_main_menu()
