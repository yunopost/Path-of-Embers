extends RefCounted
class_name DeckModel

## Deck state model - authoritative source for deck state (architecture rule 4.1)
## No rendering, just data + rules
## Piles store instance_id strings, look up cards via RunState.deck registry

var draw_pile: Array[String] = []  # instance_ids
var hand: Array[String] = []  # instance_ids
var discard_pile: Array[String] = []  # instance_ids
## Cards exhausted this combat (Exhaust keyword; Dark Pact's curses): out of
## rotation for the REST OF THIS COMBAT ONLY -- unlike RunState.remove_card_instance,
## exhausting does NOT touch RunState.deck/deck_order, so a non-temporary
## exhausted card is back in the draw pile next combat via initialize() below.
var exhaust_pile: Array[String] = []  # instance_ids

signal deck_changed()
signal draw_pile_changed()
signal hand_changed()
signal discard_pile_changed()
signal exhaust_pile_changed()
signal card_discarded(instance_id: String)
signal hand_overflow(burned_instance_ids: Array[String])  ## Cards drawn while hand was full, sent to discard instead

func initialize(p_instance_ids: Array[String]):
	## Initialize deck model with instance_ids
	## Validates all cards before adding to draw pile
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	
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

func mill(count: int) -> Array[String]:
	## Move the top `count` cards of the draw pile directly into the discard
	## pile (does not touch hand). Reshuffles discard into draw when the draw
	## pile empties, using the same reshuffle rule as draw_cards() above.
	## Returns the instance_ids actually milled (may be fewer than `count` if
	## the deck runs out of cards entirely).
	var milled: Array[String] = []

	# Snapshot of discard_pile cards that existed BEFORE this call. Only these
	## are eligible to be reshuffled back into the draw pile if it runs dry
	## mid-mill -- a card THIS call just milled must not immediately become its
	## own reshuffle fodder (that would let a 1-card deck get "milled" more
	## than once by a single Deadfall).
	var reshuffle_pool: Array[String] = discard_pile.duplicate()

	for i in range(count):
		if draw_pile.is_empty():
			if reshuffle_pool.is_empty():
				break  # Nothing left to mill
			for instance_id in reshuffle_pool:
				discard_pile.erase(instance_id)
			draw_pile.append_array(reshuffle_pool)
			reshuffle_pool.clear()
			shuffle_draw_pile()

		if not draw_pile.is_empty():
			var instance_id = draw_pile.pop_front()
			discard_pile.append(instance_id)
			milled.append(instance_id)

	if milled.size() > 0:
		draw_pile_changed.emit()
		discard_pile_changed.emit()

	return milled

func discard_hand():
	## Move all cards from hand to discard pile
	for instance_id in hand.duplicate():
		discard_card(instance_id)

func discard_card(instance_id: String) -> bool:
	## Explicit hand discard (cost/effect). Playing, milling, overflow and
	## exhausting cards are different operations and do not count as discards.
	if not hand.has(instance_id):
		return false
	hand.erase(instance_id)
	discard_pile.append(instance_id)
	hand_changed.emit()
	discard_pile_changed.emit()
	card_discarded.emit(instance_id)
	return true

func get_draw_pile_count() -> int:
	return draw_pile.size()

func get_hand_size() -> int:
	return hand.size()

func get_discard_pile_count() -> int:
	return discard_pile.size()

func get_exhaust_pile_count() -> int:
	return exhaust_pile.size()

func exhaust_card(instance_id: String) -> void:
	## Move instance_id out of hand/draw/discard and into exhaust_pile instead --
	## out of rotation for the rest of THIS combat only. RunState.deck/deck_order
	## are left untouched, so the card is a normal member of the draw pile again
	## next combat (initialize() clears exhaust_pile along with the other piles).
	## Used by the "Exhaust" card keyword and by effects that exhaust specific
	## cards out of hand (Dark Pact's curses).
	draw_pile.erase(instance_id)
	hand.erase(instance_id)
	discard_pile.erase(instance_id)
	if not exhaust_pile.has(instance_id):
		exhaust_pile.append(instance_id)
	draw_pile_changed.emit()
	hand_changed.emit()
	discard_pile_changed.emit()
	exhaust_pile_changed.emit()

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
