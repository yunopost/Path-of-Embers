extends RefCounted
class_name PetBoard

## Manages all pets in play during a single combat.
##
## Design rules:
##   - FIFO ordering: index 0 = oldest (intercepts first, overflows first)
##   - Max 3 pets; overflow policy = DESTROY_OLDEST (fires ON_PET_DESTROYED)
##   - SHARED_POOL intercept: oldest pet absorbs damage first; spillover chains
##   - Assembly rule (Golemancer): Core + Arm + Armor → destroy all three → summon Ultimate Golem
##
## Holds a weak reference to CombatController so it can grant block / deal damage.

const MAX_PETS: int = 3
const OVERFLOW_POLICY: String = "DESTROY_OLDEST"

## Active pets, oldest-first
var pets: Array = []

## Turn counter (incremented by CombatController.start_player_turn)
var current_turn: int = 0

## Set by CombatController._pre_enemy_act before each enemy action; cleared after
var current_acting_enemy = null   # Enemy

## Weak reference to CombatController (never freed here)
var _cc = null   # CombatController

# ──────────────────────────────────────────────────────────────────────────────
func _init(p_combat_controller) -> void:
	_cc = p_combat_controller

# ═══════════════════════════  Pet Registry  ═══════════════════════════════════

func get_def(pet_def_id: String) -> PetDefinition:
	## Looks up a pet definition from DataRegistry.
	## All definitions are registered in DataRegistry._register_pet_definitions().
	## Equipment and relics may call DataRegistry.register_pet_def() to add more.
	return DataRegistry.get_pet_def(pet_def_id) if DataRegistry else null

# ═══════════════════════════  Summoning  ══════════════════════════════════════

func summon_pet(pet_def_id: String, hp_bonus: int = 0) -> PetInstance:
	## Summon a pet by definition id.  hp_bonus is added to base_max_hp (e.g. from upgrades).
	## Returns the new PetInstance, or null if the definition is unknown.
	var def: PetDefinition = get_def(pet_def_id)
	if not def:
		push_error("PetBoard.summon_pet: unknown pet_def_id '%s'" % pet_def_id)
		return null

	# Overflow handling
	while pets.size() >= MAX_PETS:
		match OVERFLOW_POLICY:
			"DESTROY_OLDEST":
				if pets.size() > 0:
					_destroy_pet(pets[0])
				else:
					break
			_:
				break

	# Generate unique instance id
	var base_id: String = "pet_%d_%s" % [current_turn, pet_def_id]
	var instance_id: String = base_id
	var counter: int = 0
	while _find_pet(instance_id) != null:
		counter += 1
		instance_id = "%s_%d" % [base_id, counter]

	var inst: PetInstance = PetInstance.new(instance_id, def, current_turn)

	# Apply explicit hp_bonus (upgrades, etc.)
	if hp_bonus > 0:
		inst.max_hp += hp_bonus
		inst.hp = inst.max_hp

	# Apply Grand Assembly passive bonus (if Power card is in play)
	_apply_grand_assembly_bonus(inst, def)

	pets.append(inst)
	_refresh_interceptor()

	# Triggers
	_fire_hook_on_pet("ON_PET_SUMMONED", {}, inst)
	check_assembly()

	return inst

# ═══════════════════════════  Removal  ════════════════════════════════════════

func _destroy_pet(inst: PetInstance) -> void:
	## Fire ON_PET_DESTROYED triggers, then remove pet from board.
	if not inst:
		return
	_fire_hook_on_pet("ON_PET_DESTROYED", {}, inst)
	pets.erase(inst)
	_refresh_interceptor()

func _remove_pet_silently(inst: PetInstance) -> void:
	## Remove without triggering ON_PET_DESTROYED (internal use only).
	pets.erase(inst)
	_refresh_interceptor()

# ═══════════════════════════  Damage Interception  ════════════════════════════

func intercept_damage(raw_damage: int) -> int:
	## Called from EntityStats.take_damage via the damage_interceptor Callable.
	## Routes post-vulnerable, pre-block damage through SHARED_POOL pets (oldest first).
	## Returns remaining damage that the player's block/hp must handle.
	if raw_damage <= 0:
		return 0

	var remaining: int = raw_damage

	# Snapshot to avoid mutation issues during iteration (pets may die mid-loop)
	var shared_pets: Array = []
	for p in pets:
		if p.intercept_mode == "SHARED_POOL":
			shared_pets.append(p)

	for pet in shared_pets:
		if remaining <= 0:
			break
		if not pet.is_alive():
			continue

		var absorbed: int = min(remaining, pet.hp)
		pet.hp -= absorbed
		remaining -= absorbed

		# ON_PET_DAMAGED hook
		_fire_hook_on_pet("ON_PET_DAMAGED", {"damage": absorbed}, pet)

		if pet.hp <= 0:
			# Pet dies from this damage
			_destroy_pet(pet)
		else:
			# Pet survived — mark for Reinforced Frame check
			pet.damaged_not_destroyed_this_action = true

	_refresh_interceptor()
	return remaining

# ═══════════════════════════  Hook Dispatch  ==================================

func fire_hook(hook: String, params: Dictionary) -> void:
	## Fire a hook for every alive pet currently in play.
	## Iterates a snapshot so pets can be safely removed during iteration.
	for pet in pets.duplicate():
		if pet.is_alive():
			_fire_hook_on_pet(hook, params, pet)

func _fire_hook_on_pet(hook: String, params: Dictionary, pet: PetInstance) -> void:
	for trigger in pet.triggers:
		if trigger.get("hook", "") == hook:
			_execute_trigger(trigger, pet)

func _execute_trigger(trigger: Dictionary, _from_pet: PetInstance) -> void:
	var action: String = trigger.get("action", "")
	var amount: int = int(trigger.get("amount", 0))

	match action:
		"gain_block":
			_grant_player_block(amount)

		"damage_acting_enemy":
			_damage_enemy(current_acting_enemy, amount)

		"damage_attacker_or_random":
			var target = current_acting_enemy if (current_acting_enemy != null and current_acting_enemy.stats.is_alive()) else _get_random_alive_enemy()
			_damage_enemy(target, amount)

		"damage_random_enemy":
			_damage_enemy(_get_random_alive_enemy(), amount)

		_:
			if not action.is_empty():
				push_warning("PetBoard: unrecognised trigger action '%s'" % action)

# ═══════════════════════════  Golemancer Assembly  ════════════════════════════

func check_assembly() -> void:
	## If Core + Arm + Armor are all in play and no Ultimate exists → assemble.
	## Fires ON_PET_DESTROYED on each consumed piece (Golem Arm deals damage on assembly!).
	if _has_tag_alive("Ultimate"):
		return   # Only one Ultimate at a time

	var core_pet:  PetInstance = _oldest_alive_with_tag("Core")
	var arm_pet:   PetInstance = _oldest_alive_with_tag("Arm")
	var armor_pet: PetInstance = _oldest_alive_with_tag("Armor")

	if core_pet == null or arm_pet == null or armor_pet == null:
		return

	# Consume components — each fires ON_PET_DESTROYED
	_destroy_pet(core_pet)
	_destroy_pet(arm_pet)
	_destroy_pet(armor_pet)

	# Summon the Ultimate Golem (no hp_bonus here; Grand Assembly bonus applies inside summon_pet)
	summon_pet("ultimate_golem")

# ═══════════════════════════  Combat Lifecycle Hooks  =========================

func on_start_player_turn() -> void:
	current_turn += 1
	fire_hook("START_OF_PLAYER_TURN", {})
	check_assembly()

func on_end_player_turn() -> void:
	fire_hook("END_OF_PLAYER_TURN", {})
	# Clear per-turn pet flags
	for pet in pets:
		pet.reinforced_this_turn = false

func on_enemy_acted(enemy) -> void:
	## Call this from CombatController._on_enemy_acted, passing the acting Enemy.
	## Fires WHEN_ENEMY_ACTS on all pets, then checks Reinforced Frame draw.
	current_acting_enemy = enemy
	fire_hook("WHEN_ENEMY_ACTS", {})
	_check_reinforced_frame_draw()
	clear_action_flags()
	current_acting_enemy = null

func clear_action_flags() -> void:
	## Reset per-action flags on all pets.  Called after each enemy action resolves.
	for pet in pets:
		pet.damaged_not_destroyed_this_action = false

# ═══════════════════════════  Helpers (Public)  ═══════════════════════════════

func get_oldest_alive() -> PetInstance:
	for pet in pets:
		if pet.is_alive():
			return pet
	return null

func get_all_alive() -> Array:
	var result: Array = []
	for pet in pets:
		if pet.is_alive():
			result.append(pet)
	return result

func has_alive_pets() -> bool:
	for pet in pets:
		if pet.is_alive():
			return true
	return false

func count_alive() -> int:
	var n: int = 0
	for pet in pets:
		if pet.is_alive():
			n += 1
	return n

## Used by Grand Assembly immediate-trigger check (EffectResolver)
func can_assemble() -> bool:
	return (not _has_tag_alive("Ultimate")
			and _oldest_alive_with_tag("Core") != null
			and _oldest_alive_with_tag("Arm") != null
			and _oldest_alive_with_tag("Armor") != null)

# ═══════════════════════════  Helpers (Private)  ══════════════════════════════

func _has_tag_alive(tag: String) -> bool:
	for pet in pets:
		if pet.is_alive() and pet.has_tag(tag):
			return true
	return false

func _oldest_alive_with_tag(tag: String) -> PetInstance:
	## Index 0 = oldest (FIFO)
	for pet in pets:
		if pet.is_alive() and pet.has_tag(tag):
			return pet
	return null

func _find_pet(instance_id: String) -> PetInstance:
	for pet in pets:
		if pet.pet_instance_id == instance_id:
			return pet
	return null

func _has_shared_pool_pets() -> bool:
	for pet in pets:
		if pet.is_alive() and pet.intercept_mode == "SHARED_POOL":
			return true
	return false

func _refresh_interceptor() -> void:
	## Set or clear EntityStats.damage_interceptor based on current pet state.
	if not _cc:
		return
	var ps: EntityStats = _cc.player_stats if _cc.has("player_stats") else null
	if not ps:
		return
	if _has_shared_pool_pets():
		ps.damage_interceptor = Callable(self, "intercept_damage")
	else:
		ps.damage_interceptor = Callable()  # Clear (invalid Callable)

func _apply_grand_assembly_bonus(inst: PetInstance, def: PetDefinition) -> void:
	## If Grand Assembly power is active and this is a Construct pet, apply HP bonus.
	if not ("Construct" in def.tags):
		return
	if not _cc:
		return
	var ps: EntityStats = _cc.player_stats if _cc.has("player_stats") else null
	if not ps:
		return
	var ga_bonus = ps.get_status(StatusEffectType.GRAND_ASSEMBLY_ACTIVE)
	if ga_bonus != null and int(ga_bonus) > 0:
		var bonus: int = int(ga_bonus)
		inst.max_hp += bonus
		inst.hp = min(inst.hp + bonus, inst.max_hp)

func _grant_player_block(amount: int) -> void:
	if not _cc:
		return
	var ps: EntityStats = _cc.player_stats if _cc.has("player_stats") else null
	if ps:
		ps.add_block(amount)
		if ResourceManager:
			ResourceManager.set_block(ps.block)

func _damage_enemy(enemy, amount: int) -> void:
	if not enemy:
		return
	if enemy.stats.is_alive():
		enemy.stats.take_damage(amount, false)

func _get_random_alive_enemy():
	if not _cc or not _cc.has("enemies"):
		return null
	var alive: Array = []
	for enemy in _cc.enemies:
		if enemy.stats.is_alive():
			alive.append(enemy)
	if alive.is_empty():
		return null
	return alive[randi() % alive.size()]

# ═══════════════════════════  Serialisation (prep work)  ═════════════════════
## These methods are not yet wired into SaveManager because there is no
## mid-combat save path.  They exist so that when a checkpoint save is added
## in a future phase, PetBoard state can be round-tripped without rework.

func get_state() -> Dictionary:
	## Serialise the current board state (active pets + turn counter).
	var pets_data: Array = []
	for pet in pets:
		pets_data.append(pet.to_dict())
	return {
		"current_turn": current_turn,
		"pets": pets_data,
	}

func restore_state(data: Dictionary) -> void:
	## Restore board state from get_state() output.
	pets.clear()
	current_turn = data.get("current_turn", 0)
	for pet_data in data.get("pets", []):
		var inst: PetInstance = PetInstance.from_dict(pet_data)
		if inst:
			pets.append(inst)
	_refresh_interceptor()

# ═══════════════════════════  Helpers (Private)  ══════════════════════════════

func _check_reinforced_frame_draw() -> void:
	## After WHEN_ENEMY_ACTS, draw cards for any reinforced pet that survived damage.
	if not _cc:
		return
	for pet in pets:
		if pet.reinforced_this_turn and pet.damaged_not_destroyed_this_action:
			var draw_count: int = int(pet.stacks.get("draw_if_survives", 0))
			if draw_count > 0:
				RunState.draw_cards(draw_count)
			# One-shot — clear to avoid drawing on every subsequent action
			pet.reinforced_this_turn = false
			pet.stacks.erase("draw_if_survives")
