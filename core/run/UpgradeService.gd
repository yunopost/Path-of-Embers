extends RefCounted
class_name UpgradeService

## Service for rolling and managing upgrade options

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
