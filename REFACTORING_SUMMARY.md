# Data Structure & Scalability Refactoring Summary

This document summarizes the refactoring work completed to improve data structures, type safety, and scalability.

## Completed Phases

### Phase 1: Resource Loading Infrastructure ✅
- **Added ResourceLoader functionality** in `DataRegistry.gd`
- **Created directory structure constants** for data files:
  - `DATA_DIR_CARDS = "res://Path-of-Embers/data/cards/"`
  - `DATA_DIR_CHARACTERS = "res://Path-of-Embers/data/characters/"`
  - `DATA_DIR_ENEMIES = "res://Path-of-Embers/data/enemies/"`
  - `DATA_DIR_UPGRADES = "res://Path-of-Embers/data/upgrades/"`
- **Implemented `_load_resources_from_directory()`** method to load .tres files
- **Maintains backward compatibility** - falls back to hardcoded initialization if no resource files exist

**Next Steps for Phase 1:**
- Create the data directory folders in the Godot editor
- Convert hardcoded data (upgrades, enemies, cards) to .tres resource files
- Place resource files in appropriate directories

### Phase 2: Type-Safe Effect System ✅
- **Created `EffectType` class** (`Path-of-Embers/data/EffectType.gd`) with constants for all effect types
- **Updated `EffectData`** to include validation
- **Refactored `EffectResolver`** to use `EffectType` constants instead of string literals
- **Updated all EffectData creation** throughout codebase to use `EffectType` constants:
  - `DataRegistry.gd`
  - `CombatController.gd`
  - `CardRules.gd`
  - `CardWidget.gd`
  - `CharacterSelect.gd`
  - `Enemy.gd`

**Benefits:**
- Compile-time checking (IDE autocomplete)
- Reduced typos
- Easier to extend effect system

### Phase 3: Type-Safe Status Effect System ✅
- **Created `StatusEffectType` class** (`Path-of-Embers/data/StatusEffectType.gd`) with constants
- **Created `StatusEffect` data class** (`Path-of-Embers/data/StatusEffect.gd`)
- **Refactored `EntityStats`** to use `StatusEffectType` constants
- **Updated all status effect access** throughout codebase:
  - `EntityStats.gd`
  - `CombatController.gd`
  - `EffectResolver.gd`

**Benefits:**
- Type safety for status effects
- Clearer API with helper methods (`is_stacking()`, `is_pending()`)
- Easier to extend status system

### Phase 4: Split RunState into Focused Managers ✅
- **Created `PartyManager`** - manages party composition
- **Created `ResourceManager`** - manages gold, HP, energy, block
- **Created `QuestManager`** - manages quest state and progression
- **Created `MapManager`** - manages map state and progression
- **Updated `RunState`** to delegate to managers while maintaining backward compatibility
- **Added managers to autoload** in `project.godot`
- **Updated `SaveManager`** to sync with managers during save/load
- **Updated signal connections** to keep RunState properties in sync with managers

**Benefits:**
- Single Responsibility Principle - each manager handles one concern
- Easier to test individual systems
- Clearer dependencies
- Backward compatible - existing code using RunState continues to work

## Architecture Changes

### Manager Structure
```
PartyManager       → Manages party_ids, party data
ResourceManager    → Manages gold, HP, energy, block
QuestManager       → Manages quests, quest evaluation
MapManager         → Manages map, nodes, progression
RunState           → Delegates to managers (backward compatibility layer)
```

### Data Flow
- **Write operations**: Code calls `RunState.set_*()` → delegates to manager → manager updates → signals sync back to RunState
- **Read operations**: Code reads from RunState properties (synced from managers)
- **New code**: Can access managers directly for better separation of concerns

## Files Modified

### New Files Created
- `Path-of-Embers/data/EffectType.gd`
- `Path-of-Embers/data/StatusEffectType.gd`
- `Path-of-Embers/data/StatusEffect.gd`
- `Path-of-Embers/autoload/PartyManager.gd`
- `Path-of-Embers/autoload/ResourceManager.gd`
- `Path-of-Embers/autoload/QuestManager.gd`
- `Path-of-Embers/autoload/MapManager.gd`

### Major Files Refactored
- `Path-of-Embers/autoload/DataRegistry.gd` - Added ResourceLoader, updated to use EffectType
- `Path-of-Embers/autoload/RunState.gd` - Delegates to managers, maintains compatibility
- `Path-of-Embers/core/combat/EffectResolver.gd` - Uses EffectType constants
- `Path-of-Embers/core/combat/EntityStats.gd` - Uses StatusEffectType constants
- `Path-of-Embers/autoload/SaveManager.gd` - Syncs with managers on save/load
- All files creating/accessing EffectData or status effects

## Backward Compatibility

All changes maintain **full backward compatibility**:
- Existing code using `RunState.property` continues to work
- Existing code using `RunState.set_*()` methods delegates to managers
- Signal connections keep RunState properties synced with managers
- Hardcoded data initialization still works if resource files don't exist

## Next Steps (Future Work)

### Phase 5: Refactor DataRegistry (Optional)
- Split DataRegistry into DataLoader + separate caches
- Or reorganize internal structure for clarity

### Phase 6: Dependency Injection (Optional, Low Priority)
- Create interfaces/base classes for data access
- Inject dependencies instead of global access
- Improves testability

### Migration Guide for New Code
1. **For resources**: Use `ResourceManager` directly instead of `RunState.gold`, `RunState.current_hp`, etc.
2. **For party**: Use `PartyManager` directly instead of `RunState.party_ids`
3. **For quests**: Use `QuestManager` directly instead of `RunState.quests`
4. **For map**: Use `MapManager` directly instead of `RunState.current_map`, etc.
5. **For effects**: Always use `EffectType` constants when creating EffectData
6. **For status effects**: Always use `StatusEffectType` constants when accessing status effects

## Testing Recommendations

1. **Test backward compatibility**: Ensure existing save files load correctly
2. **Test managers**: Verify managers work independently
3. **Test delegation**: Ensure RunState methods properly delegate to managers
4. **Test signals**: Verify all signals fire correctly when managers update
5. **Test save/load**: Ensure SaveManager correctly syncs with managers

## Notes

- Resource files (.tres) can be created in Godot editor and placed in data directories
- Managers are initialized before RunState (autoload order)
- RunState syncs properties from managers on `_ready()` and via signal connections
- All string-based type systems have been migrated to type-safe constants

