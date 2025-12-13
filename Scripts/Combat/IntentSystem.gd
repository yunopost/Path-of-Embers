extends RefCounted
class_name IntentSystem

## Generates intents for enemies
## For Slice 4, uses simple deterministic logic that can be expanded later

func generate_intent(_enemy) -> IntentData:
	## Generate a new intent for the given enemy
	## For Slice 4: deterministic simple attack
	## Can be expanded later with pattern systems, RNG, etc.
	
	# Simple deterministic attack (can be replaced with pattern system later)
	var damage = 6
	var intent = IntentData.new("Attack", {"damage": damage}, "Attack %d" % damage)
	return intent

