# Friends demo candidate status

Candidate: `builds/friends-candidate-03/Path-of-Embers-friends-candidate-03.zip`. Extract the ZIP and launch the executable inside `Path of Embers`. Build artifacts and temporary profiles are ignored by Git; source, tests, and compact evidence are retained. This is a candidate for acceptance testing, not a full-run release sign-off.

## Implemented

- A first-fight, modal How to Play guide, remembered separately from run saves and reopenable from combat. It explains the clock, shared resources, targeting, Breathe, Focus, abilities, persistent block, overflow, and the quest gate. Closing it does not spend time.
- Corrected Breathe's stale energy-cap tooltip. Combat cards expose complete live rules in an 18px wrapped tooltip. Locked roster cards show milestone hints; characters without implemented unlocks say they are unavailable in the demo.
- Compact enemy artwork at small heights preserves intent text and targeting area while clearing the hand and navigation. Layout checks pass at 1280x720, 1600x900, and 1920x1080. Rendered 1280 combat, introduction, and party selection were inspected. Full setup/reward dialog and actual pointer interaction acceptance at that resolution remains open.
- Windows release preset and reproducible builder. The first export exposed a real blocker: directory scanning ignored exported `.tres.remap` resources, leaving every registry empty. DataRegistry now loads the original path through ResourceLoader. Exported registry counts match the editor.
- Player README plus exact engine notices and bundled font licenses. Package excludes assessment, tests, development plugins, local settings, scripts, and build artifacts; the export log checks those exclusions. The ZIP is extracted separately and executable/PCK/README hashes compared.

## Verification

Godot 4.5.1: all original 342 assertions pass after the production changes, plus 8 new guide assertions pass (350 combined). Tests cover modal state, Space/F suppression while reading, preference persistence, reopening, no ticks spent on dismissal, resumed input, and nonempty full-card rules. Layout probes pass at all three sizes. The final package's clean-profile startup loads 31 cards, 9 enemies, 12 characters, 18 upgrades, 20 equipment, 3 milestones, 5 encounters, and 6 abilities. Passing `--debug-mode` to the release cannot enable developer mode.

The extracted startup log still sometimes reports the known shutdown-only ObjectDB/resource leak. The builder permits only that exact shutdown resource-error line; all other runtime errors fail the startup check. No script errors were observed in the new ordinary flow diagnostics. These are not claims that every gameplay interaction is certified.

Three new ordinary-policy attempts died in Act II at rows 0, 6, and 1. They entered that act at 18, 58, and 53 HP out of 81. The diagnostic now records per-fight HP, action counts, deck size, gold, and upgrade points. It skips shops, chooses the first card reward, and is not an adequate human balance proxy. No balance edits were made, including to Witch. Evidence is in `assessment/2026-09-10/demo-candidate/ordinary-diagnostic.json`.

## Reproduction

`tests/verify_release.ps1 -Godot <Godot-4.5.1-console.exe>` now includes the 8 guide assertions. Use `tests/combat_layout.tscn` with `-- --small`, no size flag, or `-- --large` for the three sizes; add `--guide` to show the introduction. Tests must use disposable APPDATA/LOCALAPPDATA profiles.

`tests/build_windows_demo.ps1 -Godot <Godot-4.5.1-console.exe> -TemplateDirectory <4.5.1.stable-template-directory> -BuildId <new-name>` exports, generates notices, zips, extracts, hashes, and checks clean-profile startup. Templates are copied into a private build profile; player settings are untouched. The script requires access to the normal Windows certificate store. Source templates were obtained from the official Godot 4.5.1 archive. Each candidate retains logs and a SHA256 record.

## Remaining go/no-go gate

Two legitimate three-act victories with different party compositions in the extracted release remain unverified. So do extracted-build defeat/restart, quit/resume at all specified boundaries, repeated-run equipment checks, and actual drag/hotkey/dialog interaction. The earlier integration tests remain useful but do not replace these packaged-game checks. Minimum-resolution combat and party-selection inspection does not certify every screen. The original assessment's release gate remains in force.

Next priority: play the extracted candidate from a fresh profile, exercise the intended reward/equipment/shop choices, and record the first point of confusion or failure. Use that evidence to address bugs and make any difficulty decision. Keep the approved temporary unlocks and boss upgrade substitution; freeze new mechanics/content for the deadline.
