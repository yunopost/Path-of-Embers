## Godot 4 Development Rules — Path of Embers
**Project:** Path of Embers (Roguelike Deck Builder)
**Engine:** Godot 4.5.1
**Language:** GDScript
**Team Size:** 2 Developers

---

## 🎯 Core Philosophy

**Node-First Architecture (CRITICAL)**
Prefer nodes and scenes over pure script solutions.

- ALWAYS use the Godot editor and inspector to configure node properties
- NEVER create systems entirely in code when nodes can handle them
- ALWAYS leverage built-in node functionality before writing custom code
- Use `Area2D` with `CollisionShape2D` for detection, NOT a script that checks distances

**Separation of Concerns**
- **Data** (what a thing is) → Custom `Resource` classes and `.tres` files
- **State** (what is happening right now in a run) → Autoload singletons
- **Behavior** (how things interact) → Scene nodes and scripts
- **View** (what the player sees) → Screen and UI scenes that listen to signals

---

## 📁 Project Structure

```
path-of-embers/
├── autoload/                  # Global singletons (see Autoload Rules)
│   ├── DataRegistry.gd        # Resource loader/cache — cards, characters, enemies, upgrades
│   ├── RunState.gd            # Deck, relics, pity counter (core run state)
│   ├── ResourceManager.gd     # Gold, HP, energy, block
│   ├── PartyManager.gd        # Party composition (3 character IDs)
│   ├── SaveManager.gd         # Serialization to user://save_run.json
│   ├── AutoSaveManager.gd     # Force saves on key state changes
│   ├── MapManager.gd          # Map progress and node state
│   ├── QuestManager.gd        # Quest tracking + game event bus
│   ├── SceneRouter.gd         # Screen navigation
│   └── ScreenManager.gd       # UI state
│
├── core/                      # Pure logic — no UI, no scene dependencies
│   ├── combat/
│   │   ├── CombatController.gd    # Turn/action management
│   │   ├── EffectResolver.gd      # Generic effect execution engine
│   │   ├── Enemy.gd
│   │   ├── EnemyTimeSystem.gd
│   │   ├── EntityStats.gd         # HP, block, status effects
│   │   ├── IntentSystem.gd
│   │   ├── PetBoard.gd            # Pet summon/management
│   │   ├── PetDefinition.gd       # Pet blueprint (immutable)
│   │   └── PetInstance.gd         # Pet runtime state
│   ├── deck/
│   │   ├── DeckModel.gd           # Draw/hand/discard pile state
│   │   └── CardValidation.gd
│   ├── rules/
│   │   └── CardRules.gd           # Cost/damage/block calculations
│   ├── run/
│   │   ├── RewardResolver.gd
│   │   └── UpgradeService.gd
│   └── map/
│       ├── MapData.gd
│       ├── MapGenerator.gd
│       └── MapNodeData.gd
│
├── data/                      # Resource definitions
│   ├── CardData.gd            # Card blueprint (immutable)
│   ├── DeckCardData.gd        # Card instance in player's deck (has upgrades, instance_id)
│   ├── CharacterData.gd       # Character blueprint
│   ├── EnemyData.gd           # Enemy blueprint
│   ├── EffectData.gd          # Effect type + params
│   ├── EffectType.gd          # Effect type constants
│   ├── StatusEffect.gd        # Status instance wrapper
│   ├── StatusEffectType.gd    # Status type constants
│   ├── RelicData.gd
│   ├── UpgradeData.gd
│   ├── cards/                 # .tres card resources
│   ├── enemies/               # .tres enemy resources
│   └── upgrades/              # .tres upgrade resources
│
└── scenes/                    # All .tscn files
    ├── screens/               # Full-screen scenes (Combat, Map, Rewards, etc.)
    └── ui/                    # Reusable UI components
        ├── cards/
        ├── hud/
        └── rewards/
```

---

## 📛 Naming Conventions (STRICT)

### Files and Folders
- All folders and `.gd` / `.tscn` / `.tres` files: `snake_case`
- Class names in scripts: `PascalCase`
- Script filename must match class name: `deck_model.gd` → `class_name DeckModel`

### Class Name Suffixes
| Suffix | Purpose | Examples |
|--------|---------|---------|
| `Data` | Immutable resource definition | `CardData`, `EnemyData`, `CharacterData`, `UpgradeData` |
| `Manager` / `State` / `Registry` | Autoload singleton | `DataRegistry`, `RunState`, `ResourceManager`, `PartyManager` |
| `Model` | Pure data container (no UI) | `DeckModel` |
| `Controller` | Orchestrates systems | `CombatController` |
| `System` | Focused subsystem | `EnemyTimeSystem`, `IntentSystem` |
| `Resolver` | Executes/processes logic | `EffectResolver`, `RewardResolver` |
| `Screen` | Full-screen scene script | `CombatScreen`, `MapScreen`, `RewardsScreen` |
| `Widget` / `Block` / `Indicator` | Reusable UI component | `DeckCardWidget`, `CharacterHUDBlock`, `StatusEffectIndicator` |
| `Type` | Enum-like constants class | `EffectType`, `StatusEffectType` |
| `Definition` | Immutable blueprint (non-Resource) | `PetDefinition` |
| `Instance` | Runtime mutable state object | `PetInstance` |

### Variable Names
- Public variables: `snake_case` (e.g., `current_hp`, `draw_pile`)
- Private variables: `_snake_case` with leading underscore (e.g., `_cached_path`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `DATA_DIR_CARDS`, `MAX_HAND_SIZE`)
- `@onready` vars: `snake_case`, declared near top of script

### ID Conventions
- **Card definition IDs:** `snake_case` strings matching filename (e.g., `"strike_1"`, `"monster_hunter_full_attack"`)
- **Character IDs:** role prefix + number (e.g., `"warrior_1"`, `"healer_2"`, `"defender_3"`)
- **Card instance IDs:** UUID-style string generated by `DeckCardData._generate_instance_id()` (e.g., `"a1b2c3d4-e5f6-7890-abcd-ef1234567890"`)
- **Status effect types:** Accessed via `StatusEffectType` constants (e.g., `StatusEffectType.VULNERABLE`)
- **Effect types:** Accessed via `EffectType` constants (e.g., `EffectType.DAMAGE`)

---

## 🏗️ Scene Architecture

### Self-Contained Scenes
Each scene must be reusable and environment-agnostic:

```gdscript
# ❌ BAD — reaches up to parent
func _ready():
    get_parent().get_node("CombatController").turn_ended.connect(_on_turn_ended)

# ✅ GOOD — initialized by the parent
@export var combat_controller: CombatController

func initialize(controller: CombatController) -> void:
    combat_controller = controller
    combat_controller.turn_ended.connect(_on_turn_ended)
```

### Screen Hierarchy
```
Main (Node)
├── SceneRouter (Node)          # Handles scene transitions
├── ScreenManager (Node)        # Tracks active screen/UI state
└── CurrentScreen               # Swapped by SceneRouter (never change_scene_to_file!)
    ├── CombatScreen
    ├── MapScreen
    └── RewardsScreen
```

**NEVER** use `get_tree().change_scene_to_file()` — it destroys the Main node. Use `SceneRouter` instead.

### Scene Instantiation
```gdscript
# ✅ CORRECT — parent owns relationships, children are initialized after add_child
func _ready():
    var card_widget = card_widget_scene.instantiate()
    add_child(card_widget)
    card_widget.initialize(deck_card_data)  # After add_child
```

**NEVER** have children reach up with `get_parent()` or hardcoded paths like `get_node("../../CombatController")`.

---

## 💾 Data Architecture — The Core Pattern

### Resource Definitions vs Runtime Instances

This is the most important architectural pattern in the project:

```
CardData (extends Resource)         DeckCardData (extends RefCounted)
├── id: String                      ├── card_id: String → points to CardData.id
├── name: String                    ├── instance_id: String (UUID, unique per deck copy)
├── cost: int                       ├── applied_upgrades: Array[String]
├── card_type: CardData.CardType    ├── owner_character_id: String
├── base_effects: Array[EffectData] ├── is_transcended: bool
└── keywords: Array[String]         └── is_temporary: bool

Stored as .tres resource files      Stored in RunState.deck[instance_id]
Loaded once, cached by DataRegistry Piles store instance_ids only
Static — never mutated at runtime   Mutable — upgraded, transcended
```

**The lookup chain at card play time:**
```gdscript
# ✅ CORRECT card resolution pattern
var card_instance: DeckCardData = RunState.deck[instance_id]
var card_data: CardData = DataRegistry.get_card_data(card_instance.card_id)
var effective_cost: int = CardRules.get_effective_cost(card_data, card_instance)
```

### When to Use What

| Use Resource | Use RefCounted Instance | Use Node/Scene |
|---|---|---|
| `CardData` (card definition) | `DeckCardData` (card in deck with upgrades) | `CardUI` / `DeckCardWidget` (visual) |
| `EnemyData` (enemy blueprint) | `Enemy` (runtime enemy in combat) | Enemy scene with stats display |
| `UpgradeData` (upgrade definition) | Applied upgrades stored in `DeckCardData.applied_upgrades` | Upgrade selection UI |
| `CharacterData` (character definition) | Party tracked as IDs in `PartyManager` | `CharacterEntry`, `CharacterHUDBlock` |
| `RelicData` (relic definition) | Owned relics tracked in `RunState.relics` | Relic icon/display |

### Piles Store IDs, Not Objects
Draw pile, hand, and discard pile are `Array[String]` of `instance_id`s — not arrays of objects:

```gdscript
# ❌ BAD — storing objects in piles
hand.append(deck_card_data_object)

# ✅ GOOD — storing IDs, look up when needed
hand.append(deck_card_data.instance_id)
var card: DeckCardData = RunState.deck[instance_id]
```

---

## 🔧 Effect System

### Always Use EffectData + EffectType
Effects are generic containers with a type and a params dictionary. **Never hardcode damage or block numbers directly into card/ability logic.**

```gdscript
# ✅ CORRECT — define effects using EffectData
var effect = EffectData.new(EffectType.DAMAGE, {"amount": 6, "hit_count": 1})
card_data.base_effects.append(effect)

# ✅ CORRECT — apply block
var block_effect = EffectData.new(EffectType.BLOCK, {"amount": 5})

# ❌ BAD — hardcoding effect logic in the card script
func play():
    target.stats.current_hp -= 6
```

### EffectResolver is the Single Source of Truth
All effect resolution goes through `EffectResolver.resolve_effect()`. **Never resolve effects outside this system.** New effect types must be added here.

### Common EffectType Constants
```gdscript
EffectType.DAMAGE          # params: {amount, hit_count, ignore_block}
EffectType.BLOCK           # params: {amount}
EffectType.HEAL            # params: {amount}
EffectType.DRAW            # params: {amount}
EffectType.VULNERABLE      # params: {duration}
EffectType.STRENGTH        # params: {amount}
EffectType.DEXTERITY       # params: {amount}
EffectType.GRANT_HASTE_NEXT_CARD  # params: {}
EffectType.SUMMON_PET      # params: {pet_id}
```

---

## 📊 Status Effect System

### StatusEffectType Constants — Always Use These
```gdscript
StatusEffectType.STRENGTH                    # Stacking — adds to damage
StatusEffectType.DEXTERITY                   # Stacking — adds to block
StatusEffectType.VULNERABLE                  # Duration — 1.5x damage taken
StatusEffectType.WEAKNESS                    # Duration — 0.75x damage dealt
StatusEffectType.RETAIN_BLOCK_THIS_TURN      # Special — block doesn't reset
StatusEffectType.PENDING_STRENGTH_IF_NO_DAMAGE  # Conditional — checked at turn end
```

### Stacking vs Duration-Based
- **Stacking** (STRENGTH, DEXTERITY, FAITH): Values accumulate. `apply_status(type, 2)` adds 2 to existing.
- **Duration** (VULNERABLE, WEAKNESS): Replace/override. Decrease by 1 each turn. Removed at 0.
- **Pending** (PENDING_STRENGTH_IF_NO_DAMAGE): One-time check at end of turn. Consumed on check.

### Applying and Reading Status Effects
```gdscript
# ✅ CORRECT
entity_stats.apply_status(StatusEffectType.VULNERABLE, 2)
var vuln_stacks: int = entity_stats.get_status(StatusEffectType.VULNERABLE)

# ❌ BAD — accessing status_effects dict directly
entity_stats.status_effects["vulnerable"] += 1
```

---

## 📡 Signal Architecture

### Rule 1: Use Signals for All Event Communication
```gdscript
# ❌ BAD — direct call creates tight coupling
func take_damage(amount: int):
    hp -= amount
    get_parent().get_node("HUD").update_hp_display(hp)

# ✅ GOOD — emit and let listeners respond
signal hp_changed(new_hp: int, max_hp: int)

func take_damage(amount: int):
    hp -= amount
    hp_changed.emit(hp, max_hp)
```

### Rule 2: Signal Naming — Past Tense (Event Already Happened)
```gdscript
signal card_played(card_data: CardData)     # ✅
signal combat_ended(victory: bool)          # ✅
signal deck_changed()                       # ✅
signal relic_gained(relic_id: String)       # ✅

signal play_card   # ❌ sounds like a command
signal end_combat  # ❌ sounds like a method
```

### Rule 3: Connect Signals in Code, Not the Editor
```gdscript
# ✅ GOOD — traceable, refactor-safe
func _ready():
    RunState.deck_changed.connect(_on_deck_changed)
    RunState.hand_changed.connect(_on_hand_changed)
    combat_controller.turn_ended.connect(_on_turn_ended)
```

### Rule 4: QuestManager as Game Event Bus
For cross-system events (achievements, quests, analytics), use `QuestManager.emit_game_event()`:

```gdscript
# Emit a game event from anywhere
QuestManager.emit_game_event("CARD_PLAYED", {"card_id": card_data.id})
QuestManager.emit_game_event("RELIC_GAINED", {"relic_id": relic_id})

# Listen in QuestManager or other subscribers
```

**When to use what:**
- **Direct signals** (`RunState.deck_changed`, `EntityStats.hp_changed`): Parent↔Child, tightly related systems, UI updates
- **QuestManager events** (`emit_game_event(...)`): Quest tracking, achievements, loosely coupled cross-system events

### Rule 5: Cascade Signals Don't Re-Emit — Connect at Source
```gdscript
# ❌ BAD — signal bubbling
func _ready():
    deck_model.deck_changed.connect(_on_model_changed)

func _on_model_changed():
    deck_changed.emit()  # Just passing it along

# ✅ GOOD — RunState cascades via lambdas at init time (existing pattern)
func _ready():
    deck_model.deck_changed.connect(func(): deck_changed.emit())
```

---

## 🔌 Autoload Rules

### Approved Autoloads (Existing — Do Not Add Without Discussion)
| Autoload | Responsibility |
|---|---|
| `DataRegistry` | Load and cache all `.tres` resources (cards, characters, enemies, upgrades) |
| `RunState` | Core run state: deck, relics, pity counter, pending rewards |
| `ResourceManager` | Gold, HP, energy, block values for the current run |
| `PartyManager` | Party composition (exactly 3 character IDs) |
| `SaveManager` | Serialize/deserialize run state to `user://save_run.json` |
| `AutoSaveManager` | Force saves on critical state changes |
| `MapManager` | Map layout, node progress, current position |
| `QuestManager` | Quest tracking and game event bus |
| `SceneRouter` | Navigate between screens |
| `ScreenManager` | Track active screen and UI state |

### NEVER Use Autoloads For
- Individual combat state (belongs in `CombatController`)
- UI management (use proper scene hierarchy)
- Temporary per-combat data (use local variables in the combat scene)

### Autoload Access Pattern
```gdscript
# ✅ CORRECT — access autoloads by name
var card: DeckCardData = RunState.deck[instance_id]
var card_data: CardData = DataRegistry.get_card_data(card.card_id)
ResourceManager.gold -= cost
```

---

## 🧩 Pet / Hook System Pattern

Pets use a trigger-based hook system. This is the pattern to follow when building the full Relic hook system.

```gdscript
# PetDefinition blueprint (immutable)
PetDefinition.new(
    "clay_homunculus",          # pet_def_id
    "Clay Homunculus",          # display_name
    ["Construct"],              # tags
    6,                          # base_max_hp
    "SHARED_POOL",              # intercept_mode
    [
        {
            "hook": "ON_PET_DESTROYED",
            "action": "gain_block",
            "amount": 6
        }
    ]
)

# Available hooks
"START_OF_PLAYER_TURN"
"END_OF_PLAYER_TURN"
"WHEN_ENEMY_ACTS"
"ON_PET_DESTROYED"
```

When building the Relic hook system, mirror this exact pattern: immutable `RelicData` definition with a `triggers` array specifying `hook` + `action` + params.

---

## 📜 Script Structure

Always follow this order:

```gdscript
# 1. Tool annotation (if applicable)
@tool

# 2. Class name
class_name CombatController

# 3. Extends
extends Node

# 4. Docstring
## Manages turn flow, card playing, and enemy actions for a single combat encounter.

# 5. Signals
signal turn_ended
signal combat_started
signal combat_ended(victory: bool)

# 6. Enums
enum CombatPhase { PLAYER_TURN, ENEMY_TURN, RESOLVING }

# 7. Constants
const MAX_HAND_SIZE: int = 10
const BASE_ENERGY: int = 3

# 8. @export variables
@export var enemy_scene: PackedScene

# 9. Public variables
var player_stats: EntityStats
var enemies: Array[Enemy] = []
var current_energy: int = BASE_ENERGY

# 10. Private variables
var _current_phase: CombatPhase = CombatPhase.PLAYER_TURN

# 11. @onready variables
@onready var intent_system: IntentSystem = $IntentSystem
@onready var enemy_time_system: EnemyTimeSystem = $EnemyTimeSystem

# 12. Built-in virtual functions
func _ready() -> void:
    pass

# 13. Public functions
func start_combat(enemy_data_array: Array[EnemyData]) -> void:
    pass

func play_card(instance_id: String, target: Enemy) -> void:
    pass

# 14. Private functions
func _resolve_pending_next_turn_effects() -> void:
    pass

# 15. Signal callbacks
func _on_entity_stats_died() -> void:
    pass
```

---

## 🔒 Type Safety (STRICT)

**Always use type hints:**
```gdscript
# ✅ GOOD
var enemies: Array[Enemy] = []
var deck: Dictionary = {}    # [String → DeckCardData]
var current_hp: int = 0

func get_card_data(card_id: String) -> CardData:
    return generic_card_cache.get(card_id, null)

# ❌ BAD
var enemies = []
var deck = {}

func get_card_data(card_id):
    return generic_card_cache.get(card_id)
```

**Always check for null:**
```gdscript
# ✅ GOOD
func play_card(instance_id: String) -> void:
    var card_instance: DeckCardData = RunState.deck.get(instance_id, null)
    if not card_instance:
        push_warning("play_card: instance_id '%s' not found in deck" % instance_id)
        return
    var card_data: CardData = DataRegistry.get_card_data(card_instance.card_id)
    if not card_data:
        push_error("play_card: no CardData found for card_id '%s'" % card_instance.card_id)
        return
```

---

## 🔍 Code Review Checklist

### Data Checks
- [ ] Is new card/enemy/character/upgrade data a `.tres` resource or defined in `DataRegistry`?
- [ ] Is there a separate `Data` class (immutable) and instance class (mutable) where needed?
- [ ] Are piles (draw, hand, discard) storing `instance_id` strings, not objects?
- [ ] Does any new card data use `EffectData` + `EffectType` constants?

### Scene/Node Checks
- [ ] Did AI use a scene with nodes, or just pure scripts?
- [ ] Are node properties configured in Inspector, not hardcoded in script?
- [ ] Is the scene self-contained with no `get_parent()` or hardcoded node paths?
- [ ] Are `@onready` vars used for child node references?

### Signal Checks
- [ ] Are signals past-tense named?
- [ ] Are signals connected in `_ready()`, not in the editor?
- [ ] Is `QuestManager.emit_game_event()` used for cross-system events?
- [ ] Is a new autoload actually necessary, or can a direct signal/reference work?

### Style Checks
- [ ] All variables type-hinted?
- [ ] Private members have `_` prefix?
- [ ] Script follows the 15-section ordering above?
- [ ] No script over ~300 lines? (Split into components if so)
- [ ] Null checks on all potentially null values?

---

## 🚫 AI Assistant Red Flags

If you see these in AI-generated code, stop and reconsider:

| Red Flag | Better Alternative |
|---|---|
| `get_parent()` or `get_node("../../...")` | `@export` var or `initialize()` injection |
| `get_tree().change_scene_to_file()` | `SceneRouter` |
| `ColorRect.new()` or manual UI construction | Create a `.tscn` scene in the editor |
| `load()` called in `_process()` or loops | Pre-load or cache in `DataRegistry` |
| Script over 300 lines | Split into components |
| New autoload for a non-global concern | Pass as reference or use direct signals |
| Hardcoded damage/block numbers in scripts | `EffectData` + `EffectType` |
| Accessing `status_effects` dict directly | `EntityStats.apply_status()` / `get_status()` |
| Storing `DeckCardData` objects in piles | Store `instance_id` strings only |
| Character-specific logic outside `EffectResolver` | Add a new case to `EffectResolver` |

---

## 📝 Prompting Guidelines for AI

### When Adding a New Card
> "I need a new card called [Name]. Create a new `.tres` resource using `CardData`. The card should cost [X] energy, be [type], and have [effects]. Use `EffectData` with the appropriate `EffectType` constants for all effects. Add it to `DataRegistry` in the appropriate character reward pool."

### When Adding a New Status Effect
> "I need a new status effect called [Name]. Add the constant to `StatusEffectType`. Determine if it is stacking, duration-based, or pending. Add resolution logic to `EntityStats.apply_status()`, `get_status()`, and cleanup in `_process_turn_end_status_effects()`. Add display logic to `StatusEffectIndicator`."

### When Adding a New Card Effect Type
> "I need a new effect called [Name]. Add the constant to `EffectType`. Add a new `match` case to `EffectResolver.resolve_effect()` with a `params` dict defining its inputs. Do NOT add resolution logic anywhere else."

### When Adding UI
> "I'll create the [screen name] scene with Control nodes in the Godot editor. I need a script that: (1) has `@export` vars for [nodes], (2) has public `initialize()` taking [data], (3) emits signals when [events], (4) listens to [RunState/ResourceManager signals] to update display. Do NOT instantiate UI nodes in code."

### When Debugging
> "I'm getting [error] in [file] at line [N]. The scene structure is [describe tree]. I'm trying to [describe intent]. Don't just add null checks — help me understand why [thing] is null/wrong."
