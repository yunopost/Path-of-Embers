extends Control
class_name CardWidget

## Unified card widget used everywhere (combat hand, deck view, reward screen)
## Handles visual display only - no interaction logic

var deck_card_data: DeckCardData = null
var card_width: float = 210.0

## Optional live-preview context (Job: real-time card numbers). When set, the
## Damage/Block/Heal/Energy lines are computed by CardRules.get_live_preview
## (owner's Strength/Dexterity/Faith incl. equipment, shared in-combat
## statuses, Vulnerable/Weakness/Agility, pile sizes, Curses in hand) instead
## of the static upgrade-only values -- see CardRules.gd. Left null outside
## combat (deck view, reward screen), where the static values are correct.
var combat_controller: Node = null
var preview_target: EntityStats = null

# UI nodes
var card_panel: Panel
var cost_orb: Panel
var cost_label: Label
var name_label: Label
var type_pip: ColorRect
var rarity_banner: ColorRect
var art_area: Panel
var art_icon_label: Label
var art_portrait: TextureRect
var art_scrim: TextureRect
var owner_accent_bar: ColorRect
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

# ── Owner accent colors ─────────────────────────────────────────────────────
## One color per character, defined here in a single place so the art director
## can retune the whole game's owner-identity palette in one edit. Chosen from
## the colorblind-safe Okabe-Ito palette so no two characters are distinguished
## only by a red/green difference. Applied as a single mechanism (a thin accent
## bar layered on top of the type frame, plus the portrait-area border) — see
## _update_display. Keyed by CharacterData.id / CardData.owner_character_id.
const OWNER_ACCENT_COLORS = {
	"golemancer": Color("#E69F00"),    # Golemancer — orange
	"grove": Color("#009E73"),         # Grove — bluish green
	"living_armor": Color("#56B4E9"),  # Living Armor — sky blue
	"warrior_1": Color("#D55E00"),     # Monster Hunter — vermillion
	"warrior_2": Color("#0072B2"),     # Shadowfoot — blue
	"witch": Color("#CC79A7"),         # Witch — reddish purple
}
const DEFAULT_OWNER_ACCENT_COLOR = Color("#4A4A4A")  # generic / no-owner cards

# Cost orb colors
const COST_ORB_COLOR = Color("#C4881A")         # Amber — normal cost
const COST_ORB_COLOR_FREE = Color("#2D7A2D")    # Green — free card
const COST_ORB_BORDER_COLOR = Color("#FFD700")   # Gold — orb ring

# Font paths (gracefully absent until fonts are dropped in)
const FONT_CINZEL_BOLD = "res://fonts/Cinzel/static/Cinzel-Bold.ttf"
const FONT_NOTO_SANS = "res://fonts/Noto_Sans/static/NotoSans-Regular.ttf"
const FONT_NOTO_SANS_BOLD = "res://fonts/Noto_Sans/static/NotoSans-Bold.ttf"

## ── Art resolution (Job: character portraits) ────────────────────────────
## Pure/static so it can be exercised by tests without spinning up a node
## tree, and so the "which art wins" logic lives in exactly one place instead
## of being duplicated at each CardWidget/CardUI call site.

static func get_owner_accent_color(character_id: String) -> Color:
	## The one accent color for a character, or DEFAULT_OWNER_ACCENT_COLOR for
	## an empty/unknown id (generic cards like strike_1/defend_1).
	if character_id == "":
		return DEFAULT_OWNER_ACCENT_COLOR
	return OWNER_ACCENT_COLORS.get(character_id, DEFAULT_OWNER_ACCENT_COLOR)

static func resolve_owner_id(card_data: CardData, card_inst: DeckCardData = null) -> String:
	## The character a card belongs to *in this run*, which is what the player
	## needs to see. The instance wins over the blueprint: strike_1 and defend_1
	## carry no owner on CardData, but every copy in a real deck was contributed
	## by a specific character, and it is that character's stats which modify it
	## (CardRules.get_live_preview reads card_inst.owner_character_id). Reading
	## only the blueprint would leave the party's Strikes and Defends unmarked
	## while their numbers were quietly being changed by an owner the card never
	## names.
	if card_inst != null and card_inst.owner_character_id != "":
		return card_inst.owner_character_id
	if card_data != null:
		return card_data.owner_character_id
	return ""

static func resolve_card_art_path(card_data: CardData, card_inst: DeckCardData = null) -> String:
	## Resolution order: bespoke per-card art (CardData.art_path) when set and
	## present on disk; otherwise the owning character's portrait
	## (CharacterData.portrait_path) when the card has an owner and that file
	## is present on disk; otherwise "" (no art -- caller falls back to the
	## default type-icon treatment). This is the single hook bespoke per-card
	## art should plug into later: set CardData.art_path and nothing else
	## needs to change.
	if not card_data:
		return ""
	if card_data.art_path != "" and ResourceLoader.exists(card_data.art_path):
		return card_data.art_path
	var owner_id_for_art := resolve_owner_id(card_data, card_inst)
	if owner_id_for_art != "" and DataRegistry:
		var char_data: CharacterData = DataRegistry.get_character(owner_id_for_art)
		if char_data and char_data.portrait_path != "" and ResourceLoader.exists(char_data.portrait_path):
			return char_data.portrait_path
	return ""

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
	custom_minimum_size = Vector2(card_width, 280)

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

	# Owner accent bar — a thin colored spine along the left edge, layered on
	# top of the type-colored card_panel border (see OWNER_ACCENT_COLORS).
	# Sits in the margin's own 5px gutter so it never overlaps any label.
	# Invisible (alpha 0) for generic/no-owner cards -- the default treatment.
	owner_accent_bar = ColorRect.new()
	owner_accent_bar.anchor_left = 0.0
	owner_accent_bar.anchor_top = 0.0
	owner_accent_bar.anchor_right = 0.0
	owner_accent_bar.anchor_bottom = 1.0
	owner_accent_bar.offset_right = 5
	owner_accent_bar.color = Color(0, 0, 0, 0)
	owner_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(owner_accent_bar)

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

	# ── Art area (character portrait, or type-icon placeholder) ────────────
	art_area = Panel.new()
	art_area.custom_minimum_size = Vector2(0, 80)
	art_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_area.clip_contents = true  # portrait uses cover-crop; clip any overhang
	art_area.add_theme_stylebox_override("panel",
		_make_flat_style(TYPE_ART_COLORS[0], Color.TRANSPARENT, 0, 2))
	vbox.add_child(art_area)

	# Portrait texture -- cropped/scaled to fill the art area without
	# distorting aspect ratio (STRETCH_KEEP_ASPECT_COVERED). Hidden (no
	# texture) for generic cards, which fall back to the type-icon treatment.
	art_portrait = TextureRect.new()
	art_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_portrait.visible = false
	art_area.add_child(art_portrait)

	# Scrim -- darkens the lower portion of the art area so any text a future
	# layout places over the portrait (or the art area's own bottom edge
	# against the separator) stays legible against busy character art.
	art_scrim = TextureRect.new()
	art_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	art_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_scrim.visible = false
	var scrim_gradient = Gradient.new()
	scrim_gradient.set_color(0, Color(0, 0, 0, 0.0))
	scrim_gradient.set_color(1, Color(0, 0, 0, 0.55))
	var scrim_texture = GradientTexture2D.new()
	scrim_texture.gradient = scrim_gradient
	scrim_texture.fill_from = Vector2(0, 0.4)
	scrim_texture.fill_to = Vector2(0, 1)
	scrim_texture.width = 4
	scrim_texture.height = 64
	art_scrim.texture = scrim_texture
	art_area.add_child(art_scrim)

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

func set_preview_context(cc: Node, target: EntityStats = null) -> void:
	## Set (or update) the live-combat context this card previews against --
	## see `combat_controller`/`preview_target` above. Re-renders immediately
	## so a changed target (e.g. dragging over a different enemy) is reflected
	## right away.
	combat_controller = cc
	preview_target = target
	if deck_card_data:
		_update_display()

func refresh() -> void:
	## Re-render against the current preview context. Cheap enough to call
	## every frame for a hand's worth of cards; used to keep the numbers live
	## as stats/equipment/statuses/piles change without a card ever moving.
	if deck_card_data:
		_update_display()

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

	# ── Owner accent bar (Job: character identification) ────────────────────
	# Layers on top of the type frame; invisible for generic/no-owner cards.
	var owner_id: String = resolve_owner_id(card_data, deck_card_data)
	var accent_color := get_owner_accent_color(owner_id)
	if owner_accent_bar:
		owner_accent_bar.color = accent_color if owner_id != "" else Color(0, 0, 0, 0)

	# ── Art area: character portrait (or bespoke art), type icon fallback ──
	var art_path := resolve_card_art_path(card_data, deck_card_data)
	var art_texture: Texture2D = null
	if art_path != "":
		var loaded = load(art_path)
		if loaded is Texture2D:
			art_texture = loaded

	if art_area:
		var art_bg = TYPE_ART_COLORS.get(ctype, TYPE_ART_COLORS[0])
		# Owner-colored border frames the portrait -- same accent, one
		# mechanism, layered with (not replacing) the type-colored card border.
		var portrait_border = accent_color if (art_texture and owner_id != "") else Color.TRANSPARENT
		var portrait_border_width = 3 if (art_texture and owner_id != "") else 0
		art_area.add_theme_stylebox_override("panel",
			_make_flat_style(art_bg, portrait_border, portrait_border_width, 2))

	if art_portrait:
		if art_texture:
			art_portrait.texture = art_texture
			art_portrait.visible = true
		else:
			art_portrait.texture = null
			art_portrait.visible = false

	if art_scrim:
		# Only needed to keep text legible when a portrait is showing; the
		# default icon-only treatment doesn't need it.
		art_scrim.visible = art_texture != null

	if art_icon_label:
		art_icon_label.text = TYPE_ICONS.get(ctype, "?")
		# Default/no-art treatment for generic cards; hidden once a portrait
		# fills the art area so it doesn't double up with the character art.
		art_icon_label.visible = art_texture == null

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

		# Live preview: the real numbers this card produces right now for its
		# owner (Strength/Dexterity/Faith incl. equipment, shared statuses,
		# Vulnerable/Weakness/Agility, pile sizes, Curses in hand) when a combat
		# context is set; otherwise falls back to the static upgrade-only
		# values (deck view / reward screen, outside combat).
		var live = CardRules.get_live_preview(card_data, deck_card_data, combat_controller, preview_target)
		var damage = live.damage
		var block = live.block
		var heal = live.heal
		var energy = live.energy
		var shown_stat_types = []

		if damage > 0:
			shown_stat_types.append("damage")
			_add_stat_label(stats_container, "Damage: %d" % damage, live.damage_modified)
		if block > 0:
			shown_stat_types.append("block")
			_add_stat_label(stats_container, "Block: %d" % block, live.block_modified)
		if heal > 0:
			shown_stat_types.append("heal")
			_add_stat_label(stats_container, "Heal: %d" % heal, live.heal_modified)
		if energy > 0:
			_add_stat_label(stats_container, "Energy: %d" % energy, live.energy_modified)

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
			var min_cost = effect.params.get("conditional_draw_min_cost", 0)
			var draw_amount = effect.params.get("conditional_draw_amount", 0)
			if min_cost > 0 and draw_amount > 0:
				return "The next card you play gains Haste. If that card costs %d or more, draw %d" % [min_cost, draw_amount]
			return "The next card you play gains Haste"

		"next_card_haste_and_discount":
			var discount = effect.params.get("discount", 1)
			var grant_haste = effect.params.get("grant_haste", true)
			if grant_haste:
				return "The next card you play gains Haste and costs %d less" % discount
			return "The next card you play costs %d less" % discount

		"agility":
			var duration = effect.params.get("duration", 1)
			return "Apply %d Agility" % duration

		"damage_if_last_applied_debuff":
			var base_amount = effect.params.get("base_amount", 0)
			var bonus_amount = effect.params.get("bonus_amount", 0)
			return "Deal %d damage (+%d if the last card you played applied a debuff)" % [base_amount, bonus_amount]

		"damage_per_curse_in_hand":
			var base_amount = effect.params.get("base_amount", 0)
			var per_curse = effect.params.get("per_curse", 0)
			return "Deal %d damage for each Curse in your hand" % per_curse if base_amount == 0 else "Deal %d damage (+%d per Curse in hand)" % [base_amount, per_curse]

		"block_equal_to_pile_size":
			var pile = effect.params.get("pile", "discard")
			return "Gain Block equal to the number of cards in your %s pile" % pile

		"damage_equal_to_pile_size":
			var pile2 = effect.params.get("pile", "draw")
			return "Deal damage equal to the number of cards in your %s pile" % pile2

		"mill_draw_pile":
			var amount = effect.params.get("amount", 1)
			return "Put the top %d card%s of your draw pile into your discard pile" % [amount, "s" if amount != 1 else ""]

		"exhaust_hand_curses":
			return "Exhaust all Curses from your hand. Gain energy and draw a card for each exhausted"

		"energy_per_discard_pile":
			var per = effect.params.get("per", 4)
			var cap = effect.params.get("max", 3)
			return "Gain 1 Energy for every %d cards in your discard pile (max %d)" % [per, cap]

		"gain_energy":
			var amount = effect.params.get("amount", 1)
			return "Gain %d Energy" % amount

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
			return "If you've taken no damage since the last enemy action, gain %d Strength" % amount

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
			var divisor = effect.params.get("divisor", 1)
			if divisor == 2:
				return "Deal damage equal to half your current Block, rounded up"
			elif divisor > 1:
				return "Deal damage equal to 1/%d of your current Block, rounded up" % divisor
			return "Deal damage equal to your current Block"

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
