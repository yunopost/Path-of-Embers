extends Control

## Reusable Party HUD component showing party members with portraits, names, and quest info

var party_margin: MarginContainer = null
var party_row: HBoxContainer = null

var character_hud_blocks: Array[Control] = []

func _ready():
	# Wait one frame to ensure nodes are ready
	await get_tree().process_frame
	
	# Get node references safely
	party_margin = get_node_or_null("PartyMargin")
	party_row = get_node_or_null("PartyMargin/VBoxContainer/PartyRow")
	
	# Enforce padding and spacing at runtime
	_apply_layout_overrides()
	
	# Connect to RunState signals (with safety check)
	if RunState:
		if not RunState.party_changed.is_connected(_on_party_changed):
			RunState.party_changed.connect(_on_party_changed)
		if not RunState.quests_changed.is_connected(_on_quests_changed):
			RunState.quests_changed.connect(_on_quests_changed)
	
	# Initial refresh (deferred to ensure everything is ready)
	call_deferred("refresh")

func _apply_layout_overrides():
	## Apply theme constant overrides for spacing and padding
	if not is_instance_valid(party_margin) or not is_instance_valid(party_row):
		return
	
	# PartyMargin padding
	party_margin.add_theme_constant_override("margin_left", 16)
	party_margin.add_theme_constant_override("margin_top", 8)
	party_margin.add_theme_constant_override("margin_right", 8)
	party_margin.add_theme_constant_override("margin_bottom", 12)
	
	# PartyRow separation between character blocks
	party_row.add_theme_constant_override("separation", 24)
	party_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _on_party_changed():
	refresh()

func _on_quests_changed():
	refresh()

func refresh():
	## Refresh the party display from RunState
	# Apply layout overrides every refresh to ensure they persist
	_apply_layout_overrides()
	
	# Clear existing blocks
	for block in character_hud_blocks:
		if is_instance_valid(block):
			block.queue_free()
	character_hud_blocks.clear()
	
	# Create blocks for each party member
	if RunState and RunState.party_ids.size() == 3 and is_instance_valid(party_row):
		for i in range(3):
			var char_id = RunState.party_ids[i]
			var block = _create_character_hud_block(char_id)
			party_row.add_child(block)
			character_hud_blocks.append(block)

func _create_character_hud_block(character_id: String) -> Control:
	## Create a single character HUD block
	# Root block container with enforced minimum size
	var block = VBoxContainer.new()
	block.custom_minimum_size = Vector2(200, 190)
	block.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	block.add_theme_constant_override("separation", 6)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Inner margin container for padding
	var inner_margin = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 8)
	inner_margin.add_theme_constant_override("margin_right", 8)
	inner_margin.add_theme_constant_override("margin_top", 8)
	inner_margin.add_theme_constant_override("margin_bottom", 8)
	inner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(inner_margin)
	
	# Content container
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_FILL
	container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_margin.add_child(container)
	
	# Spacer to seperate HP bar above from portraits
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 12
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(spacer)
	
	# Portrait placeholder panel with enforced size
	var portrait = Panel.new()
	portrait.custom_minimum_size = Vector2(170, 95)
	portrait.size_flags_horizontal = Control.SIZE_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(portrait)
	
	# Character name label centered over portrait
	var name_label = Label.new()
	if DataRegistry:
		name_label.text = DataRegistry.get_character_display_name(character_id)
	else:
		name_label.text = character_id
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	portrait.add_child(name_label)
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Quest info container with separation
	var quest_container = VBoxContainer.new()
	quest_container.add_theme_constant_override("separation", 6)
	quest_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Quest title label
	var quest_title_label = Label.new()
	quest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_title_label.add_theme_font_size_override("font_size", 11)
	quest_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_title_label.clip_contents = true
	quest_title_label.custom_minimum_size.y = 28
	quest_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Quest progress label
	var quest_progress_label = Label.new()
	quest_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_progress_label.add_theme_font_size_override("font_size", 10)
	quest_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Get quest data from RunState
	if RunState and RunState.quests.has(character_id):
		var quest_state = RunState.quests[character_id]
		var is_complete = quest_state.get("is_complete", false)
		var progress = quest_state.get("progress", 0)
		var progress_max = quest_state.get("progress_max", 0)
		var title = quest_state.get("title", "Quest: —")
		
		quest_title_label.text = ("[✓] " if is_complete else "[ ] ") + title
		if is_complete:
			quest_progress_label.text = "Complete"
			quest_progress_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			quest_progress_label.text = "Progress: %d/%d" % [progress, progress_max]
	else:
		quest_title_label.text = "[ ] Quest: —"
		quest_progress_label.text = "Progress: —"
	
	quest_container.add_child(quest_title_label)
	quest_container.add_child(quest_progress_label)
	container.add_child(quest_container)
	
	return block
