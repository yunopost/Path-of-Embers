extends Control

## Map screen - shows the current map/act

@onready var test_gold_button: Button = $VBoxContainer/TestGoldButton

func _ready():
	if test_gold_button:
		test_gold_button.pressed.connect(_on_test_gold_pressed)
		test_gold_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_test_gold_pressed():
	# Test RunState update - should update UI instantly
	RunState.set_gold(RunState.gold + 10)

