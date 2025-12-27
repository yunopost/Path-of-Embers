extends Control

## Persistent UI overlay that stays across all scenes
## Subscribes to RunState signals and updates UI reactively

var hp_label: Label = null
var hp_fill: ColorRect = null
var block_overlay: ColorRect = null
var bar_stack: Control = null
var block_label: Label = null
var party_hud: Control = null
var debug_label: Label = null
var gold_label: Label = null
var node_progress_label: Label = null
var map_button: Button = null
var deck_button: Button = null
var settings_button: Button = null

var settings_popup: Control = null
var deck_popup: Control = null

var _bar_sync_retry_count: int = 0
const MAX_BAR_SYNC_RETRIES: int = 10

func _ready():
	# Wait one frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Get node references safely
	hp_label = get_node_or_null("TopLeft/TopLeftMargin/TopLeftHUD/HPRow/HPContainer/BarStack/HPNumber")
	hp_fill = get_node_or_null("TopLeft/TopLeftMargin/TopLeftHUD/HPRow/HPContainer/BarStack/HPFill")
	block_overlay = get_node_or_null("TopLeft/TopLeftMargin/TopLeftHUD/HPRow/HPContainer/BarStack/BlockOverlay")
	bar_stack = get_node_or_null("TopLeft/TopLeftMargin/TopLeftHUD/HPRow/HPContainer/BarStack")
	block_label = get_node_or_null("TopLeft/TopLeftMargin/TopLeftHUD/HPRow/HPContainer/BlockNumber")
	party_hud = get_node_or_null("TopLeft/TopLeftMargin/TopLeftHUD/PartyHUD")
	debug_label = get_node_or_null("TopCenter/DebugLabel")
	gold_label = get_node_or_null("TopRight/GoldContainer/GoldValue")
	node_progress_label = get_node_or_null("TopRight/NodeProgressContainer/NodeProgressValue")
	map_button = get_node_or_null("TopRight/ButtonContainer/MapButton")
	deck_button = get_node_or_null("TopRight/ButtonContainer/DeckButton")
	settings_button = get_node_or_null("TopRight/ButtonContainer/SettingsButton")
	
	# Validate critical nodes and log errors
	if not is_instance_valid(bar_stack):
		push_error("UIRoot: Critical node 'BarStack' not found! UI may be broken.")
	if not is_instance_valid(hp_fill):
		push_error("UIRoot: Critical node 'HPFill' not found! HP bar will not display.")
	if not is_instance_valid(block_overlay):
		push_error("UIRoot: Critical node 'BlockOverlay' not found! Block overlay will not display.")
	if not is_instance_valid(party_hud):
		push_warning("UIRoot: PartyHUD not found. Bar width syncing will be disabled.")
	
	# Connect to manager signals (with safety checks)
	if ResourceManager:
		if not ResourceManager.hp_changed.is_connected(_on_hp_changed):
			ResourceManager.hp_changed.connect(_on_hp_changed)
		if not ResourceManager.block_changed.is_connected(_on_block_changed):
			ResourceManager.block_changed.connect(_on_block_changed)
		if not ResourceManager.gold_changed.is_connected(_on_gold_changed):
			ResourceManager.gold_changed.connect(_on_gold_changed)
	if MapManager:
		if not MapManager.node_position_changed.is_connected(_on_node_position_changed):
			MapManager.node_position_changed.connect(_on_node_position_changed)
	if PartyManager:
		if not PartyManager.party_changed.is_connected(_on_party_changed_ui):
			PartyManager.party_changed.connect(_on_party_changed_ui)
	
	# Connect buttons (with safety check)
	if is_instance_valid(map_button):
		if not map_button.pressed.is_connected(_on_map_button_pressed):
			map_button.pressed.connect(_on_map_button_pressed)
	if is_instance_valid(deck_button):
		if not deck_button.pressed.is_connected(_on_deck_button_pressed):
			deck_button.pressed.connect(_on_deck_button_pressed)
	if is_instance_valid(settings_button):
		if not settings_button.pressed.is_connected(_on_settings_button_pressed):
			settings_button.pressed.connect(_on_settings_button_pressed)
	
	# Set bar colors (only if nodes are valid) - colors are now set in scene, but ensure they're correct
	if is_instance_valid(hp_fill):
		hp_fill.color = Color(0.8, 0.1, 0.1, 1.0)  # Red
	if is_instance_valid(block_overlay):
		block_overlay.color = Color(0.7, 0.8, 1.0, 0.7)  # Light blue with alpha
		block_overlay.z_index = 2  # Ensure it draws on top
	
	# Initial UI update
	_update_all_ui()
	
	# Load popups
	_load_popups()
	
	# Setup debug info (only in debug builds)
	if OS.is_debug_build():
		_setup_debug_info()
	else:
		if is_instance_valid(debug_label):
			debug_label.visible = false
	
	# Sync bar width to party HUD after layout (only if PartyHUD exists)
	# Reset retry counter
	_bar_sync_retry_count = 0
	call_deferred("_sync_and_update_bars")

func _load_popups():
	# Load Settings popup
	var settings_scene = load("res://Path-of-Embers/Scenes/UI/SettingsPopup.tscn")
	settings_popup = settings_scene.instantiate()
	add_child(settings_popup)
	settings_popup.visible = false
	
	# Load Deck popup
	var deck_scene = load("res://Path-of-Embers/Scenes/UI/DeckViewPopup.tscn")
	deck_popup = deck_scene.instantiate()
	add_child(deck_popup)
	deck_popup.visible = false

func _update_all_ui():
	_on_hp_changed()
	_on_block_changed()
	_on_gold_changed()
	_on_node_position_changed()

func _on_hp_changed():
	if is_instance_valid(hp_label) and ResourceManager:
		hp_label.text = "%d/%d" % [ResourceManager.current_hp, ResourceManager.max_hp]
	_update_bar_fills()

func _on_block_changed():
	if is_instance_valid(block_label) and ResourceManager:
		block_label.text = str(ResourceManager.block)
	_update_bar_fills()

func _on_party_changed_ui():
	## Called when party changes - sync bar width to match PartyHUD
	_bar_sync_retry_count = 0
	call_deferred("_sync_and_update_bars")

func _sync_and_update_bars():
	## Safe pattern: wait one frame, then sync width and update fills
	await get_tree().process_frame
	_sync_bar_width_to_party()
	_update_bar_fills()

func _sync_bar_width_to_party():
	## Set BarStack width to match PartyHUD width
	if not is_instance_valid(bar_stack):
		return
	
	if not is_instance_valid(party_hud):
		# PartyHUD not available - this is OK, just skip syncing
		# Fall back to reasonable default width if needed
		if bar_stack.custom_minimum_size.x <= 0:
			bar_stack.custom_minimum_size.x = 600  # Fallback width
		return
	
	var w = party_hud.size.x
	if w <= 0:
		# Layout not ready yet - use fallback
		if bar_stack.custom_minimum_size.x <= 0:
			bar_stack.custom_minimum_size.x = 600  # Fallback width
		return
	
	# Success - set width using custom_minimum_size (container will handle actual sizing)
	bar_stack.custom_minimum_size.x = w

func _update_bar_fills():
	## Update HP fill and Block overlay sizes based on current values
	if not is_instance_valid(bar_stack):
		return
	
	if not is_instance_valid(hp_fill):
		return
	
	if not is_instance_valid(block_overlay):
		return
	
	# Get width - use size.x if available, else fall back to custom_minimum_size.x
	var w = bar_stack.size.x
	if w <= 0:
		w = bar_stack.custom_minimum_size.x
	if w <= 0:
		# Still no width - skip update
		return
	
	# Get height - use size.y if available, else fall back to custom_minimum_size.y
	var h = bar_stack.size.y
	if h <= 0:
		h = bar_stack.custom_minimum_size.y
	if h <= 0:
		h = 22  # Default height fallback
	
	# HP fill (left -> right)
	var hp_ratio = 0.0
	if ResourceManager and ResourceManager.max_hp > 0:
		hp_ratio = float(ResourceManager.current_hp) / float(ResourceManager.max_hp)
	hp_ratio = clamp(hp_ratio, 0.0, 1.0)
	hp_fill.position = Vector2(0, 0)
	hp_fill.size = Vector2(w * hp_ratio, h)
	
	# Block overlay (right -> left), sized relative to max_hp
	var block_ratio = 0.0
	if ResourceManager and ResourceManager.max_hp > 0:
		block_ratio = float(ResourceManager.block) / float(ResourceManager.max_hp)
	block_ratio = clamp(block_ratio, 0.0, 1.0)
	var bw = w * block_ratio
	block_overlay.size = Vector2(bw, h)
	block_overlay.position = Vector2(w - bw, 0)

func _on_gold_changed():
	if is_instance_valid(gold_label) and ResourceManager:
		gold_label.text = str(ResourceManager.gold)

func _on_node_position_changed():
	if is_instance_valid(node_progress_label) and MapManager:
		node_progress_label.text = "Node: %d" % MapManager.node_position

func _on_map_button_pressed():
	ScreenManager.go_to_map()

func _on_deck_button_pressed():
	open_popup("deck")

func _on_settings_button_pressed():
	open_popup("settings")

func open_popup(popup_name: String):
	if popup_name == "settings" and settings_popup:
		settings_popup.visible = true
		settings_popup.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	elif popup_name == "deck" and deck_popup:
		deck_popup.visible = true
		deck_popup.set_process_mode(Node.PROCESS_MODE_ALWAYS)

func close_popup(popup_name: String):
	if popup_name == "settings" and settings_popup:
		settings_popup.visible = false
	elif popup_name == "deck" and deck_popup:
		deck_popup.visible = false

func _setup_debug_info():
	## Setup debug info label (debug builds only)
	# Debug label is now in the scene at TopCenter/DebugLabel
	# Connect to signals to update debug info
	if PartyManager:
		if not PartyManager.party_changed.is_connected(_update_debug_info):
			PartyManager.party_changed.connect(_update_debug_info)
	if RunState:
		if not RunState.deck_changed.is_connected(_update_debug_info):
			RunState.deck_changed.connect(_update_debug_info)
	_update_debug_info()

func _update_debug_info():
	## Update debug info display
	if is_instance_valid(debug_label) and OS.is_debug_build():
		var party_str = ", ".join(PartyManager.party_ids) if PartyManager and PartyManager.party_ids.size() > 0 else "None"
		var deck_count = RunState.get_deck_size() if RunState and RunState.has_method("get_deck_size") else 0
		debug_label.text = "Party: [%s] | Deck: %d" % [party_str, deck_count]
		debug_label.visible = true
