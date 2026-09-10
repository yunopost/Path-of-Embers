extends Resource
class_name EquipmentData

## Immutable blueprint for an equipment item.
## Stored as .tres resource files in data/equipment/.
##
## Equipment slots: one item per slot per character.
## stat_modifiers apply at combat start to the character who has this item equipped.
## injected_cards are added to the owning character's deck at run start.
## abilities reuse the RelicSystem hook/action format.

enum SlotType {
	HELMET,
	CHEST,
	LEGS,
	BOOTS,
	WEAPON,
	RELIC_SLOT
}

enum LockType {
	NONE,       ## Any character can equip
	ARCHETYPE,  ## Only characters of a specific role (Warrior / Healer / Defender)
	CHARACTER   ## Only a specific character (lock_target = character id)
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var slot_type: SlotType = SlotType.WEAPON
@export var rarity: Rarity = Rarity.COMMON

## Stat bonuses applied to the owning character's EntityStats at combat start.
## Supported keys: "str", "def", "spirit", "hp"
## Example: { "str": 2, "hp": 5 }
@export var stat_modifiers: Dictionary = {}

## Card IDs to inject into the owning character's deck at run start (generate_starter_deck).
@export var injected_cards: Array[String] = []

## Ability triggers — same hook/action format as RelicData.triggers.
## Example: [{"hook": "START_OF_COMBAT", "action": "gain_block", "amount": 3}]
@export var abilities: Array = []

## Lock constraints — prevent non-matching characters from equipping this item.
@export var lock_type: LockType = LockType.NONE
@export var lock_target: String = ""  ## Role name (e.g. "Warrior") or character_id

## Gold cost when sold in the shop
@export var shop_price: int = 100

func _init():
	stat_modifiers = {}
	injected_cards = []
	abilities = []

func can_be_equipped_by(char_data: CharacterData) -> bool:
	## Return true if this equipment is allowed on the given character.
	if not char_data:
		return false
	match lock_type:
		LockType.NONE:
			return true
		LockType.ARCHETYPE:
			return char_data.role == lock_target
		LockType.CHARACTER:
			return char_data.id == lock_target
	return true

static func slot_name(slot: SlotType) -> String:
	match slot:
		SlotType.HELMET:    return "HELMET"
		SlotType.CHEST:     return "CHEST"
		SlotType.LEGS:      return "LEGS"
		SlotType.BOOTS:     return "BOOTS"
		SlotType.WEAPON:    return "WEAPON"
		SlotType.RELIC_SLOT: return "RELIC_SLOT"
	return "WEAPON"

static func slot_from_string(s: String) -> SlotType:
	match s:
		"HELMET":     return SlotType.HELMET
		"CHEST":      return SlotType.CHEST
		"LEGS":       return SlotType.LEGS
		"BOOTS":      return SlotType.BOOTS
		"WEAPON":     return SlotType.WEAPON
		"RELIC_SLOT": return SlotType.RELIC_SLOT
	return SlotType.WEAPON

static func all_slot_names() -> Array[String]:
	return ["HELMET", "CHEST", "LEGS", "BOOTS", "WEAPON", "RELIC_SLOT"]
