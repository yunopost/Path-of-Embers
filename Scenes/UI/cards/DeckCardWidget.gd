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
	
	# Update display immediately (works if nodes are ready) or defer
	if is_inside_tree():
		_update_display()
	else:
		call_deferred("_update_display")

func _ready():
	## Refresh display when node is ready (in case setup() was called before add_child)
	if card_instance:
		_update_display()

func _update_display():
	## Update all visual elements from card_instance
	if not card_instance:
		return
	
	# Get nodes safely (works even if @onready vars aren't set yet)
	var name_lbl = _get_name_label()
	var owner_lbl = _get_owner_label()
	var upgrades_lbl = _get_upgrades_label()
	var transcend_lbl = _get_transcend_label()
	var disabled_lbl = _get_disabled_label()
	var panel = _get_card_panel()
	
	# Card name
	if name_lbl:
		# Get display name from DataRegistry
		var display_name = DataRegistry.get_card_display_name(card_instance.card_id)
		name_lbl.text = display_name
	
	# Owner info
	if owner_lbl:
		if card_instance.owner_character_id:
			owner_lbl.text = "Owner: " + DataRegistry.get_character_display_name(card_instance.owner_character_id)
			owner_lbl.visible = true
		else:
			owner_lbl.visible = false
	
	# Upgrades info
	if upgrades_lbl:
		if card_instance.applied_upgrades.size() > 0:
			var upgrade_text = ""
			for upgrade_id in card_instance.applied_upgrades:
				var upgrade_def = DataRegistry.get_upgrade_def(upgrade_id)
				if upgrade_text != "":
					upgrade_text += ", "
				upgrade_text += upgrade_def.get("title", upgrade_id)
			upgrades_lbl.text = "Upgrades: " + upgrade_text
			upgrades_lbl.visible = true
		else:
			upgrades_lbl.visible = false
	
	# Transcend indicator
	if transcend_lbl:
		transcend_lbl.visible = card_instance.is_transcended
	
	# Disabled state (for upgrade selection)
	if disabled_lbl:
		if is_clickable and card_instance:
			var can_upgrade = RunState.can_upgrade_instance(card_instance.instance_id)
			if not can_upgrade:
				disabled_lbl.visible = true
				modulate = Color(0.5, 0.5, 0.5, 0.7)
			else:
				disabled_lbl.visible = false
				modulate = Color.WHITE
		else:
			disabled_lbl.visible = false
	
	# Make clickable if needed
	if is_clickable and panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		# Connect gui_input signal
		if panel.gui_input.is_connected(_on_card_clicked):
			pass  # Already connected
		else:
			panel.gui_input.connect(_on_card_clicked)
	else:
		if panel:
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Helper methods to get nodes safely (works before @onready vars are set)
func _get_name_label() -> Label:
	return name_label if name_label else get_node_or_null("CardPanel/VBoxContainer/NameLabel") as Label

func _get_owner_label() -> Label:
	return owner_label if owner_label else get_node_or_null("CardPanel/VBoxContainer/OwnerLabel") as Label

func _get_upgrades_label() -> Label:
	return upgrades_label if upgrades_label else get_node_or_null("CardPanel/VBoxContainer/UpgradesLabel") as Label

func _get_transcend_label() -> Label:
	return transcend_label if transcend_label else get_node_or_null("CardPanel/VBoxContainer/TranscendLabel") as Label

func _get_disabled_label() -> Label:
	return disabled_label if disabled_label else get_node_or_null("CardPanel/VBoxContainer/DisabledLabel") as Label

func _get_card_panel() -> Panel:
	return card_panel if card_panel else get_node_or_null("CardPanel") as Panel

func _on_card_clicked(event: InputEvent):
	if is_clickable and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(deck_index)
			get_viewport().set_input_as_handled()
