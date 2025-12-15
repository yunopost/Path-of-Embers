extends RefCounted
class_name RewardResolver

## Resolves reward bundles based on node reward flags

static func build_rewards_for_node(node: MapNodeData) -> RewardBundle:
	## Build a RewardBundle based on the node's reward_flags
	## Reads reward_flags from the node to determine what rewards to give
	## Key: C=CARD, U=UPGRADE, G=GOLD, R=RELIC, B=BOSS_RELIC (Boss pool), E=ELITE node type (Elite pool)
	if not node:
		return _build_default_rewards()
	
	var bundle = RewardBundle.new()
	bundle.skip_allowed = true
	
	# Check for special pools first (Boss, Elite)
	var has_boss_relic = node.reward_flags.has(MapNodeData.RewardType.BOSS_RELIC)
	var is_elite_node = node.node_type == MapNodeData.NodeType.ELITE
	
	if has_boss_relic:
		# Boss pool (B): boss relic + 3 card choices + gold + transcendence upgrade
		bundle.relic_id = "relic_boss_01"  # Placeholder
		bundle.card_choices = _generate_card_choices(3)
		bundle.gold = 50
		bundle.upgrade_count = 1
		bundle.is_transcendence_upgrade = true  # Special flag for transcendence upgrades
		return bundle
	
	if is_elite_node:
		# Elite pool (E): guaranteed relic + 3 card choices + upgrade
		# Elite nodes always have these rewards regardless of flags
		bundle.relic_id = "relic_elite_01"  # Placeholder
		bundle.card_choices = _generate_card_choices(3)
		bundle.upgrade_count = 1
		# Elite nodes may also have gold flag
		if node.reward_flags.has(MapNodeData.RewardType.GOLD):
			bundle.gold = 25
		return bundle
	
	# Regular rewards based on individual flags
	# C = CARD: 3 card choices
	if node.reward_flags.has(MapNodeData.RewardType.CARD):
		bundle.card_choices = _generate_card_choices(3)
	
	# U = UPGRADE: 1 upgrade
	if node.reward_flags.has(MapNodeData.RewardType.UPGRADE):
		bundle.upgrade_count = 1
	
	# G = GOLD: gold amount
	if node.reward_flags.has(MapNodeData.RewardType.GOLD):
		# Gold amount varies by node type
		match node.node_type:
			MapNodeData.NodeType.FIGHT:
				bundle.gold = 10
			MapNodeData.NodeType.ELITE:
				bundle.gold = 25
			MapNodeData.NodeType.BOSS:
				bundle.gold = 50
			_:
				bundle.gold = 10
	
	# R = RELIC: regular relic
	if node.reward_flags.has(MapNodeData.RewardType.RELIC):
		bundle.relic_id = "relic_01"  # Placeholder
	
	return bundle

static func _build_default_rewards() -> RewardBundle:
	## Build default rewards if node is invalid
	var bundle = RewardBundle.new()
	bundle.gold = 10
	bundle.card_choices = _generate_card_choices(3)
	bundle.skip_allowed = true
	return bundle

static func _generate_card_choices(count: int) -> Array[String]:
	## Generate card choices (placeholder - uses hardcoded card IDs)
	## Later can pull from RunState.reward_card_pool
	var placeholder_cards = [
		"strike_1",
		"defend_1",
		"bash_1",
		"heal_1",
		"hasten_1"
	]
	
	var choices: Array[String] = []
	var available = placeholder_cards.duplicate()
	
	# Pick random cards (no duplicates)
	for i in range(min(count, available.size())):
		if available.is_empty():
			break
		var idx = randi() % available.size()
		choices.append(available[idx])
		available.remove_at(idx)
	
	return choices

