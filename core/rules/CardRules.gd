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

	# One Night Sooner (Card-Clock Combat spec §7): next card played costs N less.
	# Read-only here (not consumed) -- RunState.get_timer_tick_amount_for_card clears
	# it exactly once, when the card is actually played.
	if RunState:
		effective_cost -= RunState.next_card_discount
	
	return max(0, effective_cost)

static func get_effective_damage(card_def: CardData, card_inst: DeckCardData) -> int:
	## Get effective damage after upgrades
	## Sums all damage effects from base_effects and upgrades
	if not card_def or not card_inst:
		return 0
	
	var total_damage = 0
	
	# Sum base damage effects
	for effect in card_def.base_effects:
		if effect and effect.effect_type == EffectType.DAMAGE:
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
		if effect and effect.effect_type == EffectType.BLOCK:
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
		if effect and effect.effect_type == EffectType.HEAL:
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

static func get_card_effects_for_display(card_data: CardData, card_inst: DeckCardData) -> Array:
	## Get effects for a card from CardData, with upgrade modifications applied (for display purposes)
	## Returns array of EffectData objects
	var effects: Array = []
	
	if not card_data or not card_inst:
		return effects
	
	# Start with base effects from CardData
	for base_effect in card_data.base_effects:
		if base_effect is EffectData:
			# Create a copy of the effect to avoid modifying the original
			var effect_copy = EffectData.new(base_effect.effect_type, base_effect.params.duplicate())
			effects.append(effect_copy)
	
	# Apply upgrade modifications to effects (similar to CombatController._get_card_effects)
	for upgrade_id in card_inst.applied_upgrades:
		var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
		if not upgrade_def.has("effects"):
			continue
		
		var upgrade_effects = upgrade_def["effects"]
		
		# Apply damage modifications
		if upgrade_effects.has("damage_delta"):
			var damage_delta = upgrade_effects["damage_delta"]
			for effect in effects:
				if effect is EffectData and effect.effect_type == EffectType.DAMAGE:
					var current_amount = effect.params.get("amount", 0)
					effect.params["amount"] = current_amount + damage_delta
		
		# Apply damage multiplier (for half damage double hit)
		if upgrade_effects.has("damage_multiply"):
			var multiplier = upgrade_effects["damage_multiply"]
			if multiplier is float or multiplier is int:
				for effect in effects:
					if effect is EffectData and effect.effect_type == EffectType.DAMAGE:
						var current_amount = effect.params.get("amount", 0)
						effect.params["amount"] = int(current_amount * float(multiplier))
		
		# Set hit_count (for double hit)
		if upgrade_effects.has("hit_count_set"):
			var hit_count = upgrade_effects["hit_count_set"]
			if hit_count is int:
				for effect in effects:
					if effect is EffectData and effect.effect_type == EffectType.DAMAGE:
						effect.params["hit_count"] = hit_count
		
		# Apply ignore_block flag
		if upgrade_effects.has("ignore_block") and upgrade_effects["ignore_block"] == true:
			for effect in effects:
				if effect is EffectData and effect.effect_type == EffectType.DAMAGE:
					effect.params["ignore_block"] = true
		
		# Apply block modifications
		if upgrade_effects.has("block_delta"):
			var block_delta = upgrade_effects["block_delta"]
			for effect in effects:
				if effect is EffectData and effect.effect_type == EffectType.BLOCK:
					var current_amount = effect.params.get("amount", 0)
					effect.params["amount"] = current_amount + block_delta
		
		# Add block effect (for upgrades that add block)
		if upgrade_effects.has("add_block"):
			var block_amount = upgrade_effects["add_block"]
			if block_amount is int:
				var block_effect = EffectData.new(EffectType.BLOCK, {"amount": block_amount})
				effects.append(block_effect)
		
		# Apply heal modifications
		if upgrade_effects.has("heal_delta"):
			var heal_delta = upgrade_effects["heal_delta"]
			for effect in effects:
				if effect is EffectData and effect.effect_type == EffectType.HEAL:
					var current_amount = effect.params.get("amount", 0)
					effect.params["amount"] = current_amount + heal_delta
	
	return effects

static func get_resolved_effects(card_inst: DeckCardData) -> Array:
	## Canonical runtime method: returns a copy of a card's effects with all
	## upgrade modifications applied.  Used by CombatController at play time
	## and by get_card_effects_for_display (which wraps this).
	if not card_inst:
		return []
	var card_data: CardData = DataRegistry.get_card_data(card_inst.card_id) if DataRegistry else null
	if not card_data:
		return []
	return get_card_effects_for_display(card_data, card_inst)

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
		if effect and effect.effect_type == EffectType.DAMAGE:
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
		if effect and effect.effect_type == EffectType.BLOCK:
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
		if effect and effect.effect_type == EffectType.HEAL:
			var heal = effect.params.get("amount", 0)
			if heal is int:
				base_heal += heal
			elif heal is float:
				base_heal += int(heal)

	var effective_heal = get_effective_heal(card_def, card_inst)
	return effective_heal != base_heal

# ─────────────────────────────────────────────────────────────────────────────
# Live preview -- non-mutating "what would this card actually do right now"
# ─────────────────────────────────────────────────────────────────────────────
## Mirrors EffectResolver.resolve_effect's math exactly (owner base STR/DEF/
## SPIRIT + equipment via combat_controller.character_stats, shared in-combat
## Strength/Dexterity/Faith/Weakness/Agility via combat_controller.player_stats,
## Vulnerable on the target, pile sizes, Curses in hand) without touching any
## game state -- no draw, no curse added to hand, no Block spent, no
## haste_next_card/next_card_discount consumed. CardWidget renders from this
## single source instead of duplicating the formulas; keep this in sync with
## EffectResolver.resolve_effect if either changes.

static func _owner_stats_for(card_inst: DeckCardData, combat_controller: Node) -> EntityStats:
	if not card_inst or not combat_controller:
		return null
	var character_stats = combat_controller.get("character_stats")
	if character_stats is Dictionary:
		var s = character_stats.get(card_inst.owner_character_id, null)
		return s if s is EntityStats else null
	return null

static func _source_stats(combat_controller: Node) -> EntityStats:
	if not combat_controller:
		return null
	var s = combat_controller.get("player_stats")
	return s if s is EntityStats else null

static func _live_strength(owner_stats: EntityStats, source: EntityStats) -> int:
	var total := 0
	if owner_stats:
		var v = owner_stats.get_status(StatusEffectType.STRENGTH)
		if v != null:
			total += int(v)
	if source:
		var v = source.get_status(StatusEffectType.STRENGTH)
		if v != null:
			total += int(v)
	return total

static func _live_dexterity(owner_stats: EntityStats, source: EntityStats) -> int:
	var total := 0
	if owner_stats:
		var v = owner_stats.get_status(StatusEffectType.DEXTERITY)
		if v != null:
			total += int(v)
	if source:
		var v = source.get_status(StatusEffectType.DEXTERITY)
		if v != null:
			total += int(v)
	return total

static func _live_faith(owner_stats: EntityStats, source: EntityStats) -> int:
	var total := 0
	if owner_stats:
		var v = owner_stats.get_status(StatusEffectType.FAITH)
		if v != null:
			total += int(v)
	if source:
		var v = source.get_status(StatusEffectType.FAITH)
		if v != null:
			total += int(v)
	return total

static func _source_is_weak(source: EntityStats) -> bool:
	if not source:
		return false
	var v = source.get_status(StatusEffectType.WEAKNESS)
	return v != null and int(v) > 0

static func _source_is_agile(source: EntityStats) -> bool:
	if not source:
		return false
	var v = source.get_status(StatusEffectType.AGILITY)
	return v != null and int(v) > 0

static func _target_is_vulnerable(target: EntityStats) -> bool:
	if not target:
		return false
	var v = target.get_status(StatusEffectType.VULNERABLE)
	return v != null and int(v) > 0

static func _apply_weakness(raw: int, weak: bool) -> int:
	return int(ceil(float(raw) * 0.75)) if weak else raw

static func _apply_vulnerable(dmg: int, vulnerable: bool) -> int:
	# Matches EntityStats.take_damage's truncation exactly (not rounded).
	return int(dmg * 1.5) if vulnerable else dmg

static func _apply_agility(block: int, agile: bool) -> int:
	return int(ceil(float(block) * 1.25)) if agile else block

static func _live_pile_size(pile_name: String) -> int:
	if not RunState or not RunState.deck_model:
		return 0
	match pile_name:
		"draw":
			return RunState.deck_model.draw_pile.size()
		"discard":
			return RunState.deck_model.discard_pile.size()
		"hand":
			return RunState.deck_model.hand.size()
		_:
			return 0

static func _live_curse_count(include_discard: bool = false) -> int:
	var count := 0
	if RunState and RunState.deck_model:
		var piles: Array = [RunState.deck_model.hand]
		if include_discard:
			piles.append(RunState.deck_model.discard_pile)
		for pile in piles:
			for instance_id in pile:
				var card = RunState.deck.get(instance_id)
				if card:
					var cd = DataRegistry.get_card_data(card.card_id)
					if cd and cd.card_type == CardData.CardType.CURSE:
						count += 1
	return count

static func get_live_preview(card_def: CardData, card_inst: DeckCardData, combat_controller: Node, target: EntityStats = null) -> Dictionary:
	## Returns {damage, damage_modified, block, block_modified, heal,
	## heal_modified, energy, energy_modified} -- the real numbers this card
	## would produce right now for its owner, given current stats, equipment,
	## statuses, piles and target. Non-mutating. Falls back to the static
	## (upgrade-only) values when combat_controller is null (deck view /
	## reward screen -- no live combat state to preview against).
	var result := {
		"damage": 0, "damage_modified": false,
		"block": 0, "block_modified": false,
		"heal": 0, "heal_modified": false,
		"energy": 0, "energy_modified": false,
	}
	if not card_def or not card_inst:
		return result

	if not combat_controller:
		result.damage = get_effective_damage(card_def, card_inst)
		result.block = get_effective_block(card_def, card_inst)
		result.heal = get_effective_heal(card_def, card_inst)
		return result

	var owner_stats := _owner_stats_for(card_inst, combat_controller)
	var source := _source_stats(combat_controller)
	var weak := _source_is_weak(source)
	var agile := _source_is_agile(source)
	var vulnerable := _target_is_vulnerable(target)

	var damage_total := 0
	var block_total := 0
	var heal_total := 0
	var energy_total := 0

	for effect in get_resolved_effects(card_inst):
		if not effect is EffectData:
			continue
		match effect.effect_type:
			EffectType.DAMAGE:
				var base = int(effect.params.get("amount", 0))
				var double_strength = bool(effect.params.get("double_strength", false))
				var str_bonus = _live_strength(owner_stats, source)
				if double_strength:
					str_bonus *= 2
				var raw = _apply_weakness(base + str_bonus, weak)
				damage_total += _apply_vulnerable(raw, vulnerable)

			EffectType.DAMAGE_EQUAL_TO_BLOCK:
				var divisor = maxi(1, int(effect.params.get("divisor", 1)))
				var block_value = int(ceil(float(source.block) / float(divisor))) if source else 0
				if block_value > 0:
					var raw = _apply_weakness(block_value + _live_strength(owner_stats, source), weak)
					damage_total += _apply_vulnerable(raw, vulnerable)

			EffectType.DAMAGE_EQUAL_TO_PILE_SIZE:
				var pile_size = _live_pile_size(str(effect.params.get("pile", "draw")))
				var raw = _apply_weakness(pile_size + _live_strength(owner_stats, source), weak)
				damage_total += _apply_vulnerable(raw, vulnerable)

			EffectType.DAMAGE_PER_CURSE_IN_HAND:
				var base_dpch = int(effect.params.get("base_amount", 0))
				var per_curse = int(effect.params.get("per_curse", 0))
				var total = base_dpch + per_curse * _live_curse_count(false)
				var raw = _apply_weakness(total + _live_strength(owner_stats, source), weak)
				damage_total += _apply_vulnerable(raw, vulnerable)

			EffectType.DAMAGE_PER_CURSE:
				var base_dpc = int(effect.params.get("base_amount", 0))
				var per_curse2 = int(effect.params.get("per_curse", 0))
				var total2 = base_dpc + per_curse2 * _live_curse_count(true)
				var raw2 = _apply_weakness(total2 + _live_strength(owner_stats, source), weak)
				damage_total += _apply_vulnerable(raw2, vulnerable)

			EffectType.BLOCK:
				var base_b = int(effect.params.get("amount", 0))
				var raw_b = base_b + _live_dexterity(owner_stats, source)
				block_total += _apply_agility(raw_b, agile)

			EffectType.BLOCK_EQUAL_TO_PILE_SIZE:
				var pile_size_b = _live_pile_size(str(effect.params.get("pile", "discard")))
				var raw_b2 = pile_size_b + _live_dexterity(owner_stats, source)
				block_total += _apply_agility(raw_b2, agile)

			EffectType.HEAL:
				var base_h = int(effect.params.get("amount", 0))
				heal_total += base_h + _live_faith(owner_stats, source)

			EffectType.GAIN_ENERGY:
				energy_total += int(effect.params.get("amount", 1))

			EffectType.ENERGY_PER_DISCARD_PILE:
				var per = int(effect.params.get("per", 4))
				var cap = int(effect.params.get("max", 3))
				if per > 0:
					var discard_size = _live_pile_size("discard")
					energy_total += mini(int(discard_size / per), cap)

	result.damage = maxi(0, damage_total)
	result.block = maxi(0, block_total)
	result.heal = maxi(0, heal_total)
	result.energy = maxi(0, energy_total)
	result.damage_modified = result.damage != get_effective_damage(card_def, card_inst)
	result.block_modified = result.block != get_effective_block(card_def, card_inst)
	result.heal_modified = result.heal != get_effective_heal(card_def, card_inst)
	result.energy_modified = result.energy > 0
	return result
