# Path of Embers — friends demo assessment

September 10, 2026. Assessed the existing working copy in Godot 4.5.1 on Windows, including its uncommitted changes. Target supplied by the developer: a Windows download where friends can build a party, play several full runs, and understand the general gameplay.

## Release judgment

**Do not distribute this working copy as a full-run demo yet.** There is a promising playable combat foundation, but reproducible progression failures stop ordinary runs. Three automated attempts using the real game screens all stopped in Act I when claiming gold. Shipping those failures would mostly generate bug reports and frustration instead of useful feedback about the game.

This looks like a stabilization task rather than a reason to redesign the game. A concentrated fix pass could make a friends demo plausible tomorrow, but that is conditional on successful end-to-end retesting and an actual Windows release build. I would not promise the date before those checks pass.

For this deadline, freeze new mechanics and content. Prioritize a reliable complete run, multiple available party combinations, clear combat information, and a short explanation of the controls.

## Findings in fix order

### 1. Gold rewards stop the run — release blocker

**Reproduction:** reach a reward containing gold and press Claim. The handler reads `RunState.gold`, which is no longer a property on that singleton. It errors before consuming the reward. Gold stays unclaimed and Continue remains disabled.

Three run attempts stopped at Act I rows 5, 6, and 5 respectively. A separate controlled probe reproduced gold remaining 0, bundle gold remaining 10, and Continue disabled.

**Fix direction:** use ResourceManager consistently for the transaction; persist the consumed reward state. Check every reward category and partially claimed rewards after reload, not just combat victory.

Source: [RewardsScreen.gd:310](C:/Users/amkru/Documents/path-of-embers/scenes/screens/RewardsScreen.gd:310).

### 2. A selectable Witch quest cannot progress and locks the final boss — release blocker

**Reproduction:** select Curse Weaver, discard cards, and inspect progress. Calling the actual discard-cost implementation to discard 20 cards left quest progress at 0. With the other two quests completed and the party immediately before the final boss, the available-node list was empty.

The quest listens for `CARD_DISCARDED`; a project-wide search found no gameplay emission of that event. Quest selection can preselect this option. Every fresh-profile party includes Witch, so this is directly exposed to the intended audience.

**Fix direction:** define which discard operations count and emit the event from those operations, then test the quest end to end. For the demo, making quests optional rewards would also remove the risk of an otherwise successful run becoming permanently unwinnable because of a missed objective. Simply hiding this one broken quest is the narrower emergency option.

Sources: [QuestSystem.gd:95](C:/Users/amkru/Documents/path-of-embers/systems/QuestSystem.gd:95), [MapManager.gd:125](C:/Users/amkru/Documents/path-of-embers/autoload/MapManager.gd:125).

### 3. Some upgrade selections fail at runtime — fix before distribution

During the run tests, choosing a Strike for an upgrade generated a typed-array error in UpgradeService. Its fallback in UpgradeFlowPanel generated another typed-array error. The run harness could select a different card, so this was not the final stopping point in those attempts; it is still a broken player-facing choice.

**Cause:** an untyped `Array` is returned or assigned where `Array[String]` is required, including the branch with three or fewer remaining upgrade options.

**Fix direction:** keep the upgrade-option collections explicitly typed through both normal and fallback paths. Test repeated upgrades on the same card and small/exhausted option pools.

Sources: [UpgradeService.gd:52](C:/Users/amkru/Documents/path-of-embers/core/run/UpgradeService.gd:52), [UpgradeFlowPanel.gd:252](C:/Users/amkru/Documents/path-of-embers/scenes/ui/rewards/UpgradeFlowPanel.gd:252).

### 4. Continue skips unfinished combat — fix the save boundary

A save with an unfinished selected fight and 31 HP loaded into the map, retained 31 HP, and allowed selection of the following node. No enemy state is serialized. Map availability advances from the selected node without requiring its completion; Main routes loaded runs to rewards or map.

This is more than an exploit: players who quit during a boss fight can lose the normal transition path because the boss node has no onward connection. That boss-specific case is inferred from the routing and map structure; the ordinary-fight skip was reproduced.

**Fix direction:** choose a clear resume contract. A checkpoint immediately before the encounter is likely cheaper for this demo than serializing every aspect of live combat. Prevent incomplete nodes from advancing the map. Test quitting during an ordinary fight, both act bosses, and the final boss, plus quitting after a partial reward claim.

Sources: [Main.gd:324](C:/Users/amkru/Documents/path-of-embers/scenes/screens/Main.gd:324), [MapManager.gd:117](C:/Users/amkru/Documents/path-of-embers/autoload/MapManager.gd:117), [SaveManager.gd](C:/Users/amkru/Documents/path-of-embers/autoload/SaveManager.gd).

### 5. Fresh profiles cannot actually choose a party composition

With developer mode disabled, only Monster Hunter, Witch, and Living Armor were selectable. The game loads zero milestones, so the implemented unlock system currently has no milestone content through which friends can earn the other characters. This gives a fresh player exactly one three-character combination.

**Fix direction:** make the six implemented characters available for this demo, provided each receives a smoke test, and clearly mark or hide unfinished characters. That would expose 20 party combinations without adding new characters. Keeping three available is a legitimate tightly scoped combat test, but it does not meet the requested party-building/replay goal.

Source: [MilestoneManager.gd:15](C:/Users/amkru/Documents/path-of-embers/autoload/MilestoneManager.gd:15). Runtime evidence: registry reports 0 milestones.

### 6. Equipment HP bonuses accumulate every fight

With unchanged Chain Mail and Iron Helm, maximum HP went **75 → 81 → 87 → 93** across three combat starts. CombatController seeds HP from the already modified persistent resource value and adds the equipment bonus again.

**Fix direction:** derive maximum HP from the party and current equipment without repeated accumulation. Preserve damage taken when changing equipment according to one explicit rule. Retest multiple combat entries and save/load with equipment.

This should be fixed before tuning late-game difficulty: otherwise balance feedback measures an accidental source of permanent growth.

Source: [CombatController.gd:230](C:/Users/amkru/Documents/path-of-embers/core/combat/CombatController.gd:230).

### 7. Combat presentation hides information the player needs

At **1600×900**, the hand overlaps enemy intent information and the lower player information. Cards overlap one another enough to cut off some rules text; Witch's Hex was an example. These are important tactical details, not decorative polish.

The party HUD shows three instances of **“Character Name”** with missing portraits. A separate runtime probe confirmed those exact label values and null portrait textures. PartyHUD initializes the block before adding it to the scene tree, before its onready node references are populated. The narrow stat-block tests pass because they do not exercise this complete parent construction path.

The front-end art has a coherent dark-fantasy direction, and the character-selection/loadout screens are much more composed than the in-run HUD. The transition into the run currently feels like a transition from an illustrated front end into a development interface. For friends, temporary art is acceptable; obscured intent numbers and unidentified ability owners are not.

**Fix direction:** initialize HUD blocks after adding them to the tree; reserve distinct areas for hand, enemies, and party controls; make all card text readable on hover. Verify at 1920×1080 and 1280×720 as well as 1600×900. The smaller and default resolutions were not visually certified in this assessment.

Source: [PartyHUD.gd:120](C:/Users/amkru/Documents/path-of-embers/scenes/ui/hud/PartyHUD.gd:120).

[Observed combat screenshot](C:/Users/amkru/Documents/path-of-embers/assessment/2026-09-10/evidence/combat-1600x900.png).

## Design assessment

**The strongest idea is the shared enemy clock.** Cards consume time as well as energy, and Breathe/Focus let players trade time for different resources. That creates a useful decision beyond simply spending a fixed turn's energy. The six character abilities provide different ways to interact with that economy, and the combined party deck gives the game a credible identity.

**The main risk is communicating the rules.** The game asks players to choose characters, equipment, and quests before they have experienced its distinctive combat. In the path I tested, there was no introductory explanation of the timer model. Labels and tooltips carry a lot of that burden. The Breathe tooltip still says energy is capped, while the implementation and passing tests explicitly allow uncapped energy. Existing design and smoke-test documents also describe older End Turn behavior.

For this demo, add a short first-fight panel explaining: drag a card upward or onto an enemy; card plays advance enemy timers; Space/Breathe gains energy at a time cost; F/Focus draws cards at a time cost; party abilities have their own costs; the three characters share HP and a deck. Explain persistent block and hand overflow where players first encounter them. Use current rules rather than copying the old design document.

**Replayability should come from the content already implemented.** Unlocking the working roster, making reward choices reliable, and letting friends compare parties will teach you more than adding another subsystem this week. There are 31 registered cards, 9 enemies, 20 equipment items, 18 upgrades, 5 encounters, and 6 abilities. That is enough material to test the core loop, but it is not evidence that every combination is balanced or every content interaction works.

**Do not use these results to approve three-act balance.** The opening party is strong in the isolated Act I tests, but the simulation is a heuristic and has no onboarding burden. Later-act tests used starter decks without the upgrades and gear earned during a real run. The equipment accumulation defect also contaminates longer-run difficulty. Fix progression and persistent stats before making broad balance changes.

## What was tested

| Check | Result | Limits |
|---|---|---|
| Five existing regression suites | 195 assertions passed | Card clock 94; signature cards 49; Hex playability 19; party stats 10; backpack 23 |
| Existing setup-flow test | Loadout → quests → map reached | Test emits its own child-setup error; this is not a clean zero-error certification |
| Existing boss-gate test | Passed | Verifies the current gate rule, not that all quest choices are achievable |
| Visible fresh-profile playtest | Menu, available roster, loadout, quest selection, map, first combat, Breathe | Windows editor executable; developer cheats disabled; 1600×900 |
| Card dragging | Developer confirmed manual dragging works | Desktop automation did not successfully resolve card drags; not counted as a game defect |
| Two exploratory parties across selected encounters in Acts I–III | 720 isolated battles; no simulator findings reported | 24 configurations × 30; starter decks; these parties are not selectable on a fresh release profile |
| Actual available starting party, complete Act I encounter pool | 270/270 isolated victories | 9 configurations × 30; timed heuristic; no run attrition or reward decisions |
| Three attempts through real game screens | All stopped on broken gold claims in Act I | 255 total combat actions; heuristic chosen cards/abilities, first reward card, affordable upgrades, survival-oriented paths, shops skipped |
| Focused runtime probes | Reproduced gold lock, discard quest failure, Continue skip, HP accumulation, HUD initialization defect | Synthetic setup isolates each issue; not an organic full run |
| Exported Windows release | **Not tested** | No export preset was present in the project; no release executable was produced |

For the available party, isolated standard Act I fights averaged approximately 9–17 clock ticks and 3–9 net HP lost. The Act I boss averaged 20.8 ticks and 14.0 HP lost. These are measurements of one automated policy, not predicted friend win rates or real-time fight lengths.

All probes and save files were isolated under this assessment directory using separate profiles. Production game code was not edited. The original working copy already contained substantial uncommitted changes. Test shutdowns report resource/object leaks; sandboxed launches also report a certificate-store error absent from the visible unsandboxed launch. Those diagnostics were not used as release blockers without stronger evidence.

## Practical release plan

1. **Stabilize transactions and progression:** gold claims, upgrade typing, achievable quest choices/final-boss access, and a reliable save checkpoint. Reproduce the failures above before fixing them, then rerun the probes.
2. **Make the demo reflect the intended game:** expose the tested working roster, fix repeated equipment HP gains, restore party names/portraits, and separate overlapping combat information.
3. **Add only essential onboarding:** a short rules panel and a plain controls/readme sheet. Correct stale tooltips. Defer new characters, new mechanics, broad visual rework, achievements, and Boss Rush polish.
4. **Package and test the thing friends will receive:** create a Windows release preset, exclude assessment/test artifacts, export, zip, extract elsewhere, and launch with a fresh profile. Verify resource loading and that developer controls are absent.
5. **Go/no-go gate:** complete two legitimate full runs with different party compositions in the extracted release build; deliberately die and restart; resume after quitting on the map, during combat, and after a partially claimed reward; verify repeat-run equipment state. Test the intended minimum display resolution. A forced victory or synthetic boss transition does not satisfy the full-run check.

Once that gate passes, a small friends-only test is appropriate even with placeholder content. Ask friends whether they understood what advanced the clock, why they took damage, which reward decisions felt meaningful, and whether they wanted another run. Record where confusion happened before explaining the rules to them.

## Reproduction files

- [Focused probes](C:/Users/amkru/Documents/path-of-embers/assessment/2026-09-10/probes.gd) and [probe results](C:/Users/amkru/Documents/path-of-embers/assessment/2026-09-10/logs/probes.console.txt).
- [Run-flow harness](C:/Users/amkru/Documents/path-of-embers/assessment/2026-09-10/run_flow.gd), [run results](C:/Users/amkru/Documents/path-of-embers/assessment/2026-09-10/logs/run-flow.json), and [full run log](C:/Users/amkru/Documents/path-of-embers/assessment/2026-09-10/logs/run-flow.console.txt).
- The input probe confirms HUD initialization state. Its synthetic pointer does not update the OS mouse position used by CardUI, so its drag result is an instrumentation limitation, not proof that input is broken.
- All 33 combat simulation summaries and corresponding logs are in [the logs folder](C:/Users/amkru/Documents/path-of-embers/assessment/2026-09-10/logs).

Run the added `.tscn` harnesses from the project root using Godot 4.5.1 with `--headless --path .`, the scene path, and `-- --no-debug`. Set the process's APPDATA to a disposable assessment profile before launching; the probes intentionally change their test run state and saves. The full-run harness intentionally stops when it reaches a blocking flow error rather than bypassing it. Its heuristic and setup are documented in the source.
