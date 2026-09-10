extends Control

## Encounter screen - loads an EncounterData resource and displays choices.

@onready var title_label: Label = $CenterPanel/VBoxContainer/TitleLabel
@onready var body_label: Label = $CenterPanel/VBoxContainer/BodyLabel
@onready var choices_container: VBoxContainer = $CenterPanel/VBoxContainer/ChoicesContainer
@onready var debug_label: Label = $CenterPanel/VBoxContainer/DebugLabel

var current_node: MapNodeData = null
var encounter_data: EncounterData = null

func _ready():
	if not MapManager.current_map or MapManager.current_node_id.is_empty():
		push_warning("EncounterScreen: No current node, returning to map")
		ScreenManager.go_to_map()
		return

	current_node = MapManager.current_map.get_node(MapManager.current_node_id)
	if not current_node or current_node.node_type != MapNodeData.NodeType.ENCOUNTER:
		push_warning("EncounterScreen: Current node is not an ENCOUNTER, returning to map")
		ScreenManager.go_to_map()
		return

	# Pick a random encounter for the current act
	var act = MapManager.get_current_act() if MapManager.has_method("get_current_act") else 1
	encounter_data = DataRegistry.get_random_encounter(act) if DataRegistry else null

	_setup_ui()
	_setup_choices()

func _setup_ui():
	if title_label:
		title_label.text = encounter_data.title if encounter_data else "Encounter"
	if body_label:
		body_label.text = encounter_data.body if encounter_data else "A strange figure approaches you on the path..."
	if debug_label:
		if OS.is_debug_build():
			var enc_id = encounter_data.id if encounter_data else "none"
			debug_label.text = "Node: %s | Encounter: %s" % [current_node.id, enc_id]
			debug_label.visible = true
		else:
			debug_label.visible = false

func _setup_choices():
	if not choices_container:
		return
	for child in choices_container.get_children():
		child.queue_free()

	if not encounter_data or encounter_data.choices.is_empty():
		# Fallback: single leave button
		var btn = Button.new()
		btn.text = "Continue"
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_fallback_continue)
		choices_container.add_child(btn)
		return

	for choice in encounter_data.choices:
		var btn = Button.new()
		btn.text = choice.get("label", "?")
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_choice_pressed.bind(choice))
		choices_container.add_child(btn)

func _on_choice_pressed(choice: Dictionary):
	var choice_id: String = choice.get("id", "")
	var enc_id: String = encounter_data.id if encounter_data else "unknown"

	# Emit quest event
	if QuestManager:
		QuestManager.emit_game_event("ENCOUNTER_CHOICE", {
			"encounter_id": enc_id,
			"choice_id": choice_id,
		})

	# Build reward bundle
	var bundle = RewardBundle.new()
	bundle.gold = choice.get("reward_gold", 0)
	bundle.heal_amount = choice.get("reward_heal", 0)
	bundle.upgrade_count = choice.get("reward_upgrade_count", 0)
	bundle.skip_allowed = true

	var card_choices_count: int = choice.get("reward_card_choices", 0)
	if card_choices_count > 0:
		bundle.card_choices = _generate_card_choices(card_choices_count)

	if RunState:
		RunState.set_pending_rewards(bundle)
	ScreenManager.go_to_rewards(bundle)

func _on_fallback_continue():
	if MapManager:
		MapManager.mark_current_node_completed()
	ScreenManager.go_to_map()

func _generate_card_choices(count: int) -> Array[String]:
	return RewardResolver._generate_card_choices(count, MapNodeData.NodeType.ENCOUNTER)
