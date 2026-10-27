# FearFlip

A 2D horror maze game in the style of Pokémon Ash Gray (FireRed-era top-down
pixel art, made scary). Reach the exit while the world keeps flipping your
controls, find the keys, hide in blue spirit candles and stay ahead of the
Devil.

Built with Flutter. The web build is made for **CrazyGames** (see
[docs/crazygames_submission.md](docs/crazygames_submission.md)); the same app
runs on Android and iOS.

## Play modes

- **Campaign:** 100 stages in 5 worlds, each world with its own twist, 3 stars
  per stage, a gate stage with a chest every 10 stages.
- **Endless Night:** one maze after another until you fall.
- **Daily Nightmare:** one maze a day, the same for every player.

Around them: souls to collect and spend (runners, lanterns, trails,
power-ups), a 7-day login calendar, 3 daily missions, free and video chests,
and 24 achievements.

## Run it

```bash
flutter pub get
flutter run -d chrome          # web
flutter test                   # tests
bash tool/build_crazygames.sh  # the CrazyGames upload zip
```

Test builds can add `--dart-define=FF_DEV_KEYS=true`: in the maze, F8 escapes
and F9 is caught by the Devil (compiled out of normal builds).

## Where things are

| Path | What |
|---|---|
| `lib/arcade/` | The app: dashboard and menus (`screens/`), the UI kit (`ui/`), progress and economy (`model/`, `progress_controller.dart`), the CrazyGames bridge (`platform/`) |
| `lib/presentation/gameplay/` | The maze: `game_screen.dart` (+ `game_screen_arcade.dart` for modes, souls, power-ups), `maze_painter.dart`, `pixel_sprites.dart` |
| `lib/game/` | Traps, the key hunt, the Daily Nightmare rules |
| `web/index.html` | Loading screen and the CrazyGames SDK bridge (`window.ffcg`) |
| `assets/` | Tilesets and art (`images/2d/`), sounds (`audio/`, menu sounds in `audio/ui/`), fonts |
| `tool/` | Art and audio pipelines, `build_crazygames.sh`, `make_covers.py` |
| `store/` | Covers and icon for the store listing |

Fonts: Jacquard 12 and Jersey 15 by Sarah Cadigan-Fried, SIL Open Font
License (`assets/fonts/OFL-*.txt`). Menu sounds are synthesised by
`tool/audio/ui_sfx.py`.
