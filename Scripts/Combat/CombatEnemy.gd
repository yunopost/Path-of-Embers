extends RefCounted
class_name CombatEnemy

## Represents an enemy in combat

var enemy_id: String = ""
var name: String = ""
var stats: EntityStats
var intent: EffectData = null  # Next action this enemy will take

func _init(p_enemy_id: String, p_name: String, p_max_hp: int):
	enemy_id = p_enemy_id
	name = p_name
	stats = EntityStats.new(p_max_hp, p_max_hp)

func set_intent(effect: EffectData):
	intent = effect

func get_intent() -> EffectData:
	return intent

