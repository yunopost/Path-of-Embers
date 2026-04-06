extends Control
class_name CardWidget

## Unified card widget used everywhere (combat hand, deck view, reward screen)
## Handles visual display only - no interaction logic

var deck_card_data: DeckCardData = null

# UI nodes
var card_panel: Panel
var cost_orb: Panel
var cost_label: Label
var name_label: Label
var type_pip: ColorRect
var rarity_banner: ColorRect
var art_area: Panel
var art_icon_label: Label
var keywords_container: VBoxContainer
var stats_container: VBoxContainer
var owner_label: Label
var upgrade_indicator: Label

# Fonts (populated if .ttf files exist in fonts/)
var _cinzel_bold: Font = null
var _noto_sans: Font = null
var _noto_sans_bold: Font = null

# Type color palette
const TYPE_BORDER_COLORS = {
	0: Color("#8B2020"),  # Attack — dark crimson
	1: Color("#1A4A6B"),  # Skill — dark steel blue
	2: Color("#4B1A6B"),  # Power — dark purple
	3: Color("#2A2A2A"),  # Curse — near-black
}
const TYPE_BG_COLORS = {
	0: Color("#1A0808"),  # Attack
	1: Color("#0D2035"),  # Skill
	2: Color("#1A0828"),  # Power
	3: Color("#111111"),  # Curse
}
const TYPE_ART_COLORS = {
	0: Color("#2A1010"),  # Attack
	1: Color("#0A1A28"),  # Skill
	2: Color("#1A0A28"),  # Power
	3: Color("#0A0A0A"),  # Curse
}
const TYPE_ICONS = {
	0: "⚔",  # Attack
	1: "◈",  # Skill
	2: "★",  # Power
	3: "✗",  # Curse
}
const TYPE_PIP_COLORS = {
	0: Color("#FF4444"),  # Attack
	1: Color("#44AAFF"),  # Skill
	2: Color("#CC44FF"),  # Power
	3: Color("#666666"),  # Curse
}

# Rarity colors
const RARITY_COLORS = {
	0: Color("#555555"),  # Common — gray
	1: Color("#2D6AA0"),  # Uncommon — blue
	2: Color("#B8860B"),  # Rare — dark gold
}

# Cost orb colors
const COST_ORB_COLOR = Color("#C4881A")         # Amber — normal cost
const COST_ORB_COLOR_FREE = Color("#2D7A2D")    # Green — free card
const COST_ORB_BORDER_COLOR = Color("#FFD700")   # Gold — orb ring

# Font paths (gracefully absent until fonts are dropped in)
const FONT_CINZEL_BOLD = "res://fonts/Cinzel/static/Cinzel-Bold.ttf"
const FONT_NOTO_SANS = "res://fonts/Noto_Sans/static/NotoSans-Regular.ttf"
const FONT_NOTO_SANS_BOLD = "res://fonts/Noto_Sans/static/NotoSans-Bold.ttf"

func _ready():
	_load_fonts()
	_setup_ui()

func _load_fonts():
	if ResourceLoader.exists(FONT_CINZEL_BOLD):
		_cinzel_bold = load(FONT_CINZEL_BOLD)
	if ResourceLoader.exists(FONT_NOTO_SANS):
		_noto_sans = load(FONT_NOTO_SANS)
	if ResourceLoader.exists(FONT_NOTO_SANS_BOLD):
		_noto_sans_bold = load(FONT_NOTO_SANS_BOLD)

func _apply_font(label: Label, font: Font, size: int):
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)

func _make_flat_style(bg: Color, border: Color = Color.TRANSPARENT,
		border_width: int = 0, corner_radius: int = 4) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = corner_radius
	s.corner_radius_top_right = corner_radius
	s.corner_radius_bottom_left = corner_radius
	s.corner_radius_bottom_right = corner_radius
	if border_width > 0:
		s.border_color = border
		s.border_width_left = border_width
		s.border_width_right = border_width
		s.border_width_top = border_width
		s.border_width_bottom = border_width
	return s

func _setup_ui():
	custom_minimum_size = Vector2(210, 280)

	# Outer panel — carries the type-colored border and background
	card_panel = Panel.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Default style (overwritten per card type in _update_display)
	card_panel.add_theme_stylebox_override("panel",
		_make_flat_style(Color("#1A0808"), Color("#8B2020"), 2, 4))
	add_child(card_panel)

	# Clipping container
	var clip = Control.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(clip)

	# Outer margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(margin)

	# Root vertical layout
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)

	# ── Top strip: cost orb | name | type pip ──────────────────────────────
	var top_strip = HBoxContainer.new()
	top_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_strip.add_theme_constant_override("separation", 3)
	top_strip.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(top_strip)

	# Cost orb (28×28 circle)
	cost_orb = Panel.new()
	cost_orb.custom_minimum_size = Vector2(28, 28)
	cost_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_orb.add_theme_stylebox_override("panel",
		_make_flat_style(COST_ORB_COLOR, COST_ORB_BORDER_COLOR, 1, 14))
	top_strip.add_child(cost_orb)

	cost_label = Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(cost_label, _cinzel_bold, 14)
	cost_orb.add_child(cost_label)

	# Card name (expanding center)
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(name_label, _cinzel_bold, 12)
	top_strip.add_child(name_label)

	# Type pip (small colored square — right edge)
	type_pip = ColorRect.new()
	type_pip.custom_minimum_size = Vector2(8, 8)
	type_pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	type_pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_strip.add_child(type_pip)

	# ── Rarity banner (4px colored strip) ─────────────────────────────────
	rarity_banner = ColorRect.new()
	rarity_banner.custom_minimum_size = Vector2(0, 4)
	rarity_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_banner)

	# ── Art area (placeholder with type icon) ─────────────────────────────
	art_area = Panel.new()
	art_area.custom_minimum_size = Vector2(0, 80)
	art_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_area.add_theme_stylebox_override("panel",
		_make_flat_style(TYPE_ART_COLORS[0], Color.TRANSPARENT, 0, 2))
	vbox.add_child(art_area)

	art_icon_label = Label.new()
	art_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_icon_label.modulate = Color(1, 1, 1, 0.3)
	art_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(art_icon_label, _cinzel_bold, 28)
	art_area.add_child(art_icon_label)

	# ── Separator ──────────────────────────────────────────────────────────
	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(1, 1, 1, 0.15)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# ── Description area (keywords + effects) ─────────────────────────────
	var desc_area = VBoxContainer.new()
	desc_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_area.add_theme_constant_override("separation", 1)
	vbox.add_child(desc_area)

	keywords_container = VBoxContainer.new()
	keywords_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_area.add_child(keywords_container)

	stats_container = VBoxContainer.new()
	stats_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_area.add_child(stats_container)

	# Owner label (very small, bottom)
	owner_label = Label.new()
	owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_label.modulate = Color(1, 1, 1, 0.35)
	owner_label.custom_minimum_size = Vector2(0, 12)
	_apply_font(owner_label, _noto_sans, 9)
	vbox.add_child(owner_label)

	# ── Upgrade indicator (★ top-right corner) ────────────────────────────
	upgrade_indicator = Label.new()
	upgrade_indicator.text = "★"
	upgrade_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	upgrade_indicator.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	upgrade_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	upgrade_indicator.offset_left = -22
	upgrade_indicator.offset_top = 2
	upgrade_indicator.modulate = Color("#FFD700")
	upgrade_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(upgrade_indicator, _cinzel_bold, 14)
	upgrade_indicator.visible = false
	clip.add_child(upgrade_indicator)

func setup_card(deck_card: DeckCardData):
	## Setup card with DeckCardData instance
	deck_card_data = deck_card
	if is_inside_tree():
		_update_display()
	else:
		call_deferred("_update_display")

func _update_display():
	if not deck_card_data:
		return

	if not CardValidation.validate_card_instance(deck_card_data, "CardWidget._update_display"):
		if name_label:
			name_label.text = "INVALID"
			name_label.modulate = Color.RED
		return

	var card_data = DataRegistry.get_card_data(deck_card_data.card_id)
	if not card_data:
		return

	var ctype: int = card_data.card_type

	# ── Card frame: type-colored border + background ───────────────────────
	if card_panel:
		var bg = TYPE_BG_COLORS.get(ctype, Color("#1A0808"))
		var border = TYPE_BORDER_COLORS.get(ctype, Color("#8B2020"))
		card_panel.add_theme_stylebox_override("panel",
			_make_flat_style(bg, border, 2, 4))

	# ── Type pip ───────────────────────────────────────────────────────────
	if type_pip:
		type_pip.color = TYPE_PIP_COLORS.get(ctype, Color("#FF4444"))

	# ── Rarity banner ─────────────────────────────────────────────────────
	if rarity_banner:
		rarity_banner.color = RARITY_COLORS.get(card_data.rarity, RARITY_COLORS[0])

	# ── Art area: placeholder tint + icon ─────────────────────────────────
	if art_area:
		var art_bg = TYPE_ART_COLORS.get(ctype, TYPE_ART_COLORS[0])
		art_area.add_theme_stylebox_override("panel",
			_make_flat_style(art_bg, Color.TRANSPARENT, 0, 2))
	if art_icon_label:
		art_icon_label.text = TYPE_ICONS.get(ctype, "?")

	# ── Card name ─────────────────────────────────────────────────────────
	if name_label:
		name_label.text = DataRegistry.get_card_display_name(deck_card_data.card_id)
		name_label.modulate = Color.WHITE

	# ── Cost orb ──────────────────────────────────────────────────────────
	if cost_label and deck_card_data.instance_id:
		var effective_cost = CardRules.get_effective_cost(card_data, deck_card_data)
		cost_label.text = str(effective_cost)

		# Orb color changes with cost state
		var orb_bg: Color
		var text_color: Color
		if effective_cost == 0:
			orb_bg = COST_ORB_COLOR_FREE
			text_color = Color(0.8, 1.0, 0.8)
		elif CardRules.is_cost_modified(card_data, deck_card_data):
			orb_bg = Color("#1A6B9A")  # Blue tint for reduced cost
			text_color = CardRules.COLOR_MODIFIED_COST
		else:
			orb_bg = COST_ORB_COLOR
			text_color = Color.WHITE
		cost_label.modulate = text_color
		if cost_orb:
			cost_orb.add_theme_stylebox_override("panel",
				_make_flat_style(orb_bg, COST_ORB_BORDER_COLOR, 1, 14))

	# ── Keywords ──────────────────────────────────────────────────────────
	if keywords_container:
		for child in keywords_container.get_children():
			child.queue_free()
		var keywords = CardRules.get_card_keywords(deck_card_data)
		for keyword in keywords:
			var kw_label = Label.new()
			kw_label.text = keyword
			kw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kw_label.modulate = Color(1.0, 0.84, 0.0, 1.0)
			kw_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			kw_label.clip_contents = true
			_apply_font(kw_label, _noto_sans_bold, 10)
			keywords_container.add_child(kw_label)

	# ── Effect descriptions ────────────────────────────────────────────────
	if stats_container:
		for child in stats_container.get_children():
			child.queue_free()

		var damage = CardRules.get_effective_damage(card_data, deck_card_data)
		var block = CardRules.get_effective_block(card_data, deck_card_data)
		var heal = CardRules.get_effective_heal(card_data, deck_card_data)
		var shown_stat_types = []

		if damage > 0:
			shown_stat_types.append("damage")
			_add_stat_label(stats_container, "Damage: %d" % damage,
				CardRules.is_damage_modified(card_data, deck_card_data))
		if block > 0:
			shown_stat_types.append("block")
			_add_stat_label(stats_container, "Block: %d" % block,
				CardRules.is_block_modified(card_data, deck_card_data))
		if heal > 0:
			shown_stat_types.append("heal")
			_add_stat_label(stats_container, "Heal: %d" % heal,
				CardRules.is_heal_modified(card_data, deck_card_data))

		# Other effects
		var effects = CardRules.get_card_effects_for_display(card_data, deck_card_data)
		for effect in effects:
			if not effect is EffectData:
				continue
			if effect.effect_type == EffectType.DAMAGE and "damage" in shown_stat_types:
				continue
			if effect.effect_type == EffectType.BLOCK and "block" in shown_stat_types:
				continue
			if effect.effect_type == EffectType.HEAL and "heal" in shown_stat_types:
				continue
			var desc = _generate_effect_description(effect, card_data)
			if desc != "":
				_add_stat_label(stats_container, desc, false)

	# ── Owner label ───────────────────────────────────────────────────────
	if owner_label:
		if deck_card_data.owner_character_id:
			owner_label.text = DataRegistry.get_character_display_name(
				deck_card_data.owner_character_id)
		else:
			owner_label.text = ""

	# ── Upgrade star ─────────────────────────────────────────────────────
	if upgrade_indicator:
		upgrade_indicator.visible = deck_card_data.applied_upgrades.size() > 0

func _add_stat_label(container: VBoxContainer, text: String, modified: bool):
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.clip_contents = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate = CardRules.COLOR_MODIFIED_VALUE if modified else CardRules.COLOR_NORMAL
	_apply_font(lbl, _noto_sans, 10)
	container.add_child(lbl)

func _generate_effect_description(effect: EffectData, _card_data: CardData) -> String:
	## Generate human-readable description from EffectData
	if not effect:
		return ""

	match effect.effect_type:
		"damage":
			var amount = effect.params.get("amount", 0)
			var hit_count = effect.params.get("hit_count", 1)
			var ignore_block = effect.params.get("ignore_block", false)
			var double_strength = effect.params.get("double_strength", false)
			var desc = "Deal %d damage" % amount
			if hit_count > 1:
				desc += " %d times" % hit_count
			if ignore_block:
				desc += " (ignores block)"
			if double_strength:
				desc += " (double Strength)"
			return desc

		"block":
			var amount = effect.params.get("amount", 0)
			return "Gain %d block" % amount

		"heal":
			var amount = effect.params.get("amount", 0)
			return "Heal %d" % amount

		"vulnerable":
			var duration = effect.params.get("duration", 1)
			return "Apply %d Vulnerable" % duration

		"vulnerable_all_enemies":
			var duration = effect.params.get("duration", 1)
			return "Apply %d Vulnerable to all enemies" % duration

		"strength":
			var amount = effect.params.get("amount", 1)
			return "Gain %d Strength" % amount

		"dexterity":
			var amount = effect.params.get("amount", 1)
			return "Gain %d Dexterity" % amount

		"faith":
			var amount = effect.params.get("amount", 1)
			return "Gain %d Faith" % amount

		"weakness":
			var duration = effect.params.get("duration", 1)
			return "Apply %d Weakness" % duration

		"grant_haste_next_card":
			return "Next card played doesn't advance enemy timer"

		"add_curse_to_hand":
			return "Add a Curse to hand"

		"damage_per_curse":
			var base_amount = effect.params.get("base_amount", 0)
			var per_curse = effect.params.get("per_curse", 0)
			if per_curse > 0:
				return "Deal %d damage (+%d per Curse)" % [base_amount, per_curse]
			else:
				return "Deal %d damage" % base_amount

		"conditional_strength_if_no_damage":
			var amount = effect.params.get("amount", 1)
			return "If no damage taken this turn, gain %d Strength" % amount

		"retain_block_this_turn":
			return "Block persists until next turn"

		"block_on_enemy_act":
			var amount = effect.params.get("amount", 1)
			return "Gain %d block whenever an enemy acts" % amount

		"damage_on_block_gain":
			var amount = effect.params.get("amount", 1)
			return "Deal %d damage to random enemy on block gain" % amount

		"draw":
			var amount = effect.params.get("amount", 1)
			return "Draw %d card%s" % [amount, "s" if amount != 1 else ""]

		"draw_per_turn":
			var amount = effect.params.get("amount", 1)
			return "Draw %d extra card%s each turn" % [amount, "s" if amount != 1 else ""]

		"damage_conditional_elite":
			var normal_damage = effect.params.get("normal_amount", 18)
			var elite_damage = effect.params.get("elite_amount", 36)
			return "Deal %d damage (%d vs Elite/Boss)" % [normal_damage, elite_damage]

		"damage_equal_to_block":
			return "Deal damage equal to your block"

		"damage_spite":
			var base_amount = effect.params.get("base_amount", 6)
			var bonus = effect.params.get("bonus_per_10_missing_hp", 3)
			return "Deal %d damage (+%d per 10 HP missing)" % [base_amount, bonus]

		"draw_if_took_damage":
			var amount = effect.params.get("amount", 2)
			return "If you took damage this turn, draw %d card%s" % [amount, "s" if amount != 1 else ""]

		"block_to_energy":
			var ratio = effect.params.get("block_per_energy", 3)
			return "Convert block to energy (%d:1)" % ratio

		"scry":
			var amount = effect.params.get("amount", 2)
			return "Look at top %d cards and reorder" % amount

		"mirror":
			return "Replay the last card you played"

		"resonance_block":
			var base = effect.params.get("base_amount", 4)
			var bonus = effect.params.get("bonus_if_last_was_skill", 3)
			return "Gain %d block (+%d if last card was a Skill)" % [base, bonus]

		"ApplyStatus":
			var status_type = effect.params.get("status_type", "")
			var status_value = effect.params.get("value", 0)
			return "Apply %d %s" % [status_value, status_type.capitalize()]

		_:
			return "Effect: %s" % effect.effect_type
