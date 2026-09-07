extends VBoxContainer

## Character HUD block for party display
## Shows character portrait, name, quest information, and (in combat,
## Addendum §4 item 1) that character's party ability button directly
## beneath the portrait -- the party is the visible source of the abilities,
## not an anonymous toolbar.

signal ability_pressed(character_id: String)

@onready var inner_margin: MarginContainer = $InnerMargin
@onready var container: VBoxContainer = $InnerMargin/Container
@onready var portrait_container: Panel = $InnerMargin/Container/PortraitContainer
@onready var portrait: TextureRect = $InnerMargin/Container/PortraitContainer/Portrait
@onready var name_label: Label = $InnerMargin/Container/PortraitContainer/NameLabel
@onready var quest_title_label: Label = $InnerMargin/Container/QuestTitleLabel
@onready var quest_container: VBoxContainer = $InnerMargin/Container/QuestContainer
@onready var quest_progress_label: Label = $InnerMargin/Container/QuestContainer/QuestProgressLabel
@onready var ability_button: Button = $InnerMargin/Container/AbilityButton
@onready var ability_cooldown_fill: ProgressBar = $InnerMargin/Container/AbilityButton/AbilityCooldownFill

var _character_id: String = ""
var _combat_controller: CombatController = null

# Three visually distinct ability-button states (Addendum §4 item 2): ready /
# on cooldown / cannot afford. "Cannot afford" must not look like "on
# cooldown" -- the player's fix differs (wait vs. spend differently).
const STYLE_READY := {"bg": Color(0.10, 0.30, 0.14), "border": Color(0.35, 0.85, 0.40), "font": Color(0.85, 1.0, 0.85)}
const STYLE_COOLDOWN := {"bg": Color(0.14, 0.14, 0.16), "border": Color(0.45, 0.45, 0.50), "font": Color(0.70, 0.70, 0.72)}
const STYLE_CANNOT_AFFORD := {"bg": Color(0.30, 0.08, 0.08), "border": Color(0.80, 0.25, 0.20), "font": Color(1.0, 0.75, 0.70)}

func initialize(character_id: String) -> void:
	## Initialize the HUD block with character data
	## Must be called after instantiation
	_character_id = character_id
	_load_portrait(character_id)
	_update_name(character_id)
	_update_quest_info(character_id)
	if is_instance_valid(ability_button):
		ability_button.visible = false
		if not ability_button.pressed.is_connected(_on_ability_button_pressed):
			ability_button.pressed.connect(_on_ability_button_pressed)
		if not ability_button.mouse_entered.is_connected(_on_ability_hover_start):
			ability_button.mouse_entered.connect(_on_ability_hover_start)

func refresh_quest_info(character_id: String) -> void:
	## Refresh quest information (called when quest state changes)
	_update_quest_info(character_id)

# -- Combat ability button (Addendum §4) ---------------------------------------

func bind_combat(cc: CombatController) -> void:
	## Show and wire this character's ability button for the current combat.
	## No-op (button stays hidden) if this character has no ability_id.
	_combat_controller = cc
	if not is_instance_valid(ability_button):
		return
	var char_data := DataRegistry.get_character(_character_id) if DataRegistry else null
	if not char_data or char_data.ability_id.is_empty():
		ability_button.visible = false
		return
	var ability: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id) if DataRegistry else null
	if not ability:
		ability_button.visible = false
		return
	ability_button.visible = true
	refresh_ability_state()

func unbind_combat() -> void:
	_combat_controller = null
	if is_instance_valid(ability_button):
		ability_button.visible = false
		ability_button.tooltip_text = ""

func refresh_ability_state() -> void:
	## Update the button's label, cost badge, cooldown fill, and the
	## ready/cooldown/cannot-afford visual state. Call after any action that
	## could change energy, hand size, HP, Block, or cooldowns.
	if not _combat_controller or not is_instance_valid(ability_button) or not ability_button.visible:
		return
	var char_data := DataRegistry.get_character(_character_id) if DataRegistry else null
	if not char_data or char_data.ability_id.is_empty():
		return
	var ability: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id) if DataRegistry else null
	if not ability:
		return

	var cooldown: int = _combat_controller.get_ability_cooldown(_character_id)
	var can_use: bool = _combat_controller.can_use_ability(_character_id)
	var cost_badge: String = _combat_controller.get_ability_cost_summary(_character_id)

	ability_button.text = "%s\n%s" % [ability.display_name, cost_badge]
	ability_button.tooltip_text = "%s -- %s\nCost: %s" % [ability.display_name, ability.description, cost_badge]

	var style: Dictionary
	if cooldown > 0:
		# On cooldown: fill shows progress back to ready (0 -> full as it counts down).
		ability_cooldown_fill.visible = true
		ability_cooldown_fill.max_value = maxf(1.0, float(ability.cooldown))
		ability_cooldown_fill.value = float(ability.cooldown - cooldown)
		ability_button.text += "\n(%d)" % cooldown
		style = STYLE_COOLDOWN
		ability_button.disabled = true
	elif not can_use:
		# Off cooldown but a cost is unpayable right now -- visually distinct
		# from "on cooldown" (Addendum §4 item 2).
		ability_cooldown_fill.visible = false
		style = STYLE_CANNOT_AFFORD
		ability_button.disabled = true
	else:
		ability_cooldown_fill.visible = false
		style = STYLE_READY
		ability_button.disabled = false

	_apply_ability_style(style)

func _apply_ability_style(style: Dictionary) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = style.bg
	box.border_color = style.border
	box.border_width_left = 2
	box.border_width_right = 2
	box.border_width_top = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	ability_button.add_theme_stylebox_override("normal", box)
	ability_button.add_theme_stylebox_override("disabled", box)
	ability_button.add_theme_stylebox_override("hover", box)
	ability_button.add_theme_color_override("font_color", style.font)
	ability_button.add_theme_color_override("font_disabled_color", style.font)

func _on_ability_button_pressed() -> void:
	ability_pressed.emit(_character_id)

func _on_ability_hover_start() -> void:
	## Ability hover preview (Addendum §4 item 5): the real numbers this
	## ability would produce right now, given current state.
	if not _combat_controller:
		return
	var preview := _combat_controller.get_ability_preview_text(_character_id)
	if not preview.is_empty():
		var char_data := DataRegistry.get_character(_character_id) if DataRegistry else null
		var ability_name := "Ability"
		if char_data:
			var ability: PartyAbilityData = DataRegistry.get_ability(char_data.ability_id) if DataRegistry else null
			if ability:
				ability_name = ability.display_name
		ability_button.tooltip_text = "%s: %s" % [ability_name, preview]

func _load_portrait(character_id: String) -> void:
	## Load character portrait image
	if not is_instance_valid(portrait):
		return
	
	var char_data = DataRegistry.get_character(character_id) if DataRegistry else null
	if not char_data:
		return
	
	var texture = null

	# Load texture from CharacterData.portrait_path — one path for all characters.
	if char_data.portrait_path != "" and char_data.portrait_path != null \
			and ResourceLoader.exists(char_data.portrait_path):
		texture = ResourceLoader.load(char_data.portrait_path)

	if texture:
		portrait.texture = texture
	else:
		push_warning("CharacterHUDBlock: No portrait art for %s (portrait_path='%s')" % [char_data.display_name, char_data.portrait_path])

func _update_name(character_id: String) -> void:
	## Update character name label
	if not is_instance_valid(name_label):
		return
	
	if DataRegistry:
		name_label.text = DataRegistry.get_character_display_name(character_id)
	else:
		name_label.text = character_id

func _update_quest_info(character_id: String) -> void:
	## Update quest title and progress labels
	if not is_instance_valid(quest_title_label) or not is_instance_valid(quest_progress_label):
		return
	
	# Get quest data from QuestManager
	var quest_state = QuestManager.get_quest(character_id) if QuestManager else null
	if quest_state and quest_state is QuestState:
		# Set quest title
		quest_title_label.text = quest_state.title
		var is_complete = quest_state.is_complete
		var progress = quest_state.progress
		var progress_max = quest_state.progress_max
		
		if is_complete:
			quest_progress_label.text = "Complete"
			quest_progress_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			quest_progress_label.text = "Progress: %d/%d" % [progress, progress_max]
			quest_progress_label.remove_theme_color_override("font_color")
	else:
		quest_title_label.text = ""
		quest_progress_label.text = "Progress: —"
		quest_progress_label.remove_theme_color_override("font_color")

