extends Resource
class_name MilestoneData

## Immutable blueprint for a one-time achievement milestone.
## Stored as .tres resource files in data/milestones/.
##
## Condition evaluation uses the same event bus as QuestSystem.
## Milestones fire immediately when their condition is met during any run,
## then write to the meta save — they are never re-evaluated once completed.
##
## ── Supported condition_type values ──────────────────────────────────────
##   "complete_run"           — finish a full run (FINAL_BOSS_DEFEATED event)
##   "complete_nodes"         — complete condition_count nodes total
##   "win_elites"             — defeat condition_count elite nodes
##   "win_boss"               — defeat any boss node (condition_count times)
##   "gain_relics"            — pick up condition_count relics
##   "gain_gold"              — accumulate condition_count gold in one run
##   "character_used"         — complete a run with character in condition_params["character_id"]
##   "choose_encounter_option"— trigger ENCOUNTER_CHOICE with condition_params["choice_id"]
##
## ── Supported unlock_type values ─────────────────────────────────────────
##   "character"              — unlock a character for party selection
##   "modifier"               — unlock a difficulty modifier
##   "boss_rush_boss"         — unlock a boss for Boss Rush mode
##   "story"                  — mark a story beat as seen
##   "map_path"               — unlock an alternate map path variant

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""

## Shown on the character card / modifier list when the unlock is still locked.
## Good format: "Complete a run to unlock."
@export var unlock_hint: String = ""

## Condition ─────────────────────────────────────────────────────────────────
@export var condition_type: String = ""
@export var condition_params: Dictionary = {}  ## Extra match criteria (e.g. {"character_id": "warrior_1"})
@export var condition_count: int = 1           ## How many times the condition must be met

## Unlock ─────────────────────────────────────────────────────────────────────
@export var unlock_type: String = ""    ## "character" | "modifier" | "boss_rush_boss" | "story" | "map_path"
@export var unlock_target: String = ""  ## character_id, modifier_id, etc.

func _init():
	condition_params = {}
