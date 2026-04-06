extends Node

## Autoload singleton - Manages background music playback
## Plays the main menu theme on launch, fades out when the player enters a run.

const MUSIC_PATH := "res://Path-of-Embers/Audio/Music/The Path of Embers.mp3"
const FADE_DURATION := 1.5  # seconds
const MUSIC_VOLUME_DB := -10.0  # default playback volume

var _player: AudioStreamPlayer
var _tween: Tween = null

## Screens that are considered "in a run" — music fades out on these
const GAME_SCREENS := ["character_select", "loadout", "map", "combat", "rewards",
		"encounter", "shop", "game_over", "victory", "boss_rush"]

## Screens that are considered the main menu — music plays/resumes on these
const MENU_SCREENS := ["main", "main_menu"]

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MenuMusicPlayer"
	_player.bus = "Master"
	add_child(_player)

	var stream = load(MUSIC_PATH)
	if stream == null:
		push_error("MusicManager: Failed to load music at %s" % MUSIC_PATH)
		return

	_player.stream = stream
	_player.volume_db = MUSIC_VOLUME_DB
	_player.play()

	# Connect to ScreenManager once it's ready
	await get_tree().process_frame
	if ScreenManager:
		ScreenManager.screen_changed.connect(_on_screen_changed)

func _on_screen_changed(screen_name: String) -> void:
	if screen_name in GAME_SCREENS:
		_fade_out()
	elif screen_name in MENU_SCREENS:
		_fade_in()

func _fade_out() -> void:
	if not _player.playing:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", -80.0, FADE_DURATION)
	_tween.tween_callback(_player.stop)

func _fade_in() -> void:
	_kill_tween()
	if not _player.playing:
		_player.volume_db = -80.0
		_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", MUSIC_VOLUME_DB, FADE_DURATION)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
