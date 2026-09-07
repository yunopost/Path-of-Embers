extends Node
## Path of Embers — headless combat simulator (Lead Playtester tool).
##
## Run:
##   cd <project root>
##   ../Godot_v4.5-stable_linux.x86_64 --headless --path . res://tests/sim.tscn -- \
##       --party=warrior_1,warrior_2,golemancer --enemies=ash_man:1 --act=1 --n=200 --policy=greedy
##
## Options (all after the bare `--`):
##   --party=a,b,c        three character ids (default: CFG.party)
##   --enemies=id:count,… explicit composition, OR
##   --pool=fight:N | elite:N | boss   composition from EncounterDirector constants (boss uses act)
##   --act=1|2|3          applies EncounterDirector ACT_HP_MULT / ACT_DMG_MULT (bosses unscaled, as in-game)
##   --n=100              fights per configuration
##   --policy=greedy|random
##   --seed=12345         base seed; fight i uses seed+i
##   --max_turns=60       fight is scored "timeout" past this
##   --label=text         free-text label used in outputs
##   --json=path          per-config JSON summary (absolute path)
##   --csv=path           per-fight CSV rows (appended; header written when file is new)
##   --md=path            stand-alone markdown report for this single config
##
## Model-swap point: advance(cc) is the single "advance the clock when nothing is playable"
## action. Card-clock combat: it calls cc.focus().

const CFG := {
	"party": ["warrior_1", "warrior_2", "golemancer"],
	"enemies": "ash_man:1",
	"pool": "",
	"act": 1,
	"n": 100,
	"policy": "greedy",
	"seed": 12345,
	"max_turns": 60,
	"label": "",
	"json": "",
	"csv": "",
	"md": "",
}

var cfg: Dictionary = CFG.duplicate(true)
var findings: Array[String] = []          # sanity-check failures / logic anomalies observed by the sim
var rng := RandomNumberGenerator.new()    # policy randomness (seeded per fight)

# ── per-fight live tracking (reset in run_fight) ─────────────────────────────
var _hp_cur: int = 0
var _block_prev: int = 0
var _block_cur: int = 0
var _pending_hp_dmg: int = 0
var _enemy_acted_this_action: bool = false
var _enemy_actions: int = 0
var _dmg_by_enemy: Dictionary = {}     # enemy_id -> HP damage dealt to player
var _actions_by_enemy: Dictionary = {}
var _turn_ended_count: int = 0
var _block_gained: int = 0
var _block_decreased: int = 0
var _hp_lost_gross: int = 0

func _ready() -> void:
	_parse_args()
	var enemy_data := _build_enemy_data()
	if enemy_data.is_empty():
		push_error("sim: no enemies resolved from --enemies/--pool")
		get_tree().quit(2)
		return
	var label: String = cfg.label if not str(cfg.label).is_empty() else "%s vs %s act%d" % [",".join(cfg.party), _enemies_str(enemy_data), int(cfg.act)]
	print("sim: %s  n=%d policy=%s seed=%d" % [label, int(cfg.n), cfg.policy, int(cfg.seed)])

	var rows: Array = []
	var t0 := Time.get_ticks_msec()
	for i in range(int(cfg.n)):
		rows.append(run_fight(i, enemy_data))
	var elapsed := Time.get_ticks_msec() - t0

	var summary := summarize(rows, enemy_data, label)
	summary["elapsed_ms"] = elapsed
	summary["findings"] = findings
	print("sim: done %d fights in %d ms  win=%.2f  turns=%.1f  ticks=%.1f  dmg=%.1f" % [
		rows.size(), elapsed, summary.win_rate, summary.turns.mean, summary.ticks.mean, summary.damage_taken.mean])
	for f in findings:
		print("sim FINDING: ", f)

	if not str(cfg.json).is_empty():
		_write_text(cfg.json, JSON.stringify(summary, "  "))
	if not str(cfg.csv).is_empty():
		_append_csv(cfg.csv, rows, label)
	if not str(cfg.md).is_empty():
		_write_text(cfg.md, render_markdown(summary))
	get_tree().quit()

# ── configuration ────────────────────────────────────────────────────────────

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var eq := a.find("=")
		var key := a.substr(2, eq - 2) if eq > 0 else a.substr(2)
		var val := a.substr(eq + 1) if eq > 0 else "true"
		match key:
			"party": cfg.party = Array(val.split(","))
			"n", "act", "seed", "max_turns": cfg[key] = int(val)
			_: cfg[key] = val

func _build_enemy_data() -> Array:
	var act: int = clampi(int(cfg.act), 1, 3)
	var comp: Array = []
	var is_boss := false
	var pool: String = str(cfg.pool)
	if pool.begins_with("fight:"):
		comp = EncounterDirector.FIGHT_POOLS[int(pool.get_slice(":", 1))].duplicate(true)
	elif pool.begins_with("elite:"):
		comp = EncounterDirector.ELITE_POOLS[int(pool.get_slice(":", 1))].duplicate(true)
	elif pool == "boss":
		comp = [{"enemy_id": "boss_act%d" % act, "count": 1}]
		is_boss = true
	else:
		for part in str(cfg.enemies).split(",", false):
			var id := part.get_slice(":", 0).strip_edges()
			var count := int(part.get_slice(":", 1)) if part.find(":") >= 0 else 1
			if DataRegistry.get_enemy(id) == null:
				push_error("sim: unknown enemy id '%s'" % id)
				continue
			var ed = DataRegistry.get_enemy(id)
			if ed.enemy_type == EnemyData.EnemyType.BOSS:
				is_boss = true
			comp.append({"enemy_id": id, "count": count})
	if not is_boss:
		for e in comp:
			e["hp_mult"] = EncounterDirector.ACT_HP_MULT.get(act, 1.0)
			e["dmg_mult"] = EncounterDirector.ACT_DMG_MULT.get(act, 1.0)
	return comp

func _enemies_str(enemy_data: Array) -> String:
	var parts: PackedStringArray = []
	for e in enemy_data:
		parts.append("%s:%d" % [e.enemy_id, e.count])
	return ",".join(parts)

# ── fresh run state ──────────────────────────────────────────────────────────

func _fresh_run() -> bool:
	## Mirrors what the game does between New Game and CombatScreen: reset_run → set_party → starter deck.
	RunState.reset_run()
	var ids: Array[String] = []
	for p in cfg.party:
		ids.append(str(p))
	PartyManager.set_party(ids)
	var chars: Array[CharacterData] = []
	for id in ids:
		var c = DataRegistry.get_character(id)
		if c == null:
			push_error("sim: unknown character id '%s'" % id)
			return false
		chars.append(c)
	RunState.generate_starter_deck(chars)
	return true

func _sanity_check(cc: CombatController, fight_idx: int, expected_deck: int, expected_hp: int) -> void:
	## Verifies that state really is fresh at the start of each fight (only reports first 3 offences per kind).
	var problems: Array[String] = []
	if RunState.deck.size() != expected_deck:
		problems.append("deck size %d != %d" % [RunState.deck.size(), expected_deck])
	if RunState.deck_model.hand.size() != 5:
		problems.append("opening hand %d != 5" % RunState.deck_model.hand.size())
	if RunState.deck_model.draw_pile.size() + RunState.deck_model.hand.size() + RunState.deck_model.discard_pile.size() != RunState.deck_order.size():
		problems.append("piles (%d+%d+%d) != deck_order %d" % [RunState.deck_model.draw_pile.size(), RunState.deck_model.hand.size(), RunState.deck_model.discard_pile.size(), RunState.deck_order.size()])
	if cc.player_stats.current_hp != expected_hp or cc.player_stats.max_hp != expected_hp:
		problems.append("player hp %d/%d != %d" % [cc.player_stats.current_hp, cc.player_stats.max_hp, expected_hp])
	if ResourceManager.current_hp != expected_hp:
		problems.append("ResourceManager hp %d != %d" % [ResourceManager.current_hp, expected_hp])
	if cc.current_energy != 3:
		problems.append("energy %d != 3" % cc.current_energy)
	if cc.player_stats.block != 0:
		problems.append("block %d != 0" % cc.player_stats.block)
	if not cc.player_stats.status_effects.is_empty():
		problems.append("player statuses not empty: %s" % str(cc.player_stats.status_effects.keys()))
	if RunState.haste_next_card:
		problems.append("haste_next_card leaked true")
	for p in problems:
		var msg := "reset sanity (fight %d): %s" % [fight_idx, p]
		if findings.count(msg) == 0 and findings.size() < 40:
			findings.append(msg)

# ── one fight ────────────────────────────────────────────────────────────────

func run_fight(idx: int, enemy_data: Array) -> Dictionary:
	seed(int(cfg.seed) + idx)          # game RNG (shuffles, enemy moves, HP rolls)
	rng.seed = int(cfg.seed) + idx     # policy RNG
	if not _fresh_run():
		return {"result": "error"}

	var expected_deck := RunState.deck.size()
	var expected_hp := 0
	for p in cfg.party:
		expected_hp += DataRegistry.get_character(str(p)).hp_base

	var cc := CombatController.new()
	add_child(cc)
	_hp_cur = cc.player_stats.current_hp
	_block_prev = 0
	_block_cur = 0
	_pending_hp_dmg = 0
	_enemy_actions = 0
	_dmg_by_enemy = {}
	_actions_by_enemy = {}
	_turn_ended_count = 0
	_block_gained = 0
	_block_decreased = 0
	_hp_lost_gross = 0
	cc.player_stats.hp_changed.connect(_on_hp_changed)
	cc.player_stats.block_changed.connect(_on_block_changed)
	cc.turn_ended.connect(func(): _turn_ended_count += 1)

	cc.start_combat(enemy_data.duplicate(true))
	_hp_cur = cc.player_stats.current_hp
	for e in cc.enemies:
		e.intent_changed.connect(_on_enemy_intent_changed.bind(e))
	_sanity_check(cc, idx, expected_deck, expected_hp)

	var hp_start := cc.player_stats.current_hp
	var ticks := 0
	var card_ticks := 0
	var cards_played: Dictionary = {}
	var cards_seen: Dictionary = {}       # card_id -> decision points where it was in hand
	var cards_affordable: Dictionary = {} # card_id -> decision points where it was playable
	var energy_unspent := 0
	var block_wasted := 0
	var heal_wasted := 0
	var end_turns := 0
	var result := "timeout"
	var blocked: Dictionary = {}          # instance ids that play_card refused this turn
	var ability_uses: Dictionary = {}     # character_id -> times used this fight

	while cc.combat_active:
		# Party abilities (Card-Clock Combat spec §7/§10.6): use one whenever
		# off cooldown, before considering cards -- mirrors the "greedy" policy's
		# philosophy of never leaving a free resource on the table. Runs at
		# most once per decision point, in party order.
		var ability_result := _try_use_ability(cc)
		if not ability_result.is_empty():
			ability_uses[ability_result.char_id] = ability_uses.get(ability_result.char_id, 0) + 1
			ticks += ability_result.tick_cost
			_flush_pending_damage()
			if cc.player_stats.current_hp <= 0:
				result = "loss"
				cc.end_combat(false)
			elif _all_dead(cc):
				result = "win"
				cc.end_combat(true)
			continue

		# Decision-point bookkeeping (drives "never played" diagnosis)
		var playable := _playable_cards(cc, blocked)
		for iid in RunState.deck_model.hand:
			var cid: String = RunState.deck[iid].card_id
			cards_seen[cid] = cards_seen.get(cid, 0) + 1
		for pc in playable:
			cards_affordable[pc.dc.card_id] = cards_affordable.get(pc.dc.card_id, 0) + 1

		var choice: Dictionary = _policy_choose(cc, playable)
		_enemy_acted_this_action = false
		if not choice.is_empty():
			var dc: DeckCardData = choice.dc
			var tick := _predict_tick(dc)
			var target: Node = null
			if choice.enemy != null:
				target = Node.new()
				target.set_meta("enemy", choice.enemy)
			var hp_before := cc.player_stats.current_hp
			var ok: bool = cc.play_card(dc, target)
			if target:
				target.free()
			if ok:
				ticks += tick
				card_ticks += tick
				cards_played[dc.card_id] = cards_played.get(dc.card_id, 0) + 1
				# healing at full HP is wasted
				var cd := DataRegistry.get_card_data(dc.card_id)
				if cd and hp_before >= cc.player_stats.max_hp and _card_has_effect(dc, EffectType.HEAL) and not _enemy_acted_this_action:
					heal_wasted += 1
			else:
				blocked[dc.instance_id] = true
				_note("play_card refused a card the policy considered playable: %s (turn %d)" % [dc.card_id, end_turns + 1])
		else:
			# Card-clock: energy carries over between cycles (no reset), so it is
			# only "wasted" when Focus's +2 would push past the cap.
			var pre_focus_energy := cc.current_energy
			end_turns += 1  # counts Focus uses == cycles completed
			blocked.clear()
			advance(cc)
			ticks += 1
			energy_unspent += maxi(0, (pre_focus_energy + 2) - cc.max_energy)
			if cc.player_stats.block == 0:
				block_wasted += _block_prev
		_flush_pending_damage()

		# End conditions (CombatScreen does this in-game)
		if cc.player_stats.current_hp <= 0:
			result = "loss"
			cc.end_combat(false)
		elif _all_dead(cc):
			result = "win"
			cc.end_combat(true)
		elif end_turns >= int(cfg.max_turns):
			result = "timeout"
			cc.end_combat(false)

	var turns := end_turns + 1
	if _turn_ended_count != end_turns:
		_note("turn_ended signal count %d != advance() calls %d (forced end-turn effects?)" % [_turn_ended_count, end_turns])

	var row := {
		"fight": idx, "seed": int(cfg.seed) + idx, "result": result,
		"turns": turns, "ticks": ticks, "card_ticks": card_ticks,
		"enemy_actions": _enemy_actions,
		"damage_taken": hp_start - cc.player_stats.current_hp, "hp_lost_gross": _hp_lost_gross,
		"hp_end": cc.player_stats.current_hp, "hp_max": cc.player_stats.max_hp,
		"block_gained": _block_gained, "block_wasted": block_wasted,
		"energy_unspent": energy_unspent, "heal_wasted": heal_wasted,
		"cards_played_total": _sum(cards_played),
		"cards_played": cards_played, "cards_seen": cards_seen, "cards_affordable": cards_affordable,
		"dmg_by_enemy": _dmg_by_enemy.duplicate(), "actions_by_enemy": _actions_by_enemy.duplicate(),
		"enemy_hp_left": _enemy_hp_left(cc),
		"ability_uses": ability_uses.duplicate(), "ability_uses_total": _sum(ability_uses),
	}
	cc.player_stats.hp_changed.disconnect(_on_hp_changed)
	cc.player_stats.block_changed.disconnect(_on_block_changed)
	remove_child(cc)
	cc.free()
	return row

func advance(cc: CombatController) -> void:
	## THE swap point (card-clock combat): Focus is the "nothing playable" action.
	cc.focus()

func _try_use_ability(cc: CombatController) -> Dictionary:
	## Use the first ready party ability, in party order (spec §7/§10.6). Mirrors
	## the greedy policy: abilities are treated as always worth using once off
	## cooldown, since none of the six EA abilities have a downside for the
	## "cheapest card, else Focus" policy to weigh against. ENEMY-targeted
	## abilities target the lowest-HP alive enemy, same as attack cards.
	## Returns {char_id, tick_cost} on success, {} if nothing was used.
	for cid in cfg.party:
		var char_id := str(cid)
		if not cc.can_use_ability(char_id):
			continue
		var char_data := DataRegistry.get_character(char_id)
		var ability: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id)
		var target: Node = null
		if ability.targeting_mode == CardData.TargetingMode.ENEMY:
			var e := _lowest_hp_enemy(cc)
			if e == null:
				continue
			target = Node.new()
			target.set_meta("enemy", e)
		var ok: bool = cc.use_ability(char_id, target)
		if target:
			target.free()
		if ok:
			return {"char_id": char_id, "tick_cost": ability.tick_cost}
	return {}

# ── policies ─────────────────────────────────────────────────────────────────
## A policy is one function: (cc, playable: Array[{dc, cd, cost}]) -> {} (advance) or {dc, enemy}

func _policy_choose(cc: CombatController, playable: Array) -> Dictionary:
	match str(cfg.policy):
		"greedy": return policy_greedy(cc, playable)
		"random": return policy_random(cc, playable)
		_:
			push_error("sim: unknown policy '%s'" % cfg.policy)
			return {}

func policy_greedy(cc: CombatController, playable: Array) -> Dictionary:
	## Cheapest playable card (hand order breaks ties); enemy-targeted cards hit the lowest-HP enemy.
	if playable.is_empty():
		return {}
	var best = playable[0]
	for p in playable:
		if p.cost < best.cost:
			best = p
	return {"dc": best.dc, "enemy": _lowest_hp_enemy(cc) if best.cd.targeting_mode == CardData.TargetingMode.ENEMY else null}

func policy_random(cc: CombatController, playable: Array) -> Dictionary:
	## Uniformly random playable card; random alive enemy as target.
	if playable.is_empty():
		return {}
	var p = playable[rng.randi_range(0, playable.size() - 1)]
	var enemy: Enemy = null
	if p.cd.targeting_mode == CardData.TargetingMode.ENEMY:
		var alive := _alive_enemies(cc)
		enemy = alive[rng.randi_range(0, alive.size() - 1)] if not alive.is_empty() else null
	return {"dc": p.dc, "enemy": enemy}

# ── helpers ──────────────────────────────────────────────────────────────────

func _playable_cards(cc: CombatController, blocked: Dictionary) -> Array:
	var out: Array = []
	for iid in RunState.deck_model.hand:
		if blocked.has(iid):
			continue
		var dc: DeckCardData = RunState.deck.get(iid)
		if dc == null:
			continue
		var cd := DataRegistry.get_card_data(dc.card_id)
		if cd == null or cd.card_type == CardData.CardType.CURSE:
			continue
		var cost := CardRules.get_effective_cost(cd, dc)
		if not cc.can_play_card(cost, cd):
			continue
		if CardRules.get_card_keywords(dc).has("Opener") and cc.cards_played_this_cycle > 0:
			continue
		out.append({"dc": dc, "cd": cd, "cost": cost})
	return out

func _predict_tick(dc: DeckCardData) -> int:
	## Same rule as RunState.get_timer_tick_amount_for_card, without consuming haste_next_card.
	if RunState.haste_next_card:
		return 0
	if RunState.has_upgrade(dc.instance_id, "upgrade_haste"):
		return 0
	var keywords: Array[String] = CardRules.get_card_keywords(dc)
	if keywords.has("Haste"):
		return 0
	for kw in keywords:
		if kw == "Slow":
			return 2
		if kw.begins_with("Slow "):
			var mag_str := kw.substr(5).strip_edges()
			return int(mag_str) if mag_str.is_valid_int() else 2
	return 1

func _card_has_effect(dc: DeckCardData, type: String) -> bool:
	for e in CardRules.get_resolved_effects(dc):
		if e is EffectData and e.effect_type == type:
			return true
	return false

func _alive_enemies(cc: CombatController) -> Array:
	var out: Array = []
	for e in cc.enemies:
		if e.stats.is_alive():
			out.append(e)
	return out

func _lowest_hp_enemy(cc: CombatController) -> Enemy:
	var best: Enemy = null
	for e in _alive_enemies(cc):
		if best == null or e.stats.current_hp < best.stats.current_hp:
			best = e
	return best

func _all_dead(cc: CombatController) -> bool:
	return _alive_enemies(cc).is_empty()

func _enemy_hp_left(cc: CombatController) -> int:
	var s := 0
	for e in cc.enemies:
		s += e.stats.current_hp
	return s

func _on_hp_changed(new_hp: int) -> void:
	if new_hp < _hp_cur:
		_pending_hp_dmg += _hp_cur - new_hp
		_hp_lost_gross += _hp_cur - new_hp
	_hp_cur = new_hp

func _on_block_changed(new_block: int) -> void:
	_block_prev = _block_cur
	_block_cur = new_block
	if new_block > _block_prev:
		_block_gained += new_block - _block_prev
	else:
		_block_decreased += _block_prev - new_block

func _on_enemy_intent_changed(_intent, enemy: Enemy) -> void:
	## intent_changed fires right after an enemy acts (and once at spawn, before we connect).
	_enemy_actions += 1
	_enemy_acted_this_action = true
	_actions_by_enemy[enemy.enemy_id] = _actions_by_enemy.get(enemy.enemy_id, 0) + 1
	_dmg_by_enemy[enemy.enemy_id] = _dmg_by_enemy.get(enemy.enemy_id, 0) + _pending_hp_dmg
	_pending_hp_dmg = 0

func _flush_pending_damage() -> void:
	if _pending_hp_dmg > 0:
		_dmg_by_enemy["(unattributed/self)"] = _dmg_by_enemy.get("(unattributed/self)", 0) + _pending_hp_dmg
		_pending_hp_dmg = 0

func _note(msg: String) -> void:
	if findings.count(msg) == 0 and findings.size() < 40:
		findings.append(msg)

func _sum(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s

# ── statistics ───────────────────────────────────────────────────────────────

static func stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p10": 0, "p50": 0, "p90": 0, "min": 0, "max": 0}
	var v := values.duplicate()
	v.sort()
	var total := 0.0
	for x in v:
		total += float(x)
	var pct := func(p: float): return v[clampi(int(floor(p * (v.size() - 1))), 0, v.size() - 1)]
	return {"mean": total / v.size(), "p10": pct.call(0.1), "p50": pct.call(0.5), "p90": pct.call(0.9), "min": v[0], "max": v[v.size() - 1]}

func summarize(rows: Array, enemy_data: Array, label: String) -> Dictionary:
	var n := rows.size()
	var wins := 0
	var losses := 0
	var timeouts := 0
	var col := func(k: String):
		var a: Array = []
		for r in rows:
			a.append(r.get(k, 0))
		return a
	var played: Dictionary = {}
	var seen: Dictionary = {}
	var affordable: Dictionary = {}
	var dmg_enemy: Dictionary = {}
	var act_enemy: Dictionary = {}
	var ability_uses: Dictionary = {}
	for r in rows:
		match r.result:
			"win": wins += 1
			"loss": losses += 1
			_: timeouts += 1
		for k in r.cards_played: played[k] = played.get(k, 0) + r.cards_played[k]
		for k in r.cards_seen: seen[k] = seen.get(k, 0) + r.cards_seen[k]
		for k in r.cards_affordable: affordable[k] = affordable.get(k, 0) + r.cards_affordable[k]
		for k in r.dmg_by_enemy: dmg_enemy[k] = dmg_enemy.get(k, 0) + r.dmg_by_enemy[k]
		for k in r.actions_by_enemy: act_enemy[k] = act_enemy.get(k, 0) + r.actions_by_enemy[k]
		for k in r.get("ability_uses", {}): ability_uses[k] = ability_uses.get(k, 0) + r.ability_uses[k]

	var per_ability: Array = []
	for char_id in ability_uses:
		var char_data := DataRegistry.get_character(char_id)
		var ability_name := "?"
		if char_data:
			var ab: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id)
			if ab:
				ability_name = ab.display_name
		per_ability.append({"character_id": char_id, "ability_name": ability_name, "uses_per_fight": float(ability_uses[char_id]) / n})

	# Deck catalogue (fresh deck of this party) → never-played diagnosis
	var catalogue: Array = []
	var deck_ids: Dictionary = {}
	for iid in RunState.deck_order:
		var dc: DeckCardData = RunState.deck[iid]
		if deck_ids.has(dc.card_id):
			deck_ids[dc.card_id] += 1
			continue
		deck_ids[dc.card_id] = 1
		var cd := DataRegistry.get_card_data(dc.card_id)
		var effs: PackedStringArray = []
		for e in CardRules.get_resolved_effects(dc):
			if e is EffectData:
				effs.append("%s%s" % [e.effect_type, str(e.params) if not e.params.is_empty() else ""])
		catalogue.append({"card_id": dc.card_id, "owner": dc.owner_character_id, "cost": CardRules.get_effective_cost(cd, dc),
			"type": CardData.CardType.keys()[cd.card_type], "targeting": CardData.TargetingMode.keys()[cd.targeting_mode],
			"keywords": CardRules.get_card_keywords(dc), "effects": ", ".join(effs)})
	for c in catalogue:
		c["copies"] = deck_ids[c.card_id]
	var never: Array = []
	for cid in deck_ids:
		if played.get(cid, 0) == 0:
			var reason := "unplayable (curse)" if DataRegistry.get_card_data(cid).card_type == CardData.CardType.CURSE else (
				"policy-starved: affordable at %d decision points but a cheaper card was always chosen" % affordable.get(cid, 0) if affordable.get(cid, 0) > 0 else
				"never affordable/legal when in hand (%d sightings)" % seen.get(cid, 0))
			never.append({"card_id": cid, "reason": reason})
	# also list cards that were only ever created mid-combat (curses etc.)
	for cid in played:
		if not deck_ids.has(cid):
			deck_ids[cid] = 0

	var per_card: Array = []
	for cid in deck_ids:
		per_card.append({"card_id": cid, "copies": deck_ids[cid], "plays": played.get(cid, 0), "plays_per_fight": float(played.get(cid, 0)) / n,
			"seen": seen.get(cid, 0), "affordable": affordable.get(cid, 0)})
	per_card.sort_custom(func(a, b): return a.plays > b.plays)

	var per_enemy: Array = []
	for eid in act_enemy:
		per_enemy.append({"enemy_id": eid, "actions_per_fight": float(act_enemy[eid]) / n, "hp_damage_per_fight": float(dmg_enemy.get(eid, 0)) / n})
	if dmg_enemy.has("(unattributed/self)"):
		per_enemy.append({"enemy_id": "(unattributed/self)", "actions_per_fight": 0.0, "hp_damage_per_fight": float(dmg_enemy["(unattributed/self)"]) / n})

	var turns_arr: Array = col.call("turns")
	var eu: Array = col.call("energy_unspent")
	var eu_per_turn: Array = []
	for i in range(n):
		eu_per_turn.append(float(eu[i]) / max(1, int(turns_arr[i]) - 1) if int(turns_arr[i]) > 1 else 0.0)

	return {
		"label": label, "party": cfg.party, "enemies": _enemies_str(enemy_data), "enemy_data": enemy_data,
		"act": int(cfg.act), "policy": cfg.policy, "n": n, "seed": int(cfg.seed), "max_turns": int(cfg.max_turns),
		"win_rate": float(wins) / n, "wins": wins, "deaths": losses, "timeouts": timeouts,
		"turns": stats(turns_arr), "cycles": stats(turns_arr), "ticks": stats(col.call("ticks")), "card_ticks": stats(col.call("card_ticks")),
		"enemy_actions": stats(col.call("enemy_actions")),
		"damage_taken": stats(col.call("damage_taken")), "hp_lost_gross": stats(col.call("hp_lost_gross")), "hp_end": stats(col.call("hp_end")), "hp_max": rows[0].hp_max if n > 0 else 0,
		"block_gained": stats(col.call("block_gained")), "block_wasted": stats(col.call("block_wasted")),
		"energy_unspent": stats(eu), "energy_unspent_per_turn": stats(eu_per_turn),
		"heal_wasted": stats(col.call("heal_wasted")),
		"cards_played_total": stats(col.call("cards_played_total")),
		"enemy_hp_left_on_loss": stats(_filter_col(rows, "enemy_hp_left", "loss")),
		"per_card": per_card, "never_played": never, "catalogue": catalogue, "per_enemy": per_enemy,
		"ability_uses_total": stats(col.call("ability_uses_total")), "per_ability": per_ability,
	}

func _filter_col(rows: Array, k: String, result: String) -> Array:
	var a: Array = []
	for r in rows:
		if r.result == result:
			a.append(r.get(k, 0))
	return a

# ── output ───────────────────────────────────────────────────────────────────

func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("sim: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(text)
	f.close()

const CSV_COLS := ["label", "party", "enemies", "act", "policy", "fight", "seed", "result", "turns", "ticks", "card_ticks",
	"enemy_actions", "damage_taken", "hp_lost_gross", "hp_end", "hp_max", "block_gained", "block_wasted", "energy_unspent", "heal_wasted", "cards_played_total", "enemy_hp_left", "ability_uses_total"]

func _append_csv(path: String, rows: Array, label: String) -> void:
	var exists := FileAccess.file_exists(path)
	var f := FileAccess.open(path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		push_error("sim: cannot write %s" % path)
		return
	if exists:
		f.seek_end()
	else:
		f.store_line(",".join(CSV_COLS))
	var enemies_s := _enemies_str(_build_enemy_data())
	for r in rows:
		var vals: PackedStringArray = []
		for c in CSV_COLS:
			match c:
				"label": vals.append('"%s"' % label)
				"party": vals.append('"%s"' % ",".join(cfg.party))
				"enemies": vals.append('"%s"' % enemies_s)
				"act": vals.append(str(cfg.act))
				"policy": vals.append(str(cfg.policy))
				_: vals.append(str(r.get(c, "")))
		f.store_line(",".join(vals))
	f.close()

static func _fmt(s: Dictionary) -> String:
	return "%.1f (p10 %s / p90 %s)" % [s.mean, str(s.p10), str(s.p90)]

func render_markdown(s: Dictionary) -> String:
	var L: PackedStringArray = []
	L.append("# Sim report — %s" % s.label)
	L.append("")
	L.append("Party `%s` vs `%s` act %d, policy `%s`, N=%d, seed %d, max_turns %d." % [",".join(s.party), s.enemies, s.act, s.policy, s.n, s.seed, s.max_turns])
	L.append("")
	L.append("| metric | mean (p10 / p90) |")
	L.append("|---|---|")
	L.append("| win rate | %.2f (deaths %d, timeouts %d) |" % [s.win_rate, s.deaths, s.timeouts])
	L.append("| turns | %s |" % _fmt(s.turns))
	L.append("| ticks (card ticks + 1 per end turn) | %s |" % _fmt(s.ticks))
	L.append("| enemy actions | %s |" % _fmt(s.enemy_actions))
	L.append("| net damage taken (of %d HP) | %s |" % [s.hp_max, _fmt(s.damage_taken)])
	L.append("| gross HP lost (before heals) | %s |" % _fmt(s.hp_lost_gross))
	L.append("| block gained / wasted | %s / %s |" % [_fmt(s.block_gained), _fmt(s.block_wasted)])
	L.append("| energy unspent per turn | %s |" % _fmt(s.energy_unspent_per_turn))
	L.append("| heals at full HP | %s |" % _fmt(s.heal_wasted))
	L.append("| cards played | %s |" % _fmt(s.cards_played_total))
	L.append("| ability uses (total) | %s |" % _fmt(s.ability_uses_total))
	L.append("")
	if not s.per_ability.is_empty():
		L.append("| character | ability | uses/fight |")
		L.append("|---|---|---|")
		for a in s.per_ability:
			L.append("| %s | %s | %.2f |" % [a.character_id, a.ability_name, a.uses_per_fight])
		L.append("")
	L.append("| card | copies | plays/fight | seen | affordable |")
	L.append("|---|---|---|---|---|")
	for c in s.per_card:
		L.append("| %s | %d | %.2f | %d | %d |" % [c.card_id, c.copies, c.plays_per_fight, c.seen, c.affordable])
	if not s.never_played.is_empty():
		L.append("")
		L.append("Never played:")
		for c in s.never_played:
			L.append("- `%s` — %s" % [c.card_id, c.reason])
	L.append("")
	L.append("| enemy | actions/fight | HP dmg/fight |")
	L.append("|---|---|---|")
	for e in s.per_enemy:
		L.append("| %s | %.2f | %.2f |" % [e.enemy_id, e.actions_per_fight, e.hp_damage_per_fight])
	if not s.findings.is_empty():
		L.append("")
		L.append("Sim findings:")
		for f in s.findings:
			L.append("- %s" % f)
	L.append("")
	return "\n".join(L)
