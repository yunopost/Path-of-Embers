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

# Move history and AI state
var enemy_data: EnemyData = null  # Reference to blueprint (loaded on demand)
var move_history: Array[String] = []  # Last 2 move IDs for AI anti-repetition

func _init(p_enemy_id: String, p_name: String, p_max_hp: int, p_time_max: int = 3):
	enemy_id = p_enemy_id
	name = p_name
	stats = EntityStats.new(p_max_hp, p_max_hp)
	time_max = p_time_max
	time_current = p_time_max
	move_history = []  # Initialize move history for AI
	
	# Connect to stats.died signal
	stats.died.connect(_on_stats_died)

func _on_stats_died():
	## Forward the died signal when stats indicate death
	died.emit()

func set_intent(new_intent: IntentData, update_timer: bool = false):
	## Set the enemy's intent
	## update_timer: if true, also update time_current to match time_max (for initial intent)
	intent = new_intent
	
	# Update time_max if intent has a time_max_override (move-specific timer)
	if new_intent and new_intent.time_max_override > 0:
		time_max = new_intent.time_max_override
		# Update time_current if requested (for initial intent) or if timer was at 0 (after action)
		if update_timer or time_current == 0:
			time_current = time_max
	
	intent_changed.emit(intent)

func get_intent() -> IntentData:
	return intent

func get_next_move() -> Dictionary:
	## Get the next move to perform using AI rules with anti-repetition
	## Returns a move Dictionary from EnemyData.moves
	
	# Load EnemyData if not already loaded
	if not enemy_data:
		enemy_data = DataRegistry.get_enemy(enemy_id)
	
	if not enemy_data or enemy_data.moves.is_empty():
		return {}
	
	# Calculate weights for each move based on history
	var move_weights: Array[float] = []
	for move in enemy_data.moves:
		var move_id = move.get("id", "")
		var weight = get_move_weight(move_id)
		move_weights.append(weight)
	
	# Weighted random selection
	var selected_move = weighted_random_select(enemy_data.moves, move_weights)
	
	# Update history (keep last 2)
	if selected_move.has("id"):
		move_history.push_front(selected_move.get("id", ""))
		if move_history.size() > 2:
			move_history.pop_back()
	
	return selected_move

func get_move_weight(move_id: String) -> float:
	## Calculate weight for a move based on history (anti-repetition rules)
	var weight = 1.0
	
	# If last move matches, reduce weight by 50%
	if move_history.size() >= 1 and move_history[0] == move_id:
		weight *= 0.5
	
	# If last 2 moves match, prevent 3 in a row (weight = 0)
	if move_history.size() >= 2 and move_history[0] == move_id and move_history[1] == move_id:
		weight = 0.0
	
	return weight

func weighted_random_select(items: Array, weights: Array) -> Dictionary:
	## Perform weighted random selection from items array
	if items.is_empty():
		return {}
	
	# Calculate total weight
	var total_weight = 0.0
	for weight in weights:
		total_weight += float(weight)
	
	if total_weight <= 0.0:
		# Fallback if all weights are 0
		return items[0] if items.size() > 0 else {}
	
	# Random selection
	var random_value = randf() * total_weight
	var current_weight = 0.0
	for i in range(items.size()):
		current_weight += float(weights[i])
		if random_value <= current_weight:
			return items[i]
	
	# Fallback to first item
	return items[0] if items.size() > 0 else {}

func perform_intent(combat_controller: CombatController):
	## Execute the enemy's intent using move effects
	if not intent:
		return
	
	if not stats.is_alive():
		return
	
	# Get the move associated with this intent (stored in intent.values)
	var move_data = intent.values.get("move_data", null)
	if move_data is Dictionary and move_data.has("effects"):
		# Resolve all effects from the move
		var effects = move_data.get("effects", [])
		var source = stats
		var target = combat_controller.player_stats
		
		# Resolve effects
		for effect in effects:
			if effect is EffectData:
				EffectResolver.resolve_effect(effect, source, target)
		
		# Update RunState HP and block after effects
		if ResourceManager:
			ResourceManager.set_hp(combat_controller.player_stats.current_hp, combat_controller.player_stats.max_hp)
			ResourceManager.set_block(combat_controller.player_stats.block)
		
		# Notify combat controller that enemy acted (for Power card effects)
		if combat_controller.has_method("_on_enemy_acted"):
			combat_controller._on_enemy_acted()
	else:
		# Legacy support: handle old "Attack" intent type
		match intent.intent_type:
			"Attack":
				var damage = intent.values.get("damage", 0)
				var attack_effect = EffectData.new(EffectType.DAMAGE, {"amount": damage})
				EffectResolver.resolve_effect(attack_effect, stats, combat_controller.player_stats)
				if ResourceManager:
					ResourceManager.set_hp(combat_controller.player_stats.current_hp, combat_controller.player_stats.max_hp)
					ResourceManager.set_block(combat_controller.player_stats.block)
				
				# Notify combat controller that enemy acted (for Power card effects)
				if combat_controller.has_method("_on_enemy_acted"):
					combat_controller._on_enemy_acted()
			_:
				push_warning("Unknown intent type: " + intent.intent_type)
