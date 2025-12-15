extends Resource
class_name EnemyData

## Enemy data with HP, intents, and art references

@export var id: String = ""
@export var name: String = ""
@export var max_hp: int = 50
@export var intents: Array[EffectData] = []  # Enemy intents/actions
@export var portrait_path: String = ""
@export var fullbody_path: String = ""

func _init():
	intents = []

