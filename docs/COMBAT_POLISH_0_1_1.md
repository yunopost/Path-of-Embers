# Friends demo 0.1.1 — 11 September 2026

User-approved follow-up to the September 10 assessment and demo candidate. This is a playable-test candidate; ordinary three-act victory and balance acceptance remain open.

## Delivered

- Start-menu version in the upper right. Project version also supplies Windows executable metadata.
- New Run starts with Iron Helm, Chain Mail and Swift Boots, empty equipped slots and an empty backpack. Continue restores that run's saved equipment. Returning to loadout does not re-import legacy equipment. Debug equipment grants affect the current run. Win/loss no longer exports equipment to the old collection.
- Existing meta data is backed up once to `meta-before-equipment-reset.json` before recording the new equipment policy. Milestones and other progress remain intact. Legacy stash read/write helpers remain for compatibility and archive tooling, but gameplay does not import their collection.
- Removed Breathe/Focus cycle boundaries and unused turn-boundary pet hooks. Each resource action advances one tick. Fade Step resolves immediately before the next enemy action against the damage-since-last-action window. Reinforced Frame remains armed until a pet survives damage during an enemy action. Historical serialized field names remain compatible.
- Left-side Breathe, Focus, rules and character abilities; draw on the left and discard on the right. A centered overlapping hand exposes larger cards on hover, with right-click pinning and Escape dismissal. Reused hand controls prevent every hand change from replaying every card's entrance.
- Cards enter from the draw pile; successful plays lift and leave toward discard, with an exhaust fade. Rejected plays return to hand. Targeting uses a curved ember-colored arrow with a wider glow. Successful targeted plays flash the target; HP loss/healing and block gains have floating feedback.
- Compact party portraits, larger battlefield sprites, overhead enemy readouts, corrected node label and release debug text suppression. Full-body art is supplied for the three starting characters; other characters retain the existing portrait fallback.

## Reference research

The user's Chaos Zero Nightmare screenshot informed the separate action rail, central hand, opposing pile positions, and enemy information above the battlefield. [Prydwen's combat guide](https://www.prydwen.gg/chaos-zero-nightmare/guides/combat-explained) describes CZN's shared HP, party cards, AP/turn structure and enemy action counters. [GameVika's UI guide](https://gamevika.com/en/czn/combat-guide) provides supplementary UI context. These are secondary guides, not an authoritative specification for Path of Embers. PoE retains its own action clock, persistent energy and block, with no end-turn button or imported AP reset.

Godot's [Windows export documentation](https://docs.godotengine.org/en/4.5/classes/class_editorexportplatformwindows.html) documents the project-version fallback when executable version overrides are empty.

## Art provenance

New assets: `art/battle/monster_hunter_battle.png`, `witch_battle.png`, and `living_armor_battle.png`. Generated through the built-in image-generation tool using each existing character portrait as reference. Brief: full-body, right-facing dark-fantasy battle pose; retain the character identity, costume, weapons and palette; isolated transparent background. The generator returned opaque backgrounds, including checkerboard patterns. After explicit user approval, local rembg/u2net removal produced RGBA cutouts; a residual checkerboard opening in the armor sprite was cleaned locally. The original portraits were retained. Generator outputs remain in the Codex generated-images directory; local removal dependencies and intermediate files remain outside the repository.

## Verification

Godot 4.5.1: **362 assertions passed**, including 12 new equipment-reset/migration/Continue and action-clock checks. The 30-fight simulator completed without script errors; it is a diagnostic, not full-run balance certification. Exact logs are under `assessment/2026-09-11/release-0_1_1/`.

Rendered layout probes pass at 1280×720, 1600×900 and 1920×1080. They check eight-card bounds/exposure, owner labels, enemy separation, stable card identities, enlarged preview bounds, pinning, rejected-drag recovery, successful card consumption and animation cleanup. The start-menu probe confirms the visible version text and upper-right bounds. Captures and logs are under `assessment/2026-09-11/polish/`. Card interactions are driven through the actual CardUI drag handlers; these checks are not a complete human mouse/controller playthrough.

ZIP: `builds/friends-v0_1_1/Path-of-Embers-friends-v0_1_1.zip`. The builder verifies exclusions, extraction hashes, fresh-profile startup, registry counts and the release debug-mode guard. Tests use disposable save profiles and do not touch the player's normal saves.

## Remaining acceptance

A friend should play a normal run without coaching. Full three-act victory, economy and Witch balance remain uncertified. Existing shutdown ObjectDB/resource cleanup warnings remain. Some unlock-character and card art/content is unfinished; the roster still excludes unfinished characters. The approved temporary unlock milestones and boss normal-upgrade substitution remain unchanged.
