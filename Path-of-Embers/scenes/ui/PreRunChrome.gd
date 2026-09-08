extends RefCounted

## Shared chrome for the pre-run wizard screens -- CharacterSelect, LoadoutScreen,
## QuestSelectScreen -- Card-Clock Spec Addendum B §1.
##
## Loaded via `const` + `preload` from each screen (same pattern as DebugPanel.gd)
## rather than a class_name, so all three screens build the *same* step bar,
## header panel and footer nav bar instead of three hand-copied versions that
## drift apart. Fixes: one persistent 3-step bar (Party -> Loadout -> Quests),
## and Back-bottom-left / Next-bottom-right on every pre-run screen.

const EMBER_GLOW   := Color("#C4621E")
const EMBER_MID    := Color("#C4821A")
const EMBER_BRIGHT := Color("#E8A020")
const FOG          := Color("#A09070")
const PALE         := Color("#F0E6C8")
const INK          := Color("#0D0C0A")

## The real pre-run flow (spec: Modifiers lives inside Loadout, so the bar
## must describe what actually exists -- three steps, not four).
const STEPS := ["PARTY", "LOADOUT", "QUESTS"]

static func _get_font(variant: String) -> Font:
	match variant:
		"bold":
			return load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-Bold.ttf")
		"extrabold":
			return load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-ExtraBold.ttf")
		_:
			return load("res://Path-of-Embers/fonts/Cinzel/static/Cinzel-Regular.ttf")

static func build_step_bar(current_step: int) -> Control:
	## current_step: 0 = Party, 1 = Loadout, 2 = Quests.
	## Current step is highlighted, completed steps are dimmed (with a
	## checkmark), upcoming steps are greyed out further.
	var steps_hbox := HBoxContainer.new()
	steps_hbox.custom_minimum_size.x = 420
	steps_hbox.add_theme_constant_override("separation", 4)
	steps_hbox.mouse_filter = Control.MOUSE_FILTER_PASS

	var reg_font := _get_font("regular")
	var bold_font := _get_font("bold")

	for i in range(STEPS.size()):
		var step_hbox := HBoxContainer.new()
		step_hbox.add_theme_constant_override("separation", 5)
		step_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		steps_hbox.add_child(step_hbox)

		var num_label := Label.new()
		num_label.text = str(i + 1)
		num_label.mouse_filter = Control.MOUSE_FILTER_PASS
		num_label.add_theme_font_size_override("font_size", 16)
		if reg_font:
			num_label.add_theme_font_override("font", reg_font)
		step_hbox.add_child(num_label)

		var name_label := Label.new()
		name_label.text = STEPS[i]
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.add_theme_font_size_override("font_size", 14)
		if reg_font:
			name_label.add_theme_font_override("font", reg_font)
		step_hbox.add_child(name_label)

		if i == current_step:
			num_label.add_theme_color_override("font_color", EMBER_GLOW)
			name_label.add_theme_color_override("font_color", EMBER_BRIGHT)
			if bold_font:
				name_label.add_theme_font_override("font", bold_font)
		elif i < current_step:
			num_label.text = "✓"
			num_label.add_theme_color_override("font_color", Color(FOG, 0.55))
			name_label.add_theme_color_override("font_color", Color(FOG, 0.55))
		else:
			num_label.add_theme_color_override("font_color", Color(FOG, 0.28))
			name_label.add_theme_color_override("font_color", Color(FOG, 0.28))

		if i < STEPS.size() - 1:
			var sep_label := Label.new()
			sep_label.text = "  —  "
			sep_label.mouse_filter = Control.MOUSE_FILTER_PASS
			sep_label.add_theme_font_size_override("font_size", 13)
			sep_label.add_theme_color_override("font_color", Color(FOG, 0.35))
			if reg_font:
				sep_label.add_theme_font_override("font", reg_font)
			steps_hbox.add_child(sep_label)

	return steps_hbox

static func build_header(current_step: int, title_text: String = "PATH OF EMBERS", right_content: Control = null) -> PanelContainer:
	## Full header bar shared by every pre-run screen: step bar (left),
	## title (center), optional right-side content (e.g. HP badge).
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = INK
	header_style.border_color = EMBER_MID
	header_style.set_border_width_all(0)
	header_style.border_width_bottom = 1
	header_style.content_margin_left = 32
	header_style.content_margin_right = 24
	header_style.content_margin_top = 12
	header_style.content_margin_bottom = 12

	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size.y = 92
	header_panel.add_theme_stylebox_override("panel", header_style)
	header_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var inner_hbox := HBoxContainer.new()
	inner_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_hbox.add_theme_constant_override("separation", 12)
	inner_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	header_panel.add_child(inner_hbox)

	inner_hbox.add_child(build_step_bar(current_step))

	var title_label := Label.new()
	title_label.text = title_text
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(FOG, 0.7))
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var reg_font := _get_font("regular")
	if reg_font:
		title_label.add_theme_font_override("font", reg_font)
	inner_hbox.add_child(title_label)

	if right_content:
		inner_hbox.add_child(right_content)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(260, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner_hbox.add_child(spacer)

	return header_panel

static func build_footer(back_text: String, back_cb: Callable, next_text: String, next_cb: Callable) -> Dictionary:
	## Fixed nav bar shared by every pre-run screen: Back is always bottom-left,
	## Next is always bottom-right. Screens can drop screen-specific content
	## (difficulty modifiers, item counts, ...) into the returned "center" node
	## without disturbing where Back/Next sit.
	## Returns {panel, back_btn, next_btn, center}.
	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = INK
	footer_style.border_width_top = 1
	footer_style.border_width_left = 0
	footer_style.border_width_right = 0
	footer_style.border_width_bottom = 0
	footer_style.border_color = EMBER_MID
	footer_style.content_margin_left = 32
	footer_style.content_margin_right = 32
	footer_style.content_margin_top = 16
	footer_style.content_margin_bottom = 16

	var footer_panel := PanelContainer.new()
	footer_panel.custom_minimum_size.y = 96
	footer_panel.add_theme_stylebox_override("panel", footer_style)
	footer_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	footer_panel.add_child(hbox)

	var back_btn := build_ghost_button(back_text)
	if back_cb.is_valid():
		back_btn.pressed.connect(back_cb)
	hbox.add_child(back_btn)

	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(center)

	var next_btn := build_primary_button(next_text)
	if next_cb.is_valid():
		next_btn.pressed.connect(next_cb)
	hbox.add_child(next_btn)

	return {"panel": footer_panel, "back_btn": back_btn, "next_btn": next_btn, "center": center}

static func build_ghost_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 0)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var bold_font := _get_font("bold")
	if bold_font:
		btn.add_theme_font_override("font", bold_font)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", FOG)
	btn.add_theme_color_override("font_hover_color", PALE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.4)
	normal.set_border_width_all(2)
	normal.border_color = Color(FOG, 0.55)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = EMBER_MID
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)
	return btn

static func build_primary_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 0)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var bold_font := _get_font("bold")
	if bold_font:
		btn.add_theme_font_override("font", bold_font)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", PALE)
	btn.add_theme_color_override("font_hover_color", PALE)
	btn.add_theme_color_override("font_disabled_color", Color(FOG, 0.5))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#2A1A0ECC")
	normal.set_border_width_all(2)
	normal.border_color = EMBER_GLOW
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#4A3020CC")
	hover.border_color = EMBER_BRIGHT
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("#1A1A1A55")
	disabled.border_color = Color("#4A5060", 0.4)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", normal)
	return btn

static func ensure_background(screen: Control) -> void:
	## Adds the shared background texture + vignette as the first two children
	## of `screen`, if not already present. Used by screens (e.g. QuestSelectScreen)
	## whose .tscn predates the shared pre-run look.
	if screen.get_node_or_null("BackgroundTexture"):
		return
	var bg_tex: Texture2D = load("res://Path-of-Embers/Art Assets/Start Menu/Main Menu background v2.png")
	if bg_tex:
		var bg := TextureRect.new()
		bg.name = "BackgroundTexture"
		bg.texture = bg_tex
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(bg)
		screen.move_child(bg, 0)

	var vignette_shader: Shader = load("res://shaders/vignette.gdshader")
	if vignette_shader:
		var mat := ShaderMaterial.new()
		mat.shader = vignette_shader
		mat.set_shader_parameter("opacity", 0.35)
		var vignette := ColorRect.new()
		vignette.name = "VignetteRect"
		vignette.material = mat
		vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(vignette)
		screen.move_child(vignette, 1)

	var dim_overlay := ColorRect.new()
	dim_overlay.name = "DimOverlay"
	dim_overlay.color = Color(0.04, 0.035, 0.03, 0.78)
	dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dim_overlay)
	screen.move_child(dim_overlay, 2)
