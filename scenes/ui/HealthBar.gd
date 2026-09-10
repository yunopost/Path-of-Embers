extends Control
class_name HealthBar

## Reusable health bar component that displays HP and block like the player health bar

var bar_container: HBoxContainer = null
var bar_stack: Control = null
var background: ColorRect = null
var hp_fill: ColorRect = null
var block_overlay: ColorRect = null
var hp_label: Label = null
var block_label: Label = null

var entity_stats: EntityStats = null

const BAR_HEIGHT: int = 22
const BAR_WIDTH: int = 150

func _ready():
	_setup_nodes()
	# Set size flags to expand horizontally
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Set minimum height to ensure proper spacing
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_update_display()

func _setup_nodes():
	## Set up all the visual nodes for the health bar
	# Try to get existing nodes first
	bar_container = get_node_or_null("BarContainer")
	
	if not bar_container:
		bar_container = HBoxContainer.new()
		bar_container.name = "BarContainer"
		bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(bar_container)
	
	bar_stack = bar_container.get_node_or_null("BarStack")
	if not bar_stack:
		bar_stack = Control.new()
		bar_stack.name = "BarStack"
		bar_stack.custom_minimum_size = Vector2(0, BAR_HEIGHT)  # Height fixed, width flexible
		bar_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_container.add_child(bar_stack)
	
	background = bar_stack.get_node_or_null("Background")
	if not background:
		background = ColorRect.new()
		background.name = "Background"
		background.color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray background
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar_stack.add_child(background)
	
	hp_fill = bar_stack.get_node_or_null("HPFill")
	if not hp_fill:
		hp_fill = ColorRect.new()
		hp_fill.name = "HPFill"
		hp_fill.color = Color(0.8, 0.1, 0.1, 1.0)  # Red
		hp_fill.z_index = 1
		bar_stack.add_child(hp_fill)
	
	block_overlay = bar_stack.get_node_or_null("BlockOverlay")
	if not block_overlay:
		block_overlay = ColorRect.new()
		block_overlay.name = "BlockOverlay"
		block_overlay.color = Color(0.7, 0.8, 1.0, 0.7)  # Light blue with alpha
		block_overlay.z_index = 2
		bar_stack.add_child(block_overlay)
	
	hp_label = bar_stack.get_node_or_null("HPNumber")
	if not hp_label:
		hp_label = Label.new()
		hp_label.name = "HPNumber"
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		hp_label.z_index = 3
		bar_stack.add_child(hp_label)
	
	block_label = bar_container.get_node_or_null("BlockNumber")
	if not block_label:
		block_label = Label.new()
		block_label.name = "BlockNumber"
		block_label.custom_minimum_size = Vector2(30, BAR_HEIGHT)
		block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar_container.add_child(block_label)
	
	# Set initial sizes
	bar_stack.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)

func setup(entity: EntityStats):
	## Set up the health bar for an entity
	if entity_stats:
		# Disconnect old signals if reusing
		if entity_stats.hp_changed.is_connected(_update_display):
			entity_stats.hp_changed.disconnect(_update_display)
		if entity_stats.block_changed.is_connected(_update_display):
			entity_stats.block_changed.disconnect(_update_display)
	
	entity_stats = entity
	_update_display()
	
	if entity_stats:
		if not entity_stats.hp_changed.is_connected(_update_display):
			entity_stats.hp_changed.connect(_update_display)
		if not entity_stats.block_changed.is_connected(_update_display):
			entity_stats.block_changed.connect(_update_display)

func _update_display(_arg = null):
	## Update the visual representation of the health bar
	## _arg: Optional argument from signal emissions (ignored, we read from entity_stats directly)
	if not entity_stats:
		if hp_label:
			hp_label.text = "0/0"
		if block_label:
			block_label.text = ""
		if hp_fill:
			hp_fill.size = Vector2(0, BAR_HEIGHT)
		if block_overlay:
			block_overlay.size = Vector2(0, BAR_HEIGHT)
		return
	
	# Update HP label
	if hp_label:
		hp_label.text = "%d/%d" % [entity_stats.current_hp, entity_stats.max_hp]
	
	# Update block label
	if block_label:
		if entity_stats.block > 0:
			block_label.text = str(entity_stats.block)
		else:
			block_label.text = ""
	
	# Update bar fills
	_update_bar_fills()

func _update_bar_fills():
	## Update HP fill and Block overlay sizes based on current values
	if not bar_stack or not entity_stats:
		return
	
	# Wait for layout to ensure size is correct
	call_deferred("_update_bar_fills_deferred")

func _update_bar_fills_deferred():
	## Deferred update to ensure layout has calculated sizes
	if not bar_stack or not entity_stats:
		return
	
	# Get width - prefer actual size, fall back to parent width, then default
	var w = bar_stack.size.x
	if w <= 0:
		# Try to get width from parent container
		if bar_container:
			w = bar_container.size.x
		if w <= 0:
			# Fall back to default width
			w = BAR_WIDTH
	
	# Get height
	var h = bar_stack.size.y
	if h <= 0:
		h = bar_stack.custom_minimum_size.y
	if h <= 0:
		h = BAR_HEIGHT
	
	# HP fill (left -> right)
	var hp_ratio = 0.0
	if entity_stats.max_hp > 0:
		hp_ratio = float(entity_stats.current_hp) / float(entity_stats.max_hp)
	hp_ratio = clamp(hp_ratio, 0.0, 1.0)
	if hp_fill:
		hp_fill.position = Vector2(0, 0)
		hp_fill.size = Vector2(w * hp_ratio, h)
	
	# Block overlay (right -> left), sized relative to max_hp
	var block_ratio = 0.0
	if entity_stats.max_hp > 0:
		block_ratio = float(entity_stats.block) / float(entity_stats.max_hp)
	block_ratio = clamp(block_ratio, 0.0, 1.0)
	if block_overlay:
		var bw = w * block_ratio
		block_overlay.size = Vector2(bw, h)
		block_overlay.position = Vector2(w - bw, 0)

func refresh():
	_update_display()
