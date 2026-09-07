extends VBoxContainer

## Character HUD block for party display
## Shows character portrait, name, and quest information

@onready var inner_margin: MarginContainer = $InnerMargin
@onready var container: VBoxContainer = $InnerMargin/Container
@onready var portrait_container: Panel = $InnerMargin/Container/PortraitContainer
@onready var portrait: TextureRect = $InnerMargin/Container/PortraitContainer/Portrait
@onready var name_label: Label = $InnerMargin/Container/PortraitContainer/NameLabel
@onready var quest_title_label: Label = $InnerMargin/Container/QuestTitleLabel
@onready var quest_container: VBoxContainer = $InnerMargin/Container/QuestContainer
@onready var quest_progress_label: Label = $InnerMargin/Container/QuestContainer/QuestProgressLabel

func initialize(character_id: String) -> void:
	## Initialize the HUD block with character data
	## Must be called after instantiation
	_load_portrait(character_id)
	_update_name(character_id)
	_update_quest_info(character_id)

func refresh_quest_info(character_id: String) -> void:
	## Refresh quest information (called when quest state changes)
	_update_quest_info(character_id)

func _load_portrait(character_id: String) -> void:
	## Load character portrait image
	if not is_instance_valid(portrait):
		return
	
	var char_data = DataRegistry.get_character(character_id) if DataRegistry else null
	if not char_data:
		return
	
	var texture = null

	# Load texture from CharacterData.portrait_path — one path for all characters.
	if char_data.portrait_path != "" and char_data.portrait_path != null \
			and ResourceLoader.exists(char_data.portrait_path):
		texture = ResourceLoader.load(char_data.portrait_path)

	if texture:
		portrait.texture = texture
	else:
		push_warning("CharacterHUDBlock: No portrait art for %s (portrait_path='%s')" % [char_data.display_name, char_data.portrait_path])

func _update_name(character_id: String) -> void:
	## Update character name label
	if not is_instance_valid(name_label):
		return
	
	if DataRegistry:
		name_label.text = DataRegistry.get_character_display_name(character_id)
	else:
		name_label.text = character_id

func _update_quest_info(character_id: String) -> void:
	## Update quest title and progress labels
	if not is_instance_valid(quest_title_label) or not is_instance_valid(quest_progress_label):
		return
	
	# Get quest data from QuestManager
	var quest_state = QuestManager.get_quest(character_id) if QuestManager else null
	if quest_state and quest_state is QuestState:
		# Set quest title
		quest_title_label.text = quest_state.title
		var is_complete = quest_state.is_complete
		var progress = quest_state.progress
		var progress_max = quest_state.progress_max
		
		if is_complete:
			quest_progress_label.text = "Complete"
			quest_progress_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			quest_progress_label.text = "Progress: %d/%d" % [progress, progress_max]
			quest_progress_label.remove_theme_color_override("font_color")
	else:
		quest_title_label.text = ""
		quest_progress_label.text = "Progress: —"
		quest_progress_label.remove_theme_color_override("font_color")

