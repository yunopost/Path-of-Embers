extends Control

## Settings popup — modal with dimmed backdrop, solid dialog panel,
## and a music volume slider (persisted via MusicManager).

signal popup_closed(popup_name: String)

@onready var close_button: Button = $VBoxContainer/CloseButton

var _volume_slider: HSlider = null

func _ready():
	close_button.pressed.connect(_on_close_pressed)

	# Make interactive elements work with touch
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP

	_setup_popup()

func _setup_popup():
	# Make it a modal-like popup
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dimmed full-screen backdrop (swallows clicks behind the dialog)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 0)

	# Solid dialog panel behind the content
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 1.0)
	style.set_border_width_all(1)
	style.border_color = Color(0.85, 0.50, 0.15, 0.5)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_top = -170
	panel.offset_right = 220
	panel.offset_bottom = 170
	add_child(panel)
	move_child(panel, 1)

	# Re-parent the content VBox into the panel so it sits on the solid background
	var content = $VBoxContainer
	content.get_parent().remove_child(content)
	panel.add_child(content)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 16)

	# ── Music volume row (inserted after the title) ──────────────────────────
	var volume_vbox := VBoxContainer.new()
	volume_vbox.add_theme_constant_override("separation", 6)

	var volume_label := Label.new()
	volume_label.text = "Music Volume"
	volume_vbox.add_child(volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = MusicManager.music_volume if MusicManager else 1.0
	_volume_slider.custom_minimum_size = Vector2(0, 24)
	_volume_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_volume_slider.value_changed.connect(_on_volume_changed)
	volume_vbox.add_child(_volume_slider)

	content.add_child(volume_vbox)
	content.move_child(volume_vbox, 1)  # directly under the title

	# Spacer pushes the close button to the bottom of the dialog
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	content.move_child(spacer, content.get_child_count() - 2)

func _on_volume_changed(value: float) -> void:
	if MusicManager:
		MusicManager.set_music_volume(value)

func _on_close_pressed():
	visible = false
	# Emit signal to notify parent (UIRoot)
	popup_closed.emit("settings")

func _input(event):
	# Close on escape
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
