# Friends demo release plan — September 11 target

Basis: assessment/2026-09-10/ASSESSMENT.md and docs/ENGINEERING_HANDOFF.md. Stabilization baseline: 9fd475b. Target is a Windows download friends can extract, understand, and use for several complete runs. The original assessment's no-go judgment predates the fixes; distribution still requires the remaining evidence below.

## Scope and decisions

Freeze new mechanics, characters, broad art work, equipment expansion, and broad balance tuning. Retain the approved starting three and temporary unlock milestones, and the approved normal upgrade substitution for missing transcendence content. Do not change Witch balance without authorization. Preserve real player saves; verification uses isolated profiles. Do not distribute assessment data, development tools, tests, or local settings.

## Execution order

1. Essential onboarding and truthful rules. Inspect current input and combat code, then add a short dismissible first-fight explanation with a way to reopen it. Cover shared HP/deck, card targeting, clock advancement, Breathe/Space, Focus/F, ability costs, persistent block, and hand overflow. Correct stale tooltips, especially the energy-cap claim. Explain quest requirements before commitment and show unlock requirements. Include a short player README with controls, saves/resume behavior, temporary content, and feedback prompts. Verify explanation dismissal cannot advance combat or leave input blocked.

2. Minimum display and input. Inspect actual rendered combat at 1280x720, 1600x900, and 1920x1080. Certify readable card text/hover, enemy intentions, party abilities, reward/upgrade dialogs, and window resizing. Exercise actual dragging and hotkeys. Existing 1600/1920 layout checks are a starting point, not a replacement for the missing small-display and input checks.

3. Build a candidate early. Check Godot 4.5.1 Windows export templates; create a release preset with explicit development-artifact exclusions and developer controls disabled. Export a versioned executable/package, zip it with the player README, extract to a separate directory, and launch using a fresh isolated profile. Inspect the exported resource set and logs. Verify dynamic registry-loaded content is included. Use the actual extracted build for subsequent release checks.

4. Full-run viability. Investigate why the post-fix ordinary policy died at the start of Act II: distinguish policy limitations, missed upgrades/equipment, quest feasibility, attrition, and actual defects. Run two legitimate complete runs with different party compositions, earning unlocks normally from a fresh profile. Record party, route, rewards, quests, deaths, and elapsed time. Forced kills, synthetic quest completion, and isolated combat win rates cannot satisfy this gate. Address concrete defects first; escalate design choices supported by play evidence rather than silently changing balance or the quest gate.

5. Extracted-build regression. Deliberately die and restart; start another run after victory; verify equipment does not accumulate HP. Quit/relaunch on the map, during an ordinary fight, each act boss and final boss, and after partially claiming rewards. Confirm checkpoint restoration, no duplicate rewards, unlock persistence, final-boss access, and clean transitions. Check developer keys are unavailable in the release build. Re-run targeted tests for changes, then the release harness once the candidate is final.

## Go/no-go evidence

- Exported, zipped, extracted Windows candidate launches and loads all required resources with developer controls disabled.
- First-time controls/rules are accurate and discoverable; essential information and dialogs remain usable at 1280x720 and larger tested sizes.
- Two legitimate three-act victories with different parties in the extracted build, plus defeat/restart and save/resume checks above.
- No unresolved progression blocker, script error affecting play, or repeat-run state corruption. Investigate cleanup leaks if they grow during play or affect the packaged process; baseline harness shutdown leaks alone do not establish a release blocker.
- Final version, test evidence, known limitations, and player README accompany the candidate.

If the deadline arrives before the gate passes, report the missing checks explicitly. Do not label a forced progression run or an editor-only test as release certification. A narrower combat preview would be a scope decision for Aaron, not an automatic substitute for the requested full-run demo.

## Current evidence gaps

Update: see `DEMO_CANDIDATE_STATUS.md` for completed onboarding, the Windows candidate, compact layout checks, and fresh diagnostics. The paragraph below records the starting baseline.

No Windows export exists. No legitimate three-act victory is certified. The three post-fix automated ordinary attempts died in Act II rows 0–2; that is a diagnostic lead, not proof of excessive difficulty. Controlled three-act progression passed. The stabilization suites passed 342 assertions. Minimum-resolution usability, introductory rules, packaged input behavior, and exported-build regressions remain to be completed.
