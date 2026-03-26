extends RefCounted
class_name PetInstance

## Runtime state of a single summoned pet.
## Created from a PetDefinition blueprint; lives until removed from PetBoard.

var pet_instance_id: String = ""
var pet_def_id: String = ""
var display_name: String = ""
var tags: Array[String] = []
var max_hp: int = 0
var hp: int = 0
var created_turn: int = 0
var duration_turns: int = -1          ## -1 = permanent
var stacks: Dictionary = {}           ## Flexible counter storage for special effects
var triggers: Array = []              ## Copied from PetDefinition at summon time
var intercept_mode: String = "NONE"

## Per-enemy-action flags — reset by PetBoard.clear_action_flags()
var damaged_not_destroyed_this_action: bool = false

## Persistent-until-cleared flag set by the Reinforced Frame card
var reinforced_this_turn: bool = false

func _init(p_instance_id: String, p_def: PetDefinition, p_turn: int) -> void:
	pet_instance_id = p_instance_id
	pet_def_id = p_def.pet_def_id
	display_name = p_def.display_name
	tags = p_def.tags.duplicate()
	max_hp = p_def.base_max_hp
	hp = max_hp
	created_turn = p_turn
	triggers = p_def.triggers.duplicate(true)
	intercept_mode = p_def.intercept_mode

func has_tag(tag: String) -> bool:
	return tag in tags

func is_alive() -> bool:
	return hp > 0

func to_dict() -> Dictionary:
	## Serialise runtime state. Triggers and tags are re-derived from the
	## PetDefinition on restore, so we only save mutable state here.
	return {
		"pet_instance_id": pet_instance_id,
		"pet_def_id": pet_def_id,
		"max_hp": max_hp,
		"hp": hp,
		"created_turn": created_turn,
		"duration_turns": duration_turns,
		"stacks": stacks.duplicate(),
		"intercept_mode": intercept_mode,
	}

static func from_dict(data: Dictionary) -> PetInstance:
	## Restore a PetInstance from serialised data.
	## Requires DataRegistry to have the PetDefinition registered.
	var def: PetDefinition = DataRegistry.get_pet_def(data.get("pet_def_id", "")) if DataRegistry else null
	if not def:
		push_error("PetInstance.from_dict: unknown pet_def_id '%s'" % data.get("pet_def_id", ""))
		return null
	var inst := PetInstance.new(data.get("pet_instance_id", ""), def, data.get("created_turn", 0))
	inst.max_hp = data.get("max_hp", def.base_max_hp)
	inst.hp = data.get("hp", inst.max_hp)
	inst.duration_turns = data.get("duration_turns", -1)
	inst.stacks = data.get("stacks", {}).duplicate()
	inst.intercept_mode = data.get("intercept_mode", def.intercept_mode)
	return inst
