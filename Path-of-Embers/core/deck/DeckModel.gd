extends RefCounted
class_name DeckModel

## Deck state model - authoritative source for deck state (architecture rule 4.1)
## No rendering, just data + rules
## Piles store instance_id strings, look up cards via RunState.deck registry

var draw_pile: Array[String] = []  # instance_ids
var hand: Array[String] = []  # instance_ids
var discard_pile: Array[String] = []  # instance_ids

signal deck_changed()
signal draw_pile_changed()
signal hand_changed()
signal discard_pile_changed()
signal hand_overflow(burned_instance_ids: Array[String])  ## Cards drawn while hand was full, sent to discard instead

func initialize(p_instance_ids: Array[String]):
	## Initialize deck model with instance_ids
	## Validates all cards before adding to draw pile
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	
	# Validate each instance_id references a valid card
	for instance_id in p_instance_ids:
		var card = get_card(instance_id)
		if card and CardValidation.validate_card_instance(card, "DeckModel.initialize"):
			draw_pile.append(instance_id)
		else:
			push_error("DeckModel.initialize: Skipping invalid card instance_id=%s" % instance_id)
	
	deck_changed.emit()
	draw_pile_changed.emit()

func get_card(instance_id: String) -> DeckCardData:
	## Get card instance from RunState registry
	return RunState.deck.get(instance_id)

func shuffle_draw_pile():
	## Shuffle the draw pile
	draw_pile.shuffle()
	draw_pile_changed.emit()

func draw_cards(count: int, hand_max: int = -1) -> Dictionary:
	## Draw cards from draw pile.
	## hand_max < 0 means unlimited (legacy behaviour). When the hand is at
	## hand_max, a card that would be drawn is "burned" — sent straight to the
	## discard pile instead of into hand (card-clock: hand is never force-discarded,
	## so a drawn overflow needs somewhere to go).
	## Returns {"drawn": Array[String], "burned": Array[String]} (instance_ids).
	var drawn: Array[String] = []
	var burned: Array[String] = []
	
	for i in range(count):
		if draw_pile.is_empty():
			# Shuffle discard into draw
			if discard_pile.is_empty():
				break  # No more cards
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			shuffle_draw_pile()
		
		if not draw_pile.is_empty():
			var instance_id = draw_pile.pop_front()
			if hand_max >= 0 and hand.size() >= hand_max:
				discard_pile.append(instance_id)
				burned.append(instance_id)
			else:
				hand.append(instance_id)
				drawn.append(instance_id)
	
	if drawn.size() > 0:
		hand_changed.emit()
	if drawn.size() > 0 or burned.size() > 0:
		draw_pile_changed.emit()
	if burned.size() > 0:
		discard_pile_changed.emit()
		hand_overflow.emit(burned)
	
	return {"drawn": drawn, "burned": burned}

func discard_hand():
	## Move all cards from hand to discard pile
	discard_pile.append_array(hand)
	hand.clear()
	hand_changed.emit()
	discard_pile_changed.emit()

func get_draw_pile_count() -> int:
	return draw_pile.size()

func get_hand_size() -> int:
	return hand.size()

func get_discard_pile_count() -> int:
	return discard_pile.size()

func get_hand_cards() -> Array[DeckCardData]:
	## Get actual card instances in hand by looking up instance_ids in RunState registry
	## Only returns valid cards (validates each card)
	var cards: Array[DeckCardData] = []
	for instance_id in hand:
		var card = get_card(instance_id)
		if card and CardValidation.validate_card_instance(card, "DeckModel.get_hand_cards"):
			cards.append(card)
		else:
			push_error("DeckModel.get_hand_cards: Invalid card in hand instance_id=%s" % instance_id)
	return cards

func add_card_instance(instance_id: String):
	## Add a card instance_id to the draw pile
	draw_pile.append(instance_id)
	draw_pile_changed.emit()
	deck_changed.emit()

func remove_instance_from_piles(instance_id: String):
	## Remove instance_id from all piles (used when card is removed from deck)
	draw_pile.erase(instance_id)
	hand.erase(instance_id)
	discard_pile.erase(instance_id)
	draw_pile_changed.emit()
	hand_changed.emit()
	discard_pile_changed.emit()
	deck_changed.emit()
