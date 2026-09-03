# Path of Embers — Code & Design Review

---

## What You've Built

Path of Embers is a card-based roguelike RPG built in Godot 4 (GDScript). The concept is a three-character party roguelike where each character has a personal quest, a unique card set, and a role-based starter deck. The combat uses an **enemy timer system** — cards tick enemy countdown timers rather than a traditional "end of turn" trigger — which is the game's most distinctive mechanical idea. The full game loop covers: Main Menu → Character Select → Map → Combat → Rewards/Shop → repeat.

The codebase is genuinely well-architected for a project at this stage. The broad structure is clean and the separation of concerns is largely good. Below is a detailed breakdown.

---

## Architecture Overview

### Autoloads (Singletons)
| Autoload | Purpose |
|---|---|
| `RunState` | Source of truth for deck, relics, buffs, settings, pity counter, reward pool |
| `ResourceManager` | Gold, HP, energy, block — emits signals for reactive UI |
| `DataRegistry` | Loads and caches all .tres resources (cards, enemies, characters, upgrades) |
| `SaveManager` | Serialize/deserialize RunState to `user://save_run.json` |
| `AutoSaveManager` | Triggers SaveManager at key moments |
| `MapManager` | Act, node position, map data, available nodes |
| `PartyManager` | Party member IDs |
| `QuestManager` | Quest states, event emission |
| `SceneRouter` | Scene transitions |
| `ScreenManager` | Overlay screen management (Deck view, Settings popup, etc.) |

### Core Systems
- **Combat**: `CombatController` → `EffectResolver` → `EntityStats` (enemies and player)
- **Deck**: `DeckModel` (draw/hand/discard pile logic) + `DeckCardData` (card instances with unique IDs)
- **Map**: `MapGenerator` → `MapData` → `MapNodeData`
- **Upgrades**: `UpgradeData` resources + `CardRules` (centralized rule evaluation)

### Data Layer
All game content (cards, enemies, characters, upgrades) is stored as `.tres` resource files and loaded at startup by `DataRegistry`. This is the right call for a data-driven game.

---

## What's Working Well

**Signal-driven reactive UI.** ResourceManager and RunState emit signals on every state change, and UI components subscribe. This is idiomatic Godot and means UI is never manually refreshed — it just reacts.

**Instance-based deck system.** Every card in the deck is a `DeckCardData` instance with a unique `instance_id`. Two copies of "Strike" are distinct objects. This correctly handles upgrades per-copy, ownership tracking, and transcendence without any ambiguity.

**Separation of game logic from UI.** `EffectResolver`, `EntityStats`, `CombatController`, `EnemyTimeSystem`, and `IntentSystem` are all pure game logic with no UI dependencies. You can reason about and test them independently.

**Data-driven upgrades.** The `UpgradeData` + `applies_to_cards` + `effects_dict` system lets you define upgrade behaviour entirely in .tres files. This is scalable.

**CardValidation layer.** Cards are validated on creation and before save/load. This catches data integrity problems early.

**Save robustness.** The SaveManager handles multiple legacy save formats and validates cards during load. Version-tracking (currently v5) is present. AutoSave triggers on key moments.

**Rare pity system.** Incrementing the rare chance counter per common shown, resetting on rare — this is good game feel design baked into the data layer.

---

## Bugs and Issues

### 🔴 Critical — Will break functionality

**1. `_remove_temporary_cards()` is never called.**
`CombatController` has a method to strip temporary cards (like cursed cards) from the deck at combat end, but it is never invoked. Any card added as `is_temporary = true` during combat will persist in the deck permanently. This needs to be connected to `combat_ended`.

**2. `_on_enemy_acted()` is never connected.**
The method that triggers `BLOCK_ON_ENEMY_ACT` (the "Survey the Path" power card — "whenever an enemy acts, gain block") exists in `CombatController` but there is no signal connection calling it when an enemy performs its intent. The power card can be selected and applied, but its effect will never fire.

**3. Case-sensitive path mismatch in scene files.**
Some `.tscn` files reference scripts at `res://Path-of-Embers/scenes/` (lowercase `s`) while the actual folder on disk is `Scenes/` (uppercase `S`). On Windows this works fine. On Linux (which is where Godot exports and where the game may be run or hosted), this will produce `null` script references and scenes will fail to initialize. Files affected include `CombatScreen.tscn`, `MapScreen.tscn`, `EncounterScreen.tscn`, `RewardsScreen.tscn`, `ShopScreen.tscn`, `SettingsPopup.tscn`, `MapNodeWidget.tscn`, `UIRoot.tscn`, and `UpgradeFlowPanel.tscn`. Either standardise the folder name to lowercase throughout, or fix all the references. Lowercase is the Godot convention.

**4. Reward card pool loses effect data on save/load.**
`SaveManager` serializes the reward pool as `{id, name, cost, rarity}` only. When loaded back, the reconstructed `CardData` objects have no `base_effects`. If the player saves mid-run and loads, the reward pool cards will display correctly but have no effects when played after being added to the deck. The correct fix is to not serialize the reward pool at all — it should be regenerated from character data on load, since the party IDs are already saved.

### 🟡 Medium — Wrong behaviour or fragile code

**5. Discard cost choice is not player-controlled.**
`_pay_discard_cost()` in `CombatController` discards cards from the end of the available array (last cards added). The comment acknowledges this: "UI for player choice can be added later." For any card with a discard cost, the player has no agency over which cards are discarded. This should be addressed before the discard-cost mechanic is used in real gameplay.

**6. Portrait loading is hardcoded by display name.**
`CharacterEntry._load_portrait()` has explicit checks for `"Monster Hunter"` and `"Witch"` by string name. Adding a third character requires editing this method. The `portrait_path` field already exists on `CharacterData` — use it exclusively. The hardcoded block exists only because the path wasn't being set correctly on the resource, which is the actual thing to fix.

**7. `RETAIN_BLOCK_THIS_TURN` applied with raw string literal.**
In `EffectResolver` line 195: `source.apply_status("retain_block_this_turn", status_value)` — this uses a raw string instead of `StatusEffectType.RETAIN_BLOCK_THIS_TURN`. If the constant value ever changes, or is mistyped anywhere, the effect will silently fail. Use the constant.

**8. `ResourceManager.reset_resources()` hardcodes 50 HP.**
On new game reset, HP is always set to 50/50 and energy to 3/3 regardless of character-specific starting values. If any character ever has different base HP, this will be wrong. HP should be computed from the party's `CharacterData` during `reset_run()`.

**9. `previous_block` variable declared mid-file after it's first used.**
The variable is first assigned at line 110 in `start_player_turn()`, but its declaration appears at line 507. GDScript allows this (all class vars are in scope), but it makes the code very hard to read and follow. Move the declaration to the top with the other vars.

### 🟢 Minor — Technical debt, polish, or potential future problems

**10. Two duplicate top-level .tscn files.**
`Scenes/CombatScreen.tscn` and `Scenes/MapScreen.tscn` at the root `Scenes/` level appear to be old scaffold versions. The real scenes are in `Scenes/screens/`. The orphans should be deleted to avoid confusion.

**11. `EncounterScreen.tscn` contains a `DebugLabel` node.**
Not a bug, but a placeholder that shouldn't ship. Same for the "Tap to Play (not implemented)" checkbox in `SettingsPopup`.

**12. `CharacterEntry.gd` initialization is unnecessarily complex.**
The `initialize()` → `_pending_char_data` → `call_deferred("_initialize_when_ready")` → `_do_initialize()` flow exists to handle the timing gap between `initialize()` being called and Godot's `_ready()` firing. The standard and simpler pattern is: store all data as member variables in `initialize()`, then read from them in `_ready()`. The current approach creates three nearly identical code paths.

**13. `DataRegistry.get_card_data()` falls back to an O(n×m) search.**
If a card isn't in `generic_card_cache`, it searches all characters' starter and reward pools. This works at current scale, but once you have 5+ characters with 20+ cards each, this scan will be slow. Cards from character data should be added to `generic_card_cache` during `_load_all_resources()`.

**14. No formal migration system for save versions.**
The version field is bumped to 5 but deserialization handles multiple legacy formats with ad-hoc `if save_data.has(...)` checks scattered through 200 lines. As the game grows, this will become unmaintainable. Consider a versioned migration pattern: a dictionary keyed by version that applies transformations in sequence.

**15. `EffectType.MODIFY_ENEMY_TIMER` is a stubbed placeholder.**
It does nothing (`pass`). If any card data references this effect type, it will silently fail.

---

## Missing Content

These are referenced in code but have no data files yet:

- **No `data/characters/` .tres files** — Characters are expected to self-register (presumably via scene-side resources), but the `DATA_DIR_CHARACTERS` directory scan will find nothing. Monster Hunter and Witch exist as art assets and are referenced by name in code, but their `CharacterData` resources aren't in the repo.
- **No character-specific card .tres files** — Upgrades reference cards like `monster_hunter_full_attack`, `witch_*`, etc., but none of those card .tres files exist yet. The upgrade pool for those cards will always return empty.
- **Only one enemy** — `ash_man.tres` is the only enemy. The map generator and intent system are designed for variety.

---

## Game Design Assessment

### The Core Mechanic: Enemy Timers

The timer system is the most interesting design choice in the game. Instead of "end your turn, enemies attack," enemies have individual countdown timers that are ticked by playing cards. A card with the `Slow` keyword ticks timers twice; `Haste` ticks zero times; `Exhaust` removes the card after play.

**This is genuinely novel and creates interesting decisions**: Do you play a powerful Slow card knowing it will trigger the enemy sooner? Do you save Haste cards to play for "free" when the timer is nearly at zero? Do you hold cards back at the end of a turn to avoid triggering the boss?

It also creates a natural difficulty knob: stronger enemy moves can have shorter timers (they attack sooner), and fragile enemies can have long timers (lots of build-up time).

**Potential issues to address:**
- Currently, when you press "End Turn," all enemy timers are forced to zero and they all act simultaneously. With multiple enemies, this could be chaotic and punishing. Consider whether enemies should act one at a time in some order, or whether simultaneous action is intentional.
- The timer mechanic can feel opaque to new players. The telegraphing system (enemy shows its next move) is already in place, which is good. But players need clear visual feedback on the timer value and what triggers enemy actions.

### Three-Character Party with Quests

Having each character carry their own quest (tracked during the run) is a strong design. It gives the run narrative direction beyond just "win combat, get stronger." The quest data is already wired into the UI (CharacterHUDBlock, CharacterEntry).

The "role-based starter deck" (each role gets 3 generic + 2 unique cards) creates a consistent 15-card starting deck with clear identity per character.

**Potential issues:**
- 15 cards is quite small. Typical Slay the Spire starts at 10 but has faster, more focused combat. At 15 with the timer system you'll want to test whether games feel "solved" too quickly or if there's enough strategic depth.
- The starter deck includes `heal_1` as a generic card for all roles. Consider whether healing should be role-gated to create more distinct character identities.

### Upgrade System

The upgrade system is well-designed. Rather than transforming cards ("Strike → Strike+"), you're layering modifiers onto individual card instances. A card can have multiple upgrades simultaneously (e.g., Strike could have `strike_damage_plus` and `strike_block`). This creates real depth.

The three keyword upgrades (`Slow`, `Exhaust`, `Haste`) are especially interesting because they modify the card's interaction with the timer system, not just its raw numbers.

**The transcendence system** (cards transform into more powerful versions after enough upgrades) is a great idea for late-game power fantasy. It needs actual transcendent card definitions, but the infrastructure is sound.

### Map and Progression

The MapGenerator is designed to create a branching path with different node types (combat, elite, shop, rest, encounter/event). This is the standard roguelike structure and appropriate here.

**Gaps to address before going further:**
- The `ShopScreen` is a placeholder ("Shop Screen" label only). If the shop is on the map, players will hit it and find nothing.
- The `EncounterScreen` is partially implemented but very basic. "A strange figure approaches you on the path..." with choices is promising, but the choices aren't wired to any outcome logic yet.

### Relic System

Relics are stored (`RunState.relics`) and have data structures (`RelicData`), but the comment in `RunState.add_relic()` explicitly says: "relic effects are not implemented. Relics are stored but have no gameplay impact." This is honest, but it means the rewards screen can offer relics that do nothing. Either remove relics from rewards until implemented, or add a few simple ones.

---

## Recommended Priority Order Before Continuing Development

**Fix first (blockers):**
1. Fix the case-sensitive path issue in .tscn files (will break on non-Windows)
2. Connect `_remove_temporary_cards()` to `combat_ended`
3. Connect `_on_enemy_acted()` so the Survey the Path power card actually works
4. Fix reward pool save/load (regenerate from character data instead of serializing partial CardData)

**Fix soon (game integrity):**
5. Make discard cost player-controlled (or remove discard-cost cards until UI exists)
6. Replace hardcoded portrait loading with `portrait_path` field
7. Fix `RETAIN_BLOCK_THIS_TURN` raw string to use the constant
8. Move `previous_block` declaration to the top of CombatController
9. Decide what "End Turn" does with multiple enemies (sequential vs. simultaneous)

**Before alpha/testing:**
10. Create CharacterData .tres files for Monster Hunter and Witch
11. Create card .tres files for all character-specific cards referenced in upgrades
12. Implement at least a few relic effects, or remove relics from reward pools
13. Implement the Shop screen (even a basic "buy cards" version)
14. Add more enemies (the system is ready; you just need more .tres files)

---

## Summary

The codebase is in better shape than most hobby projects at this stage. The architecture is sound, the data-driven design will scale well, and the core mechanic (enemy timers) is genuinely interesting. The main issues are a handful of wiring bugs (temporary cards not cleaned up, power card signal not connected), a cross-platform path bug, and significant missing content (no character .tres files, no character-specific card files). None of the structural problems require large refactors — they're mostly targeted fixes.

The game design direction is promising. The timer mechanic, three-character party, quest system, and upgrade depth give it a strong identity. The things to decide before going further are: how multi-enemy turns work, whether the shop/relic systems will be active this slice, and whether the EncounterScreen events will have real outcomes.
