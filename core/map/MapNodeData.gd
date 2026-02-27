extends RefCounted
class_name MapNodeData

## Represents a single node on the map
## Stores position, type, rewards, and connections

enum NodeType {
	FIGHT,
	ELITE,
	SHOP,
	ENCOUNTER,
	BOSS
}

enum RewardType {
	CARD,
	UPGRADE,
	GOLD,
	RELIC,
	BOSS_RELIC,
	QUEST
}

var id: String = ""
var row: int = 0
var col: int = 0
var node_type: NodeType = NodeType.FIGHT
var reward_flags: Array[RewardType] = []
var connected_to: Array[String] = []  # IDs of nodes in next row
var is_completed: bool = false  # Track if this node has been visited

func _init(p_id: String = "", p_row: int = 0, p_col: int = 0, p_type: NodeType = NodeType.FIGHT):
	id = p_id
	row = p_row
	col = p_col
	node_type = p_type
	reward_flags = []
	connected_to = []

func to_dict() -> Dictionary:
	return {
		"id": id,
		"row": row,
		"col": col,
		"node_type": node_type,
		"reward_flags": reward_flags,
		"connected_to": connected_to,
		"is_completed": is_completed
	}

static func from_dict(data: Dictionary) -> MapNodeData:
	# Convert row/col to int (JSON may store as float)
	var p_row := int(data.get("row", 0))
	var p_col := int(data.get("col", 0))
	var p_node_type := int(data.get("node_type", NodeType.FIGHT))
	var node = MapNodeData.new(
		data.get("id", ""),
		p_row,
		p_col,
		p_node_type
	)
	# Restore reward_flags by appending each item (convert to int to handle float from JSON)
	node.reward_flags.clear()
	var reward_flags_data = data.get("reward_flags", [])
	for flag in reward_flags_data:
		node.reward_flags.append(int(flag))
	# Restore connected_to (convert to typed array)
	var connected_to_data = data.get("connected_to", [])
	node.connected_to.clear()
	for conn in connected_to_data:
		node.connected_to.append(str(conn))
	node.is_completed = data.get("is_completed", false)
	return node
