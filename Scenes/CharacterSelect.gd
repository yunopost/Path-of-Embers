extends Control

## Character selection screen - allows selection of exactly 3 characters

@onready var selection_count_label: Label = $VBoxContainer/SelectionCountLabel
@onready var character_grid: GridContainer = $VBoxContainer/CharacterGrid
@onready var confirm_button: Button = $VBoxContainer/ConfirmButton

var available_characters: Array[CharacterData] = []
var selected_character_ids: Array[String] = []
var character_buttons: Dictionary = {}  # Maps character_id to Button

func _ready():
	# Create placeholder characters for testing (minimum 6 as specified)
	_create_placeholder_characters()
	
	# Populate character grid
	_populate_character_grid()
	
	# Connect confirm button
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_update_ui()

func _create_placeholder_characters():
	## Create placeholder CharacterData resources for testing
	## In a real game, these would be loaded from .tres files
	
	# Warrior characters
	for i in range(2):
		var char_data = CharacterData.new()
		char_data.id = "warrior_%d" % (i + 1)
		char_data.display_name = "Warrior %d" % (i + 1)
		char_data.role = "Warrior"
		char_data.portrait_path = ""
		
		# Create 2 unique starter cards
		var unique1 = CardData.new()
		unique1.id = "warrior_unique_%d_1" % (i + 1)
		unique1.name = "Warrior Strike %d" % (i + 1)
		var unique2 = CardData.new()
		unique2.id = "warrior_unique_%d_2" % (i + 1)
		unique2.name = "Warrior Power %d" % (i + 1)
		char_data.starter_unique_cards.append(unique1)
		char_data.starter_unique_cards.append(unique2)
		
		# Create quest
		var quest = QuestData.new()
		quest.id = "quest_warrior_%d" % (i + 1)
		quest.title = "Warrior Quest %d" % (i + 1)
		quest.description = "Complete warrior quest %d" % (i + 1)
		quest.progress_max = 10
		quest.tracking_type = "kill_count"
		char_data.quest = quest
		
		available_characters.append(char_data)
	
	# Healer characters
	for i in range(2):
		var char_data = CharacterData.new()
		char_data.id = "healer_%d" % (i + 1)
		char_data.display_name = "Healer %d" % (i + 1)
		char_data.role = "Healer"
		char_data.portrait_path = ""
		
		var unique1 = CardData.new()
		unique1.id = "healer_unique_%d_1" % (i + 1)
		unique1.name = "Heal %d" % (i + 1)
		var unique2 = CardData.new()
		unique2.id = "healer_unique_%d_2" % (i + 1)
		unique2.name = "Support %d" % (i + 1)
		char_data.starter_unique_cards.append(unique1)
		char_data.starter_unique_cards.append(unique2)
		
		var quest = QuestData.new()
		quest.id = "quest_healer_%d" % (i + 1)
		quest.title = "Healer Quest %d" % (i + 1)
		quest.description = "Complete healer quest %d" % (i + 1)
		quest.progress_max = 5
		quest.tracking_type = "heal_amount"
		char_data.quest = quest
		
		available_characters.append(char_data)
	
	# Defender characters
	for i in range(2):
		var char_data = CharacterData.new()
		char_data.id = "defender_%d" % (i + 1)
		char_data.display_name = "Defender %d" % (i + 1)
		char_data.role = "Defender"
		char_data.portrait_path = ""
		
		var unique1 = CardData.new()
		unique1.id = "defender_unique_%d_1" % (i + 1)
		unique1.name = "Shield %d" % (i + 1)
		var unique2 = CardData.new()
		unique2.id = "defender_unique_%d_2" % (i + 1)
		unique2.name = "Guard %d" % (i + 1)
		char_data.starter_unique_cards.append(unique1)
		char_data.starter_unique_cards.append(unique2)
		
		var quest = QuestData.new()
		quest.id = "quest_defender_%d" % (i + 1)
		quest.title = "Defender Quest %d" % (i + 1)
		quest.description = "Complete defender quest %d" % (i + 1)
		quest.progress_max = 20
		quest.tracking_type = "block_amount"
		char_data.quest = quest
		
		available_characters.append(char_data)

func _populate_character_grid():
	## Create buttons for each available character
	for char_data in available_characters:
		var button = Button.new()
		button.text = "%s\n(%s)" % [char_data.display_name, char_data.role]
		button.custom_minimum_size = Vector2(200, 150)
		button.pressed.connect(_on_character_selected.bind(char_data.id))
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		
		character_grid.add_child(button)
		character_buttons[char_data.id] = button

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
	selection_count_label.text = "Selected: %d / 3" % selected_character_ids.size()
	
	# Update button states
	for char_id in character_buttons:
		var button = character_buttons[char_id]
		var is_selected = char_id in selected_character_ids
		
		if is_selected:
			button.modulate = Color(0.7, 1.0, 0.7)  # Green tint
		else:
			button.modulate = Color.WHITE
	
	# Enable/disable confirm button
	confirm_button.disabled = selected_character_ids.size() != 3

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
	
	# Set party in RunState
	RunState.set_party(selected_character_ids)
	
	# Generate starter deck
	RunState.generate_starter_deck(selected_char_data)
	
	# Initialize quests
	RunState.initialize_quests(selected_char_data)
	
	# Save run
	SaveManager.save_game()
	
	# Navigate to map screen
	SceneRouter.change_scene("map")
