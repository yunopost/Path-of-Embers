extends Node

## Boot scene - transitions to CharacterSelect

func _ready():
	# Small delay to ensure everything is initialized
	await get_tree().process_frame
	SceneRouter.change_scene("character_select")

