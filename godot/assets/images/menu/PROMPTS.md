# Title dashboard art

`scripts/main_menu.gd` loads these exact files. Generated originals live in `src/` (has `.gdignore`, not imported);
the copies here are cropped to their alpha bounds and downscaled to ~2x display size.

| File | Used as | Notes |
|---|---|---|
| `menu_bg.png` | key art, cover-fit on a drifting parallax stage | spots on it (portal, braziers) are pinned as fractions in `main_menu.gd` |
| `menu_demon.png` | apparition in the sky | painted on pure black, drawn additively (black = invisible) |
| `menu_hero.png` | foreground hero + ledge, own parallax layer | transparent |
| `logo.png` | title | split at `LOGO_SPLIT` (x fraction) so FLIP can turn over |
| `ui_frame.png` / `ui_frame_active.png` | menu rows + quest cards | active = red-glow version, built from the frame with PIL |
| `ui_play_button.png` | big PLAY | text is drawn by Godot, art must stay text-free |
| `ui_icons.png` | 4x3 icon atlas, 160 px cells | order = `enum Icon` in `main_menu.gd` |
| `card_*.png` | mode cards | cover-fit, any aspect |

Font (optional): `res://assets/fonts/ui.ttf` (Oswald SemiBold, Google Fonts, OFL). Falls back to Impact/system.

Style line used for all art: dark fantasy horror mobile game art, semi-realistic painterly anime style, crimson red +
deep violet + ember orange, volumetric fog, glowing lava rim light, no text/UI/watermark.

## Act-Runs (plans/06 Phase 1)

All optional: until a file exists the game shows a stand-in (tinted panel, "LOCKED" text, plain gold words).
Drop the PNG here with the exact name and Godot picks it up on the next import; no code change needed.
Keep the full-size original in `src/`, and put a copy downscaled to ~2x display size here (same rule as above).

| File | Used as | Generate at | Ship here at |
|---|---|---|---|
| `act_1.png` … `act_5.png` | act picker cards (`main_menu.gd` `_act_card`, cover-fit 200x290) | portrait 2:3, e.g. 1024x1536 | 400x600 |
| `act_locked.png` | padlock over locked act cards (110x110) | 1024x1024, transparent | 256x256 |
| `act_cleared_burst.png` | flare behind "ACT CLEARED" when the Gate is beaten (`main.gd` `_show_act_cleared`, drawn additively) | 3:1, e.g. 1536x512, on pure black | 1440x480 |

Card layout rule (all five): portrait, edge to edge, no frame. Keep the subject in the top 60%; the bottom 40% sits
under a dark gradient with the act name. The sides may be cropped. No text, letters or numbers anywhere.

**act_1.png: AWAKENING** (cold blue)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. A lone young survivor
> seen from behind holds a flashlight at the entrance of a vast stone maze at night; cold blue moonlight, tall wet
> walls, drifting fog, a thin line of red glow leaking from far down the corridor, two faint glowing keys floating in
> the dark. Mood: uneasy calm before the hunt. Deep navy and steel blue, one small ember-red accent, volumetric
> fog, rim light, high detail, no text, no UI, no watermark.

**act_2.png: HUNTED** (blood red)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. A horned Devil
> silhouette with burning eyes fills the far end of a long maze corridor drowned in red light; claw marks gouged
> into the stone walls; in the foreground a young survivor sprints toward the viewer, red scarf trailing, dust and
> embers whipping past. Mood: the chase. Crimson and black with lava rim light, volumetric red fog, motion, high
> detail, no text, no UI, no watermark.

**act_3.png: MIND BREAK** (deep violet)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. A stone maze folding
> over itself like an impossible Escher drawing: corridors running up walls and across the ceiling, staircases
> into nowhere; the image is split down the middle by a jagged glowing crack, the left half cold blue and calm, the
> right half blood red and hellish; a small survivor floats upside down, disoriented. Mood: reality breaking. Deep
> violet, cold blue and crimson, volumetric fog, high detail, no text, no UI, no watermark.

**act_4.png: PRECISION HELL** (ember orange)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. A narrow path of
> cracked stone floor tiles hanging over a bottomless abyss of embers and lava; glowing orange cracks spiderweb
> through the tiles, several tiles already crumbling and falling away; a young survivor balances mid-step,
> flashlight beam on the next tile; a faint circular rune like a clock face glows in the smoke above. Mood: one wrong
> step and you fall. Ember orange and charcoal black, heat haze, rising sparks, high detail, no text, no UI, no
> watermark.

**act_5.png: THE BREAKER** (crimson and black)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. The bottom of the
> maze: a colossal horned demon rises behind a shattered iron gate bound with snapped chains, molten cracks across
> its body, eyes blazing; a tiny survivor silhouette stands before it on a ledge of broken stone, flashlight raised.
> Mood: the final escape. Crimson, black and molten gold, lava glow from below, volumetric smoke, epic scale, high
> detail, no text, no UI, no watermark.

**act_locked.png**
> A heavy rusted iron padlock wrapped in thick chains, front view, perfectly centered, isolated on a transparent
> background. Dark fantasy painterly style matching a horror mobile game, worn metal with scratches, faint ember-red
> rim light along the edges, soft shadowless lighting so it sits cleanly over any art. No text, no background, no
> watermark.

**act_cleared_burst.png**
> A radiant victory burst for a dark fantasy horror game: an ornate demonic seal shattering outward from the center,
> shards of glowing gold and crimson, light rays and sparks exploding horizontally, wide 3:1 composition, centered
> and symmetrical, empty middle area for overlaid words, painted on a pure black background (the black will be made
> invisible). Gold, crimson and ember orange glow, painterly, high detail, no text, no letters, no watermark.

No 3D models are needed for Phase 1. Phase 3 (Sanctuary altar, Gate arch) will come with its own model prompts.

## Meta hub (plans/06 Phase 5)

All optional, same rules as above: drop the PNG here with the exact name and it shows up on the next import; until
then the screens use flat panels and plain dark backgrounds. No 3D models are needed for Phase 5.

| File | Used as | Generate at | Ship here at |
|---|---|---|---|
| `hub_entry.png` | the frame of every line in the four hub screens (9-slice, 24 px corners, tinted per line) | 600x120, transparent | as generated |
| `hub_altar.png`, `hub_mirror.png`, `hub_bestiary.png`, `hub_archive.png`, `hub_daily.png` | behind each hub list at 30% opacity, cover-fit | 16:9, 1920x1080 | 1280x720 |
| `beast_<id>.png` (8, ids below) | beside a bestiary entry once you've met it, cover-fit 120x72 | 5:3, 1000x600 | 240x144 |
| `ending_bg.png` | behind an act's ending text at 35% opacity (in the maze, after a Gate) | 16:9, 1920x1080 | 1280x720 |

Backgrounds: keep the centre 70% dark and empty (text sits there), light only at the edges.

**hub_entry.png**
> A horizontal UI panel frame for a dark fantasy horror game, 600x120 PNG with transparency: a thin aged-iron
> border with small rivets and faint engraved runes in the four corners, a very dark translucent black-violet
> interior (about 60% opaque), a faint ember-red glow along the inner edge. Symmetrical; all the detail sits in the
> 24 px corners and the straight edges between them are plain so it stretches cleanly as a 9-slice. No text, no
> icons, no watermark.

**hub_altar.png: THE ALTAR**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a black stone altar in a ruined
> chapel at the bottom of a maze, a cracked offering bowl heaped with glowing violet crystal shards, melted red
> candles, iron chains hanging out of the dark above, faint occult sigils carved into the floor. The centre stays dark
> and empty; light comes only from the shards and candles at the edges. Crimson, deep violet and ember orange,
> volumetric haze, no text, no UI, no watermark.

**hub_mirror.png: THE MIRROR**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a tall cracked antique mirror at
> the end of an abandoned hospital ward corridor. The reflection shows the same corridor bathed in red, wet walls and
> a faint horned silhouette standing far back in it. Five small star-shaped candle holders on the ornate frame, two of
> them lit. The centre stays dark; cold blue on the near side, blood red inside the glass, no text, no UI, no
> watermark.

**hub_bestiary.png: THE BESTIARY**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a rotting corkboard wall in a
> forgotten doctor's study, covered in pinned sketches and torn pages of monsters, a tall horned figure drawn in red
> chalk at its heart, red string between the pages, specimen jars on a shelf, one flickering desk lamp. The centre
> stays dark; ember and violet light at the edges, no readable text, no UI, no watermark.

**hub_archive.png: THE ARCHIVE**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a dusty hospital records room,
> tall steel filing cabinets, one drawer pulled open and spilling yellowed patient files and handwritten notes, a
> desk lamp with a weak warm bulb, a 1987 wall calendar half in shadow. The centre stays dark; warm lamp light and
> deep violet shadow, no readable text, no UI, no watermark.

**hub_daily.png: THE DAILY** (P6)
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a cracked stone calendar wall at
> the heart of a maze, one day carved deeper than the rest and glowing ember red, tally marks and old scratched dates
> fading into the dark around it, a single candle burning on a ledge below. The centre stays dark and empty; ember
> and violet light at the edges only, no readable text or numbers, no UI, no watermark.

**ending_bg.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: looking down a stone stairwell
> that spirals into darkness, lit from far below by a faint red glow; hundreds of tally marks scratched into the wall
> beside the first steps. The centre stays very dark and empty for text. Crimson and charcoal, volumetric haze, no
> text, no UI, no watermark.

**Bestiary portraits** (one prompt each; start every one with "Dark fantasy horror game illustration, semi-realistic
painterly anime style, 5:3, the subject centred so a small crop still reads, volumetric fog, no text, no UI, no
watermark:")

| File | Subject |
|---|---|
| `beast_devil.png` | a tall patient horned figure standing in a dim red maze corridor, long arms, face in shadow except two burning eyes |
| `beast_nightmare.png` | one corridor split down the middle: a cold blue clean half and a red, wet, veined half |
| `beast_flipping_time.png` | a corridor twisting like a wrung cloth around a cracked clock face, red light pulling at the edges |
| `beast_cracked_floor.png` | stone floor tiles split by glowing orange cracks, one tile gone and embers glowing far below |
| `beast_the_clock.png` | an old hospital wall clock with its hands melting, pale morning light leaking under a closed door |
| `beast_phantom.png` | a pale translucent figure in an old nurse's uniform at the end of a blue corridor, a flashlight beam flickering on it |
| `beast_sentinel.png` | a mechanical searchlight eye in the ceiling sweeping a corridor, a heavy iron eyelid half closed |
| `beast_ripper.png` | ceiling lights dying one by one toward the viewer, a long clawed shape rushing out of the dark |
