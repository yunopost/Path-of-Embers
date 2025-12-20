extends RefCounted
class_name EffectResolver

## Resolves EffectData into actual game actions
## Generic effect system - not hardcoded per card

static func resolve_effect(effect: EffectData, source: EntityStats, target: EntityStats = null):
	## Resolve a single effect
	if not effect:
		return
	
	match effect.effect_type:
		"damage":  # Standardized effect type name
			var damage = effect.params.get("amount", 0)
			var hit_count = effect.params.get("hit_count", 1)  # Multi-hit support
			if target:
				# Apply damage multiple times (vulnerable applies per hit)
				for i in range(hit_count):
					target.take_damage(damage)
		
		"block":  # Standardized effect type name
			var block = effect.params.get("amount", 0)
			if source:
				source.add_block(block)
		
		"heal":  # Standardized effect type name
			var heal_amount = effect.params.get("amount", 0)
			if source:
				source.heal(heal_amount)
		
		"ApplyStatus":
			var status_type = effect.params.get("status_type", "")
			var status_value = effect.params.get("value", 0)
			if target:
				target.apply_status(status_type, status_value)
		
		"ModifyEnemyTimer":
			# Placeholder for future implementation
			pass
		
		"draw":  # Standardized effect type name (was "DrawCards")
			# Draw cards handled separately in CombatController
			var draw_count = effect.params.get("amount", 1)
			# Signal will be handled by CombatController
			return draw_count
		
		"grant_haste_next_card":  # Next card played doesn't advance enemy timer
			# Set status in RunState
			if RunState:
				RunState.haste_next_card = true
		
		"vulnerable":  # Apply vulnerable status (duration-based)
			var duration = effect.params.get("duration", 1)
			if target:
				target.apply_status("vulnerable", duration)
		
		_:
			push_warning("Unknown effect type: " + effect.effect_type)

static func resolve_effects(effects: Array, source: EntityStats, target: EntityStats = null) -> int:
	## Resolve multiple effects, returns number of cards to draw (if any)
	var draw_cards = 0
	for effect in effects:
		if effect is EffectData:
			if effect.effect_type == "draw":  # Standardized effect type name
				var result = resolve_effect(effect, source, target)
				if result is int:
					draw_cards += result
			else:
				resolve_effect(effect, source, target)
	return draw_cards

