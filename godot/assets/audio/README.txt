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
