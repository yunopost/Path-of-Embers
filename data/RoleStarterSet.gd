extends RefCounted
class_name RoleStarterSet

## Defines role-based generic starter cards
## Maps character roles to their generic starter card IDs

static func get_generic_starters_for_role(role: String) -> Array[String]:
	## Returns array of 3 card IDs for the given role
	match role:
		"Warrior":
			return ["strike_1", "strike_1", "heal_1"]
		"Healer":
			return ["strike_1", "heal_1", "defend_1"]
		"Defender":
			return ["defend_1", "defend_1", "heal_1"]
		_:
			# Default fallback
			return ["strike_1", "defend_1", "heal_1"]
