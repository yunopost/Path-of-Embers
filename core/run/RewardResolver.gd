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
		# Boss pool (B): 3 card choices + gold + transcendence upgrade + 12 pts
		bundle.card_choices = _generate_card_choices(3, node.node_type)
		bundle.gold = 50
		bundle.upgrade_count = 1
		bundle.upgrade_points = 12
		bundle.is_transcendence_upgrade = true  # Special flag for transcendence upgrades
		return bundle

	if is_elite_node:
		# Elite pool (E): 3 card choices + upgrade + 6 pts
		bundle.card_choices = _generate_card_choices(3, node.node_type)
		bundle.upgrade_count = 1
		bundle.upgrade_points = 6
		if node.reward_flags.has(MapNodeData.RewardType.GOLD):
			bundle.gold = 25
		return bundle
	
	# Regular rewards based on individual flags
	# C = CARD: 3 card choices
	if node.reward_flags.has(MapNodeData.RewardType.CARD):
		bundle.card_choices = _generate_card_choices(3, node.node_type)
	
	# U = UPGRADE: 1 upgrade
	if node.reward_flags.has(MapNodeData.RewardType.UPGRADE):
		bundle.upgrade_count = 1
	
	# Upgrade points by node type (Phase 4) — always granted regardless of reward_flags
	match node.node_type:
		MapNodeData.NodeType.FIGHT:
			bundle.upgrade_points = 2
		MapNodeData.NodeType.ELITE:
			bundle.upgrade_points = 6   # also set above for elite pool path
		MapNodeData.NodeType.BOSS:
			bundle.upgrade_points = 12  # also set above for boss pool path
		MapNodeData.NodeType.FINAL_BOSS:
			bundle.upgrade_points = 12
		_:
			bundle.upgrade_points = 2

	# G = GOLD: gold amount
	if node.reward_flags.has(MapNodeData.RewardType.GOLD):
		# Gold amount varies by node type
		match node.node_type:
			MapNodeData.NodeType.FIGHT:
				bundle.gold = 10
			MapNodeData.NodeType.ELITE:
				bundle.gold = 25
			MapNodeData.NodeType.BOSS, MapNodeData.NodeType.FINAL_BOSS:
				bundle.gold = 50
			_:
				bundle.gold = 10
	
	return bundle

static func _build_default_rewards() -> RewardBundle:
	## Build default rewards if node is invalid
	var bundle = RewardBundle.new()
	bundle.gold = 10
	bundle.card_choices = _generate_card_choices(3, MapNodeData.NodeType.FIGHT)
	bundle.skip_allowed = true
	return bundle

static func _generate_card_choices(count: int, node_type: MapNodeData.NodeType) -> Array[String]:
	## Generate card choices from reward pool using pity system
	## Uses weighted random selection with dynamic Rare chance
	var pool = RunState.reward_card_pool
	if pool.is_empty():
		return []
	
	var choices: Array[String] = []
	var used_ids: Array[String] = []  # Only for this reward set (no duplicates in same reward)
	
	# Get dynamic Rare chance
	var rare_chance = RunState.get_rare_chance(node_type)
	
	for i in range(count):
		# Weighted random rarity selection with dynamic Rare chance
		var rand = randf()
		var target_rarity: CardData.Rarity
		
		if rand < rare_chance:
			# Rare selected - apply deck penalty when choosing which Rare
			target_rarity = CardData.Rarity.RARE
		else:
			# Remaining probability split: 70% Common, 30% Uncommon
			var remaining = 1.0 - rare_chance
			var common_portion = remaining * 0.70  # 70% of remaining
			
			if rand < (rare_chance + common_portion):
				target_rarity = CardData.Rarity.COMMON
			else:
				target_rarity = CardData.Rarity.UNCOMMON
		
		# Filter pool by rarity and exclude already chosen cards (only for this reward)
		var available = pool.filter(func(card): 
			return card.rarity == target_rarity and not used_ids.has(card.id)
		)
		
		# If no cards of target rarity available, fall back to any available
		if available.is_empty():
			available = pool.filter(func(card): return not used_ids.has(card.id))
		
		if available.is_empty():
			break  # No more cards available (shouldn't happen with 66 cards)
		
		# For Rare cards, apply deck penalty: -10% chance per card already in deck
		var selected: CardData = null
		if target_rarity == CardData.Rarity.RARE:
			var rare_cards_in_deck = RunState.get_rare_cards_in_deck()
			
			# Calculate weights: cards in deck have -10% weight
			var weights: Array[float] = []
			for card in available:
				var weight = 1.0  # Base weight
				if rare_cards_in_deck.has(card.id):
					weight = max(0.0, weight - 0.10)  # -10% penalty, minimum 0
				weights.append(weight)
			
			# Weighted random selection
			var total_weight = 0.0
			for weight in weights:
				total_weight += weight
			
			if total_weight > 0.0:
				var rand_weight = randf() * total_weight
				var current_weight = 0.0
				for j in range(available.size()):
					current_weight += weights[j]
					if rand_weight <= current_weight:
						selected = available[j]
						break
			
			# Fallback to uniform random if weighted selection failed
			if not selected:
				selected = available[randi() % available.size()]
		else:
			# For Common/Uncommon, uniform random selection
			selected = available[randi() % available.size()]
		
		choices.append(selected.id)
		used_ids.append(selected.id)  # Prevent duplicates in this reward only
	
	# Update pity counter after generating (but before returning)
	RunState.update_rare_pity_from_rewards(choices)
	
	return choices

