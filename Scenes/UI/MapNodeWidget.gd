extends Control
class_name MapNodeWidget

## Reusable widget for displaying a map node
## Shows node type icon and reward preview icons

signal node_clicked(node_id: String)

var node_data: MapNodeData = null
var is_selectable: bool = false
var is_selected: bool = false

@onready var node_button: Button = $VBoxContainer/NodeButton
@onready var node_icon_label: Label = $VBoxContainer/NodeButton/IconLabel
@onready var reward_container: HBoxContainer = $VBoxContainer/RewardContainer

func _ready():
	# Widget should pass input to children (button will handle clicks)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if node_button:
		node_button.pressed.connect(_on_button_pressed)
		# Ensure button can receive clicks
		node_button.mouse_filter = Control.MOUSE_FILTER_STOP
		node_button.disabled = false

func _gui_input(event: InputEvent):
	## Handle input directly on widget (fallback if button doesn't receive it)
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is within button bounds
			if node_button:
				var button_rect = Rect2(node_button.position, node_button.size)
				var local_pos = get_local_mouse_position()
				if button_rect.has_point(local_pos):
					print("MapNodeWidget._gui_input: Click detected on widget, triggering button")  # Debug
					_on_button_pressed()
					get_viewport().set_input_as_handled()

func setup(node: MapNodeData, selectable: bool = false):
	## Setup the widget with node data
	node_data = node
	is_selectable = selectable
	print("MapNodeWidget.setup() called for ", node.id, ", selectable=", selectable)  # Debug
	_update_display()
	# Ensure button is properly set up after display update
	if node_button:
		node_button.disabled = false  # Ensure button is enabled initially

func _update_display():
	## Update visual display based on node data and state
	if not node_data:
		return
	
	# Update icon label based on node type
	if node_icon_label:
		match node_data.node_type:
			MapNodeData.NodeType.FIGHT:
				node_icon_label.text = "F"
			MapNodeData.NodeType.ELITE:
				node_icon_label.text = "E"
			MapNodeData.NodeType.SHOP:
				node_icon_label.text = "$"
			MapNodeData.NodeType.ENCOUNTER:
				node_icon_label.text = "?"
			MapNodeData.NodeType.BOSS:
				node_icon_label.text = "B"
			MapNodeData.NodeType.FINAL_BOSS:
				node_icon_label.text = "FB"
			MapNodeData.NodeType.STORY:
				node_icon_label.text = "S"
			MapNodeData.NodeType.REST:
				node_icon_label.text = "Z"
	
	# Update reward icons
	_update_reward_icons()
	
	# Update visual state
	_update_visual_state()

func _update_reward_icons():
	## Update reward preview icons
	if not reward_container:
		return
	
	# Clear existing reward icons
	for child in reward_container.get_children():
		child.queue_free()
	
	# Skip reward icons for ENCOUNTER, SHOP, STORY, and REST
	if node_data.node_type in [
		MapNodeData.NodeType.ENCOUNTER,
		MapNodeData.NodeType.SHOP,
		MapNodeData.NodeType.STORY,
		MapNodeData.NodeType.REST
	]:
		return
	
	# Add reward icons based on reward_flags
	for reward_type in node_data.reward_flags:
		var icon_label = Label.new()
		icon_label.text = _get_reward_icon_text(reward_type)
		icon_label.custom_minimum_size = Vector2(14, 16)
		icon_label.add_theme_font_size_override("font_size", 9)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reward_container.add_child(icon_label)

func _get_reward_icon_text(reward_type: MapNodeData.RewardType) -> String:
	## Get text/symbol for reward type
	match reward_type:
		MapNodeData.RewardType.CARD:
			return "C"
		MapNodeData.RewardType.UPGRADE:
			return "U"
		MapNodeData.RewardType.GOLD:
			return "G"
		MapNodeData.RewardType.RELIC:
			return "R"
		MapNodeData.RewardType.BOSS_RELIC:
			return "BR"
		MapNodeData.RewardType.QUEST:
			return "Q"
		_:
			return "?"

func _update_visual_state():
	## Update colors/visibility based on selectable/selected state
	if not node_button:
		return
	
	if node_data and node_data.is_completed:
		# Completed nodes are dimmed
		node_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
		node_button.disabled = true
	elif is_selectable:
		# Selectable nodes are highlighted
		node_button.modulate = Color(1.0, 1.0, 0.7, 1.0)  # Yellow tint
		node_button.disabled = false
	elif is_selected:
		# Selected node
		node_button.modulate = Color(0.7, 1.0, 0.7, 1.0)  # Green tint
		node_button.disabled = false
	else:
		# Non-selectable nodes are dimmed
		node_button.modulate = Color(0.6, 0.6, 0.6, 1.0)
		node_button.disabled = true

func set_selectable(selectable: bool):
	## Set whether this node can be selected
	if is_selectable != selectable:
		is_selectable = selectable
		_update_visual_state()
		print("MapNodeWidget: set_selectable(", selectable, ") for ", node_data.id if node_data else "null")  # Debug

func set_selected(selected: bool):
	## Set whether this node is currently selected
	if is_selected != selected:
		is_selected = selected
		_update_visual_state()
		print("MapNodeWidget: set_selected(", selected, ") for ", node_data.id if node_data else "null")  # Debug

func get_button_center_global() -> Vector2:
	## Get the global center position of the button
	if node_button:
		var button_rect = node_button.get_global_rect()
		return button_rect.get_center()
	return get_global_rect().get_center()

func get_button_radius() -> float:
	## Get the radius of the button (for connection line calculations)
	if node_button:
		var button_size = node_button.size
		return min(button_size.x, button_size.y) * 0.5
	return 25.0  # Default fallback

func _on_button_pressed():
	## Handle button click
	print("MapNodeWidget: Button pressed, node_id: ", node_data.id if node_data else "null", ", is_selectable: ", is_selectable)  # Debug
	if node_data and is_selectable:
		print("MapNodeWidget: Emitting node_clicked signal")  # Debug
		node_clicked.emit(node_data.id)
	else:
		print("MapNodeWidget: Not emitting - node_data: ", node_data != null, ", is_selectable: ", is_selectable)  # Debug

