extends Control

## Character selection screen - allows selection of exactly 3 characters

var selection_count_label: Label = null
var character_grid: GridContainer = null
var confirm_button: Button = null
var party_summary_label: Label = null

var available_characters: Array[CharacterData] = []
var selected_character_ids: Array[String] = []
var character_entries: Dictionary = {}  # Maps character_id to { "button": Button, "root": Control, "quest_title": Label, "quest_desc": Label }

func _ready():
	# Wait one frame to ensure nodes are ready
	await get_tree().process_frame
	
	# Get node references safely
	selection_count_label = get_node_or_null("VBoxContainer/SelectionCountLabel")
	character_grid = get_node_or_null("VBoxContainer/CharacterGrid")
	confirm_button = get_node_or_null("VBoxContainer/ConfirmButton")
	party_summary_label = get_node_or_null("VBoxContainer/PartySummaryLabel")
	
	# Connect confirm button (with safety check)
	if is_instance_valid(confirm_button):
		if not confirm_button.pressed.is_connected(_on_confirm_pressed):
			confirm_button.pressed.connect(_on_confirm_pressed)
		confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Initialize screen (architecture rule 2.1)
	initialize()
	
	# Ensure scene is visible
	visible = true
	
	# Force a redraw
	call_deferred("_ensure_visible")
	
	# Keep the game running - ensure we don't exit
	get_tree().paused = false
	set_process(true)
	set_physics_process(false)

func initialize():
	## Initialize the screen with current state
	## Must be called after instantiation, before use (architecture rule 2.1)
	refresh_from_state()

func refresh_from_state():
	## Refresh UI from RunState (architecture rule 11.2)
	# Create placeholder characters for testing (minimum 6 as specified)
	_create_placeholder_characters()
	
	# Populate character grid
	_populate_character_grid()
	
	_update_ui()

func _ensure_visible():
	## Ensure all UI elements are visible and properly sized
	if is_instance_valid(character_grid):
		character_grid.visible = true
		character_grid.show()
		for i in range(character_grid.get_child_count()):
			var child = character_grid.get_child(i)
			if is_instance_valid(child):
				child.visible = true
				child.show()
	
	if is_instance_valid(self):
		visible = true
		show()

func _create_placeholder_characters():
	## Populate available_characters from DataRegistry.
	## Characters are created once in DataRegistry._ready() so CharacterSelect
	## simply reads what already exists - no duplicate creation.
	available_characters.clear()
	if DataRegistry:
		available_characters = DataRegistry.get_all_characters()

func _populate_character_grid():
	## Create character entry cards for each available character
	if not is_instance_valid(character_grid):
		push_error("CharacterSelect: character_grid is null!")
		return
		
	for char_data in available_characters:
		if not char_data:
			push_warning("CharacterSelect: null char_data in available_characters")
			continue
		
		# Create character entry card
		var entry = _create_character_entry(char_data)
		character_grid.add_child(entry["root"])
		character_entries[char_data.id] = entry
		
		# Force entry to be in tree and visible
		entry["root"].set_owner(character_grid)

func _create_character_entry(char_data: CharacterData) -> Dictionary:
	## Create a character entry card with quest info
	## Returns dictionary with references to UI elements
	
	# Root container (VBoxContainer)
	var root = VBoxContainer.new()
	root.name = "Entry_" + char_data.id
	root.custom_minimum_size = Vector2(200, 200)
	root.size = Vector2(200, 200)
	root.add_theme_constant_override("separation", 4)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Select button (handles selection click)
	var button = Button.new()
	button.name = "SelectButton_" + char_data.id
	button.text = "%s\n(%s)" % [char_data.display_name, char_data.role]
	button.custom_minimum_size = Vector2(200, 60)
	button.size = Vector2(200, 60)
	button.pressed.connect(_on_character_selected.bind(char_data.id))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(button)
	
	# Quest title label
	var quest_title = Label.new()
	quest_title.name = "QuestTitle_" + char_data.id
	quest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_title.add_theme_font_size_override("font_size", 12)
	quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_title.clip_contents = true
	quest_title.custom_minimum_size.y = 20
	quest_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Quest description label
	var quest_desc = Label.new()
	quest_desc.name = "QuestDesc_" + char_data.id
	quest_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_desc.add_theme_font_size_override("font_size", 10)
	quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_desc.clip_contents = true
	quest_desc.custom_minimum_size.y = 40
	quest_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set quest info
	if char_data.quest:
		quest_title.text = char_data.quest.title
		quest_desc.text = char_data.quest.description
		# Optional: show progress_max as "Goal: X"
		if char_data.quest.progress_max > 0:
			quest_desc.text += "\nGoal: %d" % char_data.quest.progress_max
	else:
		quest_title.text = "No Quest"
		quest_desc.text = "(This character has no quest assigned.)"
	
	root.add_child(quest_title)
	root.add_child(quest_desc)
	
	return {
		"button": button,
		"root": root,
		"quest_title": quest_title,
		"quest_desc": quest_desc
	}

func _on_character_selected(character_id: String):
	## Handle character selection/deselection
	if character_id in selected_character_ids:
		# Deselect
		selected_character_ids.erase(character_id)
	else:
		# Select (if not at max)
		if selected_character_ids.size() < 3:
			selected_character_ids.append(character_id)
		else:
			# Already at max, can't select more
			return
	
	_update_ui()

func _update_ui():
	## Update UI to reflect current selection state
	# Update selection count label
	if is_instance_valid(selection_count_label):
		selection_count_label.text = "Selected: %d / 3" % selected_character_ids.size()
	
	# Update entry states (tint button and optionally root)
	for char_id in character_entries:
		var entry = character_entries[char_id]
		if not entry or not entry.has("button"):
			continue
		
		var button = entry["button"]
		if not is_instance_valid(button):
			continue
		
		var is_selected = char_id in selected_character_ids
		
		if is_selected:
			button.modulate = Color(0.7, 1.0, 0.7)  # Green tint
			# Optionally tint root container as well
			if entry.has("root") and is_instance_valid(entry["root"]):
				entry["root"].modulate = Color(0.9, 1.0, 0.9)  # Light green tint
		else:
			button.modulate = Color.WHITE
			if entry.has("root") and is_instance_valid(entry["root"]):
				entry["root"].modulate = Color.WHITE
	
	# Update party summary
	_update_party_summary()
	
	# Enable/disable confirm button
	if is_instance_valid(confirm_button):
		confirm_button.disabled = selected_character_ids.size() != 3

func _update_party_summary():
	## Update the party summary label
	if not is_instance_valid(party_summary_label):
		return
	
	if selected_character_ids.size() == 3:
		var summary_lines: Array[String] = []
		summary_lines.append("Selected Party:")
		for char_id in selected_character_ids:
			var char_data = null
			if DataRegistry:
				char_data = DataRegistry.get_character(char_id)
			if char_data:
				summary_lines.append("  â€¢ %s (%s)" % [char_data.display_name, char_data.role])
			else:
				summary_lines.append("  â€¢ %s" % char_id)
		party_summary_label.text = "\n".join(summary_lines)
		party_summary_label.visible = true
	else:
		party_summary_label.text = ""
		party_summary_label.visible = false

func _on_confirm_pressed():
	## Confirm party selection and initialize run
	if selected_character_ids.size() != 3:
		push_error("Cannot confirm party: must select exactly 3 characters")
		return
	
	# Get CharacterData for selected characters
	var selected_char_data: Array[CharacterData] = []
	for char_id in selected_character_ids:
		for char_data in available_characters:
			if char_data.id == char_id:
				selected_char_data.append(char_data)
				break
	
	if selected_char_data.size() != 3:
		push_error("Failed to find CharacterData for all selected characters")
		return
	
	# Set party
	if PartyManager:
		PartyManager.set_party(selected_character_ids)
	
	# Generate starter deck
	if RunState:
		RunState.generate_starter_deck(selected_char_data)
	
	# Initialize quests
	if QuestManager:
		QuestManager.initialize_quests(selected_char_data)
	
	# Generate initial map
	var map_gen = MapGenerator.new()
	var act = MapManager.act if MapManager else 1
	var map_data = map_gen.generate_map(act)
	if MapManager:
		MapManager.set_map_data(map_data)
	
	# Force save new run (before navigating to map)
	if AutoSaveManager:
		AutoSaveManager.force_save("new_run_started")
	
	# Navigate to map screen
	ScreenManager.go_to_map()
