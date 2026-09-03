# Smoke Test Checklist — after M0 cleanup (July 2026)

Run in the Godot editor. Check the Output panel for errors/warnings at every step. Mark ❌ items with a note and we'll fix them before M1.

## Launch & Menu
- [X] Project opens with no script errors in Output
- [X] Main menu renders (title shader, buttons, music playing)
- [X] Settings popup opens/closes — Tap-to-Play toggle should be GONE
- [X] Continue button state correct (disabled with no save / enabled with save)

## New Run
- [X] Character select shows all 12 characters (10 with colored placeholder portraits — expected)
- [X] Detail panel opens on click; synergies update as party changes 
- [X] Select 3 → Modifiers/Loadout step → toggle a difficulty modifier → score preview updates
- [ ] Loadout screen: equip an item, start run #no items to equip, lets add 3 generic starter items just so we can test this and items.
- [x] Starting deck = 15 cards (Deck view popup)

## Map & Combat
- [x] Map generates; only connected nodes clickable
- [x] Elite node icons: no stray "R" reward icon (removed this — elite shows C/U only)
- [x] Fight: cards play, energy spends, enemy timers tick per card
- [x] End Turn forces enemy actions; block/vulnerable behave correctly
- [x] Win fight → rewards screen → claim gold/card/upgrade → continue to map
- [X] Card with Exhaust disappears for rest of combat; curse/temporary cards do NOT persist after combat ends

## Other Screens
- [X] Shop: buy card/equipment, prices deduct #Shops are empty
- [X] Encounter: pick each choice type once; rewards resolve #i've picked a couple options but not all and they seem to be working now
- [X] Rest node works
- [ ] Witch's "Dark Knowledge" quest now reads "Upgrade 2 cards" and progresses when you upgrade #we need to add a screen for selecting which quests we are taking per character, at the moment it's either random are always just picking the first one

## Save/Load
- [X] Save mid-run (auto), quit to menu, Continue → same map position, deck, HP, gold
- [x] Reward card taken after load still has effects when played (was an old bug — verify)
- [x] Upgraded card keeps upgrades after load

---

## Round 2 — re-test after bug-fix pass (July 2026)
- [x] Shrine "Pray" choice no longer crashes (heal now goes through ResourceManager) 
- [x] Hex curses vanish from deck when combat ends
- [ ] Shop shows stock (Output should print "ShopScreen: generated N stock items" — if it's ever empty again, send me that log line + any red errors) #Shops appearence needs to be changed, it's not scaled correctly
- [x] Character select: cards fit in 4 columns left of the detail panel, nothing clipped (root cause: gradient stripe forced 512px min card width)
- [x] Echo now appears under Defenders, Mechanist under Healers (roles were wrong in data)
- [x] Synergy section in detail panel lists real synergies and updates as you add/remove party members
- [x] Settings popup: dimmed backdrop + solid dialog, music volume slider works and persists across restarts

## Round 2b — balance pass (encounter variety + pacing)
- [x] Standard fights are varied (2 imps / shade+imp / 1 ash man / 2 shades / 1 brute / ash man+imp) instead of always 3 Ash Men
- [x] Standard Act 1 fights resolve in roughly 3-4 turns
- [x] Elite nodes spawn Ashen Knight or Char Sentinel
- [ ] Boss nodes spawn the actual act boss (they previously spawned 3 Ash Men!) #when I try to click on the boss node it says node not available
- [ ] Act 2/3 fights feel harder (reused Act 1 roster at +60%/+120% HP, +30%/+60% damage — placeholder until real Act 2/3 enemies) #Not able to get to act 2 yet
- Known issue: in Acts 2/3 the intent telegraph shows unscaled damage numbers (actual hit is higher). Will fix with real Act 2/3 enemy data.

## Round 3 — layout fixes, boss gate, quest select (July 2026)
- [ ] Shop renders as a centered panel below the HUD; buy buttons next to their items, not screen-edge
- [ ] Rewards screen: sections stack cleanly (gold / cards / upgrade / heal), no overlapping text, panel clears the HUD
- [ ] Act 1 boss node is clickable WITHOUT completing quests (gate now applies only to the final boss)
- [ ] Fresh profile gets 3 starter items in Loadout (Iron Helm / Chain Mail / Swift Boots). Note: your existing meta.json will seed these too since your stash was empty #we need to add stats to the items and change their UI to display their properties. Also currently any item can go to any slot on a character
- [ ] Loadout button now reads "NEXT: QUESTS →" and leads to the new Quest Select screen #next quest button on the equipment screen doesn't advance to the quest screen
- [ ] Quest Select: each character shows their quest options, one pre-selected; clicking swaps selection; BEGIN RUN applies choices and enters the map 
- [ ] Chosen quests appear in the HUD during the run and track progress 

## Full Run (longer)
- [ ] Act 1 boss → Act 2 transition → Act 3 → final boss → Victory screen loads (fixed a path bug here — this screen previously could NOT load on Linux/exports)
- [ ] Die on purpose → Game Over screen → back to menu
- [ ] Boss Rush mode launches from menu

## Known-good-to-ignore
- Placeholder portraits/card art everywhere except Monster Hunter, Witch, main menu
- "SCRY: peeking..." warnings — Scry UI is M1 work
- Reward pool cards beyond starters are auto-generated placeholders — M3 work
