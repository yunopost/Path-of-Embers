extends Node
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
		print("hand=", RunState.deck_model.hand.size(), " energy=", cc.current_energy, " enemy hp=", cc.enemies[0].stats.current_hp, " timer=", cc.enemies[0].time_current)
		# play cheapest playable cards greedily, end turn, loop until someone dies
		var turns := 0
		while cc.combat_active and turns < 30:
			turns += 1
			var played := true
			while played:
				played = false
				for iid in RunState.deck_model.hand.duplicate():
					var dc = RunState.deck[iid]
					var cd = DataRegistry.get_card_data(dc.card_id)
					if cd and cd.card_type != CardData.CardType.CURSE and cc.can_play_card(CardRules.get_effective_cost(cd, dc), cd):
						var tgt := Node.new(); tgt.set_meta("enemy", cc.enemies[0])
						if cc.play_card(dc, tgt): played = true
						tgt.free()
						break
			cc.end_player_turn()
			if not cc.enemies[0].stats.is_alive() or cc.player_stats.current_hp <= 0:
				cc.end_combat(cc.enemies[0].stats.is_alive() == false)
		print("turns=", turns, " player hp=", cc.player_stats.current_hp, " enemy hp=", cc.enemies[0].stats.current_hp)
	get_tree().quit()
