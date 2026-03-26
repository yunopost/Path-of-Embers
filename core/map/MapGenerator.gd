extends RefCounted
class_name MapGenerator

## Generates STS-style branching maps
## Creates 14-15 rows before boss, with branching paths

const ROWS_BEFORE_BOSS = 15
const MIN_LANES = 2
const MAX_LANES = 5
const TOTAL_ROWS = ROWS_BEFORE_BOSS + 1  # +1 for boss row
const UP_CHANCE := 0.45
const DOWN_CHANCE := 0.30

func generate_map(act_index: int = 1) -> MapData:
	## Generate a complete map for the given act
	var map_data = MapData.new(act_index)
	map_data.total_rows = TOTAL_ROWS
	
	# Track nodes per row for positioning
	var nodes_by_row: Array[Array] = []
	for i in range(TOTAL_ROWS):
		nodes_by_row.append([])
	
	# Generate start nodes (row 0)
	var start_nodes = _generate_start_nodes(act_index)
	nodes_by_row[0] = start_nodes
	for node in start_nodes:
		map_data.add_node(node)
	
	# Generate intermediate rows (1 to ROWS_BEFORE_BOSS - 1)
	for row in range(1, ROWS_BEFORE_BOSS):
		var prev_row_nodes = nodes_by_row[row - 1]
		var new_row_nodes = _generate_row(row, prev_row_nodes, act_index)
		nodes_by_row[row] = new_row_nodes
		
		# Connect previous row to new row
		_connect_rows(prev_row_nodes, new_row_nodes)
		
		# Add nodes to map
		for node in new_row_nodes:
			map_data.add_node(node)
	
	# Generate boss node (final row)
	var boss_row = nodes_by_row[ROWS_BEFORE_BOSS - 1]
	var boss_node = _generate_boss_node(ROWS_BEFORE_BOSS, act_index)
	nodes_by_row[ROWS_BEFORE_BOSS] = [boss_node]
	map_data.boss_node_id = boss_node.id
	
	# Connect last row to boss
	_connect_rows(boss_row, [boss_node])
	map_data.add_node(boss_node)
	
	return map_data

func _generate_start_nodes(_act_index: int) -> Array[MapNodeData]:
	## Generate 3-4 start nodes at row 0
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var count = rng.randi_range(3, 4)  # 3-4 start nodes
	var nodes: Array[MapNodeData] = []
	
	# Distribute nodes across available lanes (no duplicates)
	var available_lanes = []
	for i in range(MAX_LANES):  # Use up to MAX_LANES lanes
		available_lanes.append(i)
	available_lanes.shuffle()  # Randomize order
	
	# Create nodes at selected lane positions
	for i in range(count):
		var lane_index = available_lanes[i] if i < available_lanes.size() else i
		var node = MapNodeData.new("node_0_%d" % i, 0, lane_index, MapNodeData.NodeType.FIGHT)
		# Start nodes are fights
		node.reward_flags.append(MapNodeData.RewardType.CARD)
		nodes.append(node)
	
	return nodes

func _generate_row(row: int, prev_row_nodes: Array[MapNodeData], act_index: int) -> Array[MapNodeData]:
	if prev_row_nodes.is_empty():
		return []

	var target_count := _calculate_row_width(row, prev_row_nodes.size())
	var nodes: Array[MapNodeData] = []

	# Pick random lane slots (0..MAX_LANES-1) for this row
	var lanes: Array[int] = []
	for lane in range(MAX_LANES):
		lanes.append(lane)
	lanes.shuffle()
	lanes = lanes.slice(0, target_count)
	lanes.sort() # keep top-to-bottom order

	for idx in range(target_count):
		var lane_index := lanes[idx]
		var node_id := "node_%d_%d" % [row, idx]
		var node_type := _choose_node_type(row, idx, target_count, act_index)
		var node := MapNodeData.new(node_id, row, lane_index, node_type)
		_set_reward_flags(node)
		nodes.append(node)

	return nodes


func _calculate_row_width(row: int, prev_count: int) -> int:
	# Boss approach: gently converge near the end
	var rows_left := ROWS_BEFORE_BOSS - row

	# Near the boss, bias downward
	if rows_left <= 3:
		return clamp(prev_count - randi_range(0, 1), MIN_LANES, MAX_LANES)
	if rows_left <= 5 and prev_count > MIN_LANES and randf() < 0.65:
		return clamp(prev_count - 1, MIN_LANES, MAX_LANES)

	# Otherwise: random walk with mild bias toward middle widths (3–4)
	var step := 0
	var roll := randf()

	# 25% shrink, 45% stay, 30% grow
	if roll < 0.25:
		step = -1
	elif roll < 0.70:
		step = 0
	else:
		step = 1

	var target := prev_count + step

	# Mild "center bias" so it doesn’t camp at 5 or 2 forever
	if target >= MAX_LANES and randf() < 0.60:
		target = MAX_LANES - 1
	if target <= MIN_LANES and randf() < 0.60:
		target = MIN_LANES + 1

	# Early map: don’t instantly explode to 5 lanes
	if row <= 2:
		target = min(target, 4)

	return clamp(target, MIN_LANES, MAX_LANES)

func _choose_node_type(row: int, col: int, row_width: int, act_index: int) -> MapNodeData.NodeType:
	## Choose appropriate node type based on position and act.
	## Act 1: standard (FIGHT ~55%, ENCOUNTER ~20%, SHOP ~15%, ELITE ~10%)
	## Act 2: more elites (+5%), fewer shops (-5%)
	## Act 3: even more elites (+5%), more encounters (+5%), fewer fights

	# Per-act scaling multipliers
	var elite_chance: float = 0.10 + (act_index - 1) * 0.05   # 0.10 / 0.15 / 0.20
	var shop_chance: float  = 0.15 - (act_index - 1) * 0.03   # 0.15 / 0.12 / 0.09
	var encounter_chance: float = 0.20 + (act_index - 1) * 0.05  # 0.20 / 0.25 / 0.30

	# Story nodes: acts 2+ only, mid-map band, one slot per wide row
	if act_index >= 2 and row >= 4 and row <= 10:
		if col == int(row_width / 2.0) and randf() < 0.08:
			return MapNodeData.NodeType.STORY

	# Elite nodes appear mid-to-late map (center-ish positions)
	if row >= 5 and row < 12:
		if col == int(row_width / 2.0):
			if randf() < elite_chance:
				return MapNodeData.NodeType.ELITE

	# Shop nodes scattered throughout
	if row >= 2 and randf() < shop_chance:
		return MapNodeData.NodeType.SHOP

	# Encounter nodes
	if row >= 3 and randf() < encounter_chance:
		return MapNodeData.NodeType.ENCOUNTER

	# Default to fight
	return MapNodeData.NodeType.FIGHT

func _set_reward_flags(node: MapNodeData):
	## Set reward preview icons based on node type
	node.reward_flags.clear()
	
	match node.node_type:
		MapNodeData.NodeType.FIGHT:
			# Most fights give cards
			if randf() < 0.8:
				node.reward_flags.append(MapNodeData.RewardType.CARD)
			else:
				node.reward_flags.append(MapNodeData.RewardType.GOLD)
			# Sometimes upgrade
			if randf() < 0.3:
				node.reward_flags.append(MapNodeData.RewardType.UPGRADE)
		
		MapNodeData.NodeType.ELITE:
			node.reward_flags.clear()
			node.reward_flags.append(MapNodeData.RewardType.CARD)
			node.reward_flags.append(MapNodeData.RewardType.UPGRADE)
			node.reward_flags.append(MapNodeData.RewardType.RELIC)
		
		MapNodeData.NodeType.BOSS:
			node.reward_flags.clear()
			node.reward_flags.append(MapNodeData.RewardType.CARD)  # Boss gets 3 card choices
			node.reward_flags.append(MapNodeData.RewardType.GOLD)  # Boss gets gold
			node.reward_flags.append(MapNodeData.RewardType.UPGRADE)  # Transcendent upgrade
			node.reward_flags.append(MapNodeData.RewardType.BOSS_RELIC)

		MapNodeData.NodeType.FINAL_BOSS:
			node.reward_flags.clear()
			node.reward_flags.append(MapNodeData.RewardType.CARD)
			node.reward_flags.append(MapNodeData.RewardType.GOLD)
			node.reward_flags.append(MapNodeData.RewardType.UPGRADE)
			node.reward_flags.append(MapNodeData.RewardType.BOSS_RELIC)

		MapNodeData.NodeType.SHOP, MapNodeData.NodeType.ENCOUNTER, MapNodeData.NodeType.STORY:
			# No preview icons
			node.reward_flags.clear()

func _connect_rows(from_nodes: Array[MapNodeData], to_nodes: Array[MapNodeData]) -> void:
	## 100% guarantees:
	## - No crisscrossing (X)
	## - No hanging nodes (every to_node has >= 1 incoming)
	##
	## Randomized gap assignment:
	## For each gap between primary targets, randomly split the gap into
	## a lower segment (assigned to node i) and an upper segment (assigned to node i+1).

	if from_nodes.is_empty() or to_nodes.is_empty():
		return

	# Sort both rows top-to-bottom by lane (col)
	var sorted_from: Array[MapNodeData] = from_nodes.duplicate()
	sorted_from.sort_custom(func(a: MapNodeData, b: MapNodeData) -> bool: return a.col < b.col)

	var sorted_to: Array[MapNodeData] = to_nodes.duplicate()
	sorted_to.sort_custom(func(a: MapNodeData, b: MapNodeData) -> bool: return a.col < b.col)

	var from_count: int = sorted_from.size()
	var to_count: int = sorted_to.size()

	# Clear existing connections
	for i in range(from_count):
		sorted_from[i].connected_to.clear()

	# ---- PASS 1: compute monotonic primary targets ----
	var primary_targets: Array[int] = []
	primary_targets.resize(from_count)

	var last_primary: int = 0
	for i in range(from_count):
		var from_node: MapNodeData = sorted_from[i]

		var lane_ratio: float = 0.0
		if MAX_LANES > 1:
			lane_ratio = float(from_node.col) / float(MAX_LANES - 1)

		var target: int = int(round(lane_ratio * float(to_count - 1)))
		target = clamp(target, last_primary, to_count - 1)

		primary_targets[i] = target
		last_primary = target

	# Always include each node's primary edge
	for i in range(from_count):
		var pid: String = str(sorted_to[primary_targets[i]].id)
		sorted_from[i].connected_to.append(pid)

	# ---- PASS 2: guaranteed coverage with randomized gap splits ----
	# Coverage segments:
	#   BEFORE first primary: [0 .. p0-1] -> assigned to node 0
	#   BETWEEN primaries:    [p[i] .. p[i+1]] inclusive must be covered by i and i+1
	#   AFTER last primary:   [p_last+1 .. to_count-1] -> assigned to last node
	#
	# Important: We keep ordering by only giving node i low indices and node i+1 high indices.

	# Before first primary
	var p0: int = primary_targets[0]
	for t in range(0, p0):
		sorted_from[0].connected_to.append(str(sorted_to[t].id))

	# Between each adjacent pair of primaries
	for i in range(from_count - 1):
		var a: int = primary_targets[i]
		var b: int = primary_targets[i + 1]

		# If equal or adjacent, nothing meaningful to split
		if b <= a:
			continue

		# Gap is (a+1 .. b-1). Primaries themselves already included.
		var gap_start: int = a + 1
		var gap_end: int = b - 1
		if gap_end < gap_start:
			continue

		# Choose a random split point inside the gap.
		# Node i gets [gap_start .. split], node i+1 gets [split+1 .. gap_end]
		# This guarantees full coverage and preserves ordering.
		var split: int = gap_start
		if gap_start < gap_end:
			split = randi_range(gap_start, gap_end)

		# Assign lower half to node i
		for t in range(gap_start, split + 1):
			sorted_from[i].connected_to.append(str(sorted_to[t].id))

		# Assign upper half to node i+1
		for t in range(split + 1, gap_end + 1):
			sorted_from[i + 1].connected_to.append(str(sorted_to[t].id))

	# After last primary
	var plast: int = primary_targets[from_count - 1]
	for t in range(plast + 1, to_count):
		sorted_from[from_count - 1].connected_to.append(str(sorted_to[t].id))

	# ---- PASS 3: optional “spice” edges that still cannot cross ----
	# We only allow edges that stay within the node’s safe envelope:
	# node i may not target below (min targets of i) or above (min target of i+1) boundaries.
	# For safety + simplicity, we only add edges adjacent to its primary if they exist in its owned set.
	for i in range(from_count):
		var from_node: MapNodeData = sorted_from[i]
		var primary: int = primary_targets[i]

		var up_t: int = primary - 1      # visually up
		var down_t: int = primary + 1    # visually down

		# Build a quick set of owned target indices for this node (so spice stays inside ownership)
		var owned: Dictionary = {}
		for to_id in from_node.connected_to:
			owned[str(to_id)] = true

		if up_t >= 0:
			var up_id: String = str(sorted_to[up_t].id)
			if owned.has(up_id) and randf() < UP_CHANCE:
				# already owned means it exists; no-op, but leaving here for future expansion
				pass

		if down_t < to_count:
			var down_id: String = str(sorted_to[down_t].id)
			if owned.has(down_id) and randf() < DOWN_CHANCE:
				pass

	# ---- Final: dedupe + deterministic order per node ----
	for i in range(from_count):
		var from_node: MapNodeData = sorted_from[i]
		from_node.connected_to.sort()

		var unique_ids: Array[String] = []
		for cid in from_node.connected_to:
			if not unique_ids.has(cid):
				unique_ids.append(cid)
		from_node.connected_to = unique_ids

func _remove_highest_secondary(
	targets_by_i: Array,
	primary_targets: Array[int],
	i: int
) -> bool:
	var primary := primary_targets[i]
	var arr: Array[int] = targets_by_i[i]

	for idx in range(arr.size() - 1, -1, -1):
		if arr[idx] != primary:
			arr.remove_at(idx)
			targets_by_i[i] = arr
			return true

	return false

func _remove_lowest_secondary(
	targets_by_i: Array,
	primary_targets: Array[int],
	i: int
) -> bool:
	var primary := primary_targets[i]
	var arr: Array[int] = targets_by_i[i]

	for idx in range(arr.size()):
		if arr[idx] != primary:
			arr.remove_at(idx)
			targets_by_i[i] = arr
			return true

	return false


func _calculate_monotonic_primary(sorted_index: int, from_count: int, to_count: int, _prev_primary: int) -> int:
	## Calculate primary target index for a node at sorted_index
	## Returns index based on sorted position (monotonicity enforced in caller)
	if to_count == 1:
		return 0
	
	# Map sorted index to target index proportionally
	# Use sorted_index (not col) because row widths can change
	var primary_target = int((float(sorted_index) / float(from_count)) * to_count)
	primary_target = clamp(primary_target, 0, to_count - 1)
	
	return primary_target

func _generate_boss_node(row: int, act_index: int) -> MapNodeData:
	## Generate the boss node at the end.
	## Acts 1-2 get a regular BOSS; Act 3 gets a FINAL_BOSS.
	var boss_type = MapNodeData.NodeType.FINAL_BOSS if act_index >= 3 else MapNodeData.NodeType.BOSS
	var node = MapNodeData.new("boss_%d" % act_index, row, 0, boss_type)
	_set_reward_flags(node)
	return node
