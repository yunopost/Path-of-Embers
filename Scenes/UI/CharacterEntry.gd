extends VBoxContainer

## Character entry card for character selection screen
## Displays character portrait, name, role, and quest information

signal character_selected(character_id: String)

@export var character_data: CharacterData = null

@onready var portrait_container: Panel = $PortraitContainer
@onready var portrait: TextureRect = $PortraitContainer/Portrait
@onready var select_button: Button = $SelectButton
@onready var quest_title_label: Label = $QuestTitle
@onready var quest_desc_label: Label = $QuestDesc

var _pending_char_data: CharacterData = null

func _ready():
	# If we have pending character data, initialize now that nodes are ready
	if _pending_char_data:
		initialize(_pending_char_data)
		_pending_char_data = null

func initialize(char_data: CharacterData) -> void:
	## Initialize the entry with character data
	## Must be called after instantiation
	print("CharacterEntry: initialize() called for %s" % (char_data.display_name if char_data else "null"))
	character_data = char_data
	
	if not character_data:
		push_error("CharacterEntry: initialize() called with null character_data")
		return
	
	# Get node references directly (don't rely on @onready if called before _ready)
	var portrait_node = get_node_or_null("PortraitContainer/Portrait")
	var button_node = get_node_or_null("SelectButton")
	var quest_title_node = get_node_or_null("QuestTitle")
	var quest_desc_node = get_node_or_null("QuestDesc")
	
	print("CharacterEntry: Nodes - portrait: %s, button: %s, quest_title: %s, quest_desc: %s" % [
		portrait_node != null, button_node != null, quest_title_node != null, quest_desc_node != null
	])
	
	# If nodes aren't ready yet, store data and wait for _ready()
	if not portrait_node or not button_node:
		print("CharacterEntry: Nodes not ready, storing data for deferred init")
		_pending_char_data = char_data
		call_deferred("_initialize_when_ready")
		return
	
	_do_initialize(portrait_node, button_node, quest_title_node, quest_desc_node)

func _initialize_when_ready():
	## Initialize when nodes are ready (deferred call)
	if _pending_char_data:
		character_data = _pending_char_data
		_pending_char_data = null
		_do_initialize()

func _do_initialize(portrait_node: TextureRect = null, button_node: Button = null, quest_title_node: Label = null, quest_desc_node: Label = null):
	## Perform the actual initialization
	if not character_data:
		print("CharacterEntry: _do_initialize called but character_data is null")
		return
	
	print("CharacterEntry: _do_initialize for %s" % character_data.display_name)
	
	# Use provided nodes or fall back to @onready or get_node
	var button = button_node if button_node else (select_button if is_instance_valid(select_button) else get_node_or_null("SelectButton"))
	var portrait = portrait_node if portrait_node else (self.portrait if is_instance_valid(self.portrait) else get_node_or_null("PortraitContainer/Portrait"))
	var quest_title = quest_title_node if quest_title_node else (quest_title_label if is_instance_valid(quest_title_label) else get_node_or_null("QuestTitle"))
	var quest_desc = quest_desc_node if quest_desc_node else (quest_desc_label if is_instance_valid(quest_desc_label) else get_node_or_null("QuestDesc"))
	
	# Set button text
	if is_instance_valid(button):
		button.text = "%s\n(%s)" % [character_data.display_name, character_data.role]
		print("CharacterEntry: Set button text to: %s" % button.text)
		# Connect button signal
		if not button.pressed.is_connected(_on_select_button_pressed):
			button.pressed.connect(_on_select_button_pressed)
	else:
		print("CharacterEntry: WARNING - button node is null!")
	
	# Load portrait
	if is_instance_valid(portrait):
		print("CharacterEntry: Loading portrait for %s" % character_data.display_name)
		_load_portrait(portrait)
	else:
		print("CharacterEntry: WARNING - portrait node is null!")
	
	# Set quest info
	if is_instance_valid(quest_title) and is_instance_valid(quest_desc):
		_update_quest_info(quest_title, quest_desc)
	else:
		print("CharacterEntry: WARNING - quest label nodes are null!")

func set_selected(is_selected: bool) -> void:
	## Update visual state to show selection
	if is_instance_valid(select_button):
		if is_selected:
			select_button.modulate = Color(0.7, 1.0, 0.7)  # Green tint
		else:
			select_button.modulate = Color.WHITE
	
	if is_instance_valid(self):
		if is_selected:
			modulate = Color(0.9, 1.0, 0.9)  # Light green tint
		else:
			modulate = Color.WHITE
	
	if is_instance_valid(portrait):
		if is_selected:
			portrait.modulate = Color(1.0, 1.0, 1.0)  # Full brightness
		else:
			portrait.modulate = Color(0.7, 0.7, 0.7)  # Dimmed

## Role-based placeholder colors for characters without portrait art
const ROLE_COLORS = {
	"Warrior":  Color("#5A2010"),
	"Healer":   Color("#14451E"),
	"Defender": Color("#102050"),
}
const ROLE_ICONS = {
	"Warrior":  "⚔",
	"Healer":   "✦",
	"Defender": "◈",
}

func _load_portrait(portrait_node: TextureRect = null) -> void:
	## Load character portrait image, falling back to a role-colored placeholder
	var portrait_to_use = portrait_node if portrait_node else portrait
	if not is_instance_valid(portrait_to_use) or not character_data:
		if not character_data:
			push_warning("CharacterEntry: _load_portrait called with null character_data")
		return

	var texture = null

	# Load texture - use direct path matching for known characters first
	if character_data.display_name == "Monster Hunter":
		texture = load("res://Path-of-Embers/Art Assets/Monster Hunter/Monster Hunter.png")
		if texture == null:
			texture = load("res://Path-of-Embers/Art Assets/Monster Hunter/Monster Hunter 2.png")
	elif character_data.display_name == "Witch":
		texture = load("res://Path-of-Embers/Art Assets/Witch/Witch.png")
		if texture == null:
			texture = load("res://Path-of-Embers/Art Assets/Witch/Witch 2.png")

	# Fallback: portrait_path on CharacterData
	if texture == null and character_data.get("portrait_path") and character_data.portrait_path != "":
		texture = ResourceLoader.load(character_data.portrait_path)

	if texture:
		portrait_to_use.texture = texture
	else:
		# No art available — show a role-colored placeholder
		_setup_placeholder_portrait(portrait_to_use)

func _setup_placeholder_portrait(portrait_node: TextureRect) -> void:
	## Build a styled placeholder when no portrait art is available
	if not is_instance_valid(portrait_node) or not character_data:
		return

	# Hide the (empty) TextureRect
	portrait_node.visible = false

	var container = portrait_node.get_parent()
	if not is_instance_valid(container):
		return

	# Avoid duplicating placeholder if already created
	if container.has_node("PlaceholderBg"):
		return

	# Colored background matching the character's role
	var role_color = ROLE_COLORS.get(character_data.role, Color("#2A2A2A"))
	var bg = ColorRect.new()
	bg.name = "PlaceholderBg"
	bg.color = role_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)

	# Initials label (center)
	var words = character_data.display_name.split(" ")
	var initials = ""
	for w in words:
		if w.length() > 0:
			initials += w[0].to_upper()
	var initials_label = Label.new()
	initials_label.text = initials
	initials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	initials_label.add_theme_font_size_override("font_size", 42)
	initials_label.modulate = Color(1, 1, 1, 0.75)
	initials_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(initials_label)

	# Role icon badge (bottom-right, small circle)
	var badge = Panel.new()
	badge.name = "RoleBadge"
	badge.custom_minimum_size = Vector2(24, 24)
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -28
	badge.offset_top = -28
	badge.offset_right = -4
	badge.offset_bottom = -4
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = role_color.lightened(0.3)
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.corner_radius_bottom_left = 12
	badge_style.corner_radius_bottom_right = 12
	badge_style.border_color = Color(1, 1, 1, 0.4)
	badge_style.border_width_left = 1
	badge_style.border_width_right = 1
	badge_style.border_width_top = 1
	badge_style.border_width_bottom = 1
	badge.add_theme_stylebox_override("panel", badge_style)
	container.add_child(badge)

	var badge_label = Label.new()
	badge_label.text = ROLE_ICONS.get(character_data.role, "?")
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_label)

func _update_quest_info(quest_title: Label = null, quest_desc: Label = null) -> void:
	## Update quest title and description labels
	if not character_data:
		return
	
	var title = quest_title if quest_title else quest_title_label
	var desc = quest_desc if quest_desc else quest_desc_label
	
	if is_instance_valid(title) and is_instance_valid(desc):
		if not character_data.quests.is_empty():
			# Show the full quest pool so players can evaluate co-completion risk
			var lines: Array[String] = []
			for q in character_data.quests:
				var entry = q.title
				if q.progress_max > 0:
					entry += " (×%d)" % q.progress_max
				lines.append(entry)
			title.text = "Quest Pool (%d)" % character_data.quests.size()
			desc.text = "\n".join(lines)
		else:
			title.text = "No Quest"
			desc.text = "(This character has no quest assigned.)"

func _on_select_button_pressed() -> void:
	## Handle select button press
	if character_data:
		character_selected.emit(character_data.id)

