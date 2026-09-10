extends Resource
class_name EnemyData

## Enemy data with HP, intents, and art references
## Immutable blueprint for enemy definitions

enum EnemyType {
	NORMAL,
	ELITE,
	BOSS
}

@export var id: String = ""
@export var display_name: String = ""  # Display name (renamed from "name" to match card/character pattern)
@export var name: String = ""  # Legacy field kept for backward compatibility
@export var act: int = 1  # Act this enemy appears in
@export var enemy_type: EnemyType = EnemyType.NORMAL  # Enemy type for conditional effects
@export var min_hp: int = 50  # Minimum HP for randomization
@export var max_hp: int = 50  # Maximum HP for randomization
@export var intents: Array[EffectData] = []  # Legacy: Enemy intents/actions (deprecated, use moves instead)
@export var moves: Array[Dictionary] = []  # Array of move definitions: {"id": "move_1", "timer": 4, "effects": [EffectData], "telegraph_text": "Attack 8"}
@export var sprite_path: String = ""  # Path to enemy sprite
@export var portrait_path: String = ""  # Path to enemy portrait
@export var fullbody_path: String = ""  # Legacy field kept for backward compatibility

## Anti-turtle damage escalation (opening values -- for the simulator to tune, not final):
## once the fight's elapsed tick count reaches escalation_start_tick, this enemy gains
## escalation_strength Strength every escalation_interval ticks thereafter, via the normal
## Strength status. 0 on any of these fields means "never escalates" (default -- most
## enemies are unaffected).
@export var escalation_start_tick: int = 0
@export var escalation_interval: int = 0
@export var escalation_strength: int = 0

func _init():
	intents = []
	moves = []

