extends Control

## Reusable card widget for displaying deck cards
## Scene-based widget - instantiate via scene, not class_name
## Follows architecture: scene-based, uses setup() method

signal card_clicked(deck_index: int)

@onready var card_panel: Panel = $CardPanel
@onready var name_label: Label = $CardPanel/VBoxContainer/NameLabel
@onready var owner_label: Label = $CardPanel/VBoxContainer/OwnerLabel
@onready var upgrades_label: Label = $CardPanel/VBoxContainer/UpgradesLabel
@onready var transcend_label: Label = $CardPanel/VBoxContainer/TranscendLabel
@onready var disabled_label: Label = $CardPanel/VBoxContainer/DisabledLabel

var deck_index: int = -1
var card_instance: DeckCardData = null
var is_clickable: bool = false

func setup(p_card_instance: DeckCardData, p_deck_index: int, p_clickable: bool = false):
	## Initialize the widget with card data
	## Must be called after instantiation, before use
	card_instance = p_card_instance
	deck_index = p_deck_index
	is_clickable = p_clickable
	
	_update_display()

func _update_display():
	## Update all visual elements from card_instance
	if not card_instance:
		return
	
	# Card name
	if name_label:
		name_label.text = card_instance.card_id
	
	# Owner info
	if owner_label:
		if card_instance.owner_character_id:
			owner_label.text = "Owner: " + DataRegistry.get_character_display_name(card_instance.owner_character_id)
			owner_label.visible = true
		else:
			owner_label.visible = false
	
	# Upgrades info
	if upgrades_label:
		if card_instance.applied_upgrades.size() > 0:
			var upgrade_text = ""
			for upgrade_id in card_instance.applied_upgrades:
				var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
				if upgrade_text != "":
					upgrade_text += ", "
				upgrade_text += upgrade_def.get("title", upgrade_id)
			upgrades_label.text = "Upgrades: " + upgrade_text
			upgrades_label.visible = true
		else:
			upgrades_label.visible = false
	
	# Transcend indicator
	if transcend_label:
		transcend_label.visible = card_instance.is_transcended
	
	# Disabled state (for upgrade selection)
	if disabled_label:
		if is_clickable:
			var can_upgrade = RunState.can_upgrade_card_at(deck_index)
			if not can_upgrade:
				disabled_label.visible = true
				modulate = Color(0.5, 0.5, 0.5, 0.7)
			else:
				disabled_label.visible = false
				modulate = Color.WHITE
		else:
			disabled_label.visible = false
	
	# Make clickable if needed
	if is_clickable and card_panel:
		card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		# Connect gui_input signal
		if not card_panel.gui_input.is_connected(_on_card_clicked):
			card_panel.gui_input.connect(_on_card_clicked)
	else:
		if card_panel:
			card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_card_clicked(event: InputEvent):
	if is_clickable and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(deck_index)
			get_viewport().set_input_as_handled()
