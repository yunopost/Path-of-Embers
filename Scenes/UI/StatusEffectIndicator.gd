extends Control
class_name StatusEffectIndicator

## Displays status effect icons with duration numbers for entities

@onready var status_container: HBoxContainer = $StatusContainer

var entity_stats: EntityStats = null

# Status effect display metadata
var status_colors: Dictionary = {
	"vulnerable": Color(1.0, 0.3, 0.3, 1.0),  # Red
	"weak": Color(1.0, 0.8, 0.3, 1.0),  # Yellow (future)
	"poisoned": Color(0.3, 1.0, 0.3, 1.0),  # Green (future)
	"strength": Color(1.0, 0.5, 0.2, 1.0),  # Orange
	"dexterity": Color(0.3, 0.8, 1.0, 1.0),  # Light blue
	"faith": Color(0.7, 0.3, 1.0, 1.0),  # Purple
	"weakness": Color(0.5, 0.2, 0.2, 1.0),  # Dark red
}

var status_names: Dictionary = {
	"vulnerable": "Vulnerable",
	"weak": "Weak",
	"poisoned": "Poisoned",
	"strength": "Strength",
	"dexterity": "Dexterity",
	"faith": "Faith",
	"weakness": "Weakness",
}

func _ready():
	if not status_container:
		# Create container if not found
		status_container = HBoxContainer.new()
		status_container.name = "StatusContainer"
		add_child(status_container)
	
	custom_minimum_size = Vector2(0, 30)  # Ensure minimum height

func setup(entity: EntityStats):
	## Set up the indicator to display status effects from the given EntityStats
	entity_stats = entity
	_update_display()
	
	# Connect to status effects changed signal
	if entity_stats:
		entity_stats.status_effects_changed.connect(_update_display)

func _update_display():
	## Update the display to show current status effects
	if not status_container:
		return
	
	# Clear existing status displays
	for child in status_container.get_children():
		child.queue_free()
	
	if not entity_stats:
		return
	
	# Display each active status effect
	var stacking_statuses = ["strength", "dexterity", "faith"]
	for status_type in entity_stats.status_effects.keys():
		var value = entity_stats.status_effects[status_type]
		
		# Skip if value is 0 or negative (shouldn't happen, but safety check)
		if value is int and value <= 0:
			continue
		if value is float and value <= 0.0:
			continue
		
		# Create status indicator
		var status_indicator = _create_status_indicator(status_type, value, status_type in stacking_statuses)
		status_container.add_child(status_indicator)

func _create_status_indicator(status_type: String, value, is_stacking: bool = false) -> Control:
	## Create a single status indicator (icon + duration)
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(50, 25)
	
	# Icon (colored rectangle placeholder)
	var icon = ColorRect.new()
	var color = status_colors.get(status_type, Color(0.7, 0.7, 0.7, 1.0))  # Gray default
	icon.color = color
	icon.custom_minimum_size = Vector2(20, 20)
	icon.size = Vector2(20, 20)
	container.add_child(icon)
	
	# Value label (stack count for stacking statuses, duration for duration-based)
	var value_label = Label.new()
	# Convert value to displayable format
	var value_display = value
	if value is int:
		value_display = int(value)
	elif value is float:
		value_display = int(value)
	else:
		# For non-numeric values (e.g., boolean), convert to string
		value_display = str(value)
	
	value_label.text = str(value_display)
	value_label.custom_minimum_size = Vector2(25, 20)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(value_label)
	
	# Tooltip on hover - use string formatting to handle all value types safely
	var status_name = status_names.get(status_type, status_type.capitalize())
	if is_stacking:
		container.tooltip_text = "%s: %s" % [status_name, str(value_display)]
	else:
		container.tooltip_text = "%s: %s turns" % [status_name, str(value_display)]
	
	return container

func refresh():
	## Manually refresh the display (call this when status effects change)
	_update_display()
