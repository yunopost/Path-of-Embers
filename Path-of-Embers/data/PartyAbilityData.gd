extends Resource
class_name PartyAbilityData

## Card-Clock Combat spec §7/§10.6: one persistent ability per character, always
## visible on the Ability Bar next to Focus. Not a card — no deck/discard/hand
## interaction. Cooldown is tracked in ticks by CombatController, not here.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""  # Mechanical text -- must fit on a button tooltip
@export var tick_cost: int = 0         # 0 or 1 per spec S7
@export var cooldown: int = 4          # In ticks; never above 6 per spec S7
@export var targeting_mode: CardData.TargetingMode = CardData.TargetingMode.SELF
@export var effects: Array[EffectData] = []
@export var icon_path: String = ""

func _init():
	effects = []
