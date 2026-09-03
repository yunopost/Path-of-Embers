# Instance ID Refactor Summary

## Overview
Refactored deck system to use stable `instance_id` strings instead of array indices for card identity. This enables safe card removal and transformation without breaking references.

## Modified Files

1. **Path-of-Embers/data/DeckCardData.gd**
   - Already had `instance_id` field with UUID generation
   - Serialization includes `instance_id`

2. **Path-of-Embers/core/deck/DeckModel.gd**
   - Already refactored: piles use `Array[String]` (instance_ids)
   - Added `get_card(instance_id)` helper
   - `initialize()` takes `Array[String]` instance_ids
   - `add_card_instance(instance_id)` method
   - `remove_instance_from_piles(instance_id)` method

3. **Path-of-Embers/autoload/RunState.gd**
   - `deck: Dictionary` keyed by `instance_id`
   - `deck_order: Array[String]` for stable ordering
   - Legacy piles (`draw_pile`, `hand`, `discard_pile`) are `Array[String]` instance_ids
   - `_initialize_deck_piles()` uses `deck_order` to initialize model
   - `_sync_deck_arrays_from_model()` syncs instance_id arrays
   - `can_upgrade_instance(instance_id)` - new method
   - `apply_upgrade_to_instance(instance_id, upgrade_id)` - new method
   - `remove_card_instance(instance_id)` - already implemented
   - `transform_card_instance(instance_id, new_card_id)` - already implemented
   - Legacy methods (`can_upgrade_card_at`, `apply_upgrade_to_card_at`) remain for backward compatibility

4. **Path-of-Embers/scenes/ui/rewards/UpgradeFlowPanel.gd**
   - Uses `selected_instance_id: String` instead of `selected_card_index: int`
   - Iterates `RunState.deck_order` instead of `RunState.deck`
   - Binds `instance_id` when connecting card_clicked signal
   - Looks up cards via `RunState.deck.get(instance_id)`

5. **Path-of-Embers/scenes/ui/DeckViewPopup.gd**
   - Iterates `RunState.deck_order` instead of `RunState.deck`
   - Looks up cards via `RunState.deck.get(instance_id)`

6. **Path-of-Embers/scenes/ui/cards/DeckCardWidget.gd**
   - Uses `card_instance.instance_id` for upgrade checks via `can_upgrade_instance()`

7. **Path-of-Embers/scenes/screens/CombatScreen.gd**
   - Iterates `RunState.hand` (instance_ids) and looks up cards via `RunState.deck.get(instance_id)`

8. **Path-of-Embers/Scripts/Rewards/RewardsScreen.gd**
   - Uses `upgrade_flow_panel.selected_instance_id` instead of `selected_card_index`
   - Calls `apply_upgrade_to_instance()` instead of `apply_upgrade_to_card_at()`

9. **Path-of-Embers/autoload/SaveManager.gd**
   - Serializes deck as Dictionary keyed by `instance_id`
   - Serializes `deck_order` array separately
   - Supports loading both new (Dictionary) and legacy (Array) formats
   - Saves `pending_rewards` (new in version 4)

## New Identity Rules

1. **Every card instance has a unique `instance_id: String`**
   - Generated via UUID-style random string in `DeckCardData._init()`
   - Preserved across save/load
   - Never changes for a given card instance

2. **RunState.deck is a Dictionary keyed by instance_id**
   - `deck[instance_id]` returns the `DeckCardData` object
   - This is the authoritative registry

3. **RunState.deck_order maintains stable ordering**
   - Used for UI display (deck view, upgrade selection)
   - Preserves order cards were added
   - Used to iterate deck in consistent order

4. **All piles store instance_ids, not objects or indices**
   - `DeckModel.draw_pile: Array[String]`
   - `DeckModel.hand: Array[String]`
   - `DeckModel.discard_pile: Array[String]`
   - Legacy `RunState.draw_pile/hand/discard_pile` also use instance_ids

5. **Card lookup: always go through RunState.deck registry**
   - Never store `DeckCardData` objects in piles
   - Always look up: `RunState.deck.get(instance_id)`

## Verification Checklist

### ✅ Two identical card_ids remain distinct
- Each `DeckCardData` instance gets unique `instance_id` on creation
- `DeckCardData._generate_instance_id()` uses random UUID pattern
- Two cards with same `card_id` will have different `instance_id` values

### ✅ Upgrading one copy only upgrades that copy
- `apply_upgrade_to_instance(instance_id, upgrade_id)` mutates only `deck[instance_id]`
- No pile syncing needed - piles reference the same object via instance_id
- Each card instance maintains its own `applied_upgrades` array

### ✅ Removing a card removes it from all piles safely
- `remove_card_instance(instance_id)`:
  - Removes from `deck` registry
  - Removes from `deck_order`
  - Calls `deck_model.remove_instance_from_piles()` which erases from all pile arrays
  - Emits appropriate signals

### ✅ Transforming a card changes only that instance
- `transform_card_instance(instance_id, new_card_id)`:
  - Mutates `deck[instance_id].card_id`
  - Clears upgrades (MVP decision)
  - `instance_id` remains unchanged
  - Persists through save/load because `instance_id` is preserved

### ✅ Save/Load preserves instance_id
- `DeckCardData.to_dict()` includes `"instance_id"`
- `DeckCardData.from_dict()` restores `instance_id` exactly
- Save format: Dictionary keyed by `instance_id`
- Load handles both new (Dictionary) and legacy (Array) formats

## Migration Notes

### Legacy Code Compatibility
- Old methods (`can_upgrade_card_at`, `apply_upgrade_to_card_at`, `get_upgradeable_deck_indices`) still exist
- They convert index to instance_id internally and call new methods
- UI code still uses `deck_index` for display ordering, but operations use `instance_id`

### Signal Handling
- `DeckCardWidget.card_clicked` still emits `deck_index` for display purposes
- Upgrade flow binds `instance_id` when connecting, which becomes the handler parameter
- This works but could be cleaner - signal could be updated to emit `instance_id` in future

## Future Improvements

1. **Update DeckCardWidget signal** - Change `card_clicked` to emit `instance_id` instead of `deck_index`
2. **Remove legacy methods** - Once all code is migrated, remove deprecated index-based methods
3. **Remove legacy piles** - Consider removing `RunState.draw_pile/hand/discard_pile` arrays entirely, use `DeckModel` only

## Testing Recommendations

1. Create deck with duplicate `card_id` values - verify different `instance_id` values
2. Upgrade one copy of a duplicate card - verify other copy unchanged
3. Remove a card from deck - verify removed from all piles and deck registry
4. Transform a card - verify only that instance changes, `instance_id` preserved
5. Save/load with upgraded cards - verify upgrades and `instance_id` preserved
6. Test with cards in hand when transforming - verify hand updates correctly

