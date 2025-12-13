extends Control

## Settings popup

@onready var tap_to_play_toggle: CheckBox = $VBoxContainer/TapToPlayToggle
@onready var close_button: Button = $VBoxContainer/CloseButton

func _ready():
	# Set initial value
	tap_to_play_toggle.button_pressed = RunState.tap_to_play
	tap_to_play_toggle.toggled.connect(_on_tap_to_play_toggled)
	close_button.pressed.connect(_on_close_pressed)
	
	# Make interactive elements work with touch
	tap_to_play_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Center the popup
	_setup_popup()

func _setup_popup():
	# Make it a modal-like popup
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add background panel
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 0)
	
	# Center the content
	var content = $VBoxContainer
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.offset_left = -200
	content.offset_top = -150
	content.offset_right = 200
	content.offset_bottom = 150

func _on_tap_to_play_toggled(button_pressed: bool):
	RunState.tap_to_play = button_pressed
	# Setting stored but gameplay not implemented yet

func _on_close_pressed():
	visible = false
	# Notify UIRoot if needed
	if get_parent().has_method("close_popup"):
		get_parent().close_popup("settings")

func _input(event):
	# Close on escape or click outside
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

