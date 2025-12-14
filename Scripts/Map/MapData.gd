extends RefCounted
class_name MapData

## Represents a complete map for a floor/act
## Contains all nodes and metadata

var act_index: int = 1
var nodes: Dictionary = {}  # Key: node_id, Value: MapNodeData
var start_node_ids: Array[String] = []  # Row 0 nodes
var boss_node_id: String = ""
var total_rows: int = 0  # Including boss row

func _init(p_act_index: int = 1):
	act_index = p_act_index
	nodes = {}
	start_node_ids = []
	boss_node_id = ""

func add_node(node: MapNodeData):
	## Add a node to the map
	nodes[node.id] = node
	if node.row == 0:
		start_node_ids.append(node.id)

func get_node(node_id: String) -> MapNodeData:
	## Get a node by ID
	return nodes.get(node_id)

func get_nodes_in_row(row: int) -> Array[MapNodeData]:
	## Get all nodes in a specific row
	var result: Array[MapNodeData] = []
	for node in nodes.values():
		if node.row == row:
			result.append(node)
	# Sort by col for consistent ordering
	result.sort_custom(func(a, b): return a.col < b.col)
	return result

func to_dict() -> Dictionary:
	var nodes_dict = {}
	for node_id in nodes:
		nodes_dict[node_id] = nodes[node_id].to_dict()
	
	return {
		"act_index": act_index,
		"nodes": nodes_dict,
		"start_node_ids": start_node_ids,
		"boss_node_id": boss_node_id,
		"total_rows": total_rows
	}

static func from_dict(data: Dictionary) -> MapData:
	var map_data = MapData.new(data.get("act_index", 1))
	map_data.total_rows = data.get("total_rows", 0)
	map_data.boss_node_id = data.get("boss_node_id", "")
	
	var nodes_dict = data.get("nodes", {})
	for node_id in nodes_dict:
		var node_data = MapNodeData.from_dict(nodes_dict[node_id])
		map_data.nodes[node_id] = node_data
		if node_data.row == 0:
			map_data.start_node_ids.append(node_id)
	
	return map_data
