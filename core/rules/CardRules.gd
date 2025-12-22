extends RefCounted
class_name CardRules

## Centralized card rules and calculations
## All card rendering and gameplay must use this layer

# Color constants for modified values
const COLOR_MODIFIED_COST = Color(0.5, 0.8, 1.0, 1.0)  # Light blue
const COLOR_MODIFIED_ZERO_COST = Color(0.4, 1.0, 0.4, 1.0)  # Light green
const COLOR_MODIFIED_VALUE = Color(0.8, 0.9, 1.0, 1.0)  # Light blue
const COLOR_NORMAL = Color.WHITE

static func get_effective_cost(card_def: CardData, card_inst: DeckCardData) -> int:
	## Get effective cost after upgrades
	## Returns base cost minus cost reduction upgrades (min 0)
	## For DISCARD cost type, returns discard_cost_amount (upgrades not applied to discard cost)
	if not card_def or not card_inst:
		return 1  # Default fallback
	
	# For discard cost type, return discard amount (upgrades don't affect discard cost)
	if card_def.cost_type == CardData.CostType.DISCARD:
		return card_def.discard_cost_amount
	
	var base_cost = card_def.cost
	var effective_cost = base_cost
	
	# Apply cost reduction upgrades
	for upgrade_id in card_inst.applied_upgrades:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		if upgrade_def.has("effects") and upgrade_def["effects"].has("cost_delta"):
			var cost_delta = upgrade_def["effects"]["cost_delta"]
			if cost_delta is int:
				effective_cost += cost_delta
	
	return max(0, effective_cost)

static func get_effective_damage(card_def: CardData, card_inst: DeckCardData) -> int:
	## Get effective damage after upgrades
	## Sums all damage effects from base_effects and upgrades
	if not card_def or not card_inst:
		return 0
	
	var total_damage = 0
	
	# Sum base damage effects
	for effect in card_def.base_effects:
		if effect and effect.effect_type == "damage":
			var damage = effect.params.get("amount", 0)
			if damage is int:
				total_damage += damage
			elif damage is float:
				total_damage += int(damage)
	
	# Apply damage modifications from upgrades
	for upgrade_id in card_inst.applied_upgrades:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		if upgrade_def.has("effects") and upgrade_def["effects"].has("damage_delta"):
			var damage_delta = upgrade_def["effects"]["damage_delta"]
			if damage_delta is int:
				total_damage += damage_delta
			elif damage_delta is float:
				total_damage += int(damage_delta)
	
	return max(0, total_damage)

static func get_effective_block(card_def: CardData, card_inst: DeckCardData) -> int:
	## Get effective block after upgrades
	## Sums all block effects from base_effects and upgrades
	if not card_def or not card_inst:
		return 0
	
	var total_block = 0
	
	# Sum base block effects
	for effect in card_def.base_effects:
		if effect and effect.effect_type == "block":
			var block = effect.params.get("amount", 0)
			if block is int:
				total_block += block
			elif block is float:
				total_block += int(block)
	
	# Apply block modifications from upgrades
	for upgrade_id in card_inst.applied_upgrades:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		if upgrade_def.has("effects") and upgrade_def["effects"].has("block_delta"):
			var block_delta = upgrade_def["effects"]["block_delta"]
			if block_delta is int:
				total_block += block_delta
			elif block_delta is float:
				total_block += int(block_delta)
	
	return max(0, total_block)

static func get_effective_heal(card_def: CardData, card_inst: DeckCardData) -> int:
	## Get effective heal after upgrades
	## Sums all heal effects from base_effects and upgrades
	if not card_def or not card_inst:
		return 0
	
	var total_heal = 0
	
	# Sum base heal effects
	for effect in card_def.base_effects:
		if effect and effect.effect_type == "heal":
			var heal = effect.params.get("amount", 0)
			if heal is int:
				total_heal += heal
			elif heal is float:
				total_heal += int(heal)
	
	# Apply heal modifications from upgrades
	for upgrade_id in card_inst.applied_upgrades:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		if upgrade_def.has("effects") and upgrade_def["effects"].has("heal_delta"):
			var heal_delta = upgrade_def["effects"]["heal_delta"]
			if heal_delta is int:
				total_heal += heal_delta
			elif heal_delta is float:
				total_heal += int(heal_delta)
	
	return max(0, total_heal)

static func get_card_keywords(card_inst: DeckCardData) -> Array[String]:
	## Get all keywords for a card instance
	## Returns array of keyword strings to display on the card
	var keywords: Array[String] = []
	
	if not card_inst:
		return keywords
	
	# Get card data to check for direct keywords
	var card_data = DataRegistry.get_card_data(card_inst.card_id)
	if card_data and card_data.keywords.size() > 0:
		for keyword in card_data.keywords:
			if not keyword.is_empty() and not keywords.has(keyword):
				keywords.append(keyword)
	
	# Collect keywords from upgrades (and handle keyword removal)
	var removed_keywords: Array[String] = []
	for upgrade_id in card_inst.applied_upgrades:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		# Check for keyword removal
		if upgrade_def.has("effects") and upgrade_def["effects"].has("remove_keyword"):
			var keyword_to_remove = upgrade_def["effects"]["remove_keyword"]
			if keyword_to_remove is String:
				removed_keywords.append(keyword_to_remove)
		# Check for keyword addition
		if upgrade_def.has("keyword") and upgrade_def["keyword"] is String:
			var keyword = upgrade_def["keyword"]
			if not keyword.is_empty() and not keywords.has(keyword):
				keywords.append(keyword)
	
	# Remove keywords that are marked for removal
	for removed_keyword in removed_keywords:
		if keywords.has(removed_keyword):
			keywords.erase(removed_keyword)
	
	return keywords

static func get_keyword_tooltip(keyword: String) -> String:
	## Get tooltip text for a keyword
	## Searches through upgrade definitions to find matching keyword
	if keyword.is_empty():
		return ""
	
	# Search through all upgrade definitions for matching keyword
	var upgrade_defs = DataRegistry.get_all_upgrade_definitions()
	for upgrade_id in upgrade_defs:
		var upgrade_def = upgrade_defs[upgrade_id]
		if upgrade_def.has("keyword") and upgrade_def["keyword"] == keyword:
			if upgrade_def.has("description") and upgrade_def["description"] is String:
				return upgrade_def["description"]
	
	# Fallback: return keyword as tooltip
	return keyword

static func is_cost_modified(card_def: CardData, card_inst: DeckCardData) -> bool:
	## Check if card cost has been modified by upgrades
	if not card_def or not card_inst:
		return false
	
	var base_cost = card_def.cost
	var effective_cost = get_effective_cost(card_def, card_inst)
	return effective_cost != base_cost

static func is_damage_modified(card_def: CardData, card_inst: DeckCardData) -> bool:
	## Check if card damage has been modified by upgrades
	if not card_def or not card_inst:
		return false
	
	# Get base damage
	var base_damage = 0
	for effect in card_def.base_effects:
		if effect and effect.effect_type == "damage":
			var damage = effect.params.get("amount", 0)
			if damage is int:
				base_damage += damage
			elif damage is float:
				base_damage += int(damage)
	
	var effective_damage = get_effective_damage(card_def, card_inst)
	return effective_damage != base_damage

static func is_block_modified(card_def: CardData, card_inst: DeckCardData) -> bool:
	## Check if card block has been modified by upgrades
	if not card_def or not card_inst:
		return false
	
	# Get base block
	var base_block = 0
	for effect in card_def.base_effects:
		if effect and effect.effect_type == "block":
			var block = effect.params.get("amount", 0)
			if block is int:
				base_block += block
			elif block is float:
				base_block += int(block)
	
	var effective_block = get_effective_block(card_def, card_inst)
	return effective_block != base_block

static func is_heal_modified(card_def: CardData, card_inst: DeckCardData) -> bool:
	## Check if card heal has been modified by upgrades
	if not card_def or not card_inst:
		return false
	
	# Get base heal
	var base_heal = 0
	for effect in card_def.base_effects:
		if effect and effect.effect_type == "heal":
			var heal = effect.params.get("amount", 0)
			if heal is int:
				base_heal += heal
			elif heal is float:
				base_heal += int(heal)
	
	var effective_heal = get_effective_heal(card_def, card_inst)
	return effective_heal != base_heal

