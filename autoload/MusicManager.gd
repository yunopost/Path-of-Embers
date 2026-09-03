extends Node

## Autoload singleton - Manages background music playback
## Plays the main menu theme on launch, fades out when the player enters a run.
## User music volume (0..1) is persisted to user://settings.json.

const MUSIC_PATH := "res://Path-of-Embers/Audio/Music/The Path of Embers.mp3"
const FADE_DURATION := 1.5  # seconds
const MUSIC_VOLUME_DB := -10.0  # playback volume at music_volume = 1.0
const SETTINGS_PATH := "user://settings.json"

var music_volume: float = 1.0  # linear 0..1, user-adjustable

var _player: AudioStreamPlayer
var _tween: Tween = null

## Screens that are considered "in a run" — music fades out on these
const GAME_SCREENS := ["character_select", "loadout", "quest_select", "map", "combat",
		"rewards", "encounter", "shop", "game_over", "victory", "boss_rush"]

## Screens that are considered the main menu — music plays/resumes on these
const MENU_SCREENS := ["main", "main_menu"]

func _ready() -> void:
	_load_settings()

	_player = AudioStreamPlayer.new()
	_player.name = "MenuMusicPlayer"
	_player.bus = "Master"
	add_child(_player)

	var stream = load(MUSIC_PATH)
	if stream == null:
		push_error("MusicManager: Failed to load music at %s" % MUSIC_PATH)
		return

	_player.stream = stream
	_player.volume_db = _target_db()
	_player.play()

	# Connect to ScreenManager once it's ready
	await get_tree().process_frame
	if ScreenManager:
		ScreenManager.screen_changed.connect(_on_screen_changed)

func set_music_volume(value: float) -> void:
	## Set user music volume (0..1), apply immediately, and persist.
	music_volume = clampf(value, 0.0, 1.0)
	if _player and _player.playing and (_tween == null or not _tween.is_valid()):
		_player.volume_db = _target_db()
	_save_settings()

func _target_db() -> float:
	## Convert the linear user volume into a decibel target.
	if music_volume <= 0.01:
		return -80.0
	return MUSIC_VOLUME_DB + linear_to_db(music_volume)

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
	_tween.tween_property(_player, "volume_db", _target_db(), FADE_DURATION)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

# ── Settings persistence ──────────────────────────────────────────────────────

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		music_volume = clampf(float(parsed.get("music_volume", 1.0)), 0.0, 1.0)

func _save_settings() -> void:
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not f:
		push_warning("MusicManager: could not write %s" % SETTINGS_PATH)
		return
	f.store_string(JSON.stringify({"music_volume": music_volume}))
