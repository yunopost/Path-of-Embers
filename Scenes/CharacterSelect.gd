extends Control

## Character selection screen

@onready var continue_button: Button = $VBoxContainer/ContinueButton

func _ready():
	print("CharacterSelect: Scene ready!")
	continue_button.pressed.connect(_on_continue_pressed)
	# Ensure button works with touch
	continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
	print("CharacterSelect: Button connected")

func _on_continue_pressed():
	SceneRouter.change_scene("map")
