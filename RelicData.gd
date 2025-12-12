extends Resource
class_name RelicData

## Relic data with rarity and effects

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	BOSS,
	SHOP
}

@export var id: String = ""
@export var name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var effects: Array[EffectData] = []
@export var icon_path: String = ""
@export var description: String = ""

func _init():
	effects = []

