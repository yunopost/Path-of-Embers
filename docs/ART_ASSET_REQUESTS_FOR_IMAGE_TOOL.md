# ART ASSET REQUESTS — instructions for the image-generation tool

**Who this is for:** the AI image tool Aaron is using to create art for the game *Path of Embers*. If you are that tool: read all of this, then produce the assets in §4 (Batch 1) and write each file to the exact path given. Do not do Batch 2 until Aaron tells you Batch 1 has been reviewed.

**Who wrote it:** the game's art director (Claude, in the design project). Everything here follows the project's Style Bible and World Bible. Do not invent new style rules; where this file is silent, match the existing finished art in `art/`.

All paths below are relative to this folder (the Godot project root). Create folders that do not exist yet.

---

## 1. The look — read before generating anything

**Current authority:** [ART_DIRECTION.md](ART_DIRECTION.md), updated by Aaron on 11 September 2026. Its palette, combat floor and scale requirements supersede the original batch compositions below. Historical blockouts are not approved combat compositions when they obstruct actor placement.

**Reference images (match these — they define the style):**
- `art/monster_hunter/monster_hunter.png` — the line and paint register for anything with a face
- `art/witch/witch_2.png` — same
- `art/enemy_sprites/ashen_knight_elite.png` — the enemy register
- `art/card_assets/combat_background.png` — the environment register
- `art/start_menu/main_menu_background_v2.png` — the ink-wash register for menus

**Style:** painted gouache-like illustration with visible brush texture and loose charcoal/slate/local-color ink contours. Match the Witch's balanced palette; do not impose warm-brown linework or a sepia grade.

**The world:** a fantasy world suspended in stillness. This no longer mandates eternal golden-hour lighting, or warm = alive and cool = stopped.

**Palette:** primarily varied cool and neutral slate, teal, moss green, muted violet and stone. Preserve character-specific colors. Amber, faded gold and ember orange are selective local accents, not a wash over the scene. Pale bone may be a local material highlight. Avoid pure-black or pure-white areas that destroy paint texture. No fixed warm-percentage quota.

**Light:** soft neutral or cool illumination by default; intentional warm sources may add localized accents. No obligatory low-left sun, golden sky or warm skin/cloth tint. Check the entire frame for excessive sepia and amber.

**No wind. No motion. No weather.** This is a hard rule for every environment, sprite, and illustration: banners hang straight down, smoke stands in a column, water is glass, flames are solid sculpted shapes, nothing drifts or blurs. A character's own hair or cloak may show *their* movement; the world behind them never moves.

**Characters vs enemies:** preserve readable silhouettes and distinct local palettes. Contained ember details may be warm; surrounding metal, cloth, stone and skin should retain their natural colors.

**One signature colour per character** (never on any other character): Monster Hunter dusky purple; Witch deep teal-green; Shadowfoot a single gold thread; Grove dull gold; Golemancer terracotta; Living Armor ember-orange seam light.

**Negative list (apply to everything):** photorealistic, 3d render, cel shading, anime gloss, sparkle eyes, neon, cyan, magenta, lens flare, bloom, pure black, pure white, grimdark, gore, skulls, snow, ice, frost, symmetrical composition, heroic pose, smiling, text, letters, watermark, signature, border, frame, blurry, extra limbs, motion blur, wind.

---

## 2. Delivery rules

- **PNG.** Transparent background where stated (real alpha channel — never a painted checkerboard, never a flat colour). No colour fringe on the alpha edge: no halo of the generation background colour around glows or wisps.
- Exact pixel sizes as stated. Do not add borders, frames, text, or watermarks.
- File names exactly as stated (lowercase, underscores).
- If a request cannot be met exactly, produce the closest thing and write a one-line note in `ART_ASSET_REQUESTS_NOTES.md` in this folder saying what differs.
- Do not modify any file not listed here. Do not delete anything.

---

## 3. Blockouts (composition references for backgrounds)

`art/reference/blockouts/` contains crude grey-rectangle layouts. They are **composition references only**: keep the arrangement, camera height, and where the sun and the big foreground shape are. Ignore their colours and crudeness entirely.

---

## 4. BATCH 1 — do these now

### 4A. Edits to existing files (write the result to the new path; leave the original)

| # | Source | Edit | Output |
|---|---|---|---|
| E1 | `art/shadowfoot/shadowfoot.png` | Remove the painted checkerboard behind the figure → real transparency. Recolour the purple scarf to dark ash-grey / deep slate (`#2A3040`), keep everything else. | `art/shadowfoot/shadowfoot_clean.png` (same size) |
| E2 | `art/witch/witch_2.png` | Remove the white background → real transparency, feathered hair edge. No other change. | `art/witch/witch_clean.png` |
| E3 | `art/enemy_sprites/cinder_imp.png` | Remove the red/green/yellow colour fringe around the ember glows and edges; keep the transparency clean. No other change. | `.../Enemy Sprites/cinder_imp_clean.png` |
| E4 | `art/enemy_sprites/smolder_shade.png` | Same fringe cleanup on the smoke wisps. | `.../Enemy Sprites/smolder_shade_clean.png` |
| E5 | `art/enemy_sprites/char_sentinel_elite.png` | Same fringe cleanup along the lower edge. | `.../Enemy Sprites/char_sentinel_clean.png` |
| E6 | `art/boss_sprites/fallen_obsidian_colossus.png` | Same fringe cleanup. | `.../Boss Sprites/obsidian_colossus_clean.png` |
| E7 | `art/boss_sprites/the_eternal_ember_alternate.png` | This image is being **reassigned as the final boss, the Lich**. Remove the yellow halo fringe around the glow; keep the figure and its glow. | `.../Boss Sprites/the_lich.png` |
| E8 | `art/card_assets/raw/card_back_1.png` (848×1264, 2:3) | Re-proportion to **3:4** by extending the design vertically-cropped/horizontally-extended as needed so nothing is squashed: output 900×1200. Keep the ember heart centred. Remove the white matte outside the card → transparent corners. | `.../Card Assets/card_back.png` (900×1200) |

### 4B. Backgrounds — 1920×1080, opaque, one each

Use the painted texture of the existing environments with the palette and floor plan in ART_DIRECTION.md. Combat backgrounds require eye-level staging, clear actor silhouettes and a shared ground baseline; the historical scenes below must be adapted to that requirement. No default sunset or warm foreground.

| # | Blockout | Scene | Output |
|---|---|---|---|
| B1 | `B1_town_square.png` | A farming town's square on the night of a harvest festival, seen at eye level from under the dark edge of a market awning (top-left of frame). A stone fountain right of centre whose water stands mid-fall like glass. An apple hangs in the air above a stall. Bunting hangs dead straight. Rooftops left and right under soft cool daylight; move the fountain beyond the actor staging floor. | `art/backgrounds/combat_act1_a.png` |
| B2 | `B2_granary_road.png` | The same valley, a dirt road between grain fields, eye-level camera across a clear level staging floor. Keep wagon remains small and behind the combatants. In the middle distance a hay wagon is tipping over, sheaves hanging in the air where they were thrown. Chaff suspended like snow. Soft cool daylight across the still grain. | `.../Backgrounds/combat_act1_b.png` |
| B3 | `B3_festival_green.png` | The festival green seen at eye level across an open courtyard; beams and hanging ropes stay at the outer edges. Below, a small distant harvest bonfire with contained warmth; its sculpted flames and fixed sparks never occupy the playable floor. Empty benches and tables around it, long shadows. This is a **boss arena**: keep the centre-bottom third uncluttered. | `.../Backgrounds/boss_act1.png` |
| B4 | `B4_map_valley.png` | The whole valley from a map-maker's height: a road as a pale line from bottom-left to top-right, a river as a still ribbon, a village with smoke standing in straight columns, hills at the top edge rim-lit from the far left. **Low detail and low contrast** — a node graph will be drawn on top of this, so nothing in it may compete: no strong shapes in the middle band. | `.../Backgrounds/map_act1.png` |
| B6 | `B6_death_road.png` | Lying on the ground beside the road, camera at grass level. Huge dark grass blades across the foreground, the road soft and out of focus ahead, soft neutral daylight fading into cool haze. One small sharp bird fixed in the sky. Quiet; nothing else. | `.../Backgrounds/death.png` |

### 4C. Character splash art — 1200×900 (4:3), opaque, six

A wide cinematic illustration of the character from the waist up, standing in the named place, placed off-centre (left or right third, never centred). Preserve the figure's individual palette against ashen blue-grey and cold teal haze. Use balanced neutral/cool lighting with small local warm accents. **Use the character's existing portrait as the face/costume reference** (paths in §1 and `art/<Name>/`). Nothing behind the figure moves.

| # | Character (reference file) | Place | The one frozen detail | Output |
|---|---|---|---|---|
| S1 | Monster Hunter (`Monster Hunter/Monster Hunter.png`) | a hillside track above a frozen town at dusk | a flock of birds hanging motionless mid-flight | `art/splash/monster_hunter_splash.png` |
| S2 | Shadowfoot (`Shadowfoot/Shadowfoot.png`, with the scarf recoloured as in E1) | a rooftop over a market square | a thrown coin that never lands, a crowd below mid-cheer | `.../Splash/shadowfoot_splash.png` |
| S3 | Witch (`Witch/Witch 2.png`) | a shuttered apothecary doorway on a cobbled lane | a spilled jar whose contents hang in the air | `.../Splash/witch_splash.png` |
| S4 | Grove (`Grove/Grove.png`) | the edge of an orchard | every blossom half-open, a single leaf suspended mid-fall | `.../Splash/grove_splash.png` |
| S5 | Golemancer (`Golemancer/Golemancer.png`) | a workshop yard with a half-built clay giant behind him | a bucket of water tipping, its water a frozen sheet | `.../Splash/golemancer_splash.png` |
| S6 | Living Armor (`Living Armor/Living Armor.png`) | a chapel nave lit through a broken window | dust in the light beam, perfectly still | `.../Splash/living_armor_splash.png` |

### 4D. New boss — The Eternal Ember (replacement), 1254×1254, transparent

The festival's great bonfire, given a body by centuries of people praying to it to keep them warm. A bonfire the size of a house whose flames are a solid sculpted shape, with the suggestion of a kneeling human figure inside the fire; crowd-worn stone steps and a few charred benches fused into its base. Enormous, slow, radiant, almost kind — not monstrous. Warm light comes from *it* (this is the one asset allowed to be its own light source); everything at its base cool slate. Square canvas, figure filling ~90 % of the height, feet dissolving into cool shadow, transparent background, no fringe.
→ `art/boss_sprites/the_eternal_ember.png`

### 4E. Card frames — 900×1200 (3:4), transparent outside the frame, four

Match the ornament, warm/cool split, and texture of `Card Assets/Card Frame 1.png`, re-proportioned to 3:4. The frame has: a title band near the top, a large art window in the upper ~45 %, a text box in the lower ~35 %, a round cost socket in the top-left corner (empty — the number is added by the game). The art window and the cost socket are **transparent holes**. Each of the four differs only by its accent colour on the ornament and the band:
- `card_frame_attack.png` — accent `#A03020`
- `card_frame_skill.png` — accent `#2060A0`
- `card_frame_power.png` — accent `#806020`
- `card_frame_curse.png` — accent `#602080`, ornament slightly withered
→ all into `art/card_assets/`

### 4F. UI icons — 256×256 each, transparent, flat two-tone

Style: bold, high-contrast silhouettes in pale bone `#F0E6C8` on transparent, with a single ember-orange `#E8723A` accent where noted. Brush-edged, not vector-crisp. Must read at 24 px. No text.

Into `art/ui/`:

| File | Icon |
|---|---|
| `icon_type_attack.png` | a single dagger blade at 45° |
| `icon_type_skill.png` | a closed hand, palm out |
| `icon_type_power.png` | a small flame with a ring around its base (flame in ember-orange) |
| `icon_type_curse.png` | an inverted drop with a crack |
| `icon_role_warrior.png` | crossed sword and axe |
| `icon_role_healer.png` | a four-pointed spark |
| `icon_role_defender.png` | a tower shield |
| `icon_intent_attack.png` | a downward sword |
| `icon_intent_multi.png` | two downward swords |
| `icon_intent_defend.png` | a tower shield |
| `icon_intent_buff.png` | an upward arrow with a spark |
| `icon_intent_debuff.png` | a downward arrow with a drop |
| `icon_intent_heal.png` | a cupped hand with a dot |
| `icon_intent_summon.png` | a circle with a smaller circle emerging |
| `icon_intent_special.png` | an asterisk-like burst |
| `icon_energy_full.png` | a filled ember droplet (ember-orange) |
| `icon_energy_empty.png` | the same droplet as an outline only |
| `icon_focus.png` | an eye half-closed with a spark |
| `icon_ability_monster_hunter.png` | a footprint with a chalk mark beside it |
| `icon_ability_shadowfoot.png` | a boot with a trailing line |
| `icon_ability_witch.png` | a sealed jar with a thread tied around it |
| `icon_ability_grove.png` | a seed inside a broken leaf |
| `icon_ability_golemancer.png` | a tower shield held in a hand |
| `icon_ability_living_armor.png` | a shield with a blade returning from it |
| `icon_lock.png` | a padlock |
| `icon_check.png` | a checkmark |

---

## 5. BATCH 2 — only after Aaron says Batch 1 is reviewed

- **Enemies, Act 2 (the Unfallen City — a walled city frozen in the last hour of a siege), 1254×1254 transparent, enemy rules from §1:** a wall soldier of the besieged (Skirmisher: light, quick, a broken spear), a wall soldier of the besiegers (Skirmisher: mud and rope, a ladder-hook), the bell-ringer (Disruptor: a thin man fused to his bell-rope, the bell above him mid-ring), the siege-ladder crew (Summoner: three figures and a ladder as one silhouette), the surgeon (Support: bloodless apron, bone saw, a lantern that is his ember), the gate-warden (Heavy: huge, a portcullis on his back). → `Enemy Sprites/act2_<name>.png`
- **Bosses:** *The Bride* (Act 1) — a woman in a wedding dress on a stone bridge, the procession behind her fused into one shape, petals fixed in the air, her bouquet the ember; *The Regent* (Act 2) — a gaunt figure on a throne too large, crown askew, a cradle beside the throne that has always been empty; *The Vigil* (Act 3) — a knot of many armoured heroes from many centuries fused into one mass, all facing a door, their torches the embers. 1254×1254 transparent. → `Boss Sprites/<name>.png`
- **Locked-character portraits (six, 1254×1254 transparent, same register as the existing portraits):** Revenant (M — a man who refused to stay dead before the freeze made that universal; grave-dirt, a rope burn, calm), Tempest (M — a storm given a man's will; dark clothing with gold catches, debris fixed around him), Mechanist (M — every fight leaves a mark on his cards; a satchel of engraved plates, ink on his fingers), Sibyl (F — she reads every future and they are all this one; a blindfold of thin gold, a bowl of still water), Echo (monster — a spirit made of reflections, a face that is several faces slightly offset), Hollow (monster — a void in the shape of a cloaked figure, emptied long before the lich). → `art/<Name>/<name>.png`
- **Act 2 and Act 3 backgrounds** — Aaron will supply blockouts.

---

*End of instructions. When finished, tell Aaron which files you wrote and list anything from §2's notes rule.*

## Image-tool progress — 2026-09-06
Batch 1 is in progress, not approved or complete. Built-in image generation used; originals preserved. Saved E1–E5 and B1 candidates to the requested paths. E1, E3, E4, E5 FAILED alpha validation (opaque painted checkerboards); do not integrate these candidates. E2 contains actual alpha but needs edge/identity review. B1 dimensions still need verification. Full deviations are tracked in ART_ASSET_REQUESTS_NOTES.md. Batch 2 remains untouched.
Source observation: current Shadowfoot already has a grey scarf and apparent transparency, unlike the described purple/checkerboard source; colored edge fringe remains.


### Validation update
All eight edit candidates, five backgrounds, six splashes, replacement Eternal Ember, and four frame candidates have now been saved. UI icons are in progress. The generator ignored some exact dimension requests: backgrounds 1672x941 (requested 1920x1080); splashes 1448x1086 (requested 1200x900); cards 1086x1448 (requested 900x1200). E1/E3–E8, replacement Ember, and skill/power/curse frames are opaque RGB with painted checkerboards. Witch cleanup and attack frame have actual alpha but edge artifacts remain. These are closest-available review candidates under section 2, NOT production-ready assets. Do not integrate unchecked.

