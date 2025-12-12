extends Control

## Map screen - shows the current map/act

@onready var test_gold_button: Button = $VBoxContainer/TestGoldButton
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var add_card_button: Button = $VBoxContainer/AddCardButton
@onready var remove_card_button: Button = $VBoxContainer/RemoveCardButton

func _ready() -> void:
	test_gold_button.pressed.connect(_on_test_gold_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	add_card_button.pressed.connect(_on_add_card_pressed)
	remove_card_button.pressed.connect(_on_remove_card_pressed)

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
