extends Control

## Reusable Party HUD component showing party members with portraits, names, and quest info

# Constants
const CHARACTER_HUD_BLOCK_SCENE = preload("res://Path-of-Embers/scenes/ui/hud/CharacterHUDBlock.tscn")

# Private variables
var _character_hud_blocks: Array[Control] = []

# @onready variables
@onready var party_margin: MarginContainer = $PartyMargin
@onready var party_row: HBoxContainer = $PartyMargin/VBoxContainer/PartyRow

# Built-in virtual functions
func _ready():
	# Wait one frame to ensure nodes are ready
	await get_tree().process_frame
	
	# Enforce padding and spacing at runtime
	_apply_layout_overrides()
	
	# Connect to manager signals (with safety check)
	if PartyManager:
		if not PartyManager.party_changed.is_connected(_on_party_changed):
			PartyManager.party_changed.connect(_on_party_changed)
	if QuestManager:
		if not QuestManager.quests_changed.is_connected(_on_quests_changed):
			QuestManager.quests_changed.connect(_on_quests_changed)
	
	# Initial refresh (deferred to ensure everything is ready)
	call_deferred("refresh")

# Public functions
func refresh():
	## Refresh the party display from managers
	# Apply layout overrides every refresh to ensure they persist
	_apply_layout_overrides()
	
	# Clear existing blocks
	for block in _character_hud_blocks:
		if is_instance_valid(block):
			block.queue_free()
	_character_hud_blocks.clear()
	
	# Create blocks for each party member
	if PartyManager and PartyManager.party_ids.size() == 3 and is_instance_valid(party_row):
		for i in range(3):
			var char_id = PartyManager.party_ids[i]
			var block = _create_character_hud_block(char_id)
			party_row.add_child(block)
			_character_hud_blocks.append(block)

# Private functions
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

func _create_character_hud_block(character_id: String) -> Control:
	## Create a single character HUD block by instantiating the scene
	var block = CHARACTER_HUD_BLOCK_SCENE.instantiate()
	if not block:
		push_error("PartyHUD: Failed to instantiate CharacterHUDBlock scene")
		return null
	
	# Initialize block with character data
	block.initialize(character_id)
	
	return block

func _refresh_quest_info():
	## Refresh quest information for all character blocks
	for i in range(_character_hud_blocks.size()):
		if not is_instance_valid(_character_hud_blocks[i]):
			continue
		
		if PartyManager and i < PartyManager.party_ids.size():
			var char_id = PartyManager.party_ids[i]
			_character_hud_blocks[i].refresh_quest_info(char_id)

# Signal callbacks
func _on_party_changed():
	refresh()

func _on_quests_changed():
	## Quest state changed - refresh quest info for all blocks
	_refresh_quest_info()
