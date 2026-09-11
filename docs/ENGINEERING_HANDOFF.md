# Engineering handoff — September 10, 2026

## Repository migration

- Restore point: `4896276`, committed and pushed to `origin/card-clock` before migration. The branch now tracks its remote.
- Removed the stale September 8 Git index lock after confirming no Git processes were running. Removed the obsolete local hooks override.
- Flattened resource references; normalized art/audio names using an exact rename map. Fonts kept their original names.
- Preserved both colliding Eternal Ember images: the formerly spaced filename is now `art/boss_sprites/the_eternal_ember_alternate.png`; the existing shipping image retains `the_eternal_ember.png`.
- Moved surviving documents here; removed the authorized source-art duplicates, exports, archives and scripts. Preserved the prior briefing as `handoff-prompt.md` (historical instructions, not current work).
- Preserved import UIDs, removed the generated cache last, and re-imported using Godot 4.5.1. Historical assessment paths were updated; their runtime findings are still the original findings.

## Migration verification

Godot `4.5.1.stable.official.f62fdbde1`: headless editor load clean.
Seven suites passed at the required counts: card_clock 94, signature_cards 49, card_preview 38, hex_playability 19, party_hud_stats 10, card_art 38, backpack 23 (271 total).
The 30-fight timed simulator accepted the explicit party/enemy arguments after the mandatory bare `--`; 30/30 wins, mean damage 24.8. It reports an ObjectDB/resource cleanup leak at exit, so exit code alone is not the full result.
Tests ran with a disposable APPDATA profile outside the repository.

No Witch balance changes are authorized. Equipment/stat persistence must be corrected before interpreting full-run balance data.

## Approved progression decision

Aaron chose to retain Monster Hunter, Witch and Living Armor as the starting roster. Temporary unlock milestones: Shadowfoot after 3 combat wins, Grove after 1 elite win, Golemancer after the Act I boss. **Design TODO: replace these with more interesting milestones later.** Counts accumulate across runs and partial progress persists across app restarts. Aaron authorized publishing all verified handoff work to the existing GitHub branch.

## Temporary boss reward decision

Aaron approved a normal upgrade in place of transcendence while the transcendent-card registry is empty. Existing 12 points, gold and card choices are retained. Saved unresolved transcendence bundles receive the same fallback. **Content TODO: add actual transcendence content and revisit the temporary reward.** The unused transformation path remains covered with a test-only card definition.

## Combat resume contract

Unfinished combat restarts from a pre-fight checkpoint, restoring HP, deck, quest progress, rewards and equipment. Encounter composition is retained; opening hand and random rolls can differ. This avoids pretending to serialize live combat state. Old saves without a checkpoint restart the selected fight from their saved HP; health lost before that old save cannot be recovered. The old HP accumulation is normalized against the party base on the next combat start.

## Stabilization changes

- Gold uses ResourceManager. Gold, card picks/skips, equipment, upgrade points, healing and upgrades persist consumed reward state immediately. Boss act-transition overlays retain the resolved bundle until the next act is committed.
- Curse Weaver counts explicit hand discards from card/ability costs and discard effects. Playing a card, milling, overflow and exhausting do not count. Exact-hand ability costs are supported. Completing quests updates the final-boss gate immediately.
- Typed upgrade option arrays cover small and exhausted pools. The transcendence ID query is also typed. Finished or unavailable upgrade flows update and save Continue state.
- Unfinished nodes expose only themselves. Encounter choices now mark their nodes complete; previously, the looser map gate hid that omission. Completion cannot emit duplicate node events.
- Equipment contributes HP once, survives save/load, and preserves attrition between fights. Maximum-only HP updates now work.
- PartyHUD initializes blocks after adding them to the tree. Combat intent uses a container that sizes to its contents. Eight-card hands use positive spacing and adapt width at 1600×900 and 1920×1080, preventing adjacent cards from covering rules text. The Block tooltip matches the existing persistent-Block rule.
- Corrected stale script UIDs in the combat/map scenes and obsolete party/deck accesses in the defeat screen.

## Reproducing verification

Run `tests/verify_release.ps1 -Godot <path-to-Godot-4.5.1-console.exe>`. It creates a disposable profile, validates the editor log and exact assertion counts, and runs the specified 30-fight simulator. Logs and the profile are retained in the output directory; it does not touch the player's normal saves.

The added `release_blockers` scene has 71 integration assertions. `combat_layout` checks hand bounds, card separation, owner-label bounds and enemy/hand separation; `--large` selects 1920×1080. `--capture=<absolute.png>` captures the actual rendering display when run without `--headless`.

`run_flow_regression` drives actual screens and records three seeded run attempts in `user://run-flow-regression.json`. The optional `--flow-only` argument deliberately defeats enemies and completes quests to isolate three-act progression; **it is not a balance test or an ordinary-play victory**. Three controlled attempts reached victory through all acts. The final three ordinary-policy attempts reached Act II and died at rows 0, 1 and 2, with no script errors. The final baseline suites passed all 271 assertions and the integration suite passed all 71 (342 total). Verification logs, flow summaries, simulator output and a 1600×900 screenshot are under `assessment/2026-09-10/stabilization/`.

## Remaining release work

- Windows candidate packaging is now implemented; see the demo candidate report below for its narrower verification status.
- No ordinary-play three-act victory has been certified. The controlled progression pass does not establish game balance or difficulty.
- Existing ObjectDB/resource cleanup leaks remain in several headless harnesses (also present before stabilization).
- Witch balance remains unchanged. Do not use old full-run measurements with accumulated equipment HP as a release balance sign-off.
- Shop/backpack policy, equipment affixes/rarities, expanded card/enemy/boss content, and the art queue remain outside this stabilization pass.

## Friends demo candidate follow-up

See `DEMO_CANDIDATE_STATUS.md` for the new introduction, card tooltips, compact combat layout, release-only resource loader fix, reproducible Windows packaging, and outstanding acceptance gates. This supersedes the earlier lack of an export; it does not certify full-run readiness.

## Version 0.1.1 follow-up

See [COMBAT_POLISH_0_1_1.md](COMBAT_POLISH_0_1_1.md) for the approved equipment reset, cycle removal, CZN-inspired combat layout, animations, starting-party cutouts, 362 passing assertions, rendered checks, and new Windows ZIP. This supersedes the earlier equipment carryover and non-overlapping hand descriptions. Full-run balance acceptance remains open.

## Current candidate: 0.1.2

[COMBAT_POLISH_0_1_2.md](COMBAT_POLISH_0_1_2.md) supersedes the 0.1.1 presentation: cooler staging backgrounds, shared actor baseline, compact fanned hand with raised readable cards, upper-right help, and current art-direction authority.
