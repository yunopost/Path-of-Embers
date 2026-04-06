extends RefCounted
class_name UpgradeService

## Service for rolling and managing upgrade options and upgrade point costs (Phase 4)

# Rarity base costs for upgrade point economy (Phase 4)
# cost = rarity_base * (upgrades_already_applied + 1)
const RARITY_BASE_COST: Dictionary = {
	CardData.Rarity.COMMON:   1,
	CardData.Rarity.UNCOMMON: 2,
	CardData.Rarity.RARE:     3,
}

static func compute_upgrade_cost(card_instance: DeckCardData) -> int:
	## Returns the upgrade point cost for the next upgrade on this card.
	## Formula: rarity_base_cost * (upgrades_applied + 1)
	if not card_instance:
		return 0
	var card_data: CardData = DataRegistry.get_card_data(card_instance.card_id) if DataRegistry else null
	if not card_data:
		return 1  # Safe fallback
	var rarity_base: int = RARITY_BASE_COST.get(card_data.rarity, 1)
	return rarity_base * (card_instance.applied_upgrades.size() + 1)

static func can_afford_upgrade(card_instance: DeckCardData) -> bool:
	## Returns true if ResourceManager has enough upgrade_points for the next upgrade.
	var cost = compute_upgrade_cost(card_instance)
	return ResourceManager.upgrade_points >= cost if ResourceManager else false

static func roll_upgrade_options_for_card(card_instance: DeckCardData, count: int = 3) -> Array[String]:
	## Roll upgrade options for a card instance
	## Returns Array[String] of upgrade_id options
	if not card_instance:
		return []
	
	var pool = DataRegistry.get_upgrade_pool_for_card(card_instance.card_id)
	if pool.is_empty():
		return []
	
	# Filter out already applied upgrades
	var available = []
	for upgrade_id in pool:
		if not card_instance.applied_upgrades.has(upgrade_id):
			available.append(upgrade_id)
	
	if available.is_empty():
		return []
	
	# If we have fewer than count, return all available
	if available.size() <= count:
		available.shuffle()
		return available
	
	# Randomly select count options (no duplicates)
	var selected: Array[String] = []
	var remaining = available.duplicate()
	remaining.shuffle()
	
	for i in range(min(count, remaining.size())):
		selected.append(remaining[i])
	
	return selected
