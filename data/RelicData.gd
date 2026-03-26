extends Resource
class_name RelicData

## Immutable blueprint for a relic type.
## Stored as .tres resource files in data/relics/.
##
## Relic behaviour is entirely data-driven via the triggers array.
## Each trigger dict uses the same format as PetDefinition triggers:
##   { "hook": "HOOK_NAME", "action": "action_name", "amount": <int> }
##
## See RelicSystem.gd for the full list of supported hooks and actions.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	BOSS,
	SHOP
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var icon_path: String = ""

## Trigger array — defines all hook responses for this relic.
## Example: [{"hook": "START_OF_COMBAT", "action": "gain_strength", "amount": 2}]
@export var triggers: Array = []
