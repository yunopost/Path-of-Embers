# Reward & Flow Implementation Report
## Path of Embers - Slice 7 Implementation Analysis

---

## 1. Rewards Pipeline Overview

### Flow: Node Completion → Rewards → Return to Map

**Exact Sequence:**

1. **Node Selection (MapScreen.gd)**
   - User clicks a node widget
   - `_on_node_clicked(node_id)` is called
   - `RunState.set_current_node(node_id)` is called
   - **Node is marked as completed immediately** in `RunState.set_current_node()` (line 174)
   - Screen transition based on node type:
	 - `FIGHT/ELITE/BOSS` → `ScreenManager.go_to_combat()`
	 - `ENCOUNTER` → `ScreenManager.go_to_encounter()`
	 - `SHOP` → `ScreenManager.go_to_shop()`

2. **Node Resolution (CombatScreen/EncounterScreen)**
   - **CombatScreen** (`CombatScreen.gd:278`):
	 - After combat victory: `RunState.mark_current_node_completed()` (redundant, already marked)
	 - `RewardResolver.build_rewards_for_node()` generates `RewardBundle`
	 - `RunState.set_pending_rewards(bundle)`
	 - `ScreenManager.go_to_rewards(bundle)`
   
   - **EncounterScreen** (`EncounterScreen.gd:74-103`):
	 - Player chooses option (Help/Threaten/Leave)
	 - Creates `RewardBundle` with hardcoded rewards per choice
	 - `RunState.set_pending_rewards(bundle)` via `_runstate_set_pending_rewards()`
	 - `ScreenManager.go_to_rewards(bundle)`

3. **Rewards Screen (RewardsScreen.gd)**
   - `initialize()` reads `RunState.pending_rewards`
   - Displays reward sections via `_display_rewards()`
   - Player claims rewards:
	 - Gold: `_on_claim_gold()` → `RunState.set_gold()`
	 - Card: `_on_choose_card()` → `RunState.add_card_to_deck_from_reward()`
	 - Relic: `_on_claim_relic()` → TODO placeholder
	 - Upgrade: `_on_upgrade_button_pressed()` → Opens `UpgradeFlowPanel`
   - `_update_continue_button()` checks all rewards resolved
   - Continue button: `_on_continue_pressed()` → `_finish_rewards()` → `ScreenManager.go_to_map()`

4. **Return to Map**
   - `RewardsScreen._finish_rewards()`:
	 - `RunState.clear_pending_rewards()`
	 - `ScreenManager.go_to_map()`
   - Map displays node as completed (via `is_completed` flag)
   - Next nodes unlocked via `_update_available_nodes()` (already called when node marked completed)

### Key Functions & Signals

**Node Completion:**
- `RunState.set_current_node(node_id)` - Marks node completed (line 174)
- `RunState.mark_current_node_completed()` - Redundant wrapper (line 199), also called from CombatScreen

**Reward Bundle:**
- `RunState.set_pending_rewards(bundle: RewardBundle)` - Stores bundle
- `RunState.clear_pending_rewards()` - Clears after rewards resolved
- `RewardResolver.build_rewards_for_node(node: MapNodeData)` - Generates bundle from node flags

**Signals Used:**
- `RunState.current_node_changed` - Emitted when node selected
- `RunState.available_next_node_ids_changed` - Emitted when available nodes update
- `RunState.deck_changed` - Emitted when card added
- `RunState.gold_changed` - Emitted when gold changes
- `RewardsScreen` has local flags: `gold_claimed`, `card_claimed`, `relic_claimed`, `upgrade_claimed`, `heal_applied`

**Scenes:**
- `MapScreen.tscn` → `CombatScreen.tscn` / `EncounterScreen.tscn` → `RewardsScreen.tscn` → `MapScreen.tscn`

---

## 2. Reward Data Structures

### RewardBundle (Resource/RefCounted)

**File:** `Path-of-Embers/data/RewardBundle.gd`
**Type:** `RefCounted` (class_name RewardBundle)

**Fields:**
```gdscript
var gold: int = 0
var card_choices: Array[String] = []  # Array of card IDs to choose from
var relic_id: String = ""  # Empty if no relic
var upgrade_count: int = 0  # Number of upgrades available
var heal_amount: int = 0  # Amount of HP to heal
var skip_allowed: bool = true  # Whether player can skip rewards
var is_transcendence_upgrade: bool = false  # If true, upgrade options are transcendence instead of normal
```

**Serialization:**
- `to_dict()` - Converts to Dictionary for save/load
- `from_dict(data: Dictionary)` - Static factory method

### Gold Reward

**Data Type:** `int` (stored in `RewardBundle.gold`)
**Applied via:** `RunState.set_gold(RunState.gold + amount)`
**Storage:** `RunState.gold: int`

### Card Reward

**Data Type:** `Array[String]` (card IDs in `RewardBundle.card_choices`)
**Applied via:** `RunState.add_card_to_deck_from_reward(card_id, owner_id)`
**Creates:** `DeckCardData` instance (see section 3)

### Upgrade Reward

**Data Type:** `int` (count in `RewardBundle.upgrade_count`)
**Process:** Multi-step flow (see section 4)
**Storage:** Applied to `DeckCardData.applied_upgrades: Array[String]`

### Relic Reward

**Data Type:** `String` (relic ID in `RewardBundle.relic_id`)
**Storage:** `RunState.relics: Array` (currently just IDs as strings)
**Status:** **Placeholder** - Claim button exists but `RunState.add_relic()` not implemented

### Boss Relic Reward

**Data Type:** Same as regular relic (`String` ID)
**Distinction:** `RewardBundle.is_transcendence_upgrade` flag set to `true` for boss nodes
**Difference:** Generated via `RewardResolver` when `RewardType.BOSS_RELIC` flag present, but storage identical

**Current Implementation:**
- Boss nodes generate `RewardBundle` with `relic_id = "relic_boss_01"` (placeholder)
- `is_transcendence_upgrade = true` flag set
- However, transcendence upgrade flow **not yet implemented** (see section 4)

---

## 3. Card Reward Implementation

### Card Generation

**Source Pool:**
- **Placeholder implementation** - Hardcoded array in `EncounterScreen._generate_card_choices()` and `RewardResolver._generate_card_choices()`
- Cards: `["strike_1", "defend_1", "bash_1", "heal_1", "hasten_1"]`
- **TODO Comment:** "Later can pull from RunState.reward_card_pool or DataRegistry"

**Selection Logic:**
- Random selection without replacement (no duplicates)
- Selects 3 cards from pool
- If pool < 3, returns all available

**Duplicates:** Not possible in single reward screen (pool filtered), but same card ID can appear across different reward screens.

### Card Addition to Deck

**Function:** `RunState.add_card_to_deck_from_reward(card_id: String, owner_character_id: String = "")`

**What Object is Added:**
- **`DeckCardData` instance** (not `CardData`)
- Created via: `DeckCardData.new(card_id, owner_character_id, upgrades=[], transcended=false, transcendent_card_id="")`
- Added to `RunState.deck: Array` (stores `DeckCardData` instances)

**Card Instance Structure:**
```gdscript
# DeckCardData (Path-of-Embers/data/DeckCardData.gd)
var card_id: String  # Reference to CardData.id
var owner_character_id: String
var applied_upgrades: Array[String]  # Upgrade IDs applied to this instance
var is_transcended: bool
var transcendent_card_id: String
```

**Important:** The deck stores **mutable card instances** (`DeckCardData`), not immutable definitions (`CardData`). Each instance can have different upgrades applied.

---

## 4. Upgrade Reward Implementation (CRITICAL)

### Upgrade Flow Steps

1. **Player clicks "Upgrade a card" button** → `RewardsScreen._on_upgrade_button_pressed()`
2. **UpgradeFlowPanel shown** → `_start_upgrade_flow()` → `UpgradeFlowPanel.setup(reward_bundle)`
3. **Card Selection Step** → `UpgradeFlowPanel._show_card_selection()`
   - Iterates `RunState.deck` array
   - Creates `DeckCardWidget` for each card
   - Widgets display cards and check `RunState.can_upgrade_card_at(deck_index)`
4. **Player selects card** → `_on_card_widget_clicked(deck_index: int)`
   - Stores `selected_card_index = deck_index`
   - Calls `UpgradeService.roll_upgrade_options_for_card(card_instance, 3)`
   - Shows upgrade selection UI
5. **Player selects upgrade** → `_on_upgrade_button_pressed(upgrade_id: String)`
   - Emits `upgrade_option_selected` signal
   - `RewardsScreen._on_upgrade_option_selected()` handles it
   - Calls `RunState.apply_upgrade_to_card_at(selected_index, upgrade_id)`
   - Decrements `reward_bundle.upgrade_count -= 1`
   - If count > 0, refresh panel; else mark upgrade_claimed

### Card Reference System

**Method:** **Deck Index** (array position in `RunState.deck: Array`)

**How Cards are Referenced:**
- `deck_index: int` - Position in `RunState.deck` array
- **No unique instance IDs** - Cards are identified by index
- **No object references** - Direct array access: `RunState.deck[deck_index]`

**Upgrade Application:**
```gdscript
# RunState.apply_upgrade_to_card_at(deck_index: int, upgrade_id: String)
var card_instance = deck[deck_index]  # Gets DeckCardData
card_instance.applied_upgrades.append(upgrade_id)  # Mutates the object
```

**Persistence:** The `DeckCardData` object in `RunState.deck[deck_index]` is directly mutated. This persists because:
1. The object reference remains in the array
2. Save/load serializes `applied_upgrades` array (see section 7)

### Upgrade Options Data Structure

**Data Type:** `Array[String]` (upgrade IDs)
**Generated by:** `UpgradeService.roll_upgrade_options_for_card(card_instance: DeckCardData, count: int = 3)`

**Selection Logic:**
1. Get upgrade pool for card: `DataRegistry.get_upgrade_pool_for_card(card_id)`
2. Filter out already-applied upgrades
3. If available < count, return all
4. Otherwise, randomly select count options (no duplicates)

**Upgrade Definition:**
- Stored in `DataRegistry.upgrade_definitions: Dictionary`
- Key: `upgrade_id: String`
- Value: `Dictionary` with `{"id": ..., "title": ..., "description": ...}`

### Applying Upgrades

**Function:** `RunState.apply_upgrade_to_card_at(deck_index: int, upgrade_id: String) -> bool`

**What is Mutated:**
- **`DeckCardData` instance at `RunState.deck[deck_index]`**
- Field: `applied_upgrades: Array[String]`
- Operation: `card_instance.applied_upgrades.append(upgrade_id)`

**Consistency Update:**
- After mutation, calls `_update_card_in_piles(card_id, owner_id, upgrades)`
- Updates matching cards in `draw_pile`, `hand`, `discard_pile` arrays
- **Note:** This tries to sync card instances across piles, but piles may contain duplicates/copies

**Current Limitation:**
- **Max 1 upgrade per card** enforced (line 531: `if card_instance.applied_upgrades.size() >= 1: return false`)
- Storage supports multiple (`Array[String]`) but logic limits to 1

### Transcend Implementation

**Status:** **Partial - Storage exists, logic not implemented**

**Storage:**
- `DeckCardData.is_transcended: bool`
- `DeckCardData.transcendent_card_id: String`
- `RewardBundle.is_transcendence_upgrade: bool` flag (set for boss nodes)

**UI Display:**
- `DeckCardWidget` shows "Transcended!" label when `is_transcended == true`
- Label visibility: `transcend_label.visible = card_instance.is_transcended`

**Missing Logic:**
- No code that sets `is_transcended = true`
- `UpgradeFlowPanel` does not check `is_transcendence_upgrade` flag
- Upgrade flow treats transcendence same as normal upgrades
- No special transcendence upgrade pool or selection logic

**Hook:** The `RewardBundle.is_transcendence_upgrade` flag is set but **never checked** by upgrade flow.

---

## 5. Relics

### Storage

**Location:** `RunState.relics: Array`
**Current Type:** Array of strings (relic IDs as placeholders)
**Example:** `["relic_test_01", "relic_elite_01"]`

### Application

**Status:** **Not implemented**
- `RewardsScreen._on_claim_relic()` has TODO comment
- Line 234-235: `# TODO: Implement relic adding to RunState`
- Currently just prints: `print("Relic claimed: ", relic_id)`

**No distinction between normal and boss relics** in storage - both stored as string IDs.

### Effects

**Status:** **Not implemented**
- Relics are stored but no effect system exists
- No relic effect application logic
- No runtime modification based on relics

---

## 6. Node Completion & Map State

### Marking Nodes Completed

**Function:** `RunState.set_current_node(node_id: String)`
**Location:** `RunState.gd:167-184`
**Implementation:**
```gdscript
if current_map and current_map.nodes.has(current_node_id):
	current_map.nodes[current_node_id].is_completed = true
```

**Also:** `RunState.mark_current_node_completed()` (line 199) - redundant wrapper, also called from CombatScreen.

### Data Structure

**Field:** `MapNodeData.is_completed: bool`
**Type:** `bool`
**Location:** `MapNodeData.gd:30`
**Serialization:** Included in `to_dict()` / `from_dict()`

### Unlocking Next Nodes

**Function:** `RunState._update_available_nodes()`
**Logic:**
1. Gets `current_node.connected_to: Array[String]` (node IDs)
2. Filters: `available_next_node_ids.filter(func(id): return not current_map.get_node(id).is_completed)`
3. Completed nodes excluded from available list

### Preventing Re-entry

**Mechanism:** `is_completed` flag checked in `_update_available_nodes()` filter
**Visual:** `MapNodeWidget` dims completed nodes (checked in widget display logic)
**No explicit blocking** - nodes just don't appear in `available_next_node_ids`

---

## 7. Save / Load Coverage

### Persisted Reward-Related Data

**Save/Load System:** `SaveManager.gd` (autoload)

**Serialized Fields:**

1. **Deck Contents** ✅
   - `deck: Array` - Serialized as array of `DeckCardData.to_dict()`
   - Includes: `card_id`, `owner_character_id`, `applied_upgrades`, `is_transcended`, `transcendent_card_id`
   - Load: `DeckCardData.from_dict()` reconstructs instances
   - **Upgrades ARE saved** (in `applied_upgrades` array)

2. **Gold** ✅
   - `gold: int` - Saved and loaded

3. **Relics** ✅
   - `relics: Array` - Saved and loaded (but currently just string IDs, no effect data)

4. **Completed Nodes** ✅
   - `current_map: MapData` - Serialized via `MapData.to_dict()`
   - `MapNodeData.is_completed: bool` - Included in node serialization
   - Load: `MapData.from_dict()` restores map with completion states

5. **Pending Rewards** ❌
   - **NOT saved** - `pending_rewards: RewardBundle` is not in `SaveManager._serialize_run_state()`
   - If game saved during rewards screen, rewards lost on load

6. **Reward Card Pool** ✅
   - `reward_card_pool: Array[CardData]` - Saved (serialized as dictionaries with id, name, cost)
   - Load: Reconstructed as `CardData` objects

**Not Saved:**
- `pending_rewards` (RewardBundle)
- Combat state (hand, draw_pile, discard_pile) - These are reinitialized from deck on load

---

## 8. Known Limitations & TODOs

### Rewards

1. **Card Generation** - Placeholder hardcoded pool
   - TODO: Pull from `RunState.reward_card_pool` or `DataRegistry`
   - Location: `EncounterScreen._generate_card_choices()`, `RewardResolver._generate_card_choices()`

2. **Relic System** - Not implemented
   - TODO: `RunState.add_relic()` method
   - Location: `RewardsScreen._on_claim_relic()` line 234

3. **Pending Rewards** - Not saved
   - Risk: Save during rewards screen loses rewards

### Upgrades

1. **Max 1 Upgrade** - Hardcoded limit
   - Storage supports multiple (`Array[String]`) but logic enforces 1
   - Location: `RunState.apply_upgrade_to_card_at()` line 531

2. **Transcendence** - Storage exists, logic missing
   - `RewardBundle.is_transcendence_upgrade` flag set but never checked
   - No transcendence upgrade flow
   - Location: `UpgradeFlowPanel` does not handle transcendence differently

3. **Upgrade Pool Consistency** - Piles may become out of sync
   - `_update_card_in_piles()` tries to sync but piles may have duplicate instances
   - If card exists multiple times in deck, only matching instances updated

### Relics

1. **No Effect System** - Relics stored but not applied
2. **No Distinction** - Boss vs normal relics stored identically
3. **Placeholder IDs** - `"relic_test_01"`, `"relic_elite_01"`, `"relic_boss_01"`

### Flow Control

1. **Double Completion** - Node marked completed twice
   - `RunState.set_current_node()` marks it
   - `RunState.mark_current_node_completed()` called again from CombatScreen
   - Redundant but harmless

2. **No Error Handling** - If reward bundle missing, screens may crash
   - `RewardsScreen.initialize()` has fallback to return to map
   - But no validation of bundle contents

---

## 9. Diagrams (Text-Only)

### Sequence Diagram: Map Node → Scene → Rewards → Map

```
[Player] → [MapScreen]
    |
    | click node
    v
[MapScreen._on_node_clicked]
    |
    | RunState.set_current_node(node_id)
    | (marks is_completed = true)
    v
[RunState.set_current_node]
    |
    | _update_available_nodes()
    | (filters out completed)
    v
[ScreenManager.go_to_combat/encounter/shop]
    |
    | SceneRouter.change_scene()
    v
[CombatScreen / EncounterScreen]
    |
    | (after resolution)
    | RewardResolver.build_rewards_for_node()
    | RunState.set_pending_rewards(bundle)
    v
[ScreenManager.go_to_rewards]
    |
    | SceneRouter.change_scene("rewards")
    v
[RewardsScreen.initialize]
    |
    | reads RunState.pending_rewards
    | _display_rewards()
    v
[Player claims rewards]
    |
    | (gold/card/relic/upgrade)
    | RunState methods called
    v
[RewardsScreen._on_continue_pressed]
    |
    | RunState.clear_pending_rewards()
    | ScreenManager.go_to_map()
    v
[MapScreen]
    |
    | (node shown as completed)
    | (next nodes available)
    v
```

### Data Flow: Upgrade Reward → Card Mutation → Save

```
[RewardBundle]
    |
    | upgrade_count = 1
    v
[RewardsScreen._on_upgrade_button_pressed]
    |
    | UpgradeFlowPanel.setup(reward_bundle)
    v
[UpgradeFlowPanel._show_card_selection]
    |
    | for deck_index in RunState.deck:
    |   card_instance = RunState.deck[deck_index]
    v
[Player selects card]
    |
    | _on_card_widget_clicked(deck_index)
    | UpgradeService.roll_upgrade_options_for_card()
    v
[Player selects upgrade]
    |
    | _on_upgrade_button_pressed(upgrade_id)
    | RunState.apply_upgrade_to_card_at(deck_index, upgrade_id)
    v
[RunState.apply_upgrade_to_card_at]
    |
    | card_instance = RunState.deck[deck_index]
    | card_instance.applied_upgrades.append(upgrade_id)
    | _update_card_in_piles()  # syncs piles
    v
[RunState.deck[deck_index]]
    |
    | DeckCardData {
    |   card_id: "strike_1",
    |   applied_upgrades: ["strike_damage_plus"]
    | }
    v
[SaveManager.save_game]
    |
    | _serialize_run_state()
    | deck_data.append(deck_card.to_dict())
    | {
    |   "card_id": "strike_1",
    |   "applied_upgrades": ["strike_damage_plus"],
    |   ...
    | }
    v
[JSON file]
```

---

## 10. Confidence Check

### Least Confident Part

**Card Instance Consistency Across Piles**

The `_update_card_in_piles()` method tries to sync upgrades across `draw_pile`, `hand`, and `discard_pile`, but:

1. Piles may contain duplicate card instances (same card_id, same owner)
2. Matching is done by `card_id` and `owner_character_id`, which may match multiple instances
3. If a card exists multiple times in deck, only some instances in piles may be updated
4. The deck_model integration complicates this further (piles use indices, not instances)

**Risk:** Upgrades may not appear correctly in hand/draw/discard if cards are duplicated or if sync fails.

### Hardest to Extend for Character Quests

**Reward Generation Logic**

Currently, `RewardResolver.build_rewards_for_node()` uses hardcoded rewards and simple flag checks. To extend for character quests:

1. Need to check quest progress when generating rewards
2. Need character-specific reward pools (not just global)
3. Need to pass quest context to reward resolver
4. Need to modify `RewardBundle` to include quest-related rewards
5. Multiple characters may have different quest requirements for same node

**Current state makes this difficult because:**
- `RewardResolver` is static (no access to RunState context easily)
- No quest checking in reward generation
- Card pools are global, not per-character
- Reward generation happens in multiple places (CombatScreen, EncounterScreen, RewardResolver)

**Recommendation:** Refactor to pass `RunState` context to `RewardResolver` or make it a singleton with access to quest state.

---

## Summary

The rewards system is **functionally complete for basic flow** but has several **placeholder implementations** and **missing features**:

✅ **Working:**
- Node completion and map progression
- Reward bundle generation and display
- Gold rewards
- Card rewards (selection and deck addition)
- Upgrade rewards (basic flow)
- Save/load of deck, gold, completed nodes

⚠️ **Partial:**
- Transcendence (storage exists, logic missing)
- Relics (storage exists, effects missing)

❌ **Not Implemented:**
- Relic effects
- Quest-based reward modifications
- Dynamic card pools from characters
- Saving pending rewards
- Multiple upgrades per card (storage supports, logic limits)

The architecture is **solid** with clear separation of concerns, but several TODOs need completion before quest integration.
