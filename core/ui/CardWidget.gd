extends Control
class_name CardWidget

## Unified card widget used everywhere (combat hand, deck view, reward screen)
## Handles visual display only - no interaction logic

var deck_card_data: DeckCardData = null

# UI nodes
var card_panel: Panel
var content_container: Control  # Container with clip_contents for text bounds
var cost_label: Label
var type_label: Label
var name_label: Label
var keywords_container: VBoxContainer
var stats_container: VBoxContainer
var owner_label: Label

# Card textures
const ATTACK_CARD_TEXTURE_PATH = "res://Path-of-Embers/Art Assets/Card Assets/Attack Card.png"
var attack_card_texture: Texture2D = null

func _ready():
	# Preload attack card texture
	if ResourceLoader.exists(ATTACK_CARD_TEXTURE_PATH):
		attack_card_texture = load(ATTACK_CARD_TEXTURE_PATH)
	_setup_ui()

func _setup_ui():
	# Card panel (background) - make it solid
	card_panel = Panel.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add style to make panel solid (fully opaque)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray, fully opaque
	card_panel.add_theme_stylebox_override("panel", style_box)
	add_child(card_panel)
	
	# Content container with clipping to ensure text stays within bounds
	content_container = Control.new()
	content_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_container.clip_contents = true
	content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(content_container)
	
	# Margin container for padding
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_container.add_child(margin)
	
	# Main VBox for vertical layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	
	# Cost label - TOP-LEFT (using HBoxContainer to position it)
	var cost_hbox = HBoxContainer.new()
	cost_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_hbox)
	
	cost_label = Label.new()
	cost_label.text = "1"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT  # LEFT-ALIGNED
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.custom_minimum_size = Vector2(0, 20)
	cost_hbox.add_child(cost_label)
	
	# Type label - to the right of cost
	type_label = Label.new()
	type_label.text = ""
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.custom_minimum_size = Vector2(0, 20)
	cost_hbox.add_child(type_label)
	
	# Name label
	name_label = Label.new()
	name_label.text = "Card"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_contents = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(name_label)
	
	# Keywords container (ORDER: 1. Keywords)
	keywords_container = VBoxContainer.new()
	keywords_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(keywords_container)
	
	# Stats container (ORDER: 2. Damage, 3. Block, 4. Heal)
	stats_container = VBoxContainer.new()
	stats_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_container)
	
	# Owner label (bottom)
	owner_label = Label.new()
	owner_label.text = ""
	owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_label.add_theme_font_size_override("font_size", 10)
	owner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_label.clip_contents = true
	owner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_label.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(owner_label)
	
	# Set minimum size (75% larger: 120*1.75=210, 160*1.75=280)
	custom_minimum_size = Vector2(210, 280)

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
	
	# Validate card instance
	if not CardValidation.validate_card_instance(deck_card_data, "CardWidget._update_display"):
		if name_label:
			name_label.text = "INVALID CARD INSTANCE"
			name_label.modulate = Color.RED
		return
	
	# Get card data
	var card_data = DataRegistry.get_card_data(deck_card_data.card_id)
	if not card_data:
		return
	
	# Update name
	if name_label:
		var display_name = DataRegistry.get_card_display_name(deck_card_data.card_id)
		name_label.text = display_name
		name_label.modulate = Color.WHITE
	
	# Update cost (top-left, left-aligned)
	if cost_label and deck_card_data.instance_id:
		var effective_cost = CardRules.get_effective_cost(card_data, deck_card_data)
		cost_label.text = str(effective_cost)
		# Color cost if modified
		if CardRules.is_cost_modified(card_data, deck_card_data):
			if effective_cost == 0:
				cost_label.modulate = CardRules.COLOR_MODIFIED_ZERO_COST
			else:
				cost_label.modulate = CardRules.COLOR_MODIFIED_COST
		else:
			cost_label.modulate = CardRules.COLOR_NORMAL
	
	# Update card type (top-right)
	if type_label:
		var type_names = {
			CardData.CardType.ATTACK: "Attack",
			CardData.CardType.SKILL: "Skill",
			CardData.CardType.POWER: "Power",
			CardData.CardType.CURSE: "Curse"
		}
		type_label.text = type_names.get(card_data.card_type, "")
	
	# Clear and rebuild keywords (ORDER: 1)
	if keywords_container:
		for child in keywords_container.get_children():
			child.queue_free()
		
		var keywords = CardRules.get_card_keywords(deck_card_data)
		for keyword in keywords:
			var keyword_label = Label.new()
			keyword_label.text = keyword
			keyword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			keyword_label.add_theme_font_size_override("font_size", 12)
			keyword_label.modulate = Color(1.0, 0.84, 0.0, 1.0)  # Gold color
			keyword_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			keyword_label.custom_minimum_size = Vector2(0, 20)
			keyword_label.clip_contents = true
			keywords_container.add_child(keyword_label)
	
	# Clear and rebuild stats in correct order (ORDER: 2. Damage, 3. Block, 4. Heal)
	if stats_container:
		for child in stats_container.get_children():
			child.queue_free()
		
		var damage = CardRules.get_effective_damage(card_data, deck_card_data)
		var block = CardRules.get_effective_block(card_data, deck_card_data)
		var heal = CardRules.get_effective_heal(card_data, deck_card_data)
		
		# Display damage (ORDER: 2)
		if damage > 0:
			var damage_label = Label.new()
			damage_label.text = "Damage: " + str(damage)
			damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			damage_label.clip_contents = true
			if CardRules.is_damage_modified(card_data, deck_card_data):
				damage_label.modulate = CardRules.COLOR_MODIFIED_VALUE
			else:
				damage_label.modulate = CardRules.COLOR_NORMAL
			damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_container.add_child(damage_label)
		
		# Display block (ORDER: 3)
		if block > 0:
			var block_label = Label.new()
			block_label.text = "Block: " + str(block)
			block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			block_label.clip_contents = true
			if CardRules.is_block_modified(card_data, deck_card_data):
				block_label.modulate = CardRules.COLOR_MODIFIED_VALUE
			else:
				block_label.modulate = CardRules.COLOR_NORMAL
			block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_container.add_child(block_label)
		
		# Display heal (ORDER: 4)
		if heal > 0:
			var heal_label = Label.new()
			heal_label.text = "Heal: " + str(heal)
			heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			heal_label.clip_contents = true
			if CardRules.is_heal_modified(card_data, deck_card_data):
				heal_label.modulate = CardRules.COLOR_MODIFIED_VALUE
			else:
				heal_label.modulate = CardRules.COLOR_NORMAL
			heal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_container.add_child(heal_label)
		
		# Display effect descriptions for effects not shown as stats (ORDER: 5)
		var effects = CardRules.get_card_effects_for_display(card_data, deck_card_data)
		var shown_stat_types = []  # Track which stat types we've shown
		if damage > 0:
			shown_stat_types.append("damage")
		if block > 0:
			shown_stat_types.append("block")
		if heal > 0:
			shown_stat_types.append("heal")
		
		# Filter and display other effects
		for effect in effects:
			if not effect is EffectData:
				continue
			
			# Skip effects that are already shown as stats
			if effect.effect_type == EffectType.DAMAGE and shown_stat_types.has("damage"):
				continue
			if effect.effect_type == EffectType.BLOCK and shown_stat_types.has("block"):
				continue
			if effect.effect_type == EffectType.HEAL and shown_stat_types.has("heal"):
				continue
			
			# Generate and display description
			var desc = _generate_effect_description(effect, card_data)
			if desc != "":
				var effect_label = Label.new()
				effect_label.text = desc
				effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				effect_label.clip_contents = true
				effect_label.modulate = CardRules.COLOR_NORMAL
				effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				effect_label.custom_minimum_size = Vector2(0, 20)
				stats_container.add_child(effect_label)
	
	# Update owner
	if owner_label:
		if deck_card_data.owner_character_id:
			var owner_name = DataRegistry.get_character_display_name(deck_card_data.owner_character_id)
			owner_label.text = owner_name
		else:
			owner_label.text = ""
	
	# Visual styling for upgraded cards and card type textures
	if card_panel:
		# Set texture based on card type - use StyleBoxTexture for attack cards
		if card_data.card_type == CardData.CardType.ATTACK and attack_card_texture:
			# Use StyleBoxTexture for attack cards with texture
			var texture_style_box = StyleBoxTexture.new()
			texture_style_box.texture = attack_card_texture
			# Stretch texture to fill the entire card (both horizontal and vertical)
			texture_style_box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			texture_style_box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			card_panel.add_theme_stylebox_override("panel", texture_style_box)
		else:
			# For non-attack cards, use solid color background with StyleBoxFlat
			var flat_style_box = StyleBoxFlat.new()
			flat_style_box.bg_color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray
			card_panel.add_theme_stylebox_override("panel", flat_style_box)
		
		# Apply golden tint for upgraded cards
		if deck_card_data.applied_upgrades.size() > 0:
			card_panel.modulate = Color(1.1, 1.05, 0.95, 1.0)  # Golden tint
		else:
			card_panel.modulate = Color.WHITE

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
			return "The next card you play doesn't advance enemy timer"
		
		"add_curse_to_hand":
			return "Add a Curse card to hand"
		
		"damage_per_curse":
			var base_amount = effect.params.get("base_amount", 0)
			var per_curse = effect.params.get("per_curse", 0)
			if per_curse > 0:
				return "Deal %d damage (+%d per Curse in hand/discard)" % [base_amount, per_curse]
			else:
				return "Deal %d damage" % base_amount
		
		"conditional_strength_if_no_damage":
			var amount = effect.params.get("amount", 1)
			return "If you take no damage this turn, gain %d Strength" % amount
		
		"retain_block_this_turn":
			return "Do not lose block at end of turn"
		
		"block_on_enemy_act":
			var amount = effect.params.get("amount", 1)
			return "Gain %d block whenever an enemy acts" % amount
		
		"damage_on_block_gain":
			var amount = effect.params.get("amount", 1)
			return "Deal %d damage to a random enemy whenever you gain Block" % amount
		
		"draw":
			var amount = effect.params.get("amount", 1)
			return "Draw %d card%s" % [amount, "s" if amount != 1 else ""]
		
		"damage_conditional_elite":
			var normal_damage = effect.params.get("normal_amount", 18)
			var elite_damage = effect.params.get("elite_amount", 36)
			return "Deal %d damage (%d to Elite/Boss)" % [normal_damage, elite_damage]
		
		"ApplyStatus":
			var status_type = effect.params.get("status_type", "")
			var status_value = effect.params.get("value", 0)
			# Try to format status name nicely
			var status_name = status_type.capitalize()
			return "Apply %d %s" % [status_value, status_name]
		
		_:
			# Unknown effect type - return basic info
			return "Effect: %s" % effect.effect_type
