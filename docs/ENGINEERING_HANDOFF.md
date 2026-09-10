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

No Witch balance changes are authorized. Equipment/stat persistence must be corrected before interpreting full-run balance data. Party availability is a developer decision pending confirmation.
