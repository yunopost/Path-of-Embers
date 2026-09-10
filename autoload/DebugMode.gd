extends Node
## Addendum §6: debug mode flag. Default OFF, and forced OFF in exported
## builds regardless of the persisted setting below (OS.is_debug_build() is
## false in an exported release build, true in the editor and in debug
## exports) -- so this can never ship live in a release build by accident.
##
## The player toggles debug mode at runtime from a small developer control on
## the main menu (only shown when OS.is_debug_build() is true). The choice is
## persisted to user://debug_settings.json, following the same pattern
## MusicManager uses for user://settings.json, so it survives a relaunch.
## Kept as a single flag (not threaded through game logic) -- callers check
## DebugMode.is_enabled() at the few points debug behaviour actually branches
## (party select unlock gate, DebugPanel.attach_to, CombatScreen's Instant
## Win button).

## Default persisted value on a profile with no debug_settings.json yet --
## ON, matching prior behaviour (debug mode was always on in editor/debug
## builds before the runtime toggle existed).
const DEFAULT_ENABLED: bool = true
const SETTINGS_PATH := "user://debug_settings.json"

var _persisted_enabled: bool = DEFAULT_ENABLED
var _forced: int = 0   # 0 = use the persisted value, 1 = forced on, -1 = forced off

func _ready() -> void:
	_load_settings()
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "--no-debug":
			_forced = -1
		elif a == "--debug-mode":
			_forced = 1
	if is_enabled():
		print("DebugMode: ENABLED (editor/debug build). Toggle it on the main menu or launch with --no-debug to disable.")

func is_enabled() -> bool:
	## Single read point for every debug-mode check in the game.
	if not OS.is_debug_build():
		return false
	if _forced != 0:
		# Launch flags win over the persisted value for this session only --
		# they never touch (or overwrite) what's saved to disk.
		return _forced == 1
	return _persisted_enabled

func set_enabled(value: bool) -> void:
	## Flip debug mode at runtime and persist the choice. Called by the main
	## menu's developer toggle. Has no visible effect for the rest of THIS
	## session if a launch flag forced a state (see is_enabled()), but the
	## persisted value still updates so it takes effect on next launch.
	_persisted_enabled = value
	_save_settings()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and parsed.has("debug_enabled"):
		_persisted_enabled = bool(parsed["debug_enabled"])

func _save_settings() -> void:
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not f:
		push_warning("DebugMode: could not write %s" % SETTINGS_PATH)
		return
	f.store_string(JSON.stringify({"debug_enabled": _persisted_enabled}))
