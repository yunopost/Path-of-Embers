extends Control

## Victory screen — shown when the player defeats the final boss.
## Displays run stats and offers build save for Boss Rush.

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	# Title
	var title := Label.new()
	title.text = "Victory!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "The embers are extinguished."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.modulate = Color(0.85, 0.75, 0.5)
	root.add_child(subtitle)

	# Stats panel
	var stats_panel := PanelContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 8)
	stats_panel.add_child(stats_vbox)

	var hp := ResourceManager.current_hp if ResourceManager else 0
	var max_hp := ResourceManager.max_hp if ResourceManager else 1
	var gold := ResourceManager.gold if ResourceManager else 0
	var cards_played: int = 0
	if RunState and RunState.boss_rush_stats.has("cards_played"):
		cards_played = int(RunState.boss_rush_stats["cards_played"])

	for stat: Array in [
		["HP Remaining", "%d / %d" % [hp, max_hp]],
		["Gold Collected", str(gold)],
		["Cards Played", str(cards_played)],
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 32)
		stats_vbox.add_child(row)
		var lbl := Label.new()
		lbl.text = stat[0]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var val := Label.new()
		val.text = stat[1]
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)

	# Push buttons to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	# Buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	root.add_child(btn_hbox)

	var save_btn := Button.new()
	save_btn.text = "Save This Build"
	save_btn.custom_minimum_size = Vector2(200, 50)
	save_btn.pressed.connect(_on_save_build_pressed)
	btn_hbox.add_child(save_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(200, 50)
	menu_btn.pressed.connect(_on_return_to_menu_pressed)
	btn_hbox.add_child(menu_btn)


func _on_save_build_pressed() -> void:
	if not SaveManager:
		_on_return_to_menu_pressed()
		return

	var builds: Array = SaveManager.load_boss_rush_builds()

	# Find oldest or empty slot
	var target_slot: int = 0
	var oldest_date: String = "9999"
	for i in range(builds.size()):
		if builds[i] == null:
			target_slot = i
			oldest_date = ""
			break
		var b: BuildData = builds[i]
		if b.saved_at < oldest_date:
			oldest_date = b.saved_at
			target_slot = i

	var existing: BuildData = builds[target_slot]
	var slot_desc := "Slot %d" % (target_slot + 1)
	if existing != null:
		slot_desc = "Slot %d (overwrites: %s)" % [target_slot + 1, existing.label]

	var dialog := ConfirmationDialog.new()
	dialog.title = "Save Build"
	dialog.dialog_text = "Save this build to Boss Rush %s?" % slot_desc
	dialog.ok_button_text = "Save"
	dialog.cancel_button_text = "Cancel"
	add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func():
		var build := BuildData.new()
		build.slot_index = target_slot
		build.snapshot_from_run_state()
		SaveManager.save_boss_rush_build(build)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())


func _on_return_to_menu_pressed() -> void:
	if RunState:
		RunState.reset_run()
	ScreenManager.go_to_main_menu()
