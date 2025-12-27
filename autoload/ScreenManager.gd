extends Node

## Screen navigation manager - follows architecture rule 5.1
## Autoload singleton - do not use class_name
## One screen active at a time, explicit transition methods

signal screen_changed(screen_name: String)

var current_screen: String = ""
var current_scene: Node = null
var ui_root: Control = null

var screen_scenes: Dictionary = {
	"main": "res://Path-of-Embers/scenes/screens/Main.tscn",
	"main_menu": "res://Path-of-Embers/scenes/screens/Main.tscn",  # Alias for main
	"character_select": "res://Path-of-Embers/scenes/screens/CharacterSelect.tscn",
	"map": "res://Path-of-Embers/scenes/screens/MapScreen.tscn",
	"combat": "res://Path-of-Embers/scenes/screens/CombatScreen.tscn",
	"rewards": "res://Path-of-Embers/scenes/screens/RewardsScreen.tscn",
	"encounter": "res://Path-of-Embers/scenes/screens/EncounterScreen.tscn",
	"shop": "res://Path-of-Embers/scenes/screens/ShopScreen.tscn"
}

func _ready():
	# Wait for tree to be ready
	await get_tree().process_frame
	
	# Load and add UIRoot to scene tree
	var ui_root_scene = load("res://Path-of-Embers/scenes/ui/UIRoot.tscn")
	ui_root = ui_root_scene.instantiate()
	get_tree().root.add_child(ui_root)
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.visible = false  # Start hidden, will show on Map/Combat/etc.

func go_to_map():
	## Navigate to map screen
	_change_screen("map", {})

func go_to_combat(encounter_data: Dictionary = {}):
	## Navigate to combat screen with encounter data
	## Second-line defense: check boss gate if current node is boss
	if MapManager and MapManager.current_map and not MapManager.current_node_id.is_empty():
		var node = MapManager.current_map.get_node(MapManager.current_node_id)
		if node and node.node_type == MapNodeData.NodeType.BOSS:
			if QuestManager and not QuestManager.are_all_party_quests_complete():
				push_warning("ScreenManager: Boss gate blocked - quests incomplete")
				# Return to map (MapScreen will show popup if clicked there)
				go_to_map()
				return
	
	_change_screen("combat", encounter_data)

func go_to_rewards(reward_bundle: RewardBundle = null):
	## Navigate to rewards screen with reward bundle
	_change_screen("rewards", {"reward_bundle": reward_bundle})

func go_to_encounter(encounter_data: Dictionary = {}):
	## Navigate to encounter screen
	_change_screen("encounter", encounter_data)

func go_to_shop(shop_data: Dictionary = {}):
	## Navigate to shop screen
	_change_screen("shop", shop_data)

func go_to_character_select():
	## Navigate to character selection screen
	_change_screen("character_select", {})

func go_to_main_menu():
	## Navigate to main menu screen
	_change_screen("main_menu", {})

func _change_screen(screen_name: String, data: Dictionary):
	## Internal method to change screens
	if not screen_scenes.has(screen_name):
		push_error("ScreenManager: Unknown screen name: %s" % screen_name)
		return
	
	var scene_path = screen_scenes[screen_name]
	print("ScreenManager: Loading scene: ", screen_name, " from path: ", scene_path)
	
	var scene_resource = load(scene_path)
	if not scene_resource:
		push_error("Failed to load scene resource: " + scene_path)
		return
	
	var new_scene = scene_resource.instantiate()
	if not new_scene:
		push_error("Failed to instantiate scene: " + screen_name)
		return
	
	# Store data in RunState or pass via setup() method
	if screen_name == "rewards" and data.has("reward_bundle"):
		RunState.set_pending_rewards(data["reward_bundle"])
	
	# Remove old scene
	if current_scene:
		current_scene.queue_free()
	else:
		# If no current_scene tracked, find and remove the main scene node
		# This handles the initial transition from Main.tscn
		var tree_root = get_tree().root
		var children = tree_root.get_children()
		var main_scene = null
		for child in children:
			# Skip UIRoot and the new scene we're about to add
			if child != ui_root and child != new_scene:
				# This should be the initial Main scene
				print("ScreenManager: Found initial scene node: ", child.name)
				main_scene = child
		
		if main_scene:
			main_scene.queue_free()
	
	# Add new scene
	get_tree().root.add_child(new_scene)
	current_scene = new_scene
	
	# Ensure new scene is visible if it's a Control
	if new_scene is Control:
		new_scene.visible = true
		new_scene.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	# Show/hide UI based on scene
	if ui_root:
		get_tree().root.move_child(ui_root, get_tree().root.get_child_count() - 1)
		# Hide UI on Main and CharacterSelect screens
		if screen_name == "main" or screen_name == "main_menu" or screen_name == "character_select":
			ui_root.visible = false
		else:
			ui_root.visible = true
	
	# Ensure the scene is processing
	new_scene.set_process_mode(Node.PROCESS_MODE_INHERIT)
	new_scene.set_process(true)
	
	current_screen = screen_name
	screen_changed.emit(screen_name)
	print("ScreenManager: Successfully loaded scene: ", screen_name)
