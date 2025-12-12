extends Node

## Autoload singleton - Handles scene transitions and keeps UI persistent

signal scene_changed(new_scene_name: String)

var ui_root: Control = null
var current_scene: Node = null

const SCENE_PATHS = {
	"main": "res://Path-of-Embers/Main.tscn",
	"character_select": "res://Path-of-Embers/CharacterSelect.tscn",
	"map": "res://Path-of-Embers/MapScreen.tscn",
	"combat": "res://Path-of-Embers/CombatScreen.tscn",
	"encounter": "res://Path-of-Embers/EncounterScreen.tscn",
	"shop": "res://Path-of-Embers/ShopScreen.tscn"
}

func _ready():
	# Wait for tree to be ready
	await get_tree().process_frame
	
	# Load and add UIRoot to scene tree
	var ui_root_scene = load("res://Path-of-Embers/UIRoot.tscn")
	ui_root = ui_root_scene.instantiate()
	get_tree().root.add_child(ui_root)
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.visible = false  # Start hidden, will show on Map/Combat/etc.
	
	# Main scene will handle initial transition

func change_scene(scene_name: String):
	if not SCENE_PATHS.has(scene_name):
		push_error("Scene not found: " + scene_name)
		return
	
	var scene_path = SCENE_PATHS[scene_name]
	var new_scene = load(scene_path).instantiate()
	
	# Remove old scene
	if current_scene:
		current_scene.queue_free()
	
	# Add new scene
	get_tree().root.add_child(new_scene)
	current_scene = new_scene
	
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

