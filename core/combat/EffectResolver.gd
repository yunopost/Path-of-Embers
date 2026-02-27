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
		
		# ── Revenant ─────────────────────────────────────────────────────────────
		EffectType.DAMAGE_SPITE:
			# Deals base damage + bonus scaled by missing HP (per 10 HP missing)
			var base_amount = effect.params.get("base_amount", 0)
			var bonus_per_10_missing = effect.params.get("bonus_per_10_missing_hp", 0)

			var missing_hp = 0
			if source:
				missing_hp = source.max_hp - source.current_hp
			var bonus_damage = int(missing_hp / 10) * bonus_per_10_missing
			var total_damage = base_amount + bonus_damage

			# Apply Strength / Weakness
			var strength_amount_spite = 0
			if source:
				var sv = source.get_status(StatusEffectType.STRENGTH)
				if sv != null:
					strength_amount_spite = int(sv)
			var weakness_active_spite = false
			if source:
				var wv = source.get_status(StatusEffectType.WEAKNESS)
				if wv != null and int(wv) > 0:
					weakness_active_spite = true
			var damage_bw_spite = total_damage + strength_amount_spite
			var final_damage_spite = damage_bw_spite
			if weakness_active_spite:
				final_damage_spite = int(ceil(float(damage_bw_spite) * 0.75))
			if target:
				target.take_damage(final_damage_spite, false)

		EffectType.DRAW_IF_TOOK_DAMAGE:
			# Draw N cards if the player took any damage this combat
			var draw_if_hit = effect.params.get("amount", 1)
			if combat_controller and combat_controller.get("damage_taken_this_combat") == true:
				return draw_if_hit

		# ── Tempest ───────────────────────────────────────────────────────────────
		EffectType.DAMAGE_SEQUENCING:
			# Deals base damage + bonus if the previous card played was an Attack
			var base_seq = effect.params.get("base_amount", 0)
			var bonus_seq = effect.params.get("bonus_if_last_was_attack", 0)

			var last_type_seq = combat_controller.get("last_card_type_played") if combat_controller else -1
			var bonus_applied = bonus_seq if last_type_seq == CardData.CardType.ATTACK else 0
			var total_seq = base_seq + bonus_applied

			# Apply Strength / Weakness
			var strength_seq = 0
			if source:
				var sv = source.get_status(StatusEffectType.STRENGTH)
				if sv != null:
					strength_seq = int(sv)
			var weakness_seq = false
			if source:
				var wv = source.get_status(StatusEffectType.WEAKNESS)
				if wv != null and int(wv) > 0:
					weakness_seq = true
			var damage_bw_seq = total_seq + strength_seq
			var final_seq = damage_bw_seq
			if weakness_seq:
				final_seq = int(ceil(float(damage_bw_seq) * 0.75))
			if target:
				target.take_damage(final_seq, false)

		# ── Grove ─────────────────────────────────────────────────────────────────
		EffectType.BLOOM:
			# Each play adds counters toward a threshold; at threshold, trigger the bloom effect
			var counters_add = effect.params.get("counters", 1)
			var threshold = effect.params.get("trigger_threshold", 3)
			var trigger_fx = effect.params.get("trigger_effect", "block")
			var trigger_amount = effect.params.get("trigger_amount", 6)

			if source:
				var current = 0
				var stored = source.status_effects.get("bloom_counter", null)
				if stored != null:
					current = int(stored)
				current += counters_add
				if current >= threshold:
					current = 0  # Reset counter
					if trigger_fx == "block":
						source.add_block(trigger_amount)
					elif trigger_fx == "heal":
						source.heal(trigger_amount)
					# TODO: RunState.increment_quest_counter("bloom_triggers", 1)
				source.status_effects["bloom_counter"] = current
				source.status_effects_changed.emit()

		EffectType.REGROWTH:
			# Signal CombatController to return this card to the draw pile instead of discarding
			if combat_controller:
				combat_controller.set("_regrowth_pending", true)

		# ── Sibyl ─────────────────────────────────────────────────────────────────
		EffectType.SCRY:
			# Look at the top N cards of the draw pile.
			# Full implementation requires UI to let the player choose the order.
			# For now this is a mechanical stub — the draw pile is left unchanged.
			var scry_amount = effect.params.get("amount", 2)
			push_warning("SCRY: peeking at top %d cards (UI reorder not yet implemented)" % scry_amount)
			# TODO: RunState.increment_quest_counter("foresight_uses", 1)

		EffectType.DAMAGE_CONDITIONAL_TOP_CARD:
			# Check the top card of the draw pile: if it's an Attack deal more damage;
			# otherwise deal less damage and gain some Block
			var attack_dmg = effect.params.get("attack_amount", 10)
			var default_dmg = effect.params.get("default_amount", 5)
			var default_blk = effect.params.get("default_block", 3)

			var top_is_attack = false
			if RunState and RunState.deck_model and RunState.deck_model.draw_pile.size() > 0:
				var top_id = RunState.deck_model.draw_pile[0]
				var top_deck_card = RunState.deck.get(top_id)
				if top_deck_card:
					var top_card_data = DataRegistry.get_card_data(top_deck_card.card_id)
					if top_card_data and top_card_data.card_type == CardData.CardType.ATTACK:
						top_is_attack = true

			# Shared Strength / Weakness calculation
			var strength_cond = 0
			if source:
				var sv = source.get_status(StatusEffectType.STRENGTH)
				if sv != null:
					strength_cond = int(sv)
			var weakness_cond = false
			if source:
				var wv = source.get_status(StatusEffectType.WEAKNESS)
				if wv != null and int(wv) > 0:
					weakness_cond = true

			var raw_dmg_cond = attack_dmg if top_is_attack else default_dmg
			var dmg_bw_cond = raw_dmg_cond + strength_cond
			var final_dmg_cond = dmg_bw_cond
			if weakness_cond:
				final_dmg_cond = int(ceil(float(dmg_bw_cond) * 0.75))
			if target:
				target.take_damage(final_dmg_cond, false)

			if not top_is_attack and source:
				# Bonus Block on the non-attack branch (Dexterity applies)
				var dex_cond = 0
				var dex_val = source.get_status(StatusEffectType.DEXTERITY)
				if dex_val != null:
					dex_cond = int(dex_val)
				source.add_block(default_blk + dex_cond)
			# TODO: RunState.increment_quest_counter("foresight_uses", 1)

		# ── Echo ──────────────────────────────────────────────────────────────────
		EffectType.MIRROR:
			# Replay the last played card's effects without paying its cost
			if combat_controller and combat_controller.has_method("_replay_last_card_effects"):
				combat_controller._replay_last_card_effects(null)
			# TODO: RunState.increment_quest_counter("mirror_count", 1)

		EffectType.RESONANCE_BLOCK:
			# Gain Block; gain extra Block if the previous card played was a Skill
			var base_res = effect.params.get("base_amount", 5)
			var bonus_res = effect.params.get("bonus_if_last_was_skill", 0)

			var last_type_res = combat_controller.get("last_card_type_played") if combat_controller else -1
			var res_bonus = bonus_res if last_type_res == CardData.CardType.SKILL else 0
			var total_res = base_res + res_bonus

			# Apply Dexterity
			var dex_res = 0
			if source:
				var dv = source.get_status(StatusEffectType.DEXTERITY)
				if dv != null:
					dex_res = int(dv)
			if source:
				source.add_block(total_res + dex_res)

		# ── Hollow ────────────────────────────────────────────────────────────────
		EffectType.BLOCK_TO_ENERGY:
			# Convert all current Block into Energy at the given ratio
			var block_per_energy = effect.params.get("block_per_energy", 3)
			if source and combat_controller and block_per_energy > 0:
				var current_block_val = source.block
				if current_block_val > 0:
					var energy_gained = int(current_block_val / block_per_energy)
					source.reset_block()  # ResourceManager.set_block() synced after effects resolve
					if energy_gained > 0:
						var max_e = int(combat_controller.get("max_energy") if combat_controller.get("max_energy") != null else 3)
						var cur_e = int(combat_controller.get("current_energy") if combat_controller.get("current_energy") != null else 0)
						var new_energy = min(cur_e + energy_gained, max_e)
						combat_controller.set("current_energy", new_energy)
						if ResourceManager:
							ResourceManager.set_energy(new_energy, max_e)
					# TODO: RunState.increment_quest_counter("block_converted_to_energy", current_block_val)

		EffectType.FORCE_END_TURN:
			# Signal CombatController to end the turn once this card is fully resolved
			if combat_controller:
				combat_controller.set("_end_turn_pending", true)

		_:
			push_warning("Unknown effect type: " + effect.effect_type)

static func resolve_effects(effects: Array, source: EntityStats, target: EntityStats = null, enemy_context: Enemy = null, combat_controller: Node = null) -> int:
	## Resolve multiple effects, returns number of cards to draw (if any)
	## enemy_context: Optional Enemy reference for conditional effects
	## combat_controller: Optional CombatController reference for complex effects
	var draw_cards = 0
	for effect in effects:
		if effect is EffectData:
			if effect.effect_type == EffectType.DRAW or effect.effect_type == EffectType.DRAW_IF_TOOK_DAMAGE:
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
