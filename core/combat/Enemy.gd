extends RefCounted
class_name Enemy

## Represents an enemy in combat with timer and intent system

signal time_changed(current: int, max: int)
signal intent_changed(intent: IntentData)
signal died

var enemy_id: String = ""
var name: String = ""
var stats: EntityStats
var intent: IntentData = null  # Next action this enemy will take
var time_max: int = 3
var time_current: int = 3

func _init(p_enemy_id: String, p_name: String, p_max_hp: int, p_time_max: int = 3):
	enemy_id = p_enemy_id
	name = p_name
	stats = EntityStats.new(p_max_hp, p_max_hp)
	time_max = p_time_max
	time_current = p_time_max
	
	# Connect to stats.died signal
	stats.died.connect(_on_stats_died)

func _on_stats_died():
	## Forward the died signal when stats indicate death
	died.emit()

func set_intent(new_intent: IntentData):
	## Set the enemy's intent
	intent = new_intent
	intent_changed.emit(intent)

func get_intent() -> IntentData:
	return intent

func perform_intent(combat_controller: CombatController):
	## Execute the enemy's intent
	## For Slice 4: handles "Attack" intents
	if not intent:
		return
	
	if not stats.is_alive():
		return
	
	match intent.intent_type:
		"Attack":
			var damage = intent.values.get("damage", 0)
			
			# Apply damage to player using EffectResolver for consistency
			var attack_effect = EffectData.new("damage", {"amount": damage})
			EffectResolver.resolve_effect(attack_effect, stats, combat_controller.player_stats)
			
			# Update RunState HP and block after damage
			RunState.set_hp(combat_controller.player_stats.current_hp, combat_controller.player_stats.max_hp)
			RunState.set_block(combat_controller.player_stats.block)
		
		_:
			push_warning("Unknown intent type: " + intent.intent_type)
