FearFlip audio assets.

Canonical runtime filenames:
- calm_loop.mp3
- intense_loop.mp3
- heartbeat.mp3
- fahhhhh_flippingtime.mp3
- devil_approach.wav
- low_time_alarm.wav
- low_time_alarm_10s.wav
- safe_zone_sound.mp3
- winning_soundeffect.mp3
- game_lost_soundeffect.mp3
- glitch_screen_sound_effect.mp3

Legacy aliases are kept for backward compatibility:
- wining_soundeffect.mp3
- gamelost_soundeffect.mp3

Added 9 Oct 2026 (ElevenLabs Sound Effects API):
- sfx_map_open.mp3, sfx_map_close.mp3, sfx_map_snap.mp3 (paper map, PaperMap)
- theme_main.mp3 (main menu theme, 30 s seamless loop; main_menu.gd MUSIC)

Breathing (main.gd::_breath_loop), generated 9 Oct 2026 with these prompts:
ElevenLabs Sound Effects, model eleven_text_to_sound_v2, loop: true, prompt_influence 0.6:
- sfx_breath_calm.mp3 (8 s): "Close-mic first-person human breathing, slow, shaky and nervous,
  in through the nose and out through the mouth, a frightened person creeping down a dark silent
  corridor trying to stay quiet, dry room, no music, no voice, no footsteps, seamless loop"
- sfx_breath_heavy.mp3 (6 s): "Close-mic first-person heavy panting right after a sprint, ragged
  fast breaths in and out through the mouth, exhausted and scared, dry room, no music, no voice,
  no footsteps, seamless loop"
Levels: PlayerFeel breath_volume_db / breath_heavy_volume_db.

Through the wall (main.gd::_slam_wall): not generated yet; until they exist sfx_floor_crack.mp3 stands in, pitched down.
ElevenLabs Sound Effects, model eleven_text_to_sound_v2, loop: false, prompt_influence 0.6:
- sfx_wall_slam.mp3 (1.2 s): "One heavy blow on the far side of a thick stone wall, a deep muffled thud
  with a short crunch of grit and a low rumble that dies fast, heard from inside a dark corridor, something
  huge pounding to get through, dry room, no music, no voice"
- sfx_wall_break.mp3 (2.5 s): "A thick stone wall bursting apart from a massive impact, a sharp crack then
  heavy chunks of masonry crashing onto a stone floor, grit and dust raining down after, close and loud, a
  monster smashing through, dry room, no music, no voice"

The wake cut's roar (main.gd::_build_devil_fx, played on the runtime "Echo" bus: reverb + two delay taps, sent to SFX).
Not generated yet; until it exists sfx_devil_wakes.mp3 at pitch 0.8 stands in.
- sfx_devil_roar.mp3 (2.5 s): "A huge demonic creature's roar in a stone corridor, starting as a wet guttural
  snarl and swelling into a long furious bellow with a rasping animal edge, deep and inhuman, close and loud,
  dry room with no reverb (the game adds the echo), no music, no voice, no words"
