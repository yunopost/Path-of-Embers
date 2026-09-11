# Current direction — 2026-09-11

See [ART_DIRECTION.md](ART_DIRECTION.md). Aaron identified excessive sepia/warm/golden-hour treatment. The old low-left golden sun and warm-brown linework instructions are superseded. The Witch is the palette reference. Existing backgrounds with a giant foreground wheel or high camera need replacement for a level, unobstructed combat stage; judge actors and backgrounds together at actual game scale. Historical deviations below remain provenance, not current art guidance.

# Image asset deviations — 2026-09-06
- E1, E3, E4, E5: built-in edit outputs are opaque painted checkerboards (sampled minimum alpha 255); not game-ready, and some painted details changed despite preservation prompts.
- E2: actual alpha present, but generation changed some brushwork/shading and left broad soft edge regions; not a pixel-preserving extraction.
- B1: saved first background candidate; exact dimensions pending validation.


- Backgrounds: all 1672x941 instead of 1920x1080; B4 sunlight is stronger than ideal for a low-contrast map, B6 road is sharper than requested.
- Splashes: all 1448x1086 instead of 1200x900; S1 ground has snow-like pale patches despite no-snow instruction; background warmth/detail is stronger than requested in several splashes.
- E6/E7/E8 and replacement Ember: RGB, no alpha; painted checkerboards. E8 1086x1448 instead of 900x1200.
- All frames: 1086x1448 instead of 900x1200; attack has true alpha with colored fringe; skill/power/curse have opaque checkerboards. Generated variants also vary in texture/geometry, not solely accent color.
- Replacement Eternal Ember: more humanoid/flame-creature than the requested almost-kind bonfire; needs art-direction review in addition to alpha repair.

S1 update: snow-like ground patches corrected in the saved candidate; earlier snow note is superseded.
- icon_intent_summon.png: no output; image tool rejected output with generic safety category other, request ID 17bff05e-f84a-4ef5-9b80-1e6efc75659b. Not retried or replaced with a placeholder.
