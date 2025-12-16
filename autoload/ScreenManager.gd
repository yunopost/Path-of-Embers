extends Node

## Screen navigation manager - follows architecture rule 5.1
## Autoload singleton - do not use class_name
## One screen active at a time, explicit transition methods

signal screen_changed(screen_name: String)

var current_screen: String = ""
var screen_scenes: Dictionary = {
	"main_menu": "res://Path-of-Embers/scenes/screens/Main.tscn",
	"character_select": "res://Path-of-Embers/scenes/screens/CharacterSelect.tscn",
	"map": "res://Path-of-Embers/scenes/screens/MapScreen.tscn",
	"combat": "res://Path-of-Embers/scenes/screens/CombatScreen.tscn",
	"rewards": "res://Path-of-Embers/scenes/screens/RewardsScreen.tscn",
	"encounter": "res://Path-of-Embers/scenes/screens/EncounterScreen.tscn",
	"shop": "res://Path-of-Embers/scenes/screens/ShopScreen.tscn"
}

func _ready():
	# Connect to SceneRouter for backward compatibility during transition
	# Eventually SceneRouter will delegate to ScreenManager
	pass

func go_to_map():
	## Navigate to map screen
	_change_screen("map", {})

func go_to_combat(encounter_data: Dictionary = {}):
	## Navigate to combat screen with encounter data
	## Second-line defense: check boss gate if current node is boss
	if RunState.current_map and not RunState.current_node_id.is_empty():
		var node = RunState.current_map.get_node(RunState.current_node_id)
		if node and node.node_type == MapNodeData.NodeType.BOSS:
			if not RunState.are_all_party_quests_complete():
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
	var scene = load(scene_path)
	if not scene:
		push_error("ScreenManager: Could not load scene: %s" % scene_path)
		return
	
	# Use SceneRouter for now (will be replaced later)
	# Store data in RunState or pass via setup() method
	if screen_name == "rewards" and data.has("reward_bundle"):
		RunState.set_pending_rewards(data["reward_bundle"])
	
	# Transition via SceneRouter (temporary during refactor)
	SceneRouter.change_scene(screen_name)
	current_screen = screen_name
	screen_changed.emit(screen_name)
	
	# Log transition
	print("ScreenManager: Transitioned to %s" % screen_name)
