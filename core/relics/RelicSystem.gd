extends RefCounted
class_name RelicSystem

## Manages relic hook dispatch for the current run.
##
## Owned by RunState as `var relic_system: RelicSystem`.
## Instantiated in RunState._ready(); never use as an autoload.
##
## Usage (from CombatController):
##   RunState.relic_system.fire_hook("START_OF_COMBAT", {}, {"combat_controller": self})
##
## Trigger dict format (identical to PetDefinition trigger format):
##   { "hook": "HOOK_NAME", "action": "action_name", "amount": 3 }
##
## ── Supported Hooks ───────────────────────────────────────────────────────────
##
##   START_OF_COMBAT          fires once when combat begins (before first turn)
##   START_OF_PLAYER_TURN     fires at start of each player turn (before draw)
##   END_OF_PLAYER_TURN       fires at end of each player turn (before enemies act)
##   ON_CARD_PLAYED           fires when any card is played
##                              params: { card_type: CardData.CardType, card_id: String }
##   ON_ATTACK_PLAYED         fires when an Attack card is played
##   ON_SKILL_PLAYED          fires when a Skill card is played
##   ON_PLAYER_DAMAGED        fires when player takes HP damage
##   ON_ENEMY_KILLED          fires when an enemy dies
##   WHEN_ENEMY_ACTS          fires when an enemy takes an action
##   END_OF_COMBAT            fires after combat victory
##   ON_RELIC_GAINED          fires immediately when a relic is acquired
##                              params: { relic_id: String }
##
## ── Supported Actions ─────────────────────────────────────────────────────────
##
##   gain_block               player gains <amount> block
##   gain_strength            player gains <amount> Strength stacks
##   gain_dexterity           player gains <amount> Dexterity stacks
##   gain_faith               player gains <amount> Faith stacks
##   draw_cards               player draws <amount> cards
##   heal                     player heals <amount> HP
##   gain_energy              player gains <amount> energy this turn (capped at max)
##   deal_damage_random_enemy deal <amount> damage to a random alive enemy
##   deal_damage_all_enemies  deal <amount> damage to all alive enemies
##   gain_gold                player gains <amount> gold (works in and out of combat)
##   gain_max_hp              increase player max HP by <amount> (also heals by same amount)


func fire_hook(hook: String, params: Dictionary = {}, context: Dictionary = {}) -> void:
	## Fire a named hook for every relic currently owned.
	## Iterates a snapshot of RunState.relics to allow safe mutation during dispatch.
	## context: optional dict, typically {"combat_controller": CombatController}
	if not RunState:
		return
	var relics_snapshot: Array = RunState.relics.duplicate()
	for relic_entry in relics_snapshot:
		var relic_id: String = relic_entry.get("id", "")
		if relic_id.is_empty():
			continue
		var relic_data: RelicData = DataRegistry.get_relic(relic_id) if DataRegistry else null
		if not relic_data:
			# Relic in save but not yet in registry — silently skip (future content)
			continue
		for trigger in relic_data.triggers:
			if trigger.get("hook", "") == hook:
				_execute_trigger(trigger, params, context)


# ══════════════════════════  Trigger Execution  ═══════════════════════════════

func _execute_trigger(trigger: Dictionary, _params: Dictionary, context: Dictionary) -> void:
	var action: String = trigger.get("action", "")
	var amount: int = int(trigger.get("amount", 0))
	var cc = context.get("combat_controller", null)  # CombatController | null

	match action:
		"gain_block":
			_gain_block(amount, cc)

		"gain_strength":
			_apply_player_status(StatusEffectType.STRENGTH, amount, cc)

		"gain_dexterity":
			_apply_player_status(StatusEffectType.DEXTERITY, amount, cc)

		"gain_faith":
			_apply_player_status(StatusEffectType.FAITH, amount, cc)

		"draw_cards":
			if RunState:
				RunState.draw_cards(amount)

		"heal":
			_heal_player(amount, cc)

		"gain_energy":
			_gain_energy(amount, cc)

		"deal_damage_random_enemy":
			_damage_random_enemy(amount, cc)

		"deal_damage_all_enemies":
			_damage_all_enemies(amount, cc)

		"gain_gold":
			if ResourceManager:
				ResourceManager.set_gold(ResourceManager.gold + amount)

		"gain_max_hp":
			_gain_max_hp(amount, cc)

		_:
			if not action.is_empty():
				push_warning(
					"RelicSystem: unknown action '%s' (hook '%s')" % [action, trigger.get("hook", "?")]
				)


# ══════════════════════════  Private Helpers  ═════════════════════════════════

func _get_player_stats(cc) -> EntityStats:
	## Safely retrieve the player's EntityStats from a CombatController.
	## Returns null if cc is null or does not expose player_stats.
	if cc and cc.has("player_stats"):
		return cc.player_stats as EntityStats
	return null


func _gain_block(amount: int, cc) -> void:
	var ps: EntityStats = _get_player_stats(cc)
	if ps:
		ps.add_block(amount)
		if ResourceManager:
			ResourceManager.set_block(ps.block)


func _apply_player_status(status_type: String, amount: int, cc) -> void:
	var ps: EntityStats = _get_player_stats(cc)
	if ps:
		ps.apply_status(status_type, amount)


func _heal_player(amount: int, cc) -> void:
	var ps: EntityStats = _get_player_stats(cc)
	if ps:
		ps.heal(amount)
		if ResourceManager:
			ResourceManager.set_hp(ps.current_hp, ps.max_hp)
	elif ResourceManager:
		# Out-of-combat heal (e.g. END_OF_COMBAT relic reward)
		var new_hp: int = min(ResourceManager.current_hp + amount, ResourceManager.max_hp)
		ResourceManager.set_hp(new_hp, ResourceManager.max_hp)


func _gain_energy(amount: int, cc) -> void:
	if not cc:
		return
	if not cc.has("current_energy") or not cc.has("max_energy"):
		return
	var max_e: int = int(cc.get("max_energy"))
	var cur_e: int = int(cc.get("current_energy"))
	var new_energy: int = min(cur_e + amount, max_e)
	cc.set("current_energy", new_energy)
	if ResourceManager:
		ResourceManager.set_energy(new_energy, max_e)


func _damage_random_enemy(amount: int, cc) -> void:
	if not cc or not cc.has("enemies"):
		return
	var alive: Array = []
	for enemy in cc.enemies:
		if enemy.stats.is_alive():
			alive.append(enemy)
	if alive.is_empty():
		return
	var target = alive[randi() % alive.size()]
	target.stats.take_damage(amount, false)


func _damage_all_enemies(amount: int, cc) -> void:
	if not cc or not cc.has("enemies"):
		return
	# Snapshot so a kill mid-loop does not corrupt iteration
	var alive_snapshot: Array = []
	for enemy in cc.enemies:
		if enemy.stats.is_alive():
			alive_snapshot.append(enemy)
	for enemy in alive_snapshot:
		enemy.stats.take_damage(amount, false)


func _gain_max_hp(amount: int, cc) -> void:
	var ps: EntityStats = _get_player_stats(cc)
	if ps:
		ps.max_hp += amount
		ps.heal(amount)  # heal by the bonus so current HP rises with max
		if ResourceManager:
			ResourceManager.set_hp(ps.current_hp, ps.max_hp)
	elif ResourceManager:
		# Out-of-combat: update ResourceManager directly
		var new_max: int = ResourceManager.max_hp + amount
		var new_hp: int = min(ResourceManager.current_hp + amount, new_max)
		ResourceManager.set_hp(new_hp, new_max)
