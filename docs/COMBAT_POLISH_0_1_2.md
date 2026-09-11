# Friends demo 0.1.2 — art direction and combat composition

This incorporates Aaron's four follow-up notes from 11 September 2026 and includes all the changes documented in COMBAT_POLISH_0_1_1.md. Version 0.1.1 is retained as an earlier local candidate; 0.1.2 is the current candidate.

## Changes and measurable differences

- ART_DIRECTION.md now defines the palette and composition. Both art request documents, GameDesign.md and the handoff prompt link to that authority. The old mandatory golden-hour lighting, warm-brown linework and warm-equals-alive rules are explicitly superseded. The Witch is the palette reference. Existing useful work can be rebuilt when it produces a measurable improvement.
- Two new cool/neutral courtyard backgrounds provide unobstructed combat floors. These replace the previous fight backgrounds in combat; the old images remain on disk. Standard fights share the standard courtyard, while boss/final-boss nodes use the boss courtyard. Region-specific Act II/III environments remain future content. Exact generation briefs and deviations are in ART_PROMPTS_2026_09_11.md.
- Party feet share a 68%-of-height baseline; enemy layout aligns to that same floor. Actor aspect ratios are preserved. Boss panels are wider and their sprite height target is 34% versus 26% for normal enemies, constrained to avoid the upper UI. The enemy health bar now sizes with its containing panel. Existing character colors were retained; future asset generation follows the revised brief.
- Resting cards use approximately 23.5% of viewport height (170–240 px), reduced from the previous 280 px / 39% at 720p. A shallow visual fan preserves stable rectangular hit regions. Card bottoms intentionally extend off-screen while resting. Hover/selection raises a complete 340 px card at 1.1 scale, with 14 px rules text before scaling. Moving to another card replaces the preview. Right-click pins; Escape dismisses.
- How to Play is at the upper right under navigation, with a subdued slate help style, outside the combat action rail. The energy readout has its own opaque, legible panel. The play-zone overlay appears only during a drag.

## Validation and limits

The 362-assertion release suite and 30-fight diagnostic are run against the current production changes; final logs are under assessment/2026-09-11/release-0_1_2/. Rendered probes cover 1280×720, 1600×900 and 1920×1080, plus boss scale and start-menu version. They check card exposure, baseline alignment, raised text size/bounds, help placement, stable identity, pinning, rejected play recovery and successful play cleanup. Captures are the cool-* files under assessment/2026-09-11/polish/. The boss composition probe supplies a boss encounter and the boss texture directly; regular gameplay chooses the texture from map node type.

The Windows ZIP is builds/friends-v0_1_2/Path-of-Embers-friends-v0_1_2.zip. The reproducible builder checks export exclusions, extraction hashes, registry loading and release debug suppression with disposable saves. Full-run balance and ordinary three-act victory remain uncertified; existing shutdown resource warnings remain. This is a candidate for friends to play and critique, not a claim that the whole game is finished.
