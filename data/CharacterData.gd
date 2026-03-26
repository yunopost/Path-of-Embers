extends Resource
class_name CharacterData

## Character data with starter cards, rewards, and quest references

@export var id: String = ""
@export var display_name: String = ""
@export var role: String = ""  # e.g., "Warrior", "Healer", "Defender"
@export var portrait_path: String = ""
@export var fullbody_path: String = ""
@export var starter_unique_cards: Array[CardData] = []  # Exactly 2 unique cards
@export var reward_card_pool: Array[CardData] = []  # Cards available as rewards

## Quest pool — one quest is randomly selected at run start from this array.
## All three party members must complete their assigned quest to unlock the final boss.
@export var quests: Array[QuestData] = []

## Theme display (shown on character select screen)
## theme_1 and theme_2 are the obvious starting themes.
## theme_3 is the advanced cross-character combo theme.
@export var theme_1: String = ""
@export var theme_2: String = ""
@export var theme_3: String = ""

## Base combat stats (set per character, not modified during a run — see GDD Phase 2)
## STR  — adds +1 damage per point to Attack cards owned by this character
## DEF  — adds +1 block per point to Skill block cards owned by this character
## SPIRIT — adds +1 healing per point to Heal cards owned by this character
## hp_base — contributes to the shared party HP pool (pool = sum of all 3 members)
##
## Role defaults per GDD:
##   Warrior:  STR 2 / DEF 1 / SPIRIT 1 / HP 25
##   Defender: STR 1 / DEF 2 / SPIRIT 1 / HP 28
##   Healer:   STR 1 / DEF 1 / SPIRIT 2 / HP 22
@export var str_base: int = 1
@export var def_base: int = 1
@export var spirit_base: int = 1
@export var hp_base: int = 25

func _init():
	starter_unique_cards = []
	reward_card_pool = []
	quests = []
