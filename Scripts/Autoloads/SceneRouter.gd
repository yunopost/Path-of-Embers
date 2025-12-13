extends Node

## Autoload singleton - Handles scene transitions and keeps UI persistent

signal scene_changed(new_scene_name: String)

var ui_root: Control = null
var current_scene: Node = null

const SCENE_PATHS = {
	"main": "res://Path-of-Embers/Scenes/Main.tscn",
	"character_select": "res://Path-of-Embers/Scenes/CharacterSelect.tscn",
	"map": "res://Path-of-Embers/Scenes/MapScreen.tscn",
	"combat": "res://Path-of-Embers/Scenes/CombatScreen.tscn",
	"encounter": "res://Path-of-Embers/Scenes/EncounterScreen.tscn",
	"shop": "res://Path-of-Embers/Scenes/ShopScreen.tscn"
}

func _ready():
	# Wait for tree to be ready
	await get_tree().process_frame
	
	# Load and add UIRoot to scene tree
	var ui_root_scene = load("res://Path-of-Embers/Scenes/UI/UIRoot.tscn")
	ui_root = ui_root_scene.instantiate()
	get_tree().root.add_child(ui_root)
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.visible = false  # Start hidden, will show on Map/Combat/etc.
	
	# Main scene will handle initial transition

func _input(event):
	# Debug hotkey: F3 to go to CombatScreen
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			change_scene("combat")

func change_scene(scene_name: String):
	if not SCENE_PATHS.has(scene_name):
		push_error("Scene not found: " + scene_name)
		return
	
	var scene_path = SCENE_PATHS[scene_name]
	print("SceneRouter: Loading scene: ", scene_name, " from path: ", scene_path)
	
	var scene_resource = load(scene_path)
	if not scene_resource:
		push_error("Failed to load scene resource: " + scene_path)
		return
	
	var new_scene = scene_resource.instantiate()
	if not new_scene:
		push_error("Failed to instantiate scene: " + scene_name)
		return
	
	# Remove old scene - use call_deferred to ensure it happens after this frame
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
				print("SceneRouter: Found initial scene node: ", child.name)
				main_scene = child
		
		if main_scene:
			# Remove immediately instead of queue_free for initial scene
			main_scene.queue_free()
	
	# Add new scene
	get_tree().root.add_child(new_scene)
	current_scene = new_scene
	
	# Ensure new scene is visible if it's a Control
	if new_scene is Control:
		new_scene.visible = true
	print("SceneRouter: Successfully loaded scene: ", scene_name)
	
	# Show/hide UI based on scene
	if ui_root:
		get_tree().root.move_child(ui_root, get_tree().root.get_child_count() - 1)
		# Hide UI on Main and CharacterSelect screens
		if scene_name == "main" or scene_name == "character_select":
			ui_root.visible = false
		else:
			ui_root.visible = true
	
	scene_changed.emit(scene_name)

func open_popup(popup_name: String):
	# Popups are handled by UIRoot
	if ui_root and ui_root.has_method("open_popup"):
		ui_root.open_popup(popup_name)
