# Card art and the card picker (plans/06 P3 + P4)

`scripts/card_choice.gd` loads `res://assets/images/cards/<id>.png` when the file exists and shows it in a
130 px band at the top of the card (cover-fit, so any aspect works; keep the subject centred, top and bottom
may crop). Until a file lands, the card is a dark panel edged in its kind's colour (rule = ember, door = gold,
Gate = blood red, Sanctuary = blue) with its name and rule. No code change is needed when art arrives.

Format: PNG, 880x520 (2x the display size), no transparency needed. Images are git-ignored on the
3D branch, so they stay on your machine.

Style line for every card: dark fantasy horror mobile game art, semi-realistic painterly anime style, first-person
stone maze at night, crimson red + deep violet + ember orange (cold blue where it says WAKE), volumetric fog,
glowing rim light, no text/UI/watermark/letters/numbers.

| File | Card | Subject |
|---|---|---|
| `thick_fog.png` | rule | a narrow stone maze corridor swallowed by fog, a flashlight beam dying a few metres in |
| `safe_haven.png` | rule | four glowing blue floor rings at a dark junction, their light guttering low |
| `blackout.png` | rule | dead ceiling lamps over a black corridor, one flashlight cone the only light |
| `hungry_dark.png` | rule | a horned devil silhouette sprinting down a corridor, eyes and mouth burning like embers |
| `short_fuse.png` | rule | a burning fuse snaking across the maze floor toward a cracked hourglass |
| `cracked_earth.png` | rule | floor tiles split by glowing orange cracks, one collapsing into a pit |
| `greed.png` | rule | an iron-banded chest glowing at the end of a dead-end alcove, a shadow looming at the turn |
| `deaf_night.png` | rule | a silent corridor, a single red heartbeat line floating in the dark |
| `mirror_night.png` | rule | the maze reflected upside down in a cracked mirror, cold blue above, blood red below |
| `static.png` | rule | a torn paper map dissolving into TV static and ash |
| `tight_clock.png` | rule | a stopwatch with blood-red hands, sand pouring out fast, maze walls leaning in |
| `relentless.png` | rule | the devil striding through a rift between a cold blue world and a red one, never slowing |
| `normal.png` | door | a plain stone doorway into a dim maze corridor |
| `shrine.png` | door | a candlelit shrine niche in the maze wall, a violet omen sigil floating over offerings |
| `vault.png` | door | a heavy iron vault door half open, gold light and chests inside, keys hanging from hooks |
| `hunt.png` | door | a blood-red door gouged by claws, a horned shadow behind its peephole |
| `mystery.png` | door | a door wrapped in black fog, violet smoke leaking from the keyhole |
| `first_blood.png` | Gate | the devil already awake at the far end of a long corridor, the player tiny in the foreground |
| `ritual.png` | Gate | five glowing keys floating in a ring of red candles, an hourglass burning above |
| `mind_break.png` | Gate | a maze shaped like a cracked skull, flickering between cold blue and red |
| `precision_hell.png` | Gate | a corridor of cracked glowing tiles over an abyss, a clock face burning in the ceiling |
| `the_breaker.png` | Gate | the devil tearing through the wall between the blue and red worlds, a final chase |
| `sanctuary.png` | Sanctuary | a small quiet candlelit chamber in soft blue light, an omen token resting on an altar |

---

## The picker itself (added 7 Oct 2026: the stand-in panels look cheap)

Today every card is a flat dark rectangle with a 2 px coloured line, and with no art its top 60% is empty. These three
files replace the stand-in. The kind colour (ember rule, gold door, red Gate, blue Sanctuary, violet omen, magenta
curse) stays **code-drawn** as a glow around the frame, so a single neutral frame serves every kind.

**`card_frame.png`**: the card body. 500x680 PNG (exactly 2x the 250x340 card), drawn stretched over the whole card;
the name, rule text and art are drawn on top by Godot.
> Ornate trading-card frame for a dark fantasy horror game, perfectly flat front view, symmetric, portrait 25:34.
> The border is blackened wrought iron with thin worn bone-gold filigree and hairline cracks, with a small horned
> skull crest at the top centre and a small empty round gem socket at the bottom centre. The border is thin: under 5%
> of the width on the sides, and the crest and socket under 8% of the height. Everything inside the border is smooth,
> very dark charcoal-violet stone with a faint smoke texture, low contrast and evenly lit, so white text stays
> readable on it. The frame fills the canvas edge to edge, with no background showing. No text, letters, numbers or
> symbols inside the panel; no watermark.

**`pick_backdrop.png`**: behind the cards on the pick screens (curse, start kit, omens, doors, RETURN / DESCEND).
1920x1080 PNG or JPG.
> Dark fantasy horror game background, 16:9, seen from directly above: an old black stone ritual table. Melted red
> candles and wax pools ring the outer edges, with faint chalk ritual-circle lines and a few scattered old keys and
> bones near the borders. Red and violet candlelight and a heavy vignette. The central 70% stays very dark and empty
> (the cards sit there). Painterly, volumetric haze, no text, no UI, no watermark.

**`omen_sigils.png`**: the omen cards' art (one big glowing sigil in the art band) and the omen icons in the HUD.
1024x1024 PNG, a 4x4 grid of 256 px cells, read left to right then top to bottom in the order below. Draw white and pale
lilac on pure black (Godot tints them violet and draws them additively, so the black disappears). The shapes must
read at 28 px, so keep them bold and simple.
> A 4x4 sprite sheet of 16 occult sigil icons for a dark fantasy horror game, each centred in its own square cell
> on a pure black background, glowing white and pale lilac lines, thick bold strokes, simple readable shapes, soft
> outer glow, consistent line weight, flat front view, no text, no letters, no numbers. Cells in order:
> 1 a flowing veil swept by a fast curved arrow; 2 a heart encased in sharp ice crystals; 3 a ring with a small
> keyhole at the top; 4 an hourglass held by a skeletal hand; 5 a single wide-open eye whose pupil is a crack;
> 6 an owl face with huge round eyes; 7 two crescent moons back to back, mirrored; 8 a feather resting on a cracked
> tile; 9 a compass rose over a fragment of maze; 10 two crossed old keys; 11 an open hand with a single blood drop;
> 12 an eye seen through a faint ghostly wall grid; 13 a wisp of breath rising out of a ring; 14 a lantern shaped
> like a heart; 15 a footprint with concentric echo rings; 16 a footprint with a crossed-out sound wave.

(Cells 1–16 = Quick Veil, Cold Blood, Circle Keeper, Borrowed Time, Keen Eye, Night Owl, Twin Flip, Feather Step,
Cartographer, Locksmith, Blood Pact, Ghost Sight, Last Breath, Lantern Heart, Echo Step, Soft Soles: the order of
`Cards.OMENS`.)

## New cards from P4 (same 880x520 card art as the table above)

The four curses reuse their twin rule card's art (`blackout.png`, `hungry_dark.png`, `short_fuse.png`,
`deaf_night.png` above), so only these three are new.

| File | Card | Subject |
|---|---|---|
| `no_curse.png` | curse | a single unlit black candle on a clean stone ledge, one thin wisp of smoke, calm faint blue light |
| `return.png` | the way on | a worn stone stairway climbing up out of the maze toward a pale grey dawn, a lantern left on the steps |
| `descend.png` | the way on | a spiral stairway plunging down into red glowing depths, embers rising, maze walls continuing far below |

## Priority

1. `card_frame.png` + `pick_backdrop.png`: these fix the picker on their own.
2. `omen_sigils.png`, then the 23 rule/door/Gate art files above (none have arrived yet) and the 3 new ones.
