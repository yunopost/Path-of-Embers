extends RefCounted
class_name EffectResolver

## Resolves EffectData into actual game actions
## Generic effect system - not hardcoded per card

static func resolve_effect(effect: EffectData, source: EntityStats, target: EntityStats = null, enemy_context: Enemy = null, combat_controller: Node = null):
	## Resolve a single effect
	## enemy_context: Optional Enemy reference for conditional effects
	## combat_controller: Optional CombatController reference for complex effects
	if not effect:
		return
	
	match effect.effect_type:
		EffectType.DAMAGE:
			var base_damage = effect.params.get("amount", 0)
			var hit_count = effect.params.get("hit_count", 1)  # Multi-hit support
			var ignore_block = effect.params.get("ignore_block", false)  # Ignore block flag
			var double_strength = effect.params.get("double_strength", false)  # Dark Knife special: double Strength bonus
			
			# Apply Strength bonus
			var strength_amount = 0
			if source:
				var strength_value = source.get_status(StatusEffectType.STRENGTH)
				if strength_value != null:
					strength_amount = int(strength_value)
					if double_strength:
						strength_amount *= 2  # Dark Knife doubles Strength bonus
			
			# Apply Weakness reduction (25% reduction = multiply by 0.75)
			var weakness_active = false
			if source:
				var weakness_value = source.get_status(StatusEffectType.WEAKNESS)
				if weakness_value != null and int(weakness_value) > 0:
					weakness_active = true
			
			# Calculate final damage: (base + strength) * (0.75 if weakness, else 1.0)
			var damage_before_weakness = base_damage + strength_amount
			var final_damage = damage_before_weakness
			if weakness_active:
				final_damage = int(ceil(float(damage_before_weakness) * 0.75))
			
			if target:
				# Apply damage multiple times (vulnerable applies per hit in take_damage)
				for i in range(hit_count):
					target.take_damage(final_damage, ignore_block)
		
		EffectType.BLOCK:
			var base_block = effect.params.get("amount", 0)
			
			# Apply Dexterity bonus
			var dexterity_amount = 0
			if source:
				var dexterity_value = source.get_status(StatusEffectType.DEXTERITY)
				if dexterity_value != null:
					dexterity_amount = int(dexterity_value)
			
			var final_block = base_block + dexterity_amount
			if source:
				source.add_block(final_block)
		
		EffectType.HEAL:
			var base_heal = effect.params.get("amount", 0)
			
			# Apply Faith bonus
			var faith_amount = 0
			if source:
				var faith_value = source.get_status(StatusEffectType.FAITH)
				if faith_value != null:
					faith_amount = int(faith_value)
			
			var final_heal = base_heal + faith_amount
			if source:
				source.heal(final_heal)
		
		EffectType.APPLY_STATUS:
			var status_type = effect.params.get("status_type", "")
			var status_value = effect.params.get("value", 0)
			if target:
				target.apply_status(status_type, status_value)
		
		EffectType.MODIFY_ENEMY_TIMER:
			# Placeholder for future implementation
			pass
		
		EffectType.DRAW:
			# Draw cards handled separately in CombatController
			var draw_count = effect.params.get("amount", 1)
			# Signal will be handled by CombatController
			return draw_count
		
		EffectType.GRANT_HASTE_NEXT_CARD:
			# Set status in RunState
			if RunState:
				RunState.haste_next_card = true
		
		EffectType.VULNERABLE:
			var duration = effect.params.get("duration", 1)
			if target:
				target.apply_status(StatusEffectType.VULNERABLE, duration)
		
		EffectType.VULNERABLE_ALL_ENEMIES:
			var duration = effect.params.get("duration", 1)
			if combat_controller and combat_controller.has_method("get_enemies"):
				var all_enemies = combat_controller.get_enemies()
				for enemy in all_enemies:
					if enemy.stats.is_alive():
						enemy.stats.apply_status(StatusEffectType.VULNERABLE, duration)
		
		EffectType.STRENGTH:
			var amount = effect.params.get("amount", 1)
			if source:
				source.apply_status(StatusEffectType.STRENGTH, amount)
		
		EffectType.DEXTERITY:
			var amount = effect.params.get("amount", 1)
			if source:
				source.apply_status(StatusEffectType.DEXTERITY, amount)
		
		EffectType.FAITH:
			var amount = effect.params.get("amount", 1)
			if source:
				source.apply_status(StatusEffectType.FAITH, amount)
		
		EffectType.WEAKNESS:
			var duration = effect.params.get("duration", 1)
			if target:
				target.apply_status(StatusEffectType.WEAKNESS, duration)
		
		EffectType.DAMAGE_PER_CURSE:
			var base_amount = effect.params.get("base_amount", 0)
			var per_curse = effect.params.get("per_curse", 0)
			
			# Count curses in hand and discard pile
			var curse_count = 0
			if RunState and RunState.deck_model:
				# Count in hand
				for instance_id in RunState.deck_model.hand:
					var card = RunState.deck.get(instance_id)
					if card:
						var card_data = DataRegistry.get_card_data(card.card_id)
						if card_data and card_data.card_type == CardData.CardType.CURSE:
							curse_count += 1
				# Count in discard pile
				for instance_id in RunState.deck_model.discard_pile:
					var card = RunState.deck.get(instance_id)
					if card:
						var card_data = DataRegistry.get_card_data(card.card_id)
						if card_data and card_data.card_type == CardData.CardType.CURSE:
							curse_count += 1
			
			var total_damage = base_amount + (per_curse * curse_count)
			
			# For ALL_ENEMIES targeting, this will be handled per enemy in resolve_effects
			# For single target, apply damage directly
			if target:
				# Apply Strength and Weakness modifiers
				var strength_amount = 0
				if source:
					var strength_value = source.get_status(StatusEffectType.STRENGTH)
					if strength_value != null:
						strength_amount = int(strength_value)
				
				var weakness_active = false
				if source:
					var weakness_value = source.get_status(StatusEffectType.WEAKNESS)
					if weakness_value != null and int(weakness_value) > 0:
						weakness_active = true
				
				var damage_before_weakness = total_damage + strength_amount
				var final_damage = damage_before_weakness
				if weakness_active:
					final_damage = int(ceil(float(damage_before_weakness) * 0.75))
				
				target.take_damage(final_damage, false)
		
		EffectType.ADD_CURSE_TO_HAND:
			var is_temporary = effect.params.get("is_temporary", false)
			if combat_controller and combat_controller.has_method("_add_curse_to_hand"):
				combat_controller._add_curse_to_hand(is_temporary)
		
		EffectType.CONDITIONAL_STRENGTH_IF_NO_DAMAGE:
			var amount = effect.params.get("amount", 1)
			# Set a pending status that will be checked at end of turn
			if source:
				source.apply_status(StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE, amount)
		
		EffectType.ADD_TEMPORARY_UPGRADE_TO_RANDOM_HAND_CARD:
			push_warning("EffectResolver: add_temporary_upgrade_to_random_hand_card not yet implemented (placeholder)")
			# TODO: Implement temporary upgrade system
		
		EffectType.RETAIN_BLOCK_THIS_TURN:
			var status_value = effect.params.get("value", true)
			if source:
				source.apply_status("retain_block_this_turn", status_value)
		
		EffectType.BLOCK_ON_ENEMY_ACT:
			# This is handled in CombatController._setup_power_card_effects()
			pass
		
		EffectType.DAMAGE_ON_BLOCK_GAIN:
			# This is handled in CombatController._setup_power_card_effects()
			pass
		
		EffectType.DAMAGE_CONDITIONAL_ELITE:
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

static func resolve_effects(effects: Array, source: EntityStats, target: EntityStats = null, enemy_context: Enemy = null, combat_controller: Node = null) -> int:
	## Resolve multiple effects, returns number of cards to draw (if any)
	## enemy_context: Optional Enemy reference for conditional effects
	## combat_controller: Optional CombatController reference for complex effects
	var draw_cards = 0
	for effect in effects:
		if effect is EffectData:
			if effect.effect_type == EffectType.DRAW:
				var result = resolve_effect(effect, source, target, enemy_context, combat_controller)
				if result is int:
					draw_cards += result
			elif effect.effect_type == EffectType.DAMAGE_PER_CURSE:
				# Special handling for damage_per_curse with ALL_ENEMIES targeting
				if combat_controller and combat_controller.has_method("get_enemies"):
					var all_enemies = combat_controller.get_enemies()
					for enemy in all_enemies:
						if enemy.stats.is_alive():
							resolve_effect(effect, source, enemy.stats, enemy, combat_controller)
			else:
				resolve_effect(effect, source, target, enemy_context, combat_controller)
	return draw_cards
