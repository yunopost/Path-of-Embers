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
}

var status_names: Dictionary = {
	"vulnerable": "Vulnerable",
	"weak": "Weak",
	"poisoned": "Poisoned",
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
	for status_type in entity_stats.status_effects.keys():
		var duration = entity_stats.status_effects[status_type]
		
		# Skip if duration is 0 or negative (shouldn't happen, but safety check)
		if duration is int and duration <= 0:
			continue
		if duration is float and duration <= 0.0:
			continue
		
		# Create status indicator
		var status_indicator = _create_status_indicator(status_type, duration)
		status_container.add_child(status_indicator)

func _create_status_indicator(status_type: String, duration) -> Control:
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
	
	# Duration label
	var duration_label = Label.new()
	var duration_value = int(duration) if (duration is int or duration is float) else duration
	duration_label.text = str(duration_value)
	duration_label.custom_minimum_size = Vector2(25, 20)
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(duration_label)
	
	# Tooltip on hover
	var status_name = status_names.get(status_type, status_type.capitalize())
	container.tooltip_text = "%s: %d turns" % [status_name, duration_value]
	
	return container

func refresh():
	## Manually refresh the display (call this when status effects change)
	_update_display()
