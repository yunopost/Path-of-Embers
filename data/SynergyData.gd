extends RefCounted
class_name SynergyData

## Static lookup for character pair synergies, sourced from GameDesign.md's
## Full Synergy Web. Keys are the two character ids sorted alphabetically
## and joined with "|". Used by CharacterSelect's detail panel.
##
## Character id reference:
##   warrior_1 = Monster Hunter   warrior_2 = Shadowfoot
##   warrior_3 = Revenant         warrior_4 = Tempest

const PAIRS: Dictionary = {
	# ── Timer axis ────────────────────────────────────────────────────────────
	"warrior_1|warrior_2": "Haste setup into Slow payoff — the core timer combo.",
	"warrior_1|warrior_4": "Timer control lets Tempest build card sequences safely.",
	"warrior_2|warrior_4": "Both want the maximum cards played per turn.",
	"golemancer|warrior_2": "Filtered draws make combo chains reliable.",
	"sibyl|warrior_2": "Foresight guarantees combo cards arrive in order.",

	# ── Mass axis ─────────────────────────────────────────────────────────────
	"living_armor|witch": "Deck inflation feeds discard profits — the core mass combo.",
	"mechanist|witch": "Draw power turns deck mass into engine speed.",
	"grove|witch": "Compost is explosive next to Witch's large discard pile.",
	"grove|living_armor": "A large deck spreads Bloom counters widely.",

	# ── Control ───────────────────────────────────────────────────────────────
	"warrior_1|witch": "Vulnerable amplifies curse and contagion damage.",
	"golemancer|warrior_1": "Control when hits land — and how much they cost.",
	"hollow|warrior_1": "Timer manipulation plus end-turn cards: precise turn control.",
	"living_armor|warrior_1": "Both reward long elite fights.",

	# ── Danger / resource conversion ──────────────────────────────────────────
	"grove|warrior_3": "Grove's energy funds all-in kill-and-trigger turns.",
	"warrior_3|warrior_4": "Chain damage kills weak enemies; Revenant cashes in the same turn.",
	"golemancer|warrior_3": "Damage reduction enables aggressive low-HP Spite play.",
	"warrior_3|witch": "Both turn self-harm into power.",
	"hollow|warrior_3": "Damage and defence both become resources — nothing is wasted.",
	"golemancer|hollow": "High block generation converts directly into energy.",
	"hollow|living_armor": "Two long-fight defenders with complementary styles.",

	# ── Accumulation / precision / echo ───────────────────────────────────────
	"grove|mechanist": "Bloom and Legacy both accumulate across the whole run.",
	"golemancer|sibyl": "Sibyl arranges the deck; Golemancer filters it.",
	"mechanist|sibyl": "Inevitability positions Legacy cards to fire at peak power.",
	"echo|sibyl": "Sibyl sets the sequence; Echo doubles the payoff.",
	"echo|mechanist": "Mirror copies Legacy cards at high counter values.",
	"echo|warrior_4": "Echo copies sequence-buffed cards at their peak.",
	"echo|warrior_2": "Consecutive plays build Resonance naturally.",
}

## Fallback shown for Mechanist with any partner that has no specific entry.
const MECHANIST_UNIVERSAL := "Transcendence synergy — Mechanist enhances every transcended card in the deck."

static func get_synergy(char_a: String, char_b: String) -> String:
	## Returns the synergy description for a character pair, or "" if none.
	if char_a == char_b:
		return ""
	var ids := [char_a, char_b]
	ids.sort()
	var key: String = "%s|%s" % [ids[0], ids[1]]
	if PAIRS.has(key):
		return PAIRS[key]
	if char_a == "mechanist" or char_b == "mechanist":
		return MECHANIST_UNIVERSAL
	return ""
