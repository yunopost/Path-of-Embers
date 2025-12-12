extends Control

## Deck view popup

@onready var close_button: Button = $VBoxContainer/CloseButton

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
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
	content.offset_left = -300
	content.offset_top = -200
	content.offset_right = 300
	content.offset_bottom = 200

func _on_close_pressed():
	visible = false
	# Notify UIRoot if needed
	if get_parent().has_method("close_popup"):
		get_parent().close_popup("deck")

func _input(event):
	# Close on escape
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

