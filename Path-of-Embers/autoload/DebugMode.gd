extends Node
## Addendum §6: debug mode flag. Default OFF, and forced OFF in exported
## builds regardless of DEBUG_MODE_ENABLED below (OS.is_debug_build() is
## false in an exported release build, true in the editor and in debug
## exports) -- so this can never ship live in a release build by accident.
##
## Flip DEBUG_MODE_ENABLED to true locally to turn debug mode on during
## development/testing. Kept as a single flag (not threaded through game
## logic) -- callers check DebugMode.is_enabled() at the few points debug
## behaviour actually branches (party select unlock gate, CombatScreen's
## Instant Win button, the debug panel's own visibility).

## Default: ON whenever the game is run from the Godot editor or a debug
## export, OFF in every release export. OS.is_debug_build() is the hard safety
## net -- debug mode can never reach a shipped build regardless of this flag.
## Override at launch with --no-debug (force off) or --debug-mode (force on).
const DEBUG_MODE_ENABLED: bool = true

var _forced: int = 0   # 0 = use the flag, 1 = forced on, -1 = forced off

func _ready() -> void:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "--no-debug":
			_forced = -1
		elif a == "--debug-mode":
			_forced = 1
	if is_enabled():
		print("DebugMode: ENABLED (editor/debug build). Launch with --no-debug to disable.")

func is_enabled() -> bool:
	if not OS.is_debug_build():
		return false
	if _forced != 0:
		return _forced == 1
	return DEBUG_MODE_ENABLED
