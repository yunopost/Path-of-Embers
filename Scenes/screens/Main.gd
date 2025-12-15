extends Node

## Boot scene - transitions to CharacterSelect

func _ready():
	# Wait for SceneRouter to be ready (autoloads initialize first, but wait a frame for safety)
	await get_tree().process_frame
	# Transition to character select using call_deferred to ensure it happens after this frame
	print("Main: Transitioning to character_select")
	call_deferred("_transition_to_character_select")

func _transition_to_character_select():
	if SceneRouter:
		ScreenManager.go_to_character_select()
	else:
		push_error("SceneRouter not available!")
