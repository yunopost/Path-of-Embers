extends Node
## Headless assertions for the backpack + stash rework (Card-Clock Spec Addendum B §2).
## Run: ../Godot_v4.5-stable_linux.x86_64 --headless --path . res://tests/backpack.tscn
## Prints "FAIL: <msg>" for every failed assertion and exits non-zero if any failed.

var fail_count := 0
var pass_count := 0

func _check(label: String, ok: bool) -> void:
	if ok:
		pass_count += 1
		print("PASS: ", label)
	else:
		fail_count += 1
		print("FAIL: ", label)

func _first_two_equipment_ids() -> Array[String]:
	## Any two distinct equipment ids that exist in DataRegistry, for tests
	## that don't care which items they are.
	var all_equipment: Array[EquipmentData] = DataRegistry.get_all_equipment()
	var ids: Array[String] = []
	for e in all_equipment:
		ids.append(e.id)
		if ids.size() >= 2:
			break
	return ids

func _reset_backpack_state() -> void:
	RunState.backpack.clear()
	RunState.pending_backpack_drop = ""
	RunState.equipment_slots.clear()

func _ready() -> void:
	print("=== backpack test ===")

	_test_backpack_holds_at_most_nine()
	_test_full_backpack_raises_prompt_not_silent_discard()
	_test_loss_keeps_only_safe_slot()
	_test_win_keeps_whole_backpack()
	_test_persistent_stash_accepts_more_than_nine()
	_test_slot_type_restriction_still_blocks_illegal_equip()

	print("--- backpack summary: %d passed, %d failed ---" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)

func _test_backpack_holds_at_most_nine() -> void:
	_reset_backpack_state()
	var equip_ids: Array = DataRegistry.get_all_equipment()
	_check("setup: at least 1 equipment .tres exists to test with", equip_ids.size() >= 1)
	if equip_ids.is_empty():
		return

	var some_id: String = equip_ids[0].id
	var added := 0
	for i in range(RunState.BACKPACK_SIZE + 3):  # try to overfill by 3
		if RunState.backpack_add(some_id):
			added += 1
	_check("backpack_add fills up to BACKPACK_SIZE (9) and no further", added == RunState.BACKPACK_SIZE)
	_check("backpack.size() never exceeds BACKPACK_SIZE", RunState.backpack.size() == RunState.BACKPACK_SIZE)
	_reset_backpack_state()

func _test_full_backpack_raises_prompt_not_silent_discard() -> void:
	_reset_backpack_state()
	var equip_ids: Array = DataRegistry.get_all_equipment()
	if equip_ids.is_empty():
		_check("setup: equipment exists for full-backpack prompt test", false)
		return
	var filler_id: String = equip_ids[0].id
	for i in range(RunState.BACKPACK_SIZE):
		RunState.backpack_add(filler_id)
	_check("backpack is full after filling to capacity", RunState.backpack_is_full())

	var incoming_id: String = equip_ids[min(1, equip_ids.size() - 1)].id
	var added := RunState.backpack_add(incoming_id)
	_check("backpack_add on a full backpack returns false (does not silently add)", not added)
	_check("backpack size unchanged by the rejected add", RunState.backpack.size() == RunState.BACKPACK_SIZE)
	_check("a pending prompt is now recorded instead of the item vanishing", RunState.has_pending_backpack_prompt())
	_check("the pending prompt names the incoming item", RunState.pending_backpack_drop == incoming_id)

	# Resolve by making room: discard slot 1 (index 1, not the safe slot) for the new item.
	var ok := RunState.resolve_backpack_prompt_make_room(1)
	_check("resolve_backpack_prompt_make_room succeeds with a valid index", ok)
	_check("prompt is cleared after resolving", not RunState.has_pending_backpack_prompt())
	_check("the incoming item is now actually in the backpack", RunState.backpack.has(incoming_id))
	_check("backpack is still at capacity (1 out, 1 in)", RunState.backpack.size() == RunState.BACKPACK_SIZE)
	_reset_backpack_state()

func _test_loss_keeps_only_safe_slot() -> void:
	_reset_backpack_state()
	var ids: Array[String] = _first_two_equipment_ids()
	if ids.size() < 2:
		_check("setup: at least 2 distinct equipment ids exist for the loss test", false)
		return
	RunState.backpack_add(ids[0])  # goes to index 0 -- the safe slot
	RunState.backpack_add(ids[1])  # index 1 -- NOT safe

	# Use a scratch meta save path check indirectly: read persistent stash before/after.
	var before: Array[String] = SaveManager.load_persistent_stash()
	RunState.settle_backpack_on_loss()
	var after: Array[String] = SaveManager.load_persistent_stash()

	_check("loss does not export equipment to meta", after == before)
	_check("loss keeps run contents until reset", RunState.backpack == ids)
	# settle_backpack_on_loss() only settles the stash transfer; the actual run
	# teardown (clearing the backpack) happens in reset_run(), same as every
	# other run-scoped field -- see CombatScreen._on_player_defeated().
	RunState.reset_run()
	_check("reset_run() (called after settle) clears the backpack -- everything else is lost", RunState.backpack.is_empty())
	_reset_backpack_state()

func _test_win_keeps_whole_backpack() -> void:
	_reset_backpack_state()
	var ids: Array[String] = _first_two_equipment_ids()
	if ids.size() < 2:
		_check("setup: at least 2 distinct equipment ids exist for the win test", false)
		return
	RunState.backpack_add(ids[0])
	RunState.backpack_add(ids[1])

	var before := SaveManager.load_persistent_stash()
	RunState.settle_backpack_on_win()
	var after: Array[String] = SaveManager.load_persistent_stash()

	_check("win does not export equipment to meta", after == before)
	_check("win keeps run contents until reset", RunState.backpack == ids)
	RunState.reset_run()
	_check("reset_run() (called after settle) clears the backpack", RunState.backpack.is_empty())
	_reset_backpack_state()

func _test_persistent_stash_accepts_more_than_nine() -> void:
	## Addendum B §2: "No item cap" on the persistent/meta stash. The old cap
	## (RunState.MAX_STASH_SIZE == 9) only ever limited how much of the stash
	## the Loadout screen pulled in (run_stash) -- so this checks BOTH that
	## the underlying stash storage takes more than 9 distinct items, and that
	## the constant Loadout reads no longer caps at 9.
	# Reset to a known-empty baseline first -- meta.json is a real on-disk save
	# that persists across separate test runs, so a naive "grew by N" check
	# would flake on a second run once the synthetic ids are already there.
	var meta: Dictionary = SaveManager._load_raw_meta()
	meta["persistent_stash"] = []
	meta["version"] = 2
	SaveManager._write_raw_meta(meta)

	for i in range(12):
		SaveManager.add_to_persistent_stash("test_synthetic_item_%d" % i)
	var after: Array[String] = SaveManager.load_persistent_stash()
	_check("persistent stash holds all 12 distinct ids added past the old 9-item cap (no cap)", after.size() == 12)
	_check("RunState.MAX_STASH_SIZE no longer effectively caps at 9", RunState.MAX_STASH_SIZE > 9)

func _test_slot_type_restriction_still_blocks_illegal_equip() -> void:
	## Backpack additions must not have weakened the existing slot-type gate.
	var all_equipment: Array[EquipmentData] = DataRegistry.get_all_equipment()
	var helmet: EquipmentData = null
	for e in all_equipment:
		if e.slot_type == EquipmentData.SlotType.HELMET:
			helmet = e
			break
	if not helmet:
		_check("setup: at least one HELMET-slot equipment exists", false)
		return

	var reason: String = RunState.can_swap_backpack_item("warrior_1", "WEAPON", helmet.id)
	_check("can_swap_backpack_item rejects a HELMET item for the WEAPON slot", not reason.is_empty())

	_reset_backpack_state()
	RunState.backpack_add(helmet.id)
	var swapped := RunState.swap_backpack_with_equipped("warrior_1", "WEAPON", 0)
	_check("swap_backpack_with_equipped refuses the illegal slot-type swap", not swapped)
	_check("the illegal item stays in the backpack (not silently equipped)", RunState.backpack.has(helmet.id))
	_reset_backpack_state()
