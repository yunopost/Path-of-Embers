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

func draw_cards(count: int) -> Array[String]:
	## Draw cards from draw pile
	## Returns array of instance_ids that were drawn
	var drawn: Array[String] = []
	
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
			hand.append(instance_id)
			drawn.append(instance_id)
	
	if drawn.size() > 0:
		hand_changed.emit()
		draw_pile_changed.emit()
	
	return drawn

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
