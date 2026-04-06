# Path of Embers — Game Design Document

## Overview

**Path of Embers** is a deck-building roguelike inspired by Slay the Spire. Players assemble a party of 3 characters, navigate a branching node map, and engage in tactical card-based combat across multiple Acts. The game's core identity is **satisfyingly in control of chaos** — the deck grows wilder and more powerful as the run progresses, but skilled players always have the tools to tame it.

**Platform**: PC, Mobile, Steam Deck
**Engine**: Godot 4.5.1

---

## Core Gameplay Loop

1. **Character Selection** — Choose 3 characters from a pool of 12. The combination determines starting deck, reward card pools, and strategic direction for the run.
2. **Map Navigation** — Travel through branching node paths. Each path choice is a meaningful trade-off between risk and reward.
3. **Encounters** — Combat, events, elites, and bosses at nodes.
4. **Combat** — Turn-based card combat with the enemy timer system creating a second axis of decision-making beyond energy.
5. **Rewards** — Cards, upgrades, gold, relics after encounters.
6. **Progression** — Deck grows through Acts toward the final boss. Upgrades and transcendence deepen individual cards over time.

---

## Combat System

### Core Mechanics

- **Turn-Based Card Combat** — Players play cards from hand using energy.
- **Energy System** — 3 energy per turn, refills each turn.
- **Hand Management** — Draw 5 cards at turn start, discard unused cards at end.
- **Deck Cycling** — When draw pile empties, shuffle discard pile into new draw pile.

### Enemy Timer System

This is Path of Embers' defining mechanic. Enemies don't act on a fixed schedule — they act when their countdown timer reaches zero. Every card played advances that timer. This means *when* you play cards matters as much as *which* cards you play.

- Each enemy has a visible countdown timer.
- Playing a card advances **all** enemy timers by 1 (default).
- When a timer reaches 0, the enemy performs their intent and resets to their next move's timer value.
- **End Turn** forces all timers to 0 immediately — enemies act now.

**Strategic implications**: Holding back a card to end the turn early can be intentional (force an enemy to act while you have block up). Playing quickly can delay a dangerous enemy's turn if you can reduce their timer to 0 on your terms. Cards that manipulate the timer are a high-skill axis.

### Keywords Affecting Timer

| Keyword | Effect |
|---|---|
| **Haste** | Card doesn't advance enemy timer (0 ticks) |
| **Slow** | Card advances enemy timer by 2 (instead of 1) |
| **Haste Next Card** | Status effect; next card played has Haste |

### Status Effects

- **Vulnerable** — Duration-based. Target takes 1.5× damage. Duration decreases by 1 each turn, removed at 0.
- **Block/Armor** — Prevents damage, decays at start of each player turn.
- Status effects expire at the start of each player turn.

---

## Character System

### Party Composition

- Players select **3 characters** at run start from a pool of 12.
- All 3 characters share a **single health pool** and contribute cards to **one combined deck**.
- Characters are not separate tactical units — they are **deck identity builders**. Choosing a party defines the starting deck, the reward card pool for the run, and the strategic direction.
- Each character belongs to one of three **roles**: Warrior, Healer, Defender.

### Starting Deck

Each character contributes 5 cards to the starting 15-card deck:
- **3 Generic Cards** based on role:
  - Warriors: 2× Strike, 1× Heal
  - Healers: 1× Strike, 1× Heal, 1× Defend
  - Defenders: 2× Defend, 1× Heal
- **2 Unique Cards** specific to that character (reflect their primary themes)

### The Three-Theme System

Every character has exactly three themes, listed in order of accessibility:

- **Theme 1 & 2** — Obvious from the starting unique cards. Players understand these immediately.
- **Theme 3 (Advanced)** — Designed to *combo with other characters' themes* rather than work independently. These are displayed on the character select screen but their full potential only becomes clear through cross-character play.

This creates a natural skill ladder: beginners pick characters that sound interesting, intermediate players match primary themes, expert players align advanced themes for powerful combined strategies.

---

## Character Roster

### Warriors

---

#### Monster Hunter

> *"Her most dangerous hunts begin when the enemy is already tired."*

**Theme 1 — Timer Manipulation**: Cards that control enemy tempo. Slow forces enemies to act more often; Haste lets you cycle freely. Monster Hunter specialises in choosing exactly when enemies act.

**Theme 2 — Vulnerability**: Cards that apply and exploit the Vulnerable status. Monster Hunter debuffs enemies to amplify incoming damage — her own and her party's.

**Advanced Theme 3 — Elite Hunter**: Cards that are weak or costly in standard fights but dramatically powerful against elite and boss enemies. Taking these cards is a deliberate bet on reaching high-value encounters.

*Cross-theme connections*: Pairs with Witch (Vulnerability amplifies curse and contagion damage); pairs with Living Armor (both reward long elite encounters); pairs with Golemancer for a full control strategy; pairs with Hollow (Erasure strips elite abilities, Elite Hunter cards punish them).

---

#### Shadowfoot

> *"She's already gone before the enemy knows she moved."*

**Theme 1 — Fast Actions**: Low-cost cards, Haste keyword, playing as many cards as possible per turn. Shadowfoot's turns are high-volume.

**Theme 2 — Combo Chains**: Cards that trigger bonus effects when played after specific other cards. Rewards sequencing and planning card order.

**Advanced Theme 3 — Untouchable**: Cards that are significantly more powerful when the player hasn't taken damage this combat (or this turn). Rewards building a party that protects them until Shadowfoot has acted.

*Cross-theme connections*: Core pair with Monster Hunter (Shadowfoot plays many Haste cards, Monster Hunter cashes out with one big Slow finisher); pairs with Golemancer (filtered deck means reliable combo sequencing); pairs with Tempest (both want high cards-played-per-turn count); Sibyl's Foresight guarantees Shadowfoot draws combo cards in the correct order.

---

#### Revenant

> *"It refused to stay dead. Now death refuses to take it."*

**Theme 1 — Spite**: Cards that deal more damage the lower your current HP. The Revenant fights hardest at death's door — a card that deals 10 damage at full health might deal 22 at 20% HP.

**Theme 2 — Undying**: Cards that generate value from taking damage rather than just surviving it. Block that converts to attack power when broken. HP loss that triggers draw effects. Being hit isn't a setback — it's fuel.

**Advanced Theme 3 — Death Trigger**: Cards that can only be played, or are dramatically more powerful, in the same turn an enemy dies. Strong in multi-enemy encounters where weak enemies can be picked off to unlock the payoff. Completely offline against single-enemy bosses — a deliberate design trade-off that makes party selection meaningful.

*Cross-theme connections*: Golemancer's damage reduction lets Spite cards work more aggressively without dying; Tempest's Chain damage can kill weak enemies to trigger Revenant's death payoffs in the same turn; Grove's energy generation funds the all-in turns Revenant needs (kill setup + payoff in one turn); Witch and Revenant both use self-harm strategies.

---

#### Tempest

> *"Not a person who commands storms. The storm itself, briefly given will and form."*

**Theme 1 — Cantrips**: Low-cost cards with modest effects. When upgraded, they gain draw, becoming efficient self-replacing plays. A deck full of cantrips cycles through itself at high speed with minimal energy cost.

**Theme 2 — Sequencing**: Cards with payoffs based on what was played before or after them. *Finisher*: deals damage multiplied by how many attack cards were played this turn — play it last. *After Image*: each armour card played after it this turn gains bonus armour — play it first. The hand becomes a puzzle of optimal ordering, not just what to play.

**Advanced Theme 3 — Controlled Chaos**: Cards with random effects — "play the top card of your deck," "play a random attack card from your deck." The skill expression is thinning the deck down to a single target card, at which point these random play effects become perfectly reliable. Choosing between embracing the chaos of high-volume play or controlling it through precision deck compression is Tempest's defining strategic tension.

*Cross-theme connections*: Pairs with Shadowfoot (both want maximum cards-played-per-turn); Monster Hunter's timer control lets Tempest build Sequencing safely; Echo copying a card buffed by multiple Sequencing triggers is a strong advanced combo; Golemancer and Sibyl both help Tempest achieve the thin deck needed for Controlled Chaos.

---

### Healers

---

#### Witch

> *"She gives you something. You won't want it."*

**Theme 1 — Curse Generation**: Cards that add Curse cards to the deck and hand, use curses as fuel, or scale with the number of curses in hand and discard.

**Theme 2 — Discard Payoffs**: Cards that become stronger the larger the discard pile, or that reward intentional discarding. Witch profits from quantity, not quality.

**Advanced Theme 3 — Contagion**: Debuffs that spread between enemies or compound based on existing debuff stacks. Pairs naturally with Monster Hunter's Vulnerability theme — the more enemies are debuffed, the more Witch's contagion punishes them.

*Cross-theme connections*: Core pair with Living Armor (Living Armor inflates deck size, Witch profits from the larger discard pile); pairs with Mechanist (draw effects turn deck mass into engine speed); pairs with Monster Hunter (Vulnerability amplifies all of Witch's damage scaling); Grove's Compost energy becomes extremely powerful alongside Witch's naturally large discard pile.

---

#### Mechanist

> *"Every fight leaves a mark on her cards. She likes it that way."*

**Theme 1 — Board Control**: Persistent power cards that modify the rules of combat while active. Hand size increases, draw modifications, energy adjustments — cards that change what the game looks like for the rest of the fight.

**Theme 2 — Legacy Cards**: Cards that remember the run and grow from it. Three types:
- *Kill-Counter Cards*: Gain a permanent stat increase each time they land the killing blow.
- *Deep Investment Cards*: Can be targeted for upgrade any number of times during upgrade selection, concentrating power into one centrepiece.
- *Duplicate-Growth Cards*: Upgrade automatically each time a second copy is picked from a reward screen.

**Advanced Theme 3 — Transcendence Synergy**: Cards that specifically enhance or interact with transcended cards in the deck. Mechanist is the expert connector — any party with a Mechanist gets more out of every transcended card regardless of which character owns it.

*Cross-theme connections*: Pairs with Witch + Living Armor (draw power turns deck mass into engine speed); pairs with Living Armor (both scale over long fights); Shadowfoot's fast play triggers Mechanist's Legacy counters faster; Sibyl sets up Legacy cards to fire at their peak; universal transcendence connector.

---

#### Grove

> *"An ancient forest spirit. Not a creature of the forest — the forest itself, grown patient and deliberate over centuries."*

**Theme 1 — Bloom**: Cards place growth counters on themselves or other cards in the deck. When a card with enough counters is drawn, the counters pay off in a burst effect. Bloom is slow but accumulates automatically — you don't have to manage it, just wait for it.

**Theme 2 — Regrowth**: Cards that return from the discard pile, either automatically after a set number of turns or through conditional triggers. Grove's resources never permanently deplete. Key cards cycle back into play over and over.

**Advanced Theme 3 — Energy Surge**: Cards that generate bonus energy based on conditions, and X-cost cards that scale with available energy. Example: *Compost* — "Gain 1 energy for every 3 cards in your discard pile." This is a dead draw in tight decks but explosive in large deck strategies. X-cost cards let excess energy translate directly into outsized effects. Grove either empowers other characters' expensive cards or builds its own high-energy payoff loop.

*Cross-theme connections*: Living Armor's large deck gives Grove more Bloom counter distribution; Mechanist's long-arc growth pairs naturally with Grove's accumulation; Grove's Compost becomes extremely powerful alongside Witch + Living Armor's large discard pile; Grove provides the energy for Revenant's all-in kill-and-trigger turns; Golemancer's draw filtering ensures Bloomed cards arrive when their counters are ready.

---

#### Sibyl

> *"A prophet who exists simultaneously across all possible futures. She doesn't control fate — she reads it closely enough to stand exactly where she needs to be."*

**Theme 1 — Foresight**: Cards that actively reorder upcoming draws. Different from Golemancer's Augury — Augury filters reactively, Sibyl constructs the sequence deliberately. She places specific cards at specific positions in the draw pile.

**Theme 2 — Probability**: Cards with multiple conditional effects where the outcome depends on the state of the draw pile or what was just played. *"If the next card in your draw pile is an Attack, deal 14 damage. Otherwise, gain 6 Block."* Skilled players set these up. New players play them and sometimes get lucky.

**Advanced Theme 3 — Inevitability**: Cards placed into the deck at a specific position that trigger a guaranteed powerful effect when drawn at that position. The Sibyl literally sets traps in her own deck that go off at exactly the right moment.

*Cross-theme connections*: Pairs with Golemancer for maximum deck control (Sibyl arranges, Golemancer filters); Shadowfoot benefits enormously from Foresight guaranteeing combo cards arrive in the right order; Mechanist's Legacy cards paired with Sibyl's Inevitability means a high-counter Legacy card can be positioned to fire at peak power; Echo's Recursion loops become far more reliable with Sibyl's deck ordering.

---

### Defenders

---

#### Golemancer

> *"He didn't build a weapon. He built a plan."*

**Theme 1 — Damage Reduction**: Block generation, shields, cards that reduce or absorb incoming hits. Golemancer keeps the party alive long enough to execute.

**Theme 2 — Heavy Strikes**: Cards with the Slow keyword that deal massive damage. Golemancer hits slowly and hits hard — his cards eat the timer but the payoff justifies it.

**Advanced Theme 3 — Augury**: Cards that let the player see the top of the deck, reorder draws, or conditionally skip cards. Makes large or complex decks far more reliable. The strategic planner who turns a chaotic deck into a predictable engine.

*Cross-theme connections*: Pairs with Shadowfoot (reliable combo sequencing); pairs with Witch + Living Armor (filters the chaos from a large deck); pairs with Monster Hunter for a full control strategy (Monster Hunter controls when hits land, Golemancer controls how much they cost); pairs with Tempest (Augury supports the thin deck needed for Controlled Chaos); Hollow's block-to-energy conversion works naturally alongside Golemancer's high block generation.

---

#### Living Armor

> *"It has been hit so many times it has forgotten how to fall."*

**Theme 1 — Defense into Offense**: Cards that deal damage in response to taking hits, convert accumulated block into attacks, or grow stronger from absorbing punishment.

**Theme 2 — Escalation**: Permanent growing buffs each combat turn. The longer the fight, the more dangerous Living Armor becomes. Cards that add permanent stats, stack passives, or trigger compounding effects.

**Advanced Theme 3 — Enemy Absorption**: Cards that copy or steal enemy abilities and use them against their source. The most mechanically complex theme in the roster — rewards players who understand enemy move patterns deeply.

*Cross-theme connections*: Core pair with Witch (Living Armor's card-heavy kit inflates deck and discard pile for Witch's payoffs); pairs with Mechanist (both scale over long fights); pairs with Monster Hunter for long elite encounters; Living Armor absorbs what Shadowfoot couldn't avoid — complementary defensive styles; Grove's Bloom distributes well across Living Armor's large deck.

---

#### Echo

> *"A spirit born from repetition. It has no original form — only reflections. What you see when you look at the Echo depends entirely on what you just did."*

**Theme 1 — Mirror**: Cards that replay the last card played, either exactly or with a modification. Playing a powerful card well means playing it twice.

**Theme 2 — Resonance**: Persistent effects that amplify when the same category of card is played consecutively. Playing three Attacks in a row builds Resonance that magnifies the third. Rewards deliberate sequencing over raw card power.

**Advanced Theme 3 — Recursion**: Cards that can replay themselves from the discard pile when specific conditions are met. High skill ceiling, high power ceiling, and high risk of building a deck that doesn't function without the right setup.

*Cross-theme connections*: Echo mirroring a Mechanist Legacy card while it has high kill-counter stacks is a natural advanced combo; Tempest's Sequencing-buffed cards are a natural Mirror target; Sibyl sets up the sequence, Echo doubles the payoff; Shadowfoot's consecutive card-playing builds Resonance naturally.

---

#### Hollow

> *"An ancient void entity. It was emptied of its original purpose eons ago. Now it simply contains what it destroys."*

**Theme 1 — Conversion**: Cards that convert accumulated block into energy. Spending defence to fund offence — block becomes the resource that powers your most explosive turns. Pairs naturally with any character that generates high block.

**Theme 2 — Dominance**: Cards with powerful effects that forcibly end the turn when played. Sequencing is critical — you must have already done everything you need to do before committing. Example: *"Until next turn, all enemy attacks deal 1 damage. End the turn."* You sacrifice your remaining plays to completely neutralise an incoming damage burst.

**Advanced Theme 3 — Compression**: Cards that exhaust themselves or other cards to filter the deck, with payoff cards that grow stronger based on how many cards are exhausted this combat. Simple use: exhaust weak cards for a cleaner deck. Advanced use: exhaust nearly everything until you're consistently drawing one maximally empowered card. The ceiling is extreme but requires deliberate sacrifice of most of the deck.

*Cross-theme connections*: Golemancer generates high block which Hollow converts directly to energy; Revenant and Hollow both treat damage and defence as resources — pairing them creates a party where almost nothing is wasted; Living Armor and Hollow are both long-fight defenders, but Living Armor escalates offensively while Hollow compresses and controls; Monster Hunter's timer manipulation pairs with Hollow's Dominance cards to precisely control when turns end and when enemies act.

---

## Party Synergy System

### The Two Core Strategic Axes

Most parties lean toward one of two strategic philosophies, or deliberately blend them:

**Timer Axis** — Control *when* enemies act. Decks are tight, efficient, and sequenced precisely. Key characters: Shadowfoot, Monster Hunter, Tempest.

**Mass Axis** — Profit from *volume*. Decks are large and churning, with payoffs that scale with cards played and discarded. Key characters: Witch, Living Armor, Grove.

Golemancer, Sibyl, Echo, and Mechanist are **support/connector characters** — they enhance either axis rather than defining their own.

### Strategic Axes Overview

| Axis | Characters | Core Idea |
|---|---|---|
| **Timer** | Monster Hunter, Shadowfoot, Tempest | Control when enemies act; tight, precise decks |
| **Mass** | Witch, Living Armor, Grove | Profit from large decks and high discard volume |
| **Danger** | Revenant, Hollow | Treat damage and defence as income, not loss |
| **Accumulation** | Grove, Mechanist | Scale over the entire run, not just per combat |
| **Precision** | Sibyl, Golemancer | Maximum deck control; every draw is intentional |
| **Echo** | Echo, Tempest | Amplification through repetition and chaining |

### Full Synergy Web

| Pair | Synergy |
|---|---|
| Shadowfoot + Monster Hunter | Haste setup → Slow payoff (core timer combo) |
| Witch + Living Armor | Deck inflation → discard profits (core mass combo) |
| Monster Hunter + Witch | Vulnerability amplifies curse and contagion damage |
| Shadowfoot + Golemancer | Filtered deck enables reliable combo sequencing |
| Shadowfoot + Tempest | Both maximise cards-played-per-turn count |
| Shadowfoot + Sibyl | Foresight guarantees combo cards arrive in order |
| Monster Hunter + Living Armor | Both reward long elite fights |
| Monster Hunter + Golemancer | Control timing and damage intake — full defensive layer |
| Monster Hunter + Hollow | End-turn cards + timer manipulation = precise turn control |
| Revenant + Grove | Grove energy funds kill-setup + death-trigger payoffs in one turn |
| Revenant + Tempest | Tempest Chain kills weak enemies; Revenant cashes in same turn |
| Revenant + Golemancer | Damage reduction enables aggressive Spite play at low HP |
| Revenant + Witch | Both use self-harm strategies |
| Revenant + Hollow | Both convert damage/defence resources into power |
| Tempest + Monster Hunter | Timer control lets Tempest build Sequencing safely |
| Tempest + Echo | Echo copies Sequencing-buffed cards at their peak |
| Tempest + Golemancer + Sibyl | Maximum deck thinning for Controlled Chaos precision |
| Witch + Living Armor + Mechanist | Deck mass + draw speed = engine strategy |
| Witch + Living Armor + Golemancer | Deck mass + draw filtering = reliable engine |
| Witch + Grove | Compost extremely powerful with Witch's large discard pile |
| Grove + Living Armor | Large deck distributes Bloom counters widely |
| Grove + Mechanist | Both long-arc accumulation strategies (Bloom + Legacy) |
| Grove + Revenant | Energy surplus funds Revenant's all-in turns |
| Sibyl + Golemancer | Maximum deck control — Sibyl arranges, Golemancer filters |
| Sibyl + Mechanist | Inevitability positions Legacy cards to fire at peak power |
| Sibyl + Echo | Sibyl sets the sequence; Echo doubles the payoff |
| Echo + Mechanist | Mirror copies Legacy cards at high counter values |
| Hollow + Golemancer | High block generation → converted to energy |
| Hollow + Living Armor | Both long-fight defenders, complementary approaches |
| Mechanist + anyone | Transcendence synergy is universal |

### Notable Strong Trios

| Name | Party | Strategy |
|---|---|---|
| **Timer Combo** | Shadowfoot + Monster Hunter + Golemancer | Golemancer filters deck so both draw key cards reliably |
| **Engine Combo** | Witch + Living Armor + Mechanist | Raw deck mass with maximum draw speed |
| **Control Combo** | Monster Hunter + Golemancer + Witch | Debuffs, damage reduction, and punishment layered |
| **Escalation Combo** | Living Armor + Mechanist + Monster Hunter | Long elite fights where all three scale toward a peak |
| **Danger Combo** | Revenant + Hollow + Golemancer | HP and block both become resources; Golemancer keeps you alive to use them |
| **Deep Time Combo** | Grove + Mechanist + Sibyl | Everything accumulates — counters, Legacy stacks, Inevitability traps — until the deck is unstoppable |
| **Chain Reaction** | Tempest + Revenant + Golemancer | Tempest chains kill weak enemies; Revenant detonates; Golemancer keeps the deck precise |
| **Precision Engine** | Sibyl + Shadowfoot + Echo | Sibyl orders every draw, Shadowfoot chains everything, Echo doubles the payoffs |

---

## Pre-Run Screen Design

### Character Select Screen

The character select screen is the player's first strategic decision. Its UI must communicate enough information for an informed party choice while preserving the sense of discovery. The layout is designed around a **scan → inspect → commit** interaction model.

---

#### Layout Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  HEADER: Step wizard (Party → Modifiers → Loadout)  |  Party HP    │
├──────────────────────────────────┬──────────────────────────────────┤
│                                  │                                  │
│  CHARACTER GRID (top ~35%)       │  DETAIL PANEL (right, fixed     │
│  Grouped by archetype            │  ~320–360px wide)               │
│  4 cards per archetype row       │                                  │
│  Compact cards: portrait thumb,  │  • Empty state until a card     │
│  name, archetype badge,          │    is clicked                   │
│  stat pips, theme tags           │  • Shows: portrait, name,       │
│                                  │    archetype, stats, starting   │
│                                  │    cards (all 5), themes with   │
│                                  │    descriptions, quest seed,    │
│                                  │    synergies with party members │
├──────────────────────────────────┴──────────────────────────────────┤
│                                                                      │
│  PARTY DECK PREVIEW (bottom ~55%)                                   │
│  Three slots appearing in selection order (left → right)           │
│  Each slot: large splash art + character name + 2 unique cards     │
│  Empty slots show a dimmed placeholder                              │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│  FOOTER: 3 party portrait slots  |  0/3 selected  |  Back / Next  │
└──────────────────────────────────────────────────────────────────────┘
```

---

#### Character Grid

Characters are grouped into three labeled archetype rows — Warriors, Healers, Defenders — each with a horizontal rule and a subtitle describing the archetype's strategic role (e.g. *Offense & Tempo*, *Engine & Scaling*, *Survivability & Control*). The archetype row header also shows baseline stats for that class so players can compare HP pools at a glance.

Each character card in the grid is compact and prioritises scannability over detail:
- Small portrait thumbnail (~42×42px, uses real character art)
- Character name (Cinzel, prominent)
- Archetype colour badge
- Stat pips (STR / DEF / SPR) — small dot array, serves as visual fingerprint
- Theme tags — pill badges in archetype and neutral colours, no descriptions at this size

**Selection states:**
- Default: dark card, subtle archetype top-border gradient
- Hover: border brightens to ember-glow, slight lift
- Selected: ember-orange border, radial inner glow, amber checkmark badge
- Locked: greyed out, 50% opacity, lock icon, not clickable
- Party full (3 selected, this card not one of them): 40% opacity, cursor blocked

Clicking a card **inspects** it (opens the detail panel) — it does not immediately select it. Clicking again, or clicking a dedicated "Add to Party" button in the detail panel, selects it. This prevents accidental selections and gives the detail panel a purpose.

---

#### Detail Panel (Right Side)

Opens when any character card is clicked. Animates in with a staggered fade-up on each section. Width: 320–360px.

**Sections from top to bottom:**

1. **Character header** — Large portrait (64px), name (Cinzel 18px), archetype line, add/remove party button
2. **Stats block** — STR / DEF / SPR / HP as numeric tiles
3. **Starting Cards** — All 5 starting cards listed as: `[cost pip] [type stripe] Card Name — italic effect text`. The 3 generic base cards are visually de-emphasised (dimmer); the 2 unique cards are full brightness
4. **Themes** — Numbered 01 / 02 / 03, each with a short label and one-sentence description. Theme 3 is marked *Advanced* in gold
5. **Quest Seed** — Single sentence with a left accent border
6. **Synergies** — Lists named synergies with any currently selected party members. Empty if no party members selected yet. Updates live as the party changes

**The detail panel is the only place full card effect text appears** on this screen. The grid cards and the party deck preview both show condensed versions.

---

#### Party Deck Preview (Bottom Section)

Occupies roughly the lower 55% of the screen, below the character grid. Displays the two most strategically meaningful pieces of each selected character: their **splash art** and their **2 unique signature cards**.

**Behaviour:**
- Starts empty — three dimmed placeholder slots labelled with slot numbers
- As the player selects characters (up to 3), each selection fills the next slot left-to-right in selection order
- Slot fill animation: splash art fades/slides in, then the two card entries appear below it
- Clicking a filled slot opens that character in the detail panel (right side)
- The slot does not act as a deselect — removal is handled via the footer party portrait hover-remove or the detail panel button

**Per-slot layout:**
```
┌──────────────────────────────────┐
│                                  │
│       CHARACTER SPLASH ART       │  ~400–460px tall
│       (atmospheric, full-body    │
│        or half-body illustration)│
│                                  │
├──────────────────────────────────┤
│  CHARACTER NAME  (Cinzel)        │
│  [archetype badge]               │
├──────────────────────────────────┤
│  [●] [▌] Unique Card 1 — text   │  cost pip + type stripe format
│  [●] [▌] Unique Card 2 — text   │
└──────────────────────────────────┘
```

**Why only the 2 unique cards (not all 5):**
The 3 generic base cards (Strike, Heal, Defend) are identical across most characters and add no information to the party-building decision. The 2 unique cards are the character's strategic identity. Showing only those keeps the preview focused and avoids visual repetition (a full 15-card deck would contain 9 nearly identical rows).

---

#### Footer

A slim persistent bar at the bottom of the screen:
- **Party slot portraits** — 3 small portrait thumbnails (36×36px), dashed border when empty, fills in as characters are selected. Hover reveals an ✕ remove button
- **Party HP total** — live running total of the selected party's combined base HP. Helps players understand the defensive cost of choosing low-HP characters (e.g. a Witch at 22 HP vs a Hollow at 28 HP is a visible trade-off)
- **Navigation buttons** — `← Back` (returns to main menu) and `Modifiers →` (advances to difficulty modifier selection). The forward button is disabled until exactly 3 characters are selected

---

#### Step Wizard (Header)

A minimal progress indicator spanning the top-left of the header showing the full pre-run flow:

`① Party  ——  ② Modifiers  ——  ③ Loadout`

Active step uses ember-bright colour; completed steps use dimmed gold; upcoming steps are greyed out. This communicates to the player that character select is one of several decisions before a run begins, preventing confusion about when equipment configuration happens.

---

#### Art Assets Required

| Asset | Count | Notes |
|---|---|---|
| Character portraits | 12 | Square, transparent PNG/WebP, 256×256px min. Used at ~42px (grid thumbnail) and ~64px (detail panel). One file per character. |
| Character splash art | 12 | Large atmospheric illustration, half or full-body. ~500px tall in-engine. Highest-impact asset category. Different from portraits — environment-suggestive, loose composition. |
| Card type icons | 4 | Attack, Skill, Power, Curse. Deliver at 48–64px source, display at ~12px. High contrast silhouettes only. |
| Archetype icons | 3 | Warrior, Healer, Defender. Used in row headers and card badges. 24×24px source. |
| UI texture (tileable) | 1 | Aged parchment or paper, ~256×256px. Tinted per archetype via CSS/shader overlay. |
| Selected / locked icons | 2 | Checkmark, padlock. Small, consistent with icon style. |
| Section divider ornaments | 2–3 | Used as horizontal rules in the detail panel. Ember, sigil, or branch motif. |

**Note on portrait vs splash art:** These are two distinct asset categories delivered at different dimensions and compositions. Portrait art is a close bust or face shot optimised to read at 42–64px. Splash art is a large atmospheric piece optimised to fill a ~400–500px panel. Brief artists on both separately.

---

## Card System

### Card Types

- **Attack** — Deals damage to enemies.
- **Skill** — Utility effects: block, draw, buffs, etc.
- **Power** — Persistent effects that last for the combat.

### Card Rarities

- **Common** — Most frequent, baseline power level.
- **Uncommon** — Moderate power, considered effects.
- **Rare** — Powerful, less frequent.

### Card Pools

Each character adds **22 unique cards** to the reward pool:
- 7 Common, 12 Uncommon, 3 Rare
- Total pool: 66 cards across 3 characters per run

Cards are **not removed** from the pool when selected — duplicates are possible across different reward screens. Each individual reward screen always shows 3 **different** cards.

### Card Keywords

| Keyword | Effect |
|---|---|
| **Haste** | Doesn't advance enemy timer when played |
| **Slow** | Advances enemy timer 2× when played |
| **Exhaust** | Removed from play for the rest of combat |
| **Vulnerable** | Status keyword — target takes 1.5× damage |
| **FirstCardOnly** | Enhanced or restricted effect when played as the first card this turn |

---

## Upgrade & Transcendence System

### Standard Upgrades

Cards can be upgraded at upgrade nodes. Each card has a **pool of possible upgrades** it can roll from. Upgrades vary in effectiveness — evaluating whether a rolled upgrade is worth taking for your current deck state is a meaningful skill expression.

Upgrade selection presents the player with a specific rolled upgrade to evaluate. The decision is:
- Is this upgrade good for this card?
- Is this card the right one to upgrade right now?
- Does this upgrade synergise with my current party's strategy?

### Mechanist Legacy Upgrades

Mechanist's unique cards bypass the standard upgrade mechanic and track their own growth across the run:

- **Kill-Counter Cards** — Gain a permanent stat increase each time they land the killing blow.
- **Deep Investment Cards** — Can be selected as the upgrade target any number of times during upgrade selection.
- **Duplicate-Growth Cards** — Upgrade automatically each time a second copy is picked from a reward screen.

Legacy card counters persist through saves and are tracked per card instance.

### Transcendence

Transcendence transforms a card into a more advanced version with a different mechanic, higher ceiling, and greater complexity. Transcended cards are harder to use but have payoffs that standard upgrades cannot reach.

Design principles:
- A card should generally be upgraded before it can transcend.
- Transcended Mechanist Legacy cards (especially those with accumulated kill-counts) should feel like culmination moments.
- Mechanist's advanced theme cards specifically interact with transcended cards, making her the expert connector for transcendence-heavy strategies.

---

## Rare Card Pity System

### Base Mechanics

- **Base Rare Chance**: Starts at -2% (effectively 0%).
- **Increasing Odds**: Each Common card in a reward screen increases Rare chance by +1%.
- **Reset**: Rare chance resets to -2% when a Rare card appears.
- **Elite Bonus**: Elite nodes apply a flat +10% to the Rare counter.

### Deck Penalty

Each unique Rare card already in the deck applies -10% to that **specific** Rare card appearing again in rewards. Prevents Rare stacking while keeping all Rares accessible.

---

## Map & Progression System

### Node Types

| Node | Description |
|---|---|
| **Fight** | Standard combat encounter |
| **Elite** | Harder combat with better rewards (+10% Rare bonus) |
| **Boss** | Act boss encounter |
| **Event** | Non-combat encounters with choices |
| **Rest** | Healing, shop, or upgrade options |

### Node Rewards

| Flag | Reward |
|---|---|
| **C** | Card: 3 choices from reward pool |
| **U** | Upgrade: 1 card upgrade |
| **G** | Gold: Fight 10 / Elite 25 / Boss 50 |
| **R** | Relic: Standard relic |
| **B** | Boss Relic: Special boss pool relic |
| **E** | Elite: Guaranteed relic + 3 card choices + upgrade |

---

## Enemy System

### Enemy Data Structure

- **HP Range**: Min/max for randomisation.
- **Act**: Which act the enemy appears in.
- **Moves**: Array of move patterns, each with a timer value, effects, and telegraph text.

### Enemy AI

- Weighted random move selection.
- Anti-repetition: never the same move 3 times in a row; 50% weight reduction for repeating 2 times in a row.

### Example Enemy: Ash Men (Act 1)

- **HP**: 38–44
- Move 1 (Timer 4): Attack 8 damage
- Move 2 (Timer 1): Apply Vulnerable 1 (1 turn)
- Move 3 (Timer 4): Attack 2, Heal 2 HP
- Move 4 (Timer 3): Attack 3 × 2 hits

---

## Design Philosophy

### Core Identity

**Satisfyingly in control of chaos.** The deck grows wilder and more powerful across a run. The upgrade system and transcendence mean individual cards can become extraordinary. The party system means the starting deck is always heterogeneous. The enemy timer system means every turn is a tactical puzzle with multiple valid solutions. Skilled players learn to read all of this and feel like they're conducting it rather than reacting to it.

### Design Principles

1. **Timer awareness is mastery** — Cards, card order, and end-turn timing should all be meaningful decisions. Design encounters that reward players who understand the timer deeply.
2. **Simple cards, complex decisions** — Individual cards should be readable immediately. The complexity lives in sequencing, party synergy, and upgrade choices.
3. **Chaos with agency** — Randomness (upgrade rolls, reward cards, enemy patterns) always gives the player something to evaluate and decide. Never purely random outcomes.
4. **Cross-character synergy rewards experience** — New players build a playable deck. Expert players find the advanced theme connections and build something greater.
5. **Every card remembers the run** — Mechanist literalises this, but the principle applies broadly. Upgrades, transcendence, and Legacy cards mean the deck at Act 3 tells the story of how it got there.
6. **Risk should always have a legible reward** — Death-trigger cards, Spite damage, Hollow's Compression, Revenant's low-HP thresholds — every high-risk mechanic must make the payoff visible so players can make informed bets.

### Inspiration

- **Slay the Spire**: Deck-building roguelike foundation.
- **Unique features**: Enemy timer system, multi-character party deck-building, upgrade roll system, Legacy card growth, transcendence transformation, death-trigger and threshold mechanics.

---

## Technical Architecture

### Data Patterns

- **Immutable Definitions**: CardData, CharacterData, EnemyData are Resources (blueprints).
- **Mutable Instances**: DeckCardData (with upgrades and Legacy counters), Enemy (runtime state).
- **Instance ID System**: Each card in the deck has a unique instance_id for tracking upgrades, Legacy counters, and transcendence state.
- **Registry Pattern**: DataRegistry stores all card/character/enemy definitions. Characters are registered at startup (DataRegistry._ready()) and always available regardless of game flow.

### Save System

- JSON save, version-tracked.
- Tracks: party, deck (with upgrades and Legacy counters), HP, gold, map progress, quests, pity counter.
- Auto-save on key state changes.

---

## Development Status

### Development Phases

| Phase | Name | Status | Key Deliverables |
|-------|------|--------|-----------------|
| 1 | Core Combat Engine | ✅ Complete | Combat loop, timer system, energy, hand/draw/discard, turn flow |
| 2 | Card & Character System | ✅ Complete | CardData, DeckCardData, CharacterData, keywords (Haste, Slow, Exhaust, Vulnerable), starter decks |
| 3 | Map & Progression | ✅ Complete | Procedural map generation, node types (combat, shop, encounter, rest), reward screen, rarity + pity |
| 4 | Enemy System | ✅ Complete | EnemyData, move patterns, weighted AI with anti-repetition, act 1 enemies, telegraph UI |
| 5 | Status Effects & Upgrades | ✅ Complete | Full status effect set (Strength, Dexterity, Weakness, Vulnerable, Faith, Bloom, Regrowth, Scry…), card upgrade pool system, upgrade roll UI |
| 6 | Save/Load, Relics & Quests | ✅ Complete | JSON save/load, DataRegistry character registration fix, RelicData + relic hooks, QuestData + QuestManager + 12 tracking types |
| 7 | Acts 2 & 3 + Final Boss | ✅ Complete | Act transition nodes, FINAL_BOSS/STORY node types, per-act scaling, boss_act2 + boss_act3, new enemies (Char Sentinel, Ashen Knight) |
| 8 | Equipment System | ✅ Complete | EquipmentData (6 slot types, 3 rarities), LoadoutScreen, stat modifiers, card injection, ShopScreen integration, meta stash, persistent stash |
| 9 | Milestones, Boss Rush & Content | ✅ Complete | MilestoneData + MilestoneManager, meta.json v2, locked character display, BuildData snapshots, 3 Boss Rush save slots, LeaderboardManager, BossRushScreen, 24 starter cards, 12 characters, 9 enemies + 3 bosses, 5 encounters, 12 equipment |
| 10 | Difficulty Modifiers & Polish | ✅ Complete | ModifierManager autoload (6 modifiers, score ×0.10 each), modifier toggle UI in LoadoutScreen with live score preview, equipment drop weights (Common 50% / Uncommon 35% / Rare 15%), quest event wiring (CARD_PLAYED, ENEMY_KILLED, GOLD_SPENT, DAMAGE_DEALT, BLOCK_GAINED), data bug fixes (dark_pact params, WEAKNESS dual-format, DAMAGE_EQUAL_TO_BLOCK resolver) |

### Completed Systems

- ✅ Core combat loop with timer system
- ✅ Card system with keywords (Haste, Slow, Exhaust, Vulnerable)
- ✅ Character selection and starting decks
- ✅ Reward system with rarity and pity mechanics
- ✅ Map navigation and node progression
- ✅ Enemy system with move patterns and AI
- ✅ Status effects (Vulnerable)
- ✅ Card upgrade system (upgrade pool per card)
- ✅ Save/load system with DataRegistry character registration fix
- ✅ Relic system (RelicData resource, DataRegistry loading, reward integration)
- ✅ Quest system (QuestData, QuestState, QuestManager, QuestSystem evaluator)
- ✅ Acts 2 and 3 + final boss (FINAL_BOSS/STORY node types, act transitions, per-act scaling)
- ✅ Equipment system (6 slots per character, LoadoutScreen, stat modifiers, card injection, ShopScreen, meta stash)
- ✅ Milestone system (MilestoneData, MilestoneManager, meta.json v2 unlocks, locked character display)
- ✅ Boss Rush mode (BuildData snapshots, 3 save slots, LeaderboardManager scoring, BossRushScreen, post-run save dialog)
- ✅ Content first pass (24 starter cards, 12 character .tres files, 9 enemies + 3 bosses, 5 encounters, 12 equipment, death messages, shop prices corrected, all 12 quest tracking types wired)
- ✅ Difficulty modifiers (ModifierManager autoload, 6 modifiers, score multiplier, LoadoutScreen UI, drop weight calibration)

### Difficulty Modifiers

Six modifiers are available before each run via the LoadoutScreen panel. Each active modifier adds ×0.10 to the final score multiplier.

| ID | Name | Effect |
|----|------|--------|
| `reduced_hp` | Reduced HP Pool | Player max HP −25% |
| `tougher_enemies` | Tougher Enemies | Non-boss HP +25% |
| `tougher_bosses` | Tougher Bosses | Boss HP +50% |
| `advanced_enemies_1` | Advanced Enemies I | Enemy timer intervals −20% (faster) |
| `advanced_enemies_2` | Advanced Enemies II | Enemy damage +25% |
| `advanced_enemies_3` | Advanced Enemies III | Enemy damage +50%, HP +25% |

Modifier selection is persisted to `user://modifier_settings.json`. Active modifiers are locked in at run start via `ModifierManager.begin_run()`.

### In Progress

- 🚧 Full reward card pools (22 cards per character beyond starter 2)
- 🚧 Mechanist Legacy card implementation
- 🚧 Complex effect resolver implementations (mirror, resonance, regrowth, bloom, scry, etc.)

### Planned

- ⏳ Apply `ModifierManager.get_enemy_hp_multiplier()` / `get_enemy_damage_multiplier()` in enemy spawn logic
- ⏳ Apply `ModifierManager.get_player_hp_multiplier()` to ResourceManager at run start
- ⏳ Milestone .tres data files (to gate modifier unlocks and track run completions)
- ⏳ Balance tuning
- ⏳ Art assets (character portraits, card art, enemy sprites)

---

## Notes for Designers

This document is the **source of truth** for mechanics and design philosophy. When making decisions:

1. Check this document first.
2. Update this document when adding or changing mechanics.
3. Use the synergy web when designing new cards — every card should have a home in at least one party strategy.
4. Use "satisfyingly in control of chaos" as the filter for every design decision. If a mechanic adds chaos without a corresponding player lever to manage it, reconsider.
5. When designing cards for the six new characters, use the existing six as a reference for scope and power level — starter cards should communicate the first two themes immediately, reward pool cards can explore the edges of the advanced theme.
