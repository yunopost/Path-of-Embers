extends Control

## Map screen - shows the current map/act

@onready var test_gold_button: Button = $VBoxContainer/TestGoldButton
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var add_card_button: Button = $VBoxContainer/AddCardButton
@onready var remove_card_button: Button = $VBoxContainer/RemoveCardButton
@onready var setup_15_card_button: Button = $VBoxContainer/Setup15CardButton
@onready var draw_5_button: Button = $VBoxContainer/Draw5Button
@onready var discard_hand_button: Button = $VBoxContainer/DiscardHandButton
@onready var reset_deck_button: Button = $VBoxContainer/ResetDeckButton

func _ready() -> void:
	test_gold_button.pressed.connect(_on_test_gold_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	add_card_button.pressed.connect(_on_add_card_pressed)
	remove_card_button.pressed.connect(_on_remove_card_pressed)
	setup_15_card_button.pressed.connect(_on_setup_15_card_pressed)
	draw_5_button.pressed.connect(_on_draw_5_pressed)
	discard_hand_button.pressed.connect(_on_discard_hand_pressed)
	reset_deck_button.pressed.connect(_on_reset_deck_pressed)

func _on_test_gold_pressed():
	# Test RunState update - should update UI instantly
	RunState.set_gold(RunState.gold + 10)

func _on_save_pressed():
	var success = SaveManager.save_game()
	if success:
		print("Game saved successfully!")
	else:
		print("Failed to save game")

func _on_load_pressed():
	var success = SaveManager.load_game()
	if success:
		print("Game loaded successfully!")
	else:
		print("Failed to load game")

func _on_add_card_pressed():
	# Add a test card to deck
	RunState.add_card_to_deck("test_card_" + str(RunState.get_deck_size()))
	print("Added card to deck. Deck size: ", RunState.get_deck_size())

func _on_remove_card_pressed():
	# Remove last card from deck
	if RunState.get_deck_size() > 0:
		RunState.remove_card_from_deck(RunState.get_deck_size() - 1)
		print("Removed card from deck. Deck size: ", RunState.get_deck_size())
	else:
		print("Deck is empty, cannot remove card")

func _on_setup_15_card_pressed():
	# Setup a 15-card deck for testing
	RunState.deck.clear()
	for i in range(15):
		RunState.add_card_to_deck("card_" + str(i))
	RunState._initialize_deck_piles()
	print("Setup 15-card deck. Total: ", RunState.get_deck_size())

func _on_draw_5_pressed():
	# Draw 5 cards
	RunState.draw_cards(5)
	print("Drew 5 cards. Hand: %d, Draw: %d, Discard: %d" % [
		RunState.get_hand_size(),
		RunState.get_draw_pile_count(),
		RunState.get_discard_pile_count()
	])

func _on_discard_hand_pressed():
	# Discard entire hand
	RunState.discard_hand()
	print("Discarded hand. Hand: %d, Draw: %d, Discard: %d" % [
		RunState.get_hand_size(),
		RunState.get_draw_pile_count(),
		RunState.get_discard_pile_count()
	])

func _on_reset_deck_pressed():
	# Reset deck piles (shuffle all cards back into draw)
	RunState._initialize_deck_piles()
	print("Reset deck piles. Hand: %d, Draw: %d, Discard: %d" % [
		RunState.get_hand_size(),
		RunState.get_draw_pile_count(),
		RunState.get_discard_pile_count()
	])
