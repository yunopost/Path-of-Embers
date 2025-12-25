extends Button
class_name RewardCardChoice

## Wrapper for reward card selection
## Button wrapper around CardWidget for interaction

signal chosen(card_id: String, owner_id: String)

var card_widget: CardWidget
var preview_card: DeckCardData
var card_id: String = ""
var owner_id: String = ""

func _ready():
	# Create CardWidget as child
	card_widget = CardWidget.new()
	card_widget.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Button handles input
	add_child(card_widget)
	
	# Setup preview card if ready
	if preview_card:
		card_widget.setup_card(preview_card)
	
	# Connect button press
	pressed.connect(_on_pressed)
	
	# Connect hover signals for scale effect
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup_preview(p_card_id: String, p_owner_id: String = ""):
	## Setup preview card for display
	card_id = p_card_id
	owner_id = p_owner_id
	
	# Create preview DeckCardData instance
	preview_card = DeckCardData.new(card_id, owner_id)
	
	# Setup card widget if ready
	if card_widget:
		card_widget.setup_card(preview_card)

func _on_pressed():
	chosen.emit(card_id, owner_id)

func _on_mouse_entered():
	## Hover effect: scale up card from center
	# Set pivot to center for scaling
	pivot_offset = size / 2.0
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)
	# Bring to front during hover to prevent clipping
	z_index = 10

func _on_mouse_exited():
	## Hover effect: scale back down
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	# Reset z-index
	z_index = 0

