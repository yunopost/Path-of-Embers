extends AcceptDialog
## Profile preference is separate from run checkpoints: replaying a fight does
## not replay onboarding. Opening or closing this window never spends time.
const SETTINGS_PATH := "user://combat_guide.cfg"
const RULES := "Your three characters share HP and a deck. Take your time: the clock advances when you act, not while you read.\n\nPLAY CARDS\nHover to enlarge a card; right-click to pin it for reading. Drag an attack onto an enemy. Drag other cards upward to play them. Check the card's resource cost and time cost: advancing time brings enemy timers closer to their next action.\n\nBREATHE · SPACE\nGain 1 energy and advance time by 1 tick. Energy has no upper cap.\n\nFOCUS · F\nDraw 2 cards and advance time by 1 tick. If your hand is full, additional drawn cards go to the discard pile.\n\nPARTY ABILITIES\nUse the character ability buttons on the left. Hover to see its cost. If it needs a target, click an enemy; Escape cancels targeting.\n\nSTAY ALIVE\nBlock remains until damage consumes it. Read enemy intentions before spending time. Complete your chosen quests to open the final boss path.\n\nYou can reopen these rules with HOW TO PLAY during combat."

func _ready() -> void:
	title = "How to play"
	ok_button_text = "Ready"
	exclusive = true
	min_size = Vector2i(300, 200)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 160)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var label := Label.new()
	label.text = RULES
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	scroll.add_child(label)
	confirmed.connect(_remember)
	canceled.connect(_remember)

func show_if_new() -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	if not settings.get_value("guide", "seen", false):
		show_guide()

func show_guide() -> void:
	popup_centered_clamped(Vector2i(660, 610), 0.9)

func _remember() -> void:
	var settings := ConfigFile.new()
	settings.set_value("guide", "seen", true)
	if settings.save(SETTINGS_PATH) != OK:
		push_warning("Could not save the combat guide preference.")
