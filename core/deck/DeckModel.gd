extends RefCounted
class_name DeckModel

## Deck state model - authoritative source for deck state (architecture rule 4.1)
## No rendering, just data + rules

var deck: Array[DeckCardData] = []  # Full deck
var draw_pile: Array[int] = []  # Indices into deck
var hand: Array[int] = []  # Indices into deck
var discard_pile: Array[int] = []  # Indices into deck

signal deck_changed()
signal draw_pile_changed()
signal hand_changed()
signal discard_pile_changed()

func initialize(p_deck: Array[DeckCardData]):
	## Initialize deck model with a deck
	deck = p_deck.duplicate()
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	
	# Add all cards to draw pile
	for i in range(deck.size()):
		draw_pile.append(i)
	
	deck_changed.emit()
	draw_pile_changed.emit()

func shuffle_draw_pile():
	## Shuffle the draw pile
	draw_pile.shuffle()
	draw_pile_changed.emit()

func draw_cards(count: int) -> Array[int]:
	## Draw cards from draw pile
	## Returns array of deck indices that were drawn
	var drawn: Array[int] = []
	
	for i in range(count):
		if draw_pile.is_empty():
			# Shuffle discard into draw
			if discard_pile.is_empty():
				break  # No more cards
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			shuffle_draw_pile()
		
		if not draw_pile.is_empty():
			var card_index = draw_pile.pop_front()
			hand.append(card_index)
			drawn.append(card_index)
	
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

func get_deck_size() -> int:
	return deck.size()

func get_draw_pile_count() -> int:
	return draw_pile.size()

func get_hand_size() -> int:
	return hand.size()

func get_discard_pile_count() -> int:
	return discard_pile.size()

func get_hand_cards() -> Array[DeckCardData]:
	## Get actual card instances in hand
	var cards: Array[DeckCardData] = []
	for index in hand:
		if index >= 0 and index < deck.size():
			cards.append(deck[index])
	return cards

