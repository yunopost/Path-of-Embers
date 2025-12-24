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
		"damage":  # Standardized effect type name
			var base_damage = effect.params.get("amount", 0)
			var hit_count = effect.params.get("hit_count", 1)  # Multi-hit support
			var ignore_block = effect.params.get("ignore_block", false)  # Ignore block flag
			var double_strength = effect.params.get("double_strength", false)  # Dark Knife special: double Strength bonus
			
			# Apply Strength bonus
			var strength_amount = 0
			if source:
				var strength_value = source.get_status("strength")
				if strength_value != null:
					strength_amount = int(strength_value)
					if double_strength:
						strength_amount *= 2  # Dark Knife doubles Strength bonus
			
			# Apply Weakness reduction (25% reduction = multiply by 0.75)
			var weakness_active = false
			if source:
				var weakness_value = source.get_status("weakness")
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
		
		"block":  # Standardized effect type name
			var base_block = effect.params.get("amount", 0)
			
			# Apply Dexterity bonus
			var dexterity_amount = 0
			if source:
				var dexterity_value = source.get_status("dexterity")
				if dexterity_value != null:
					dexterity_amount = int(dexterity_value)
			
			var final_block = base_block + dexterity_amount
			if source:
				source.add_block(final_block)
		
		"heal":  # Standardized effect type name
			var base_heal = effect.params.get("amount", 0)
			
			# Apply Faith bonus
			var faith_amount = 0
			if source:
				var faith_value = source.get_status("faith")
				if faith_value != null:
					faith_amount = int(faith_value)
			
			var final_heal = base_heal + faith_amount
			if source:
				source.heal(final_heal)
		
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
		
		"vulnerable_all_enemies":  # Apply vulnerable to all enemies
			var duration = effect.params.get("duration", 1)
			if combat_controller and combat_controller.has_method("get_enemies"):
				var all_enemies = combat_controller.get_enemies()
				for enemy in all_enemies:
					if enemy.stats.is_alive():
						enemy.stats.apply_status("vulnerable", duration)
		
		"strength":  # Apply Strength status (stacking)
			var amount = effect.params.get("amount", 1)
			if source:
				source.apply_status("strength", amount)
		
		"dexterity":  # Apply Dexterity status (stacking)
			var amount = effect.params.get("amount", 1)
			if source:
				source.apply_status("dexterity", amount)
		
		"faith":  # Apply Faith status (stacking)
			var amount = effect.params.get("amount", 1)
			if source:
				source.apply_status("faith", amount)
		
		"weakness":  # Apply Weakness status (duration-based)
			var duration = effect.params.get("duration", 1)
			if target:
				target.apply_status("weakness", duration)
		
		"damage_per_curse":  # Damage based on curses in hand/discard (Malediction Lash)
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
					var strength_value = source.get_status("strength")
					if strength_value != null:
						strength_amount = int(strength_value)
				
				var weakness_active = false
				if source:
					var weakness_value = source.get_status("weakness")
					if weakness_value != null and int(weakness_value) > 0:
						weakness_active = true
				
				var damage_before_weakness = total_damage + strength_amount
				var final_damage = damage_before_weakness
				if weakness_active:
					final_damage = int(ceil(float(damage_before_weakness) * 0.75))
				
				target.take_damage(final_damage, false)
		
		"add_curse_to_hand":  # Add a curse card to hand (Hexbound Ritual)
			var is_temporary = effect.params.get("is_temporary", false)
			if combat_controller and combat_controller.has_method("_add_curse_to_hand"):
				combat_controller._add_curse_to_hand(is_temporary)
		
		"conditional_strength_if_no_damage":  # Fade Step - gain Strength if no damage this turn (checked at end of turn)
			var amount = effect.params.get("amount", 1)
			# Set a pending status that will be checked at end of turn
			if source:
				source.apply_status("pending_strength_if_no_damage", amount)
		
		"add_temporary_upgrade_to_random_hand_card":  # Reinforce - placeholder for now
			push_warning("EffectResolver: add_temporary_upgrade_to_random_hand_card not yet implemented (placeholder)")
			# TODO: Implement temporary upgrade system
		
		"retain_block_this_turn":  # Plated Guard - do not lose block at end of turn
			var status_value = effect.params.get("value", true)
			if source:
				source.apply_status("retain_block_this_turn", status_value)
		
		"block_on_enemy_act":  # Survey the Path - gain block when enemy acts (handled in Power card setup)
			# This is handled in CombatController._setup_power_card_effects()
			pass
		
		"damage_on_block_gain":  # Resonant Frame - deal damage when block gained (handled in Power card setup)
			# This is handled in CombatController._setup_power_card_effects()
			pass
		
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

static func resolve_effects(effects: Array, source: EntityStats, target: EntityStats = null, enemy_context: Enemy = null, combat_controller: Node = null) -> int:
	## Resolve multiple effects, returns number of cards to draw (if any)
	## enemy_context: Optional Enemy reference for conditional effects
	## combat_controller: Optional CombatController reference for complex effects
	var draw_cards = 0
	for effect in effects:
		if effect is EffectData:
			if effect.effect_type == "draw":  # Standardized effect type name
				var result = resolve_effect(effect, source, target, enemy_context, combat_controller)
				if result is int:
					draw_cards += result
			elif effect.effect_type == "damage_per_curse":
				# Special handling for damage_per_curse with ALL_ENEMIES targeting
				if combat_controller and combat_controller.has_method("get_enemies"):
					var all_enemies = combat_controller.get_enemies()
					for enemy in all_enemies:
						if enemy.stats.is_alive():
							resolve_effect(effect, source, enemy.stats, enemy, combat_controller)
			else:
				resolve_effect(effect, source, target, enemy_context, combat_controller)
	return draw_cards
