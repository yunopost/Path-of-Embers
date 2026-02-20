extends Control

## Main menu screen - entry point for the game

@onready var new_game_button: TextureButton = null
@onready var continue_button: TextureButton = null
@onready var settings_button: TextureButton = null
@onready var quit_button: TextureButton = null

var settings_popup: Control = null

func _ready():
	# Debug: Confirm Main menu is loading
	print("Main.gd: Main menu _ready() called")
	
	# Wait one frame to ensure nodes are ready
	await get_tree().process_frame
	
	# Get node references (buttons are direct children of Main)
	new_game_button = get_node_or_null("NewGameButton")
	continue_button = get_node_or_null("ContinueButton")
	settings_button = get_node_or_null("SettingsButton")
	quit_button = get_node_or_null("QuitButton")
	
	# Debug: Check if nodes were found
	print("Main.gd: Nodes found - new_game: ", new_game_button != null, ", continue: ", continue_button != null)
	
	# Setup UI
	_setup_ui()
	
	# Load settings popup
	_load_settings_popup()
	
	# Initialize screen (architecture rule 2.1)
	initialize()
	
	# Debug: Confirm initialization complete
	print("Main.gd: Main menu initialization complete - should be visible now")

func initialize():
	## Initialize the screen with current state
	## Must be called after instantiation, before use (architecture rule 2.1)
	refresh_from_state()

func refresh_from_state():
	## Refresh UI from RunState (architecture rule 11.2)
	_update_continue_button()

func _setup_ui():
	## Setup UI buttons
	# Connect buttons
	if is_instance_valid(new_game_button):
		if not new_game_button.pressed.is_connected(_on_new_game_pressed):
			new_game_button.pressed.connect(_on_new_game_pressed)
	
	if is_instance_valid(continue_button):
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)
	
	if is_instance_valid(settings_button):
		if not settings_button.pressed.is_connected(_on_settings_pressed):
			settings_button.pressed.connect(_on_settings_pressed)
	
	if is_instance_valid(quit_button):
		if not quit_button.pressed.is_connected(_on_quit_pressed):
			quit_button.pressed.connect(_on_quit_pressed)
	
	# Update continue button state
	_update_continue_button()

func _update_continue_button():
	## Enable/disable Continue button based on save file existence
	if not is_instance_valid(continue_button):
		return
	
	if SaveManager and SaveManager.has_save():
		continue_button.disabled = false
	else:
		continue_button.disabled = true

func _on_new_game_pressed():
	## Start a new game - reset state and go to character select
	# Reset run state to clean slate
	if RunState:
		RunState.reset_run()
	
	# Navigate to character select
	ScreenManager.go_to_character_select()

func _on_continue_pressed():
	## Load existing save and route to appropriate screen
	if not SaveManager:
		_show_load_error("SaveManager not available")
		return
	
	# Attempt to load save
	var success = SaveManager.load_game()
	if not success:
		_show_load_error("Failed to load save.")
		return
	
	# Route based on game state
	if RunState and RunState.pending_rewards != null:
		# Resume at rewards screen
		ScreenManager.go_to_rewards(RunState.pending_rewards)
	elif MapManager and MapManager.current_map != null:
		# Resume at map
		ScreenManager.go_to_map()
	else:
		# Fallback to character select (shouldn't happen, but safe)
		ScreenManager.go_to_character_select()

func _on_settings_pressed():
	## Open settings popup
	if settings_popup:
		settings_popup.visible = true
		settings_popup.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	else:
		# Fallback: create minimal settings popup
		_create_minimal_settings_popup()

func _on_quit_pressed():
	## Quit the game
	get_tree().quit()

func _load_settings_popup():
	## Load settings popup scene
	var settings_scene = load("res://Path-of-Embers/scenes/ui/SettingsPopup.tscn")
	if settings_scene:
		settings_popup = settings_scene.instantiate()
		add_child(settings_popup)
		settings_popup.visible = false

func _create_minimal_settings_popup():
	## Create a minimal settings popup if the scene doesn't exist
	var popup = AcceptDialog.new()
	popup.dialog_text = "Settings"
	popup.title = "Settings"
	
	var vbox = VBoxContainer.new()
	popup.add_child(vbox)
	
	var tap_to_play_toggle = CheckBox.new()
	tap_to_play_toggle.text = "Tap to Play"
	tap_to_play_toggle.button_pressed = RunState.tap_to_play if RunState else false
	tap_to_play_toggle.toggled.connect(func(pressed): 
		if RunState:
			RunState.tap_to_play = pressed
	)
	vbox.add_child(tap_to_play_toggle)
	
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

func _show_load_error(message: String):
	## Show error popup for load failure
	var popup = AcceptDialog.new()
	popup.dialog_text = message
	popup.title = "Load Failed"
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())
