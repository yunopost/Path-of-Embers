extends Node
## Headless check: act bosses are reachable without quests; only FINAL_BOSS is quest-gated.
func _ready():
	PartyManager.party_ids = ["warrior_1", "witch", "golemancer"]
	var fails := 0
	for act_idx in [1, 2, 3]:
		var map: MapData = MapGenerator.new().generate_map(act_idx)
		MapManager.current_node_id = ""
		MapManager.set_act(act_idx)
		MapManager.set_map_data(map)
		# Walk to a node in the row directly before the boss
		var pre_boss: MapNodeData = null
		for n in map.nodes.values():
			if map.boss_node_id in n.connected_to:
				pre_boss = n
				break
		MapManager.set_current_node(pre_boss.id)
		var boss: MapNodeData = map.get_node(map.boss_node_id)
		var open := map.boss_node_id in MapManager.available_next_node_ids
		var expect_open := boss.node_type != MapNodeData.NodeType.FINAL_BOSS
		print("act ", act_idx, " boss type=", MapNodeData.NodeType.keys()[boss.node_type], " available=", open, " expected=", expect_open)
		if open != expect_open:
			fails += 1
	print("BOSS_GATE ", "PASS" if fails == 0 else "FAIL")
	get_tree().quit(fails)
