extends RefCounted
class_name EncounterDirector

## Builds enemy compositions for combat nodes based on act and node type.
##
## Pacing targets (starter deck deals roughly 12-18 damage per turn):
##   Standard fight:  ~40-65 total HP  → resolves in ~3-4 turns
##   Elite fight:     ~60-80 total HP  → resolves in ~5 turns
##   Boss fight:      authored per-act stat blocks, no extra scaling
##
## Acts 2 and 3 currently reuse the Act 1 roster with HP/damage multipliers.
## Replace with real Act 2/3 enemy data during the content pass (M4).

const ACT_HP_MULT := {1: 1.0, 2: 1.6, 3: 2.2}
const ACT_DMG_MULT := {1: 1.0, 2: 1.3, 3: 1.6}

## Standard fight compositions (total HP ranges shown for Act 1).
const FIGHT_POOLS: Array = [
	[{"enemy_id": "cinder_imp", "count": 2}],                                    # 36-48
	[{"enemy_id": "smolder_shade", "count": 1}, {"enemy_id": "cinder_imp", "count": 1}],  # 46-58
	[{"enemy_id": "ash_man", "count": 1}],                                       # 38-44
	[{"enemy_id": "smolder_shade", "count": 2}],                                 # 56-68
	[{"enemy_id": "ember_brute", "count": 1}],                                   # 55-65
	[{"enemy_id": "ash_man", "count": 1}, {"enemy_id": "cinder_imp", "count": 1}],        # 56-68
]

const ELITE_POOLS: Array = [
	[{"enemy_id": "ashen_knight", "count": 1}],   # 60-72
	[{"enemy_id": "char_sentinel", "count": 1}],  # 70-80
]

static func build_encounter(act: int, node_type: int) -> Dictionary:
	## Returns {"enemies": [{"enemy_id", "count", "hp_mult", "dmg_mult"}, ...]}
	var clamped_act: int = clampi(act, 1, 3)

	# Bosses: authored per-act stat blocks — spawn directly, no scaling
	if node_type == MapNodeData.NodeType.BOSS or node_type == MapNodeData.NodeType.FINAL_BOSS:
		var boss_act: int = 3 if node_type == MapNodeData.NodeType.FINAL_BOSS else clamped_act
		return {"enemies": [{"enemy_id": "boss_act%d" % boss_act, "count": 1}]}

	var pool: Array = ELITE_POOLS if node_type == MapNodeData.NodeType.ELITE else FIGHT_POOLS
	var composition: Array = pool[randi() % pool.size()].duplicate(true)

	var hp_mult: float = ACT_HP_MULT.get(clamped_act, 1.0)
	var dmg_mult: float = ACT_DMG_MULT.get(clamped_act, 1.0)
	for enemy_info in composition:
		enemy_info["hp_mult"] = hp_mult
		enemy_info["dmg_mult"] = dmg_mult

	return {"enemies": composition}
