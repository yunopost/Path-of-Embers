# Path of Embers — Plan to Finish (v1.0)

**Goal:** A playable, balanced, bug-free v1.0. Full run (Acts 1–3 + final boss) with all 12 characters, full 22-card reward pools per character, working milestones/unlocks, and placeholder art. Relics are officially dropped (equipment replaced them). Real art/audio deferred to post-1.0 with an asset spec.

Milestones are ordered so the game is shippable after any of them. Cards (M3) are batched per character so scope can be cut mid-stream without stranding work.

---

## M0 — Housekeeping & Verification (small)

Clean the repo and confirm what's actually broken before building on it.

| # | Task |
|---|------|
| 0.1 | Delete stale `Path-of-Embers/.claude/worktrees/agent-ab703ccb/` (full duplicate of an old project snapshot) |
| 0.2 | Delete orphan duplicate scenes `Path-of-Embers/scenes/CombatScreen.tscn` and `MapScreen.tscn` (top-level copies; real ones are in `scenes/screens/`) |
| 0.3 | Re-verify the old `Path-of-Embers-Review.md` critical bugs against current code: `_remove_temporary_cards()` connection, `_on_enemy_acted()` connection, reward-pool save/load fidelity. Fix any still broken |
| 0.4 | **Purge relics**: remove relic references from GDD, reward flag docs (`R`/`B` flags), and fix quests that track `gain_relics` (e.g. Witch "Dark Knowledge") — retarget to equipment or another counter |
| 0.5 | Reconcile the two GameDesign.md copies (`.cursor/` vs `Path-of-Embers/`) — keep one source of truth, update Development Status section (modifier multipliers are already applied; docs say they aren't) |
| 0.6 | Remove `DebugLabel` in EncounterScreen and "not implemented" settings toggle |
| 0.7 | Full smoke test: new run → all node types → boss → victory/game over → save/load mid-run → boss rush. Log every bug found into a tracked list |

## M1 — Finish Core Mechanics (medium)

Everything referenced by card data or the GDD that's currently stubbed. These must exist before the card batches, since many new cards depend on them.

| # | Task |
|---|------|
| 1.1 | **Scry/Foresight UI** — card-reorder popup for SCRY, Foresight placement, and Augury effects (currently a `push_warning`) |
| 1.2 | **Discard-cost player choice** — hand-selection UI instead of auto-discarding from array end |
| 1.3 | **Temporary upgrade effect** — implement `add_temporary_upgrade_to_random_hand_card` (or remove the effect type and any cards using it) |
| 1.4 | **Quest counters** — wire the TODO counters: `bloom_triggers`, `foresight_uses`, `mirror_count`, `block_converted_to_energy` |
| 1.5 | **Mechanist Legacy, complete** — kill-counter exists; add Deep Investment (repeat-upgradeable) and Duplicate-Growth (auto-upgrade on second copy) card types with save persistence |
| 1.6 | **Transcendence, minimum viable** — replace placeholder transcendent cache with real transcended versions for a small curated set (~1 per character), plus an acquisition point (e.g., rest node option when a card is fully upgraded). Full transcendence depth is post-1.0 |
| 1.7 | **Effect capability audit** — map each of the 36 themes (12 chars × 3) to existing `EffectType`s; list missing effect types needed for M3 card batches (contagion spread, resonance stacks, inevitability positioning, absorption, untouchable condition, etc.). Output: a checklist that gates each M3 batch |
| 1.8 | Implement the missing effect types identified in 1.7 that are shared across multiple characters (do character-unique ones inside their M3 batch) |

## M2 — Milestones & Unlock Content (small)

| # | Task |
|---|------|
| 2.1 | Create `data/milestones/` .tres files — the manager and meta-save already exist, there's just no data. Suggested set: first win, win with each role, elite kills, boss rush unlock, modifier unlocks |
| 2.2 | Wire modifier unlock gating to milestones (currently all modifiers are always available) |
| 2.3 | Locked-character display already exists — decide which characters (if any) start locked and behind which milestone |

## M3 — Reward Card Pools: 22 per character (large — the bulk of remaining work)

Target per GDD: 7 Common / 12 Uncommon / 3 Rare per character. Current reality: ~7 reward slots per character, mostly reusing starter cards, with auto-generated placeholders filling the rest. Net new: **~240 cards**.

**Pipeline per character batch:**
1. Design pass — card list on paper first (name, cost, type, rarity, effect, which theme it serves). Theme 1/2 cards should be immediate; theme 3 cards should combo cross-character per the synergy web.
2. Implement any character-unique effect types (from 1.7 audit).
3. Author .tres files + wire into character resource.
4. Validate: CardValidation passes, cards resolve in combat, upgrade pool entries exist for at least the commons.
5. Batch playtest: 2–3 runs featuring that character.

**Batch order** (pairs chosen so synergies are testable as soon as both halves exist):

| Batch | Characters | Rationale |
|-------|-----------|-----------|
| 1 | Monster Hunter + Shadowfoot | Core timer axis; most effects already exist |
| 2 | Witch + Living Armor | Core mass axis; discard/deck-inflation effects |
| 3 | Golemancer + Hollow | Block generation → conversion; heavy strikes |
| 4 | Revenant + Tempest | Spite/death-trigger + cantrip/sequencing |
| 5 | Grove + Mechanist | Bloom/regrowth + Legacy (needs 1.5 done) |
| 6 | Sibyl + Echo | Foresight/probability + mirror/resonance (needs 1.1) |

Ship checkpoint: the game is releasable after any batch — remaining characters keep placeholder pools until their batch lands.

## M4 — Balance & Tuning (medium, overlaps M3)

| # | Task |
|---|------|
| 4.1 | Enemy pass — verify act 2/3 scaling feels right with modifier multipliers; add 2–3 enemies per act if fights repeat too often (9 enemies + 3 bosses currently) |
| 4.2 | Economy pass — gold income vs. shop/upgrade prices across a full run |
| 4.3 | Pity system verification — log rare distribution over simulated reward rolls |
| 4.4 | Difficulty modifier tuning — each of the 6 should feel distinct and be beatable |
| 4.5 | Headless balance harness (optional but recommended): script auto-played combats to catch degenerate cards/combos cheaply |

## M5 — Polish & UX (medium)

| # | Task |
|---|------|
| 5.1 | Character select — ensure all 12 render correctly with placeholder portraits; the GDD's scan→inspect→commit layout is speced in detail, verify implementation matches |
| 5.2 | Combat clarity — timer feedback (per GDD: timer awareness is mastery); telegraphs, damage numbers, status tooltips |
| 5.3 | End-of-run screens — victory/game-over stats, score display with modifier multiplier |
| 5.4 | SFX hooks — add an SFX bus + play-points (card play, damage, enemy act, button) with silent/placeholder sounds so audio drop-in is trivial later |
| 5.5 | Settings — volume sliders wired to MusicManager/SFX bus; remove dead toggles |
| 5.6 | Asset spec doc for the artist — the GDD already has the character-select asset table; extend it to card art, enemy sprites, act backgrounds |

## M6 — Release Prep (small)

| # | Task |
|---|------|
| 6.1 | Save-version migration check — bump version, verify old saves load or fail gracefully |
| 6.2 | Export builds: Windows + Linux (case-sensitivity!); test on Steam Deck resolution if available |
| 6.3 | Strip godot_mcp addon from export presets |
| 6.4 | Final QA sweep against the M0.7 bug list |

---

## Suggested sequence and effort

```
M0 ──► M1 ──► M2 ──► M3 batches 1–6 ──► M6
                     │
                     ├── M4 (interleave after each batch)
                     └── M5 (interleave anytime after M1)
```

Rough relative effort: M3 ≈ 60% of remaining work, M1 ≈ 15%, M4+M5 ≈ 20%, M0+M2+M6 ≈ 5%.

## Explicitly out of scope for v1.0

Real character/card art (placeholder spec instead), full transcendence card lines beyond the curated set, contagion/absorption depth beyond what card batches need, additional music tracks, mobile export, localization.
