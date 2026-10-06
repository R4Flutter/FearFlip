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
