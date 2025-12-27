extends Control

## Character selection screen - allows selection of exactly 3 characters

var selection_count_label: Label = null
var character_grid: GridContainer = null
var confirm_button: Button = null
var party_summary_label: Label = null

var available_characters: Array[CharacterData] = []
var selected_character_ids: Array[String] = []
var character_entries: Dictionary = {}  # Maps character_id to { "button": Button, "root": Control, "quest_title": Label, "quest_desc": Label }

func _ready():
	# Wait one frame to ensure nodes are ready
	await get_tree().process_frame
	
	# Get node references safely
	selection_count_label = get_node_or_null("VBoxContainer/SelectionCountLabel")
	character_grid = get_node_or_null("VBoxContainer/CharacterGrid")
	confirm_button = get_node_or_null("VBoxContainer/ConfirmButton")
	party_summary_label = get_node_or_null("VBoxContainer/PartySummaryLabel")
	
	# Connect confirm button (with safety check)
	if is_instance_valid(confirm_button):
		if not confirm_button.pressed.is_connected(_on_confirm_pressed):
			confirm_button.pressed.connect(_on_confirm_pressed)
		confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Initialize screen (architecture rule 2.1)
	initialize()
	
	# Ensure scene is visible
	visible = true
	
	# Force a redraw
	call_deferred("_ensure_visible")
	
	# Keep the game running - ensure we don't exit
	get_tree().paused = false
	set_process(true)
	set_physics_process(false)

func initialize():
	## Initialize the screen with current state
	## Must be called after instantiation, before use (architecture rule 2.1)
	refresh_from_state()

func refresh_from_state():
	## Refresh UI from RunState (architecture rule 11.2)
	# Create placeholder characters for testing (minimum 6 as specified)
	_create_placeholder_characters()
	
	# Populate character grid
	_populate_character_grid()
	
	_update_ui()

func _ensure_visible():
	## Ensure all UI elements are visible and properly sized
	if is_instance_valid(character_grid):
		character_grid.visible = true
		character_grid.show()
		for i in range(character_grid.get_child_count()):
			var child = character_grid.get_child(i)
			if is_instance_valid(child):
				child.visible = true
				child.show()
	
	if is_instance_valid(self):
		visible = true
		show()

func _create_placeholder_characters():
	## Create placeholder CharacterData resources for testing
	## In a real game, these would be loaded from .tres files
	
	available_characters.clear()
	
	# Warrior characters
	for i in range(2):
		var char_data = CharacterData.new()
		char_data.id = "warrior_%d" % (i + 1)
		# First warrior is "Monster Hunter", second is "Shadowfoot"
		if i == 0:
			char_data.display_name = "Monster Hunter"
		else:
			char_data.display_name = "Shadowfoot"
		char_data.role = "Warrior"
		char_data.portrait_path = ""
		
		# Create 2 unique starter cards
		if i == 0:
			# Monster Hunter specific cards
			# Full Attack - Big damage card with Slow keyword
			var full_attack = CardData.new()
			full_attack.id = "monster_hunter_full_attack"
			full_attack.name = "Full Attack"
			full_attack.cost = 2
			full_attack.card_type = CardData.CardType.ATTACK
			full_attack.targeting_mode = CardData.TargetingMode.ENEMY
			full_attack.owner_character_id = "warrior_1"
			full_attack.rarity = CardData.Rarity.COMMON
			full_attack.keywords.append("Slow")
			var damage_effect = EffectData.new(EffectType.DAMAGE, {"amount": 14})
			full_attack.base_effects.append(damage_effect)
			char_data.starter_unique_cards.append(full_attack)
			
			# Shoulder Tackle - Free card that enables next card
			var shoulder_tackle = CardData.new()
			shoulder_tackle.id = "monster_hunter_shoulder_tackle"
			shoulder_tackle.name = "Shoulder Tackle"
			shoulder_tackle.cost = 0
			shoulder_tackle.card_type = CardData.CardType.SKILL
			shoulder_tackle.targeting_mode = CardData.TargetingMode.SELF
			shoulder_tackle.owner_character_id = "warrior_1"
			shoulder_tackle.rarity = CardData.Rarity.COMMON
			var haste_effect = EffectData.new(EffectType.GRANT_HASTE_NEXT_CARD, {})
			shoulder_tackle.base_effects.append(haste_effect)
			char_data.starter_unique_cards.append(shoulder_tackle)
		else:
			# Warrior 2 (Shadowfoot) specific cards
			# Dark Knife - Deal 6 damage, gains double damage from Strength
			var dark_knife = CardData.new()
			dark_knife.id = "shadowfoot_dark_knife"
			dark_knife.name = "Dark Knife"
			dark_knife.cost = 1
			dark_knife.card_type = CardData.CardType.ATTACK
			dark_knife.targeting_mode = CardData.TargetingMode.ENEMY
			dark_knife.owner_character_id = "warrior_2"
			dark_knife.rarity = CardData.Rarity.COMMON
			var dark_knife_damage = EffectData.new(EffectType.DAMAGE, {"amount": 6, "double_strength": true})
			dark_knife.base_effects.append(dark_knife_damage)
			char_data.starter_unique_cards.append(dark_knife)
			
			# Fade Step - Gain 4 Block, if no damage this turn gain 1 Strength
			var fade_step = CardData.new()
			fade_step.id = "shadowfoot_fade_step"
			fade_step.name = "Fade Step"
			fade_step.cost = 1
			fade_step.card_type = CardData.CardType.SKILL
			fade_step.targeting_mode = CardData.TargetingMode.SELF
			fade_step.owner_character_id = "warrior_2"
			fade_step.rarity = CardData.Rarity.COMMON
			var fade_step_block = EffectData.new(EffectType.BLOCK, {"amount": 4})
			fade_step.base_effects.append(fade_step_block)
			# Conditional Strength effect will be handled in card-specific mechanics
			var fade_step_strength = EffectData.new(EffectType.CONDITIONAL_STRENGTH_IF_NO_DAMAGE, {"amount": 1})
			fade_step.base_effects.append(fade_step_strength)
			char_data.starter_unique_cards.append(fade_step)
		
		# Create 22 reward pool cards (7 Common, 12 Uncommon, 3 Rare)
		_generate_reward_pool_cards(char_data)
		
		# Create quest
		var quest = QuestData.new()
		quest.id = "quest_warrior_%d" % (i + 1)
		if i == 0:
			# Monster Hunter quest (placeholder)
			quest.title = "Monster Hunter Quest"
			quest.description = "Complete %d nodes" % (10)
			quest.progress_max = 10
			quest.tracking_type = "complete_nodes"
		else:
			# Shadowfoot quest: Complete combat without taking damage 6 times
			quest.title = "Shadowfoot Quest"
			quest.description = "Complete combat without taking damage %d times" % (6)
			quest.progress_max = 6
			quest.tracking_type = "combat_no_damage"
		char_data.quest = quest
		
		available_characters.append(char_data)
		# Register with DataRegistry
		if DataRegistry:
			DataRegistry.register_character(char_data)
	
	# Healer characters
	for i in range(2):
		var char_data = CharacterData.new()
		char_data.id = "healer_%d" % (i + 1)
		# First healer is "Witch", second is "Wanderer"
		if i == 0:
			char_data.display_name = "Witch"
		else:
			char_data.display_name = "Wanderer"
		char_data.role = "Healer"
		char_data.portrait_path = ""
		
		if i == 0:
			# Healer 1 (Witch) specific cards
			# Hexbound Ritual - Add temporary Curse to hand, Apply 2 Vulnerable to ALL enemies
			var hexbound_ritual = CardData.new()
			hexbound_ritual.id = "witch_hexbound_ritual"
			hexbound_ritual.name = "Hexbound Ritual"
			hexbound_ritual.cost = 0
			hexbound_ritual.card_type = CardData.CardType.SKILL
			hexbound_ritual.targeting_mode = CardData.TargetingMode.SELF
			hexbound_ritual.owner_character_id = "healer_1"
			hexbound_ritual.rarity = CardData.Rarity.COMMON
			var add_curse_effect = EffectData.new(EffectType.ADD_CURSE_TO_HAND, {"is_temporary": true})
			hexbound_ritual.base_effects.append(add_curse_effect)
			var vulnerable_all_effect = EffectData.new(EffectType.VULNERABLE_ALL_ENEMIES, {"duration": 2})
			hexbound_ritual.base_effects.append(vulnerable_all_effect)
			char_data.starter_unique_cards.append(hexbound_ritual)
			
			# Malediction Lash - Deal 2 damage to each enemy, +2 per Curse in hand/discard
			var malediction_lash = CardData.new()
			malediction_lash.id = "witch_malediction_lash"
			malediction_lash.name = "Malediction Lash"
			malediction_lash.cost = 1
			malediction_lash.card_type = CardData.CardType.ATTACK
			malediction_lash.targeting_mode = CardData.TargetingMode.ALL_ENEMIES
			malediction_lash.owner_character_id = "healer_1"
			malediction_lash.rarity = CardData.Rarity.COMMON
			var malediction_damage = EffectData.new(EffectType.DAMAGE_PER_CURSE, {"base_amount": 2, "per_curse": 2})
			malediction_lash.base_effects.append(malediction_damage)
			char_data.starter_unique_cards.append(malediction_lash)
		else:
			# Healer 2 (Wanderer) specific cards
			# Clear the way - Deal 10 damage, can only be played if first card this turn
			var clear_the_way = CardData.new()
			clear_the_way.id = "wanderer_clear_the_way"
			clear_the_way.name = "Clear the way"
			clear_the_way.cost = 1
			clear_the_way.card_type = CardData.CardType.ATTACK
			clear_the_way.targeting_mode = CardData.TargetingMode.ENEMY
			clear_the_way.owner_character_id = "healer_2"
			clear_the_way.rarity = CardData.Rarity.COMMON
			var clear_damage = EffectData.new(EffectType.DAMAGE, {"amount": 10})
			clear_the_way.base_effects.append(clear_damage)
			# First card only restriction will be handled in card-specific mechanics
			clear_the_way.keywords.append("FirstCardOnly")
			char_data.starter_unique_cards.append(clear_the_way)
			
			# Survey the Path - Power, whenever enemy acts gain 1 block
			var survey_path = CardData.new()
			survey_path.id = "wanderer_survey_path"
			survey_path.name = "Survey the Path"
			survey_path.cost = 2
			survey_path.card_type = CardData.CardType.POWER
			survey_path.targeting_mode = CardData.TargetingMode.SELF
			survey_path.owner_character_id = "healer_2"
			survey_path.rarity = CardData.Rarity.COMMON
			var survey_effect = EffectData.new(EffectType.BLOCK_ON_ENEMY_ACT, {"amount": 1})
			survey_path.base_effects.append(survey_effect)
			char_data.starter_unique_cards.append(survey_path)
		
		# Create 22 reward pool cards (7 Common, 12 Uncommon, 3 Rare)
		_generate_reward_pool_cards(char_data)
		
		var quest = QuestData.new()
		quest.id = "quest_healer_%d" % (i + 1)
		if i == 0:
			# Witch quest: Gain 6 Curse cards
			quest.title = "Witch Quest"
			quest.description = "Gain %d Curse cards" % (6)
			quest.progress_max = 6
			quest.tracking_type = "gain_curse_cards"
		else:
			# Wanderer quest: Take the explore action at rest sites 3 times (placeholder)
			quest.title = "Wanderer Quest"
			quest.description = "Take the explore action at rest sites %d times" % (3)
			quest.progress_max = 3
			quest.tracking_type = "rest_site_explore"
		char_data.quest = quest
		
		available_characters.append(char_data)
		# Register with DataRegistry
		if DataRegistry:
			DataRegistry.register_character(char_data)
	
	# Defender characters
	for i in range(2):
		var char_data = CharacterData.new()
		char_data.id = "defender_%d" % (i + 1)
		# First defender is "Golemancer", second is "Living Armor"
		if i == 0:
			char_data.display_name = "Golemancer"
		else:
			char_data.display_name = "Living Armor"
		char_data.role = "Defender"
		char_data.portrait_path = ""
		
		if i == 0:
			# Defender 1 (Golemancer) specific cards
			# Stonebound Strike - Deal 6 damage, Gain 3 Block
			var stonebound_strike = CardData.new()
			stonebound_strike.id = "golemancer_stonebound_strike"
			stonebound_strike.name = "Stonebound Strike"
			stonebound_strike.cost = 1
			stonebound_strike.card_type = CardData.CardType.ATTACK
			stonebound_strike.targeting_mode = CardData.TargetingMode.ENEMY
			stonebound_strike.owner_character_id = "defender_1"
			stonebound_strike.rarity = CardData.Rarity.COMMON
			var stonebound_damage = EffectData.new(EffectType.DAMAGE, {"amount": 6})
			stonebound_strike.base_effects.append(stonebound_damage)
			var stonebound_block = EffectData.new(EffectType.BLOCK, {"amount": 3})
			stonebound_strike.base_effects.append(stonebound_block)
			char_data.starter_unique_cards.append(stonebound_strike)
			
			# Reinforce - Add temporary upgrade to random card in hand, Gain 4 Block
			var reinforce = CardData.new()
			reinforce.id = "golemancer_reinforce"
			reinforce.name = "Reinforce"
			reinforce.cost = 1
			reinforce.card_type = CardData.CardType.SKILL
			reinforce.targeting_mode = CardData.TargetingMode.SELF
			reinforce.owner_character_id = "defender_1"
			reinforce.rarity = CardData.Rarity.COMMON
			var reinforce_block = EffectData.new(EffectType.BLOCK, {"amount": 4})
			reinforce.base_effects.append(reinforce_block)
			var add_temp_upgrade = EffectData.new(EffectType.ADD_TEMPORARY_UPGRADE_TO_RANDOM_HAND_CARD, {})
			reinforce.base_effects.append(add_temp_upgrade)
			char_data.starter_unique_cards.append(reinforce)
		else:
			# Defender 2 (Living Armor) specific cards
			# Plated Guard - Gain 8 Block, do not lose block at end of turn
			var plated_guard = CardData.new()
			plated_guard.id = "living_armor_plated_guard"
			plated_guard.name = "Plated Guard"
			plated_guard.cost = 1
			plated_guard.card_type = CardData.CardType.SKILL
			plated_guard.targeting_mode = CardData.TargetingMode.SELF
			plated_guard.owner_character_id = "defender_2"
			plated_guard.rarity = CardData.Rarity.COMMON
			var plated_block = EffectData.new(EffectType.BLOCK, {"amount": 8})
			plated_guard.base_effects.append(plated_block)
			var retain_block_effect = EffectData.new(EffectType.RETAIN_BLOCK_THIS_TURN, {})
			plated_guard.base_effects.append(retain_block_effect)
			char_data.starter_unique_cards.append(plated_guard)
			
			# Resonant Frame - Power, whenever you gain Block deal 1 damage to random enemy
			var resonant_frame = CardData.new()
			resonant_frame.id = "living_armor_resonant_frame"
			resonant_frame.name = "Resonant Frame"
			resonant_frame.cost = 1
			resonant_frame.card_type = CardData.CardType.POWER
			resonant_frame.targeting_mode = CardData.TargetingMode.SELF
			resonant_frame.owner_character_id = "defender_2"
			resonant_frame.rarity = CardData.Rarity.COMMON
			var resonant_effect = EffectData.new(EffectType.DAMAGE_ON_BLOCK_GAIN, {"amount": 1})
			resonant_frame.base_effects.append(resonant_effect)
			char_data.starter_unique_cards.append(resonant_frame)
		
		# Create 22 reward pool cards (7 Common, 12 Uncommon, 3 Rare)
		_generate_reward_pool_cards(char_data)
		
		var quest = QuestData.new()
		quest.id = "quest_defender_%d" % (i + 1)
		if i == 0:
			# Golemancer quest: Have a card with 6 upgrades (placeholder)
			quest.title = "Golemancer Quest"
			quest.description = "Have a card with %d upgrades" % (6)
			quest.progress_max = 6
			quest.tracking_type = "card_upgrades"
		else:
			# Living Armor quest: Buy 6 relics (placeholder)
			quest.title = "Living Armor Quest"
			quest.description = "Buy %d relics" % (6)
			quest.progress_max = 6
			quest.tracking_type = "buy_relics"
		char_data.quest = quest
		
		available_characters.append(char_data)
		# Register with DataRegistry
		if DataRegistry:
			DataRegistry.register_character(char_data)

func _generate_reward_pool_cards(char_data: CharacterData):
	## Generate 22 placeholder reward pool cards for a character
	## 7 Common, 12 Uncommon, 3 Rare
	var char_id = char_data.id
	
	# Generate 7 Common cards
	for i in range(1, 8):
		var card = CardData.new()
		card.id = "%s_common_%d" % [char_id, i]
		card.name = "%s Common %d" % [char_data.display_name, i]
		card.rarity = CardData.Rarity.COMMON
		card.cost = 1
		char_data.reward_card_pool.append(card)
	
	# Generate 12 Uncommon cards
	for i in range(1, 13):
		var card = CardData.new()
		card.id = "%s_uncommon_%d" % [char_id, i]
		card.name = "%s Uncommon %d" % [char_data.display_name, i]
		card.rarity = CardData.Rarity.UNCOMMON
		card.cost = 1
		char_data.reward_card_pool.append(card)
	
	# Generate 3 Rare cards
	for i in range(1, 4):
		var card = CardData.new()
		card.id = "%s_rare_%d" % [char_id, i]
		card.name = "%s Rare %d" % [char_data.display_name, i]
		card.rarity = CardData.Rarity.RARE
		card.cost = 2
		char_data.reward_card_pool.append(card)

func _populate_character_grid():
	## Create character entry cards for each available character
	if not is_instance_valid(character_grid):
		push_error("CharacterSelect: character_grid is null!")
		return
		
	for char_data in available_characters:
		if not char_data:
			push_warning("CharacterSelect: null char_data in available_characters")
			continue
		
		# Create character entry card
		var entry = _create_character_entry(char_data)
		character_grid.add_child(entry["root"])
		character_entries[char_data.id] = entry
		
		# Force entry to be in tree and visible
		entry["root"].set_owner(character_grid)

func _create_character_entry(char_data: CharacterData) -> Dictionary:
	## Create a character entry card with quest info
	## Returns dictionary with references to UI elements
	
	# Root container (VBoxContainer)
	var root = VBoxContainer.new()
	root.name = "Entry_" + char_data.id
	root.custom_minimum_size = Vector2(200, 200)
	root.size = Vector2(200, 200)
	root.add_theme_constant_override("separation", 4)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Select button (handles selection click)
	var button = Button.new()
	button.name = "SelectButton_" + char_data.id
	button.text = "%s\n(%s)" % [char_data.display_name, char_data.role]
	button.custom_minimum_size = Vector2(200, 60)
	button.size = Vector2(200, 60)
	button.pressed.connect(_on_character_selected.bind(char_data.id))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(button)
	
	# Quest title label
	var quest_title = Label.new()
	quest_title.name = "QuestTitle_" + char_data.id
	quest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_title.add_theme_font_size_override("font_size", 12)
	quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_title.clip_contents = true
	quest_title.custom_minimum_size.y = 20
	quest_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Quest description label
	var quest_desc = Label.new()
	quest_desc.name = "QuestDesc_" + char_data.id
	quest_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_desc.add_theme_font_size_override("font_size", 10)
	quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_desc.clip_contents = true
	quest_desc.custom_minimum_size.y = 40
	quest_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set quest info
	if char_data.quest:
		quest_title.text = char_data.quest.title
		quest_desc.text = char_data.quest.description
		# Optional: show progress_max as "Goal: X"
		if char_data.quest.progress_max > 0:
			quest_desc.text += "\nGoal: %d" % char_data.quest.progress_max
	else:
		quest_title.text = "No Quest"
		quest_desc.text = "(This character has no quest assigned.)"
	
	root.add_child(quest_title)
	root.add_child(quest_desc)
	
	return {
		"button": button,
		"root": root,
		"quest_title": quest_title,
		"quest_desc": quest_desc
	}

func _on_character_selected(character_id: String):
	## Handle character selection/deselection
	if character_id in selected_character_ids:
		# Deselect
		selected_character_ids.erase(character_id)
	else:
		# Select (if not at max)
		if selected_character_ids.size() < 3:
			selected_character_ids.append(character_id)
		else:
			# Already at max, can't select more
			return
	
	_update_ui()

func _update_ui():
	## Update UI to reflect current selection state
	# Update selection count label
	if is_instance_valid(selection_count_label):
		selection_count_label.text = "Selected: %d / 3" % selected_character_ids.size()
	
	# Update entry states (tint button and optionally root)
	for char_id in character_entries:
		var entry = character_entries[char_id]
		if not entry or not entry.has("button"):
			continue
		
		var button = entry["button"]
		if not is_instance_valid(button):
			continue
		
		var is_selected = char_id in selected_character_ids
		
		if is_selected:
			button.modulate = Color(0.7, 1.0, 0.7)  # Green tint
			# Optionally tint root container as well
			if entry.has("root") and is_instance_valid(entry["root"]):
				entry["root"].modulate = Color(0.9, 1.0, 0.9)  # Light green tint
		else:
			button.modulate = Color.WHITE
			if entry.has("root") and is_instance_valid(entry["root"]):
				entry["root"].modulate = Color.WHITE
	
	# Update party summary
	_update_party_summary()
	
	# Enable/disable confirm button
	if is_instance_valid(confirm_button):
		confirm_button.disabled = selected_character_ids.size() != 3

func _update_party_summary():
	## Update the party summary label
	if not is_instance_valid(party_summary_label):
		return
	
	if selected_character_ids.size() == 3:
		var summary_lines: Array[String] = []
		summary_lines.append("Selected Party:")
		for char_id in selected_character_ids:
			var char_data = null
			if DataRegistry:
				char_data = DataRegistry.get_character(char_id)
			if char_data:
				summary_lines.append("  â€¢ %s (%s)" % [char_data.display_name, char_data.role])
			else:
				summary_lines.append("  â€¢ %s" % char_id)
		party_summary_label.text = "\n".join(summary_lines)
		party_summary_label.visible = true
	else:
		party_summary_label.text = ""
		party_summary_label.visible = false

func _on_confirm_pressed():
	## Confirm party selection and initialize run
	if selected_character_ids.size() != 3:
		push_error("Cannot confirm party: must select exactly 3 characters")
		return
	
	# Get CharacterData for selected characters
	var selected_char_data: Array[CharacterData] = []
	for char_id in selected_character_ids:
		for char_data in available_characters:
			if char_data.id == char_id:
				selected_char_data.append(char_data)
				break
	
	if selected_char_data.size() != 3:
		push_error("Failed to find CharacterData for all selected characters")
		return
	
	# Set party
	if PartyManager:
		PartyManager.set_party(selected_character_ids)
	
	# Generate starter deck
	if RunState:
		RunState.generate_starter_deck(selected_char_data)
	
	# Initialize quests
	if QuestManager:
		QuestManager.initialize_quests(selected_char_data)
	
	# Generate initial map
	var map_gen = MapGenerator.new()
	var act = MapManager.act if MapManager else 1
	var map_data = map_gen.generate_map(act)
	if MapManager:
		MapManager.set_map_data(map_data)
	
	# Force save new run (before navigating to map)
	if AutoSaveManager:
		AutoSaveManager.force_save("new_run_started")
	
	# Navigate to map screen
	ScreenManager.go_to_map()
