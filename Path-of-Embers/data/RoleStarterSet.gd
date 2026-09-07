extends RefCounted
class_name RoleStarterSet

## Defines role-based generic starter cards
## Maps character roles to their generic starter card IDs

static func get_generic_starters_for_role(role: String) -> Array[String]:
	## Returns array of 3 card IDs for the given role.
	##
	## Rule (Creative Director, 3 Sep 2026): every character contributes
	## 1 Strike + 1 Defend + 1 role card, so that any party — including one
	## with no Warrior — starts with a functional amount of damage and block.
	## Before this rule, a Healer+Defender party started with at most one
	## Strike and could not win Act 1 (see Playtest Reports, 3 Sep baseline).
	match role:
		"Warrior":
			return ["strike_1", "defend_1", "strike_1"]
		"Healer":
			return ["strike_1", "defend_1", "heal_1"]
		"Defender":
			return ["strike_1", "defend_1", "defend_1"]
		_:
			# Default fallback
			return ["strike_1", "defend_1", "heal_1"]
