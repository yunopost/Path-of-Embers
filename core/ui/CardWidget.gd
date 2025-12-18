extends Control
class_name CardWidget

## Unified card widget used everywhere (combat hand, deck view, reward screen)
## Handles visual display only - no interaction logic

var deck_card_data: DeckCardData = null

# UI nodes
var card_panel: Panel
var content_container: Control  # Container with clip_contents for text bounds
var cost_label: Label
var name_label: Label
var keywords_container: VBoxContainer
var stats_container: VBoxContainer
var owner_label: Label

func _ready():
	_setup_ui()

func _setup_ui():
	# Card panel (background)
	card_panel = Panel.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	
	# Set minimum size
	custom_minimum_size = Vector2(120, 160)

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
	
	# Clear and rebuild keywords (ORDER: 1)
	if keywords_container:
		for child in keywords_container.get_children():
			child.queue_free()
		
		var keywords = CardRules.get_card_keywords(deck_card_data)
		for keyword in keywords:
			var keyword_label = Label.new()
			keyword_label.text = keyword
			keyword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	
	# Update owner
	if owner_label:
		if deck_card_data.owner_character_id:
			var owner_name = DataRegistry.get_character_display_name(deck_card_data.owner_character_id)
			owner_label.text = owner_name
		else:
			owner_label.text = ""
	
	# Visual styling for upgraded cards
	if card_panel:
		if deck_card_data.applied_upgrades.size() > 0:
			card_panel.modulate = Color(1.1, 1.05, 0.95, 1.0)  # Golden tint
		else:
			card_panel.modulate = Color.WHITE


