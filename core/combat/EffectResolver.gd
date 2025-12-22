extends RefCounted
class_name EffectResolver

## Resolves EffectData into actual game actions
## Generic effect system - not hardcoded per card

static func resolve_effect(effect: EffectData, source: EntityStats, target: EntityStats = null, enemy_context: Enemy = null):
	## Resolve a single effect
	## enemy_context: Optional Enemy reference for conditional effects
	if not effect:
		return
	
	match effect.effect_type:
		"damage":  # Standardized effect type name
			var damage = effect.params.get("amount", 0)
			var hit_count = effect.params.get("hit_count", 1)  # Multi-hit support
			var ignore_block = effect.params.get("ignore_block", false)  # Ignore block flag
			if target:
				# Apply damage multiple times (vulnerable applies per hit)
				for i in range(hit_count):
					target.take_damage(damage, ignore_block)
		
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
		
		"damage_conditional_elite":  # Conditional damage: more for Elite/Boss
			var normal_damage = effect.params.get("normal_amount", 18)
			var elite_damage = effect.params.get("elite_amount", 36)
			var hit_count = effect.params.get("hit_count", 1)
			var ignore_block = effect.params.get("ignore_block", false)
			if target:
				var final_damage = normal_damage
				if enemy_context:
					# Get enemy type from EnemyData
					var enemy_data = enemy_context.enemy_data
					if not enemy_data:
						enemy_data = DataRegistry.get_enemy(enemy_context.enemy_id)
					
					if enemy_data and (enemy_data.enemy_type == EnemyData.EnemyType.ELITE or enemy_data.enemy_type == EnemyData.EnemyType.BOSS):
						final_damage = elite_damage
				
				# Apply damage multiple times
				for i in range(hit_count):
					target.take_damage(final_damage, ignore_block)
		
		_:
			push_warning("Unknown effect type: " + effect.effect_type)

static func resolve_effects(effects: Array, source: EntityStats, target: EntityStats = null, enemy_context: Enemy = null) -> int:
	## Resolve multiple effects, returns number of cards to draw (if any)
	## enemy_context: Optional Enemy reference for conditional effects
	var draw_cards = 0
	for effect in effects:
		if effect is EffectData:
			if effect.effect_type == "draw":  # Standardized effect type name
				var result = resolve_effect(effect, source, target, enemy_context)
				if result is int:
					draw_cards += result
			else:
				resolve_effect(effect, source, target, enemy_context)
	return draw_cards
