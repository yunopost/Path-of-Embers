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

const DEBUG_MODE_ENABLED: bool = false

func is_enabled() -> bool:
	return DEBUG_MODE_ENABLED and OS.is_debug_build()
