extends Control

## Map screen - displays STS-style node map with branching paths

var map_generator: MapGenerator = null
var node_widgets: Dictionary = {}  # Key: node_id, Value: MapNodeWidget
var connection_data: Array[Dictionary] = []  # Store connection data for _draw() rendering

@onready var map_safe_area: MarginContainer = $MapSafeArea
@onready var scroll_container: ScrollContainer = $MapSafeArea/ScrollContainer
@onready var map_root: Control = $MapSafeArea/ScrollContainer/MapRoot
@onready var map_connections: Control = $MapSafeArea/ScrollContainer/MapRoot/MapConnections
@onready var map_nodes: Control = $MapSafeArea/ScrollContainer/MapRoot/MapNodes

func _ready():
	# Initialize map generator
	map_generator = MapGenerator.new()
	
	# Connect to RunState signals
	RunState.map_changed.connect(_on_map_changed)
	RunState.current_node_changed.connect(_on_current_node_changed)
	RunState.available_next_node_ids_changed.connect(_on_available_nodes_changed)
	
	# Setup scroll container
	if scroll_container:
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		await get_tree().process_frame  # Wait for layout
		scroll_container.scroll_horizontal = 0  # Start at left
	
	# Initialize screen (architecture rule 2.1)
	initialize()

func initialize():
	## Initialize the screen with current state
	## Must be called after instantiation, before use (architecture rule 2.1)
	refresh_from_state()

func refresh_from_state():
	## Refresh UI from RunState (architecture rule 11.2)
	# Generate map if none exists
	if not RunState.current_map:
		_generate_map()
	
	# Render map
	_render_map()
	
	# Debug tools (debug builds only)
	if OS.is_debug_build():
		_setup_debug_ui()

func _setup_scroll_input():
	## Setup mouse wheel scrolling for map (handled in _gui_input)
	pass

func _gui_input(event: InputEvent) -> void:
	if not scroll_container:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.shift_pressed or scroll_container.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
				var step: float = 60.0  # tweak feel
				var dir: float = -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0

				var new_scroll: float = scroll_container.scroll_horizontal + (dir * step)

				var h_scroll_bar := scroll_container.get_h_scroll_bar()
				var max_scroll: float = h_scroll_bar.max_value if h_scroll_bar else 0.0

				scroll_container.scroll_horizontal = clamp(new_scroll, 0.0, max_scroll)
				get_viewport().set_input_as_handled()

func _setup_debug_ui():
	# Setup debug buttons (debug builds only)
	if not OS.is_debug_build():
		return

	if not has_node("DebugButtonsBar"):
		# A wide top bar that centers its contents
		var bar := HBoxContainer.new()
		bar.name = "DebugButtonsBar"
		add_child(bar)

		# Make the bar span the screen width at the top
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
		bar.offset_left = 0
		bar.offset_right = 0
		bar.offset_top = 60
		bar.offset_bottom = 60 + 40  # height
		bar.alignment = BoxContainer.ALIGNMENT_CENTER

		# Important: bar should NOT eat clicks over the map
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Buttons (these CAN receive clicks)
		var generate_btn := Button.new()
		generate_btn.text = "Generate New Map"
		generate_btn.pressed.connect(_generate_map)
		generate_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.add_child(generate_btn)

		var reset_btn := Button.new()
		reset_btn.text = "Reset Progress"
		reset_btn.pressed.connect(_reset_progress)
		reset_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.add_child(reset_btn)
		
		var pool_btn := Button.new()
		pool_btn.text = "View Reward Pool"
		pool_btn.pressed.connect(_show_reward_pool_popup)
		pool_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.add_child(pool_btn)

func _generate_map():
	## Generate a new map
	var map_data = map_generator.generate_map(RunState.act)
	RunState.set_map_data(map_data)
	RunState.current_node_id = ""
	RunState.node_position = 0
	_update_available_nodes()

func _reset_progress():
	## Reset map progress (debug tool)
	if RunState.current_map:
		# Mark all nodes as not completed
		for node in RunState.current_map.nodes.values():
			node.is_completed = false
		RunState.current_node_id = ""
		RunState.node_position = 0
		_update_available_nodes()
		_render_map()

func _show_reward_pool_popup():
	## Show popup displaying all 66 cards in reward pool
	if not has_node("RewardPoolPopup"):
		_create_reward_pool_popup()
	
	var popup = get_node_or_null("RewardPoolPopup")
	if popup:
		popup.visible = true

func _create_reward_pool_popup():
	## Create the reward pool popup instance
	var popup_scene = load("res://Path-of-Embers/Scenes/UI/RewardPoolPopup.tscn")
	if popup_scene:
		var popup = popup_scene.instantiate()
		add_child(popup)
		popup.visible = false
	else:
		push_warning("MapScreen: Could not load RewardPoolPopup.tscn")

func _update_available_nodes():
	## Update which nodes are available for selection (calls RunState method)
	RunState._update_available_nodes()
	_update_node_states()

func _update_node_states():
	## Update visual states of all node widgets
	if OS.is_debug_build():
		print("MapScreen: _update_node_states called, available nodes: ", RunState.available_next_node_ids)  # Debug
	
	for node_id in node_widgets:
		var widget = node_widgets[node_id]
		if not is_instance_valid(widget):
			continue
		
		var is_selectable = node_id in RunState.available_next_node_ids
		var is_selected = node_id == RunState.current_node_id
		
		if OS.is_debug_build() and is_selectable:
			print("MapScreen: Setting node ", node_id, " as selectable")  # Debug
		
		widget.set_selectable(is_selectable)
		widget.set_selected(is_selected)
	
	# Rebuild connection data with updated selectability
	if RunState.current_map:
		_build_connection_data_for_existing_nodes()
	
	# Trigger redraw of connections
	_draw_all_connections()

func _build_connection_data_for_existing_nodes():
	## Rebuild connection data using existing widget positions (for state updates)
	
	# Build selectable set for fast lookup
	var selectable_set: Dictionary = {}
	for node_id in RunState.available_next_node_ids:
		selectable_set[node_id] = true
	
	var current_node_id = RunState.current_node_id
	
	connection_data.clear()
	
	# Build connection data for each edge
	for from_node_id in RunState.current_map.nodes:
		var from_node = RunState.current_map.nodes[from_node_id]
		var from_widget = node_widgets.get(from_node_id)
		
		if not from_widget or not is_instance_valid(from_widget):
			continue
		
		# Get button center in map_root's local coordinates
		var from_center_global = from_widget.get_button_center_global()
		var from_center: Vector2
		if map_root:
			var map_root_global_pos = map_root.get_global_rect().position
			from_center = from_center_global - map_root_global_pos
		else:
			from_center = from_widget.position
		var from_radius = from_widget.get_button_radius()
		
		for to_node_id in from_node.connected_to:
			var to_widget = node_widgets.get(to_node_id)
			if not to_widget or not is_instance_valid(to_widget):
				continue
			
			# Get button center in map_root's local coordinates
			var to_center_global = to_widget.get_button_center_global()
			var to_center: Vector2
			if map_root:
				var map_root_global_pos = map_root.get_global_rect().position
				to_center = to_center_global - map_root_global_pos
			else:
				to_center = to_widget.position
			var to_radius = to_widget.get_button_radius()
			
			# Calculate direction and edge points (edge-to-edge connection)
			var dir = (to_center - from_center).normalized()
			var start_pos = from_center + dir * from_radius
			var end_pos = to_center - dir * to_radius
			
			var is_selectable = to_node_id in selectable_set
			var is_current_outgoing = from_node_id == current_node_id and is_selectable
			
			connection_data.append({
				"start": start_pos,
				"end": end_pos,
				"is_selectable": is_selectable,
				"is_current_outgoing": is_current_outgoing
			})

func _render_map():
	## Render the entire map with nodes and connections (horizontal layout: left → right)
	# Clear existing widgets and lines
	_clear_map()
	
	if not RunState.current_map:
		push_warning("MapScreen: No map to render")
		return
	
	# Layout constants
	const STEP_SPACING_X = 120  # Horizontal spacing between progression steps (rows)
	const LANE_SPACING_Y = 90   # Vertical spacing between lanes (columns)
	const NODE_SIZE = 50        # Node button size (for connection calculations)
	const NODE_RADIUS = NODE_SIZE * 0.5
	
	# Get screen and available area
	var screen_size = get_viewport_rect().size
	var scroll_viewport_size = scroll_container.get_viewport_rect().size if scroll_container else screen_size
	var viewport_height = scroll_viewport_size.y
	
	# Find max lanes (columns) across all rows
	var max_cols = 0
	for row in range(RunState.current_map.total_rows):
		var row_nodes = RunState.current_map.get_nodes_in_row(row)
		max_cols = max(max_cols, row_nodes.size())
	
	# Calculate step spacing (fixed for scrolling)
	var step_spacing_x = STEP_SPACING_X
	var left_padding = 100
	var right_padding = 100
	
	# Store node positions for bounding box calculation
	var node_positions: Array[Vector2] = []
	var node_positions_by_id: Dictionary = {}
	
	# First pass: calculate raw positions
	for row in range(RunState.current_map.total_rows):
		var row_nodes = RunState.current_map.get_nodes_in_row(row)
		if row_nodes.is_empty():
			continue
		
		# Debug: Print node col order for this row
		if OS.is_debug_build():
			var col_list: Array[int] = []
			for node in row_nodes:
				col_list.append(node.col)
			print("MapScreen: Row ", row, " cols order (after get_nodes_in_row): ", col_list)
		
		# Ensure nodes are sorted by col (defensive check)
		row_nodes.sort_custom(func(a, b): return a.col < b.col)
		
		if OS.is_debug_build():
			var col_list_sorted: Array[int] = []
			for node in row_nodes:
				col_list_sorted.append(node.col)
			print("MapScreen: Row ", row, " cols order (after explicit sort): ", col_list_sorted)
		
		# X position: progression axis (row becomes X)
		var x = (row * step_spacing_x) + (NODE_RADIUS)
		
		# Y positions: lane axis - use node.col directly for consistent lane ordering
		# Find min and max col values to center the lanes
		var min_col = row_nodes[0].col
		var max_col = row_nodes[row_nodes.size() - 1].col
		var col_range = max_col - min_col
		
		# Calculate base_y to center the lanes vertically
		var total_lane_height = col_range * LANE_SPACING_Y if col_range > 0 else 0
		var base_y = (viewport_height - total_lane_height) / 2.0
		
		# Store positions using node.col for Y positioning (these are button center positions)
		for node in row_nodes:
			# Use node.col relative to min_col for Y position
			var col_offset = node.col - min_col
			var y = base_y + (col_offset * LANE_SPACING_Y)
			var pos = Vector2(x, y)
			node_positions.append(pos)
			node_positions_by_id[node.id] = pos
	
	# Calculate bounding box
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	for pos in node_positions:
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)
	
	var map_width = max_x - min_x + left_padding + right_padding
	var map_height = max_y - min_y
	
	# Calculate offsets
	# X: Start at left padding (no centering for horizontal scroll)
	var offset_x = left_padding - min_x
	# Y: Center vertically
	var offset_y = (viewport_height - map_height) / 2.0 - min_y
	
	# Size MapRoot to full map width (must be larger than viewport for scrolling)
	var required_width = map_width
	var required_height = max(viewport_height, map_height + 100)  # Add padding
	
	if map_root:
		map_root.custom_minimum_size = Vector2(required_width, required_height)
		map_root.size = Vector2(required_width, required_height)
		map_root.size_flags_horizontal = Control.SIZE_FILL
		map_root.size_flags_vertical = Control.SIZE_FILL
		
		# Wait for layout to update, then verify scrolling works
		await get_tree().process_frame
		if scroll_container:
			var h_scroll_bar = scroll_container.get_h_scroll_bar()
			if h_scroll_bar:
				var max_scroll = h_scroll_bar.max_value
				if OS.is_debug_build():
					print("MapScreen: viewport size: ", scroll_container.size)
					print("MapScreen: map_root min size: ", map_root.custom_minimum_size, " actual: ", map_root.size)
					print("MapScreen: h_scroll max: ", max_scroll)
					print("MapScreen: start nodes count: ", RunState.current_map.start_node_ids.size())
	
		# Second pass: create widgets with positioned locations
		for node_id in node_positions_by_id:
			var raw_pos = node_positions_by_id[node_id]
			var final_pos = raw_pos + Vector2(offset_x, offset_y)
			var node = RunState.current_map.get_node(node_id)
			if node:
				await _create_node_widget(node, final_pos)

		# After the loop: let layout settle one more frame
		await get_tree().process_frame

		# Build + draw connections
		_build_connection_data(offset_x, offset_y, NODE_RADIUS)
		_draw_all_connections()

		# Update node visuals
		_update_node_states()
	
	# Trigger redraw of connections
	_draw_all_connections()
	
	# Update node states
	_update_node_states()

func _create_node_widget(node: MapNodeData, node_position: Vector2) -> void:
	var widget_scene := load("res://Path-of-Embers/scenes/ui/MapNodeWidget.tscn")
	var widget := widget_scene.instantiate() as MapNodeWidget
	map_nodes.add_child(widget)

	widget.setup(node, false)
	await get_tree().process_frame

	# Positioning (keep yours for now)
	if widget.node_button and is_instance_valid(widget.node_button):
		var button_rect := widget.node_button.get_rect()
		var button_center_local := button_rect.get_center()
		widget.position = node_position - button_center_local
	else:
		widget.position = node_position - Vector2(27, 27)

	# Make sure the BUTTON receives input
	widget.mouse_filter = Control.MOUSE_FILTER_PASS
	if widget.node_button:
		widget.node_button.mouse_filter = Control.MOUSE_FILTER_STOP
		widget.node_button.disabled = false

		# ✅ Connect the real click
		# (Use bind so you don’t depend on widget rect hit testing)
		if not widget.node_button.pressed.is_connected(_on_node_clicked):
			widget.node_button.pressed.connect(_on_node_clicked.bind(node.id))

	node_widgets[node.id] = widget

func _build_connection_data(_offset_x: float = 0.0, _offset_y: float = 0.0, _node_radius: float = 25.0):
	## Build connection data for rendering (stored for _draw_all_connections)
	connection_data.clear()
	
	if not RunState.current_map:
		return
	
	# Build selectable set for fast lookup
	var selectable_set: Dictionary = {}
	for node_id in RunState.available_next_node_ids:
		selectable_set[node_id] = true
	
	var current_node_id = RunState.current_node_id
	
	# Build connection data for each edge
	var widgets_found = 0
	var widgets_missing = 0
	
	if OS.is_debug_build():
		print("MapScreen._build_connection_data: node_widgets.size()=", node_widgets.size(), ", map.nodes.size()=", RunState.current_map.nodes.size())
	
	for from_node_id in RunState.current_map.nodes:
		var from_node = RunState.current_map.nodes[from_node_id]
		var from_widget = node_widgets.get(from_node_id)
		
		if not from_widget or not is_instance_valid(from_widget):
			widgets_missing += 1
			if OS.is_debug_build() and widgets_missing <= 3:
				print("MapScreen._build_connection_data: Missing widget for ", from_node_id)
			continue
		
		widgets_found += 1
		# Get button center in map_root's local coordinates
		var from_center_global = from_widget.get_button_center_global()
		var from_center: Vector2
		if map_root:
			var map_root_global_pos = map_root.get_global_rect().position
			from_center = from_center_global - map_root_global_pos
		else:
			from_center = from_widget.position
		var from_radius = from_widget.get_button_radius()
		
		for to_node_id in from_node.connected_to:
			var to_widget = node_widgets.get(to_node_id)
			if not to_widget or not is_instance_valid(to_widget):
				continue
			
			# Get button center in map_root's local coordinates
			var to_center_global = to_widget.get_button_center_global()
			var to_center: Vector2
			if map_root:
				var map_root_global_pos = map_root.get_global_rect().position
				to_center = to_center_global - map_root_global_pos
			else:
				to_center = to_widget.position
			var to_radius = to_widget.get_button_radius()
			
			# Calculate direction and edge points (edge-to-edge connection)
			var dir = (to_center - from_center).normalized()
			var start_pos = from_center + dir * from_radius
			var end_pos = to_center - dir * to_radius
			
			# Determine line state for highlighting
			var is_selectable = to_node_id in selectable_set
			var is_current_outgoing = from_node_id == current_node_id and is_selectable
			
			# Store connection data
			connection_data.append({
				"start": start_pos,
				"end": end_pos,
				"is_selectable": is_selectable,
				"is_current_outgoing": is_current_outgoing
			})
	
	# Debug: check if we have connection data
	if OS.is_debug_build():
		print("MapScreen: Built ", connection_data.size(), " connections (widgets found: ", widgets_found, ", missing: ", widgets_missing, ")")

func _draw_all_connections():
	## Trigger redraw of MapConnections (which has its own _draw() method)
	if not map_connections:
		if OS.is_debug_build():
			print("MapScreen: map_connections is null!")  # Debug
		return
	
	# Ensure MapConnections is visible and ready
	if not map_connections.visible:
		map_connections.visible = true
		print("MapScreen: Made MapConnections visible")  # Debug
	
	# Update the MapConnections control with connection data
	if map_connections.has_method("set_connection_data"):
		map_connections.set_connection_data(connection_data)
		if OS.is_debug_build():
			print("MapScreen: Updated MapConnections with ", connection_data.size(), " connections, visible=", map_connections.visible)
	else:
		if OS.is_debug_build():
			print("MapScreen: MapConnections doesn't have set_connection_data method!")

func _clear_map():
	## Clear all node widgets and connections
	connection_data.clear()
	
	for widget in node_widgets.values():
		if is_instance_valid(widget):
			widget.queue_free()
	node_widgets.clear()
	
	_draw_all_connections()

func _on_node_clicked(node_id: String):
	## Handle node selection
	print("MapScreen: Node clicked: ", node_id)  # Debug
	if node_id not in RunState.available_next_node_ids:
		print("MapScreen: Node not in available_next_node_ids")  # Debug
		return  # Invalid selection
	
	# Get node data
	var node = RunState.current_map.get_node(node_id)
	if not node:
		return
	
	# Boss gate: check if all quests are complete before allowing boss entry
	if node.node_type == MapNodeData.NodeType.BOSS:
		if not RunState.are_all_party_quests_complete():
			_show_boss_gate_popup()
			return  # Block entry
	
	print("MapScreen: Setting current node to: ", node_id)  # Debug
	# Set current node
	RunState.set_current_node(node_id)
	
	# Transition to appropriate screen based on node type
	match node.node_type:
		MapNodeData.NodeType.FIGHT, MapNodeData.NodeType.ELITE, MapNodeData.NodeType.BOSS:
			ScreenManager.go_to_combat({})
		MapNodeData.NodeType.SHOP:
			ScreenManager.go_to_shop({})
		MapNodeData.NodeType.ENCOUNTER:
			ScreenManager.go_to_encounter({})

func _show_boss_gate_popup():
	## Show popup blocking boss entry when quests are incomplete
	var popup = AcceptDialog.new()
	popup.dialog_text = "Complete all three quests to challenge the final boss."
	popup.title = "Quest Incomplete"
	popup.unresizable = true
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

func _on_map_changed():
	## Handle map change signal
	_render_map()
	# Auto-scroll to start (left side)
	if scroll_container:
		scroll_container.scroll_horizontal = 0

func _on_current_node_changed(node_id: String):
	## Handle current node change signal
	_update_node_states()
	
	# Optional: Auto-scroll to current node
	if node_id != "" and scroll_container and node_widgets.has(node_id):
		var widget = node_widgets[node_id]
		if widget:
			var node_pos_x = widget.position.x + 27  # Button center X
			var viewport_width = scroll_container.size.x
			var target_x = node_pos_x - viewport_width * 0.35
			var max_scroll = max(0, map_root.size.x - viewport_width) if map_root else 0
			scroll_container.scroll_horizontal = clamp(target_x, 0, max_scroll)

func _on_available_nodes_changed(_node_ids: Array):
	## Handle available nodes change signal
	_update_node_states()
