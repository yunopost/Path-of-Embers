extends RefCounted
class_name IntentSystem

## Generates intents for enemies using move patterns from EnemyData

func generate_intent(enemy: Enemy) -> IntentData:
	## Generate a new intent for the given enemy using move selection AI
	var move_data = enemy.get_next_move()
	
	if move_data.is_empty():
		# Fallback: simple attack if no move data available
		var damage = 6
		return IntentData.new("Attack", {"damage": damage}, "Attack %d" % damage)
	
	# Convert move Dictionary to IntentData
	var move_id = move_data.get("id", "")
	var timer = move_data.get("timer", enemy.time_max)
	var telegraph_text = move_data.get("telegraph_text", "Unknown Move")
	var effects = move_data.get("effects", [])
	
	# Create intent with move data stored in values for perform_intent()
	var intent = IntentData.new("Move", {"move_data": move_data}, telegraph_text)
	intent.time_max_override = timer
	
	return intent

