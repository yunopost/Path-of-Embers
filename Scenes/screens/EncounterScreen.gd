extends Control

## Encounter screen - displays encounter choices and generates rewards

@onready var title_label: Label = $CenterPanel/VBoxContainer/TitleLabel
@onready var body_label: Label = $CenterPanel/VBoxContainer/BodyLabel
@onready var choices_container: VBoxContainer = $CenterPanel/VBoxContainer/ChoicesContainer
@onready var debug_label: Label = $CenterPanel/VBoxContainer/DebugLabel

var current_node: MapNodeData = null

func _ready():
	# Verify we have a valid encounter node
	if not MapManager.current_map or MapManager.current_node_id.is_empty():
		push_warning("EncounterScreen: No current node, returning to map")
		ScreenManager.go_to_map()
		return
	
	current_node = MapManager.current_map.get_node(MapManager.current_node_id)
	if not current_node or current_node.node_type != MapNodeData.NodeType.ENCOUNTER:
		push_warning("EncounterScreen: Current node is not an ENCOUNTER, returning to map")
		ScreenManager.go_to_map()
		return
	
	# Setup UI
	_setup_ui()
	
	# Setup choices
	_setup_choices()

func _setup_ui():
	## Setup UI labels
	if title_label:
		title_label.text = "Encounter"
	
	if body_label:
		body_label.text = "A strange figure approaches you on the path..."
	
	if debug_label and OS.is_debug_build():
		debug_label.text = "Node: %s (Type: %s)" % [current_node.id, MapNodeData.NodeType.keys()[current_node.node_type]]
		debug_label.visible = true
	else:
		if debug_label:
			debug_label.visible = false

func _setup_choices():
	## Create choice buttons
	if not choices_container:
		return
	
	# Clear existing buttons
	for child in choices_container.get_children():
		child.queue_free()
	
	# Create choice buttons
	var help_btn = Button.new()
	help_btn.text = "Help"
	help_btn.pressed.connect(_on_help_chosen)
	help_btn.custom_minimum_size = Vector2(200, 40)
	choices_container.add_child(help_btn)
	
	var threaten_btn = Button.new()
	threaten_btn.text = "Threaten"
	threaten_btn.pressed.connect(_on_threaten_chosen)
	threaten_btn.custom_minimum_size = Vector2(200, 40)
	choices_container.add_child(threaten_btn)
	
	var leave_btn = Button.new()
	leave_btn.text = "Leave"
	leave_btn.pressed.connect(_on_leave_chosen)
	leave_btn.custom_minimum_size = Vector2(200, 40)
	choices_container.add_child(leave_btn)

func _on_help_chosen():
	## Generate rewards for "Help" choice
	# Emit ENCOUNTER_CHOICE event for quest system
	QuestManager.emit_game_event("ENCOUNTER_CHOICE", {
		"encounter_id": "encounter_placeholder_01",
		"choice_id": "help"
	})
	
	var bundle = RewardBundle.new()
	bundle.gold = 20
	bundle.card_choices = _generate_card_choices(3)
	bundle.skip_allowed = true
	
	_runstate_set_pending_rewards(bundle)
	ScreenManager.go_to_rewards(bundle)

func _on_threaten_chosen():
	## Generate rewards for "Threaten" choice
	# Emit ENCOUNTER_CHOICE event for quest system
	QuestManager.emit_game_event("ENCOUNTER_CHOICE", {
		"encounter_id": "encounter_placeholder_01",
		"choice_id": "threaten"
	})
	
	var bundle = RewardBundle.new()
	bundle.gold = 35
	bundle.card_choices = _generate_card_choices(3)
	bundle.relic_id = "relic_test_01"  # Placeholder relic ID
	bundle.skip_allowed = true
	
	_runstate_set_pending_rewards(bundle)
	ScreenManager.go_to_rewards(bundle)

func _on_leave_chosen():
	## Generate rewards for "Leave" choice
	# Emit ENCOUNTER_CHOICE event for quest system
	QuestManager.emit_game_event("ENCOUNTER_CHOICE", {
		"encounter_id": "encounter_placeholder_01",
		"choice_id": "leave"
	})
	
	var bundle = RewardBundle.new()
	bundle.heal_amount = 5
	bundle.card_choices = _generate_card_choices(3)
	bundle.skip_allowed = true
	
	_runstate_set_pending_rewards(bundle)
	ScreenManager.go_to_rewards(bundle)

func _generate_card_choices(count: int) -> Array[String]:
	## Generate card choices from reward pool using pity system
	## Delegates to RewardResolver for consistency
	return RewardResolver._generate_card_choices(count, MapNodeData.NodeType.ENCOUNTER)

func _runstate_set_pending_rewards(bundle: RewardBundle):
	## Helper to set pending rewards in RunState
	## This avoids direct property access from outside autoload
	if RunState and RunState.has_method("set_pending_rewards"):
		RunState.set_pending_rewards(bundle)
	else:
		# Fallback: direct property access
		RunState.pending_rewards = bundle

