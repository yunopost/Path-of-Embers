extends RefCounted
class_name CardValidation

## Validation helper for card instances
## Enforces invariants: instance_id non-empty, card_id non-empty, CardData exists

static func validate_card_instance(card: DeckCardData, context: String = "") -> bool:
	## Validate a card instance meets all invariants
	## Returns true if valid, false if invalid
	## Logs errors in debug builds
	
	if not card:
		push_error("INVALID CARD INSTANCE (context=%s): card is null" % context)
		return false
	
	# Invariant 1: instance_id is non-empty
	if card.instance_id.is_empty():
		push_error("INVALID CARD INSTANCE (context=%s): instance_id is empty. card_id=%s" % [context, card.card_id])
		return false
	
	# Invariant 2: card_id is non-empty
	if card.card_id.is_empty():
		push_error("INVALID CARD INSTANCE (context=%s): card_id is empty. instance_id=%s" % [context, card.instance_id])
		return false
	
	# Invariant 3: DataRegistry.get_card_data(card_id) returns valid CardData
	var card_data = DataRegistry.get_card_data(card.card_id)
	if not card_data:
		push_error("INVALID CARD INSTANCE (context=%s): CardData not found for card_id='%s'. instance_id=%s" % [context, card.card_id, card.instance_id])
		return false
	
	# All invariants satisfied
	return true

static func validate_and_log_creation(card: DeckCardData, source: String = "") -> bool:
	## Validate card at creation time with source context
	## Returns true if valid, false if invalid
	var context = "card_creation"
	if not source.is_empty():
		context += " (source=%s)" % source
	
	return validate_card_instance(card, context)
