extends Node
## Headless smoke test for card-clock combat: plays a fight to completion using
## the "cheapest playable card at the lowest-HP enemy, else Focus" auto-play policy.
func _ready():
	print("autoloads ok: RunState=", RunState != null, " DataRegistry=", DataRegistry != null)
	var chars: Array[CharacterData] = []
	for id in ["warrior_1","witch","golemancer"]:
		var c = DataRegistry.get_character(id)
		print(" char ", id, " -> ", c != null)
		if c: chars.append(c)
	if chars.size()==3:
		PartyManager.party_ids = ["warrior_1","witch","golemancer"]
		RunState.generate_starter_deck(chars)
		print("deck size=", RunState.get_deck_size())
		var cc = CombatController.new()
		add_child(cc)
		cc.start_combat([{"enemy_id":"ash_man","count":1}])
		print("hand=", RunState.deck_model.hand.size(), " energy=", cc.current_energy, "/", cc.max_energy, " enemy hp=", cc.enemies[0].stats.current_hp, " timer=", cc.enemies[0].time_current)
		# Play the cheapest playable card at the lowest-HP enemy; Focus when nothing is playable.
		var cycles := 0
		var ticks := 0
		var max_cycles := 60
		while cc.combat_active and cycles < max_cycles:
			var target_enemy: Enemy = _lowest_hp_enemy(cc)
			var best_dc: DeckCardData = null
			var best_cost := 999
			var best_cd: CardData = null
			for iid in RunState.deck_model.hand.duplicate():
				var dc = RunState.deck[iid]
				var cd = DataRegistry.get_card_data(dc.card_id)
				if cd == null or cd.card_type == CardData.CardType.CURSE:
					continue
				var cost = CardRules.get_effective_cost(cd, dc)
				if not cc.can_play_card(cost, cd):
					continue
				if CardRules.get_card_keywords(dc).has("Opener") and cc.cards_played_this_cycle > 0:
					continue
				if cost < best_cost:
					best_cost = cost
					best_dc = dc
					best_cd = cd
			if best_dc:
				var tgt: Node = null
				if best_cd.targeting_mode == CardData.TargetingMode.ENEMY and target_enemy:
					tgt = Node.new(); tgt.set_meta("enemy", target_enemy)
				var tick = RunState.get_timer_tick_amount_for_card(str(best_dc.instance_id))
				var ok = cc.play_card(best_dc, tgt)
				if tgt: tgt.free()
				if ok:
					ticks += tick
			else:
				cycles += 1
				cc.focus()
				ticks += 1
			if not cc.enemies[0].stats.is_alive() or cc.player_stats.current_hp <= 0:
				cc.end_combat(cc.enemies[0].stats.is_alive() == false)
		print("cycles=", cycles, " ticks=", ticks, " player hp=", cc.player_stats.current_hp, " enemy hp=", cc.enemies[0].stats.current_hp)
	get_tree().quit()

func _lowest_hp_enemy(cc: CombatController) -> Enemy:
	var best: Enemy = null
	for e in cc.enemies:
		if e.stats.is_alive() and (best == null or e.stats.current_hp < best.stats.current_hp):
			best = e
	return best
