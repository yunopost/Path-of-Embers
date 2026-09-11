extends Node
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		print("FAIL: ", label)
func _ready() -> void:
	call_deferred("probe")
func probe() -> void:
	for i in range(5):
		await get_tree().process_frame
	var meta := SaveManager._load_raw_meta()
	meta.erase("equipment_policy")
	meta["persistent_stash"] = ["legacy_gear", "other_gear"]
	meta["polish_unlock_marker"] = ["warrior_2", "grove"]
	SaveManager._write_raw_meta(meta)
	SaveManager.archive_legacy_stash()
	check(FileAccess.file_exists("user://meta-before-equipment-reset.json"), "legacy equipment backup exists")
	check(SaveManager._load_raw_meta().get("polish_unlock_marker") == meta["polish_unlock_marker"], "migration retains unrelated progress")
	RunState.reset_run()
	check(RunState.run_stash == SaveManager.STARTER_EQUIPMENT, "New Run installs only starter equipment")
	check(RunState.backpack.is_empty() and RunState.equipment_slots.is_empty(), "New Run clears backpack and equipped gear")
	RunState.run_stash.append("focus_stone")
	RunState.backpack.append("iron_helm")
	var saved := SaveManager._serialize_run_state()
	RunState.reset_run()
	SaveManager._deserialize_run_state(saved)
	check(RunState.run_stash.has("focus_stone") and RunState.backpack.has("iron_helm"), "Continue restores run equipment")
	SaveManager.archive_legacy_stash()
	check(RunState.run_stash.has("focus_stone"), "revisiting loadout preserves current stash")
	RunState.reset_run()
	check(not RunState.run_stash.has("focus_stone") and not RunState.run_stash.has("legacy_gear"), "second New Run imports no old equipment")
	PartyManager.set_party(["warrior_1", "witch", "living_armor"])
	var chars: Array[CharacterData] = []
	for id in PartyManager.party_ids:
		chars.append(DataRegistry.get_character(id))
	RunState.generate_starter_deck(chars)
	var cc := CombatController.new()
	add_child(cc)
	cc.start_combat([{"enemy_id":"ash_man", "count":1}])
	cc.enemies[0].time_current = 100
	cc.player_stats.apply_status(StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE, 3)
	var ticks := cc.get_total_ticks()
	cc.breathe()
	check(cc.get_total_ticks() == ticks + 1, "Breathe advances exactly one tick")
	check(cc.player_stats.get_status(StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE) != null, "Breathe does not resolve a legacy cycle reward")
	cc.focus()
	check(cc.get_total_ticks() == ticks + 2, "Focus advances exactly one tick")
	check(cc.player_stats.get_status(StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE) != null, "Focus does not resolve a legacy cycle reward")
	cc._pre_enemy_act(cc.enemies[0])
	check(cc.player_stats.get_status(StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE) == null, "enemy action consumes pending no-damage reward")
	cc.free()
	print("--- demo_polish summary: %d passed, %d failed ---" % [passed, failed])
	get_tree().quit(1 if failed else 0)
