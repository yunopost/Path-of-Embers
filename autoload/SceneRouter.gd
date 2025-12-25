extends Node

## Autoload singleton - Handles scene transitions and keeps UI persistent

signal scene_changed(new_scene_name: String)

var ui_root: Control = null
var current_scene: Node = null

const SCENE_PATHS = {
	"main": "res://Path-of-Embers/scenes/screens/Main.tscn",
	"main_menu": "res://Path-of-Embers/scenes/screens/Main.tscn",  # Alias for main
	"character_select": "res://Path-of-Embers/scenes/screens/CharacterSelect.tscn",
	"map": "res://Path-of-Embers/scenes/screens/MapScreen.tscn",
	"combat": "res://Path-of-Embers/scenes/screens/CombatScreen.tscn",
	"encounter": "res://Path-of-Embers/scenes/screens/EncounterScreen.tscn",
	"shop": "res://Path-of-Embers/scenes/screens/ShopScreen.tscn",
	"rewards": "res://Path-of-Embers/scenes/screens/RewardsScreen.tscn"
}

func _ready():
	## SceneRouter is now deprecated - ScreenManager handles scene transitions
	## UIRoot is managed by ScreenManager
	pass

func _input(event):
	# Debug hotkey: F3 to go to CombatScreen (delegates to ScreenManager)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			if ScreenManager:
				ScreenManager.go_to_combat({})

func change_scene(scene_name: String):
	## Deprecated: Use ScreenManager.go_to_*() methods instead
	## Kept for backward compatibility - delegates to ScreenManager
	push_warning("SceneRouter.change_scene() is deprecated. Use ScreenManager.go_to_*() methods instead.")
	
	# Delegate to ScreenManager
	if ScreenManager:
		# Map scene names to ScreenManager methods
		match scene_name:
			"main", "main_menu":
				ScreenManager.go_to_main_menu()
			"character_select":
				ScreenManager.go_to_character_select()
			"map":
				ScreenManager.go_to_map()
			"combat":
				ScreenManager.go_to_combat({})
			"rewards":
				ScreenManager.go_to_rewards(null)
			"encounter":
				ScreenManager.go_to_encounter({})
			"shop":
				ScreenManager.go_to_shop({})
			_:
				push_error("SceneRouter: Unknown scene name: " + scene_name)
	else:
		push_error("SceneRouter: ScreenManager not available")

func open_popup(popup_name: String):
	# Popups are handled by UIRoot
	if ui_root and ui_root.has_method("open_popup"):
		ui_root.open_popup(popup_name)
