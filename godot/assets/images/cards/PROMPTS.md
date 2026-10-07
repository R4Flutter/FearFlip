# Card art (plans/06 P3)

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
