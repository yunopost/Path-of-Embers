extends Control

## Main menu screen - entry point for the game

@onready var new_game_button: Button = null
@onready var continue_button: Button = null
@onready var settings_button: Button = null
@onready var quit_button: Button = null

var settings_popup: Control = null
var _boss_rush_button: Button = null  # Created in code; only shown when builds exist
var _title_label: Label = null
var _glow_label: Label = null
var _glow_label2: Label = null
var _music_muted: bool = false

func _ready():
	# Debug: Confirm Main menu is loading
	print("Main.gd: Main menu _ready() called")

	# Wait one frame to ensure nodes are ready
	await get_tree().process_frame

	# Get node references (buttons are inside ButtonContainer)
	new_game_button = get_node_or_null("ButtonContainer/NewGameButton")
	continue_button = get_node_or_null("ButtonContainer/ContinueButton")
	settings_button = get_node_or_null("ButtonContainer/SettingsButton")
	quit_button = get_node_or_null("ButtonContainer/QuitButton")

	# Debug: Check if nodes were found
	print("Main.gd: Nodes found - new_game: ", new_game_button != null, ", continue: ", continue_button != null)

	# Setup UI
	_setup_ui()
	_setup_title()
	_setup_mute_button()

	# Load settings popup
	_load_settings_popup()

	# Initialize screen (architecture rule 2.1)
	initialize()

	# Debug: Confirm initialization complete
	print("Main.gd: Main menu initialization complete - should be visible now")

func _process(_delta: float) -> void:
	if not is_instance_valid(_title_label):
		return
	var t = Time.get_ticks_msec() / 1000.0
	# Two overlapping sine waves at non-harmonic frequencies give an organic
	# campfire flicker rather than a mechanical pulse — never perfectly repeats
	var flicker = sin(t * 0.7) * 0.55 + sin(t * 1.3) * 0.3 + sin(t * 2.3) * 0.15
	var pulse = 0.5 + flicker * 0.45
	if is_instance_valid(_glow_label):
		_glow_label.add_theme_color_override("font_outline_color",
			Color(1.0, 0.5, 0.1, pulse * 0.25))
	if is_instance_valid(_glow_label2):
		_glow_label2.add_theme_color_override("font_outline_color",
			Color(1.0, 0.6, 0.2, pulse * 0.6))

func initialize():
	## Initialize the screen with current state
	## Must be called after instantiation, before use (architecture rule 2.1)
	refresh_from_state()

func refresh_from_state():
	## Refresh UI from RunState (architecture rule 11.2)
	_update_continue_button()
	_update_boss_rush_button()

func _setup_title() -> void:
	## Apply Cinzel ExtraBold font and amber color to the title label
	var title_label: Label = get_node_or_null("TitleLabel")
	if not is_instance_valid(title_label):
		return
	_title_label = title_label
	var font = load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-ExtraBold.ttf")
	if font:
		title_label.add_theme_font_override("font", font)
	title_label.offset_top = 150
	title_label.offset_bottom = 330
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 148)

	# Load and apply ember gradient shader
	var shader = load("res://shaders/title_ember.gdshader")
	if not shader:
		push_error("_setup_title: failed to load res://shaders/title_ember.gdshader")
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("color_base", Color(0.35, 0.12, 0.02, 1.0))
	shader_material.set_shader_parameter("color_mid", Color(0.85, 0.50, 0.08, 1.0))
	shader_material.set_shader_parameter("color_tip", Color(0.94, 0.90, 0.78, 1.0))
	shader_material.set_shader_parameter("mid_point", 0.5)
	shader_material.set_shader_parameter("glow_intensity", 0.15)
	shader_material.set_shader_parameter("label_top", title_label.offset_top)
	shader_material.set_shader_parameter("label_bottom", title_label.offset_bottom)
	title_label.material = shader_material

	# White so the shader receives clean glyph shapes to apply the gradient to.
	# Falls back to visible amber if shader fails to load.
	if shader:
		title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	else:
		title_label.add_theme_color_override("font_color", Color(0.91, 0.63, 0.13, 1.0))

	# GlowLabel — sits behind TitleLabel, outline only, no fill, no shader
	# _process pulses its outline color to create the ember glow effect
	var glow_label: Label = get_node_or_null("GlowLabel")
	if is_instance_valid(glow_label):
		_glow_label = glow_label
		var glow_font = load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-ExtraBold.ttf")
		if glow_font:
			glow_label.add_theme_font_override("font", glow_font)
		glow_label.offset_top = title_label.offset_top
		glow_label.offset_bottom = title_label.offset_bottom
		glow_label.add_theme_font_size_override("font_size", 148)
		glow_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.0))
		# Outer halo — wide and faint, provides the soft falloff
		glow_label.add_theme_constant_override("outline_size", 24)
		glow_label.add_theme_color_override("font_outline_color", Color(1.0, 0.5, 0.1, 0.2))

	# GlowLabel2 — tighter inner layer, brighter, sits between outer halo and title
	var glow_label2: Label = get_node_or_null("GlowLabel2")
	if is_instance_valid(glow_label2):
		_glow_label2 = glow_label2
		var glow_font2 = load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-ExtraBold.ttf")
		if glow_font2:
			glow_label2.add_theme_font_override("font", glow_font2)
		glow_label2.offset_top = title_label.offset_top
		glow_label2.offset_bottom = title_label.offset_bottom
		glow_label2.add_theme_font_size_override("font_size", 148)
		glow_label2.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.0))
		# Inner glow — narrower and brighter, fades into the outer halo
		glow_label2.add_theme_constant_override("outline_size", 10)
		glow_label2.add_theme_color_override("font_outline_color", Color(1.0, 0.6, 0.2, 0.5))

func setup_menu_button(button: Button, label_text: String) -> void:
	button.text = label_text

	# Font
	var font = load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-Bold.ttf")
	if font:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 28)

	# Text colors
	button.add_theme_color_override("font_color", Color("#F0E6C8"))
	button.add_theme_color_override("font_hover_color", Color("#D4A847"))
	button.add_theme_color_override("font_pressed_color", Color("#C4821A"))

	# Normal state StyleBox
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("#2A3040E8")
	normal_style.border_width_left = 4
	normal_style.border_width_right = 4
	normal_style.border_width_top = 4
	normal_style.border_width_bottom = 4
	normal_style.border_color = Color("#C4821A")
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	normal_style.content_margin_left = 32
	normal_style.content_margin_right = 32
	normal_style.content_margin_top = 12
	normal_style.content_margin_bottom = 12
	button.add_theme_stylebox_override("normal", normal_style)

	# Hover state StyleBox
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color("#4A5566CC")
	hover_style.border_color = Color("#D4A847")
	hover_style.border_width_left = 4
	hover_style.border_width_right = 4
	hover_style.border_width_top = 4
	hover_style.border_width_bottom = 4
	button.add_theme_stylebox_override("hover", hover_style)

	# Pressed state StyleBox
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color("#C4821A33")
	pressed_style.border_color = Color("#F0E6C8")
	button.add_theme_stylebox_override("pressed", pressed_style)

	# Button text outline
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color("#12161E"))

func _setup_ui():
	## Setup UI buttons
	if is_instance_valid(new_game_button):
		setup_menu_button(new_game_button, "NEW GAME")
		if not new_game_button.pressed.is_connected(_on_new_game_pressed):
			new_game_button.pressed.connect(_on_new_game_pressed)

	if is_instance_valid(continue_button):
		setup_menu_button(continue_button, "CONTINUE")
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)

	if is_instance_valid(settings_button):
		setup_menu_button(settings_button, "SETTINGS")
		if not settings_button.pressed.is_connected(_on_settings_pressed):
			settings_button.pressed.connect(_on_settings_pressed)

	if is_instance_valid(quit_button):
		setup_menu_button(quit_button, "QUIT")
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

func _update_boss_rush_button():
	## Create or show/hide the Boss Rush button depending on saved builds.
	var has_builds: bool = SaveManager != null and SaveManager.has_any_boss_rush_build()

	if has_builds and not is_instance_valid(_boss_rush_button):
		_boss_rush_button = Button.new()
		setup_menu_button(_boss_rush_button, "BOSS RUSH")
		_boss_rush_button.custom_minimum_size = Vector2(280, 0)
		_boss_rush_button.pressed.connect(_on_boss_rush_pressed)
		# Add after the continue button if found, otherwise just add to root
		var parent = continue_button.get_parent() if is_instance_valid(continue_button) else self
		var insert_idx: int = continue_button.get_index() + 1 if is_instance_valid(continue_button) else -1
		parent.add_child(_boss_rush_button)
		if insert_idx >= 0:
			parent.move_child(_boss_rush_button, insert_idx)

	if is_instance_valid(_boss_rush_button):
		_boss_rush_button.visible = has_builds

func _setup_mute_button() -> void:
	var btn: Button = get_node_or_null("MuteButton")
	if not is_instance_valid(btn):
		return
	var font = load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-Regular.ttf")
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color("#C4821A"))
	btn.add_theme_color_override("font_hover_color", Color("#F0E6C8"))
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#12161ECC")
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color("#C4821A66")
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover_style = style.duplicate()
	hover_style.bg_color = Color("#2A3040CC")
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.text = "♪  MUSIC ON"
	btn.pressed.connect(_on_mute_toggled)

func _on_mute_toggled() -> void:
	_music_muted = not _music_muted
	var master_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, _music_muted)
	var btn: Button = get_node_or_null("MuteButton")
	if is_instance_valid(btn):
		btn.text = "✕  MUSIC OFF" if _music_muted else "♪  MUSIC ON"

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

func _on_boss_rush_pressed():
	## Open the Boss Rush screen
	ScreenManager.go_to_boss_rush()

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
