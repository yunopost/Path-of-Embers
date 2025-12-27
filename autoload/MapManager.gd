extends Node

## Autoload singleton - Manages map state and progression
## Handles current map, node selection, and map-related signals

signal map_changed
signal node_position_changed
signal current_node_changed
signal available_next_node_ids_changed(node_ids: Array)

var act: int = 1
var map: String = ""
var node_position: int = 0  # How many nodes progressed (0 = start)
var current_map: MapData = null  # Current map for the floor
var current_node_id: String = ""  # ID of currently selected node
var available_next_node_ids: Array[String] = []  # IDs of nodes that can be selected next

func _ready():
	act = 1
	map = "Act1"
	node_position = 0
	current_map = null
	current_node_id = ""
	available_next_node_ids = []

func set_act(value: int):
	if act != value:
		act = value
		# Note: act_changed signal would go here if needed

func set_map(value: String):
	if map != value:
		map = value
		map_changed.emit()

func set_map_data(map_data: MapData):
	## Set the current map data
	if current_map != map_data:
		current_map = map_data
		map_changed.emit()
		_update_available_nodes()

func set_current_node(node_id: String):
	## Set the currently selected node
	## Note: Does NOT mark node as completed - use mark_current_node_completed() after encounter finishes
	if current_node_id != node_id:
		current_node_id = node_id
		
		# Update available next nodes
		_update_available_nodes()
		
		# Update node position
		if current_map and current_map.nodes.has(current_node_id):
			var node = current_map.nodes[current_node_id]
			node_position = node.row
		
		current_node_changed.emit(node_id)
		node_position_changed.emit()

func get_current_node_type() -> int:
	## Get the current node's type (MapNodeData.NodeType)
	## Returns FIGHT as fallback if node not found
	if not current_map or current_node_id.is_empty():
		return MapNodeData.NodeType.FIGHT
	
	var node = current_map.get_node(current_node_id)
	if node:
		return node.node_type
	
	return MapNodeData.NodeType.FIGHT

func mark_current_node_completed() -> void:
	## Mark the current node as completed and update available nodes
	## This is called after combat ends, separate from set_current_node
	## Emits NODE_COMPLETED event for quest system
	if not current_map or current_node_id.is_empty():
		return
	
	var node = current_map.get_node(current_node_id)
	if node:
		node.is_completed = true
		_update_available_nodes()
		# Emit map_changed to refresh map display
		map_changed.emit()
		
		# Emit NODE_COMPLETED event for quest system
		if QuestManager:
			QuestManager.emit_game_event("NODE_COMPLETED", {
				"node_id": current_node_id,
				"node_type": node.node_type,
				"row": node.row
			})
		
		# Force save after node completion
		if AutoSaveManager:
			AutoSaveManager.force_save("node_completed")

func _update_available_nodes():
	## Update the list of available next nodes based on current selection
	var old_available = available_next_node_ids.duplicate()
	available_next_node_ids.clear()
	
	if not current_map:
		# No map - make start nodes available
		available_next_node_ids_changed.emit([])
		return
	
	if current_node_id.is_empty():
		# No node selected - start nodes are available
		available_next_node_ids = current_map.start_node_ids.duplicate()
	else:
		# Get nodes connected from current node
		var current_node = current_map.get_node(current_node_id)
		if current_node:
			available_next_node_ids = current_node.connected_to.duplicate()
	
	# Filter out completed nodes (can't go back)
	available_next_node_ids = available_next_node_ids.filter(func(id): return not current_map.get_node(id).is_completed)
	
	# Emit signal if changed
	if available_next_node_ids != old_available:
		available_next_node_ids_changed.emit(available_next_node_ids)

func set_node_position(value: int):
	if node_position != value:
		node_position = value
		node_position_changed.emit()

func reset_map_state():
	## Reset map state to initial values
	set_act(1)
	set_map("Act1")
	set_node_position(0)
	current_map = null
	current_node_id = ""
	available_next_node_ids.clear()
	map_changed.emit()
	current_node_changed.emit("")
	available_next_node_ids_changed.emit([])
