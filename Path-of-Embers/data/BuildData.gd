extends RefCounted
class_name BuildData

## Snapshot of a completed run, saved for Boss Rush reuse.
## Max 3 slots stored in user://boss_rush_builds.json.
##
## Captured at FINAL_BOSS_DEFEATED: party, deck (card ids + upgrade lists),
## equipment slots, run stash, and relics.

var slot_index: int = 0          # 0 / 1 / 2
var label: String = ""            # Human-readable: "Monster Hunter · Witch · Living Armor"
var saved_at: String = ""         # ISO date string for display

var party_ids: Array[String] = []
var relics: Array[String] = []    # relic ids (order preserved)

## equipment_slots[char_id][slot_name] = equipment_id
var equipment_slots: Dictionary = {}
var run_stash: Array[String] = []

## deck entries: Array of { "id": String, "upgrades": Array[String], "owner": String }
var deck: Array = []

# ── Population ────────────────────────────────────────────────────────────────

func snapshot_from_run_state() -> void:
	## Populate this BuildData from the current RunState + PartyManager.
	party_ids.clear()
	if PartyManager:
		for id in PartyManager.get_party_ids():
			party_ids.append(id)

	# Build a nice label
	var names: Array[String] = []
	for pid in party_ids:
		var cd = DataRegistry.get_character(pid) if DataRegistry else null
		names.append(cd.display_name if cd else pid)
	label = " · ".join(names)
	saved_at = Time.get_datetime_string_from_system(false, true)

	# Deck
	deck.clear()
	if RunState:
		for instance_id in RunState.deck:
			var dcd: DeckCardData = RunState.deck[instance_id]
			deck.append({
				"id": dcd.card_id,
				"upgrades": dcd.applied_upgrades.duplicate(),
				"owner": dcd.owner_character_id,
			})

	# Equipment
	equipment_slots = {}
	if RunState:
		for char_id in RunState.equipment_slots:
			equipment_slots[char_id] = RunState.equipment_slots[char_id].duplicate()
	run_stash = RunState.run_stash.duplicate() if RunState else []

	# Relics
	relics.clear()
	if RunState:
		for r in RunState.relics:
			relics.append(r["id"] if r is Dictionary else str(r))

# ── Serialization ─────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"slot_index":       slot_index,
		"label":            label,
		"saved_at":         saved_at,
		"party_ids":        party_ids.duplicate(),
		"relics":           relics.duplicate(),
		"equipment_slots":  _deep_copy_dict(equipment_slots),
		"run_stash":        run_stash.duplicate(),
		"deck":             deck.duplicate(true),
	}

static func from_dict(d: Dictionary) -> BuildData:
	var b := BuildData.new()
	b.slot_index      = int(d.get("slot_index", 0))
	b.label           = str(d.get("label", ""))
	b.saved_at        = str(d.get("saved_at", ""))
	b.party_ids       = _to_string_array(d.get("party_ids", []))
	b.relics          = _to_string_array(d.get("relics", []))
	b.run_stash       = _to_string_array(d.get("run_stash", []))
	b.deck            = d.get("deck", [])

	var raw_equip = d.get("equipment_slots", {})
	if raw_equip is Dictionary:
		for char_id in raw_equip:
			b.equipment_slots[str(char_id)] = {}
			var slots = raw_equip[char_id]
			if slots is Dictionary:
				for slot_name in slots:
					b.equipment_slots[str(char_id)][str(slot_name)] = str(slots[slot_name])
	return b

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _to_string_array(arr) -> Array[String]:
	var result: Array[String] = []
	if arr is Array:
		for item in arr:
			result.append(str(item))
	return result

static func _deep_copy_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v = d[k]
		if v is Dictionary:
			out[k] = _deep_copy_dict(v)
		elif v is Array:
			out[k] = v.duplicate()
		else:
			out[k] = v
	return out
