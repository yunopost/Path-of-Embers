extends Resource
class_name PartyAbilityData

## Card-Clock Combat spec §7/§10.6: one persistent ability per character, always
## visible on the Ability Bar next to Focus. Not a card — no deck/discard/hand
## interaction. Cooldown is tracked in ticks by CombatController, not here.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""  # Mechanical text -- must fit on a button tooltip
@export var tick_cost: int = 0         # 0 or 1 per spec S7
@export var cooldown: int = 4          # In ticks; 0 = no cooldown (Addendum S2)
@export var targeting_mode: CardData.TargetingMode = CardData.TargetingMode.SELF

## Heterogeneous cost block (Addendum S2). Any combination is legal, including
## all-zero (no cost besides cooldown/ticks). can_use_ability() checks every
## declared cost is payable; use_ability() pays them all before resolving effects.
@export var energy_cost: int = 0
@export var discard_cost: int = 0      # Cards discarded from hand to pay this ability's cost
@export var hp_cost: int = 0           # HP lost to pay this ability's cost (bypasses Block)
@export var consumes_block: bool = false  # If true, Block is zeroed AFTER effects resolve
@export var effects: Array[EffectData] = []
@export var icon_path: String = ""

func _init():
	effects = []
