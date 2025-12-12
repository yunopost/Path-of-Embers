extends Control

## Persistent UI overlay that stays across all scenes
## Subscribes to RunState signals and updates UI reactively

@onready var hp_label: Label = $TopLeft/HPContainer/HPBar/HPNumber
@onready var hp_bar: ProgressBar = $TopLeft/HPContainer/HPBar
@onready var block_label: Label = $TopLeft/HPContainer/BlockContainer/BlockNumber
@onready var block_bar: ProgressBar = $TopLeft/HPContainer/BlockContainer/BlockBar
@onready var party_portraits: HBoxContainer = $TopLeft/PartyPortraits
@onready var gold_label: Label = $TopRight/GoldContainer/GoldValue
@onready var node_progress_label: Label = $TopRight/NodeProgressContainer/NodeProgressValue
@onready var map_button: Button = $TopRight/ButtonContainer/MapButton
@onready var deck_button: Button = $TopRight/ButtonContainer/DeckButton
@onready var settings_button: Button = $TopRight/ButtonContainer/SettingsButton

var settings_popup: Control = null
var deck_popup: Control = null

func _ready():
	# Connect to RunState signals
	RunState.hp_changed.connect(_on_hp_changed)
	RunState.block_changed.connect(_on_block_changed)
	RunState.gold_changed.connect(_on_gold_changed)
	RunState.node_position_changed.connect(_on_node_position_changed)
	
	# Connect buttons
	map_button.pressed.connect(_on_map_button_pressed)
	deck_button.pressed.connect(_on_deck_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	
	# Make buttons work with touch (no hover required)
	map_button.mouse_filter = Control.MOUSE_FILTER_STOP
	deck_button.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Initial UI update
	_update_all_ui()
	
	# Load popups
	_load_popups()

func _load_popups():
	# Load Settings popup
	var settings_scene = load("res://Path-of-Embers/SettingsPopup.tscn")
	settings_popup = settings_scene.instantiate()
	add_child(settings_popup)
	settings_popup.visible = false
	
	# Load Deck popup
	var deck_scene = load("res://Path-of-Embers/DeckViewPopup.tscn")
	deck_popup = deck_scene.instantiate()
	add_child(deck_popup)
	deck_popup.visible = false

func _update_all_ui():
	_on_hp_changed()
	_on_block_changed()
	_on_gold_changed()
	_on_node_position_changed()

func _on_hp_changed():
	if hp_label and hp_bar:
		hp_label.text = str(RunState.current_hp) + "/" + str(RunState.max_hp)
		hp_bar.max_value = RunState.max_hp
		hp_bar.value = RunState.current_hp

func _on_block_changed():
	if block_label and block_bar:
		block_label.text = str(RunState.block)
		# Block bar fills right-to-left (fill_mode = 1 in scene)
		block_bar.max_value = 50  # Placeholder max
		block_bar.value = RunState.block

func _on_gold_changed():
	if gold_label:
		gold_label.text = str(RunState.gold)

func _on_node_position_changed():
	if node_progress_label:
		node_progress_label.text = "Node: " + str(RunState.node_position)

func _on_map_button_pressed():
	SceneRouter.change_scene("map")

func _on_deck_button_pressed():
	open_popup("deck")

func _on_settings_button_pressed():
	open_popup("settings")

func open_popup(popup_name: String):
	if popup_name == "settings" and settings_popup:
		settings_popup.visible = true
		settings_popup.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	elif popup_name == "deck" and deck_popup:
		deck_popup.visible = true
		deck_popup.set_process_mode(Node.PROCESS_MODE_ALWAYS)

func close_popup(popup_name: String):
	if popup_name == "settings" and settings_popup:
		settings_popup.visible = false
	elif popup_name == "deck" and deck_popup:
		deck_popup.visible = false

