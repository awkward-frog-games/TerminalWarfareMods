Terrain Barrage — User Minigame Mod
===================================

Install:
  Copy this entire folder into your Terminal Warfare mods directory:

  Steam / fused build (Windows):
    %APPDATA%\terminal_warfare\mods\terrainbarrage\

  Development (love .):
    %APPDATA%\LOVE\terminal_warfare\mods\terrainbarrage\

  macOS fused:
    ~/Library/Application Support/terminal_warfare/mods/terrainbarrage/

  Linux:
    ~/.local/share/love/terminal_warfare/mods/terrainbarrage/

Folder layout:
  terrainbarrage.lua  — main module (required)
  sounds.lua          — sound event → filename mapping (optional overrides)
  *.wav / *.mp3       — optional sound files (see Sound effects below)

Run:
  Restart the game (mods load at startup), then type: terrainbarrage

Controls:
  Left / Right (A / D, stick) — raise / lower the barrel (hold to sweep)
  Up / Down (W / S, stick)    — more / less power (hold to sweep)
  Space / Enter / pad A       — fire
  P / gamepad Start — pause (R in the pause menu restarts)
  R / gamepad A      — retry after a game over
  ESC                — quit

The dotted guide shows only the start of the arc; read the wind and your last
three impact markers. Shells can hit a tank directly, and a blast too close to
your own tank damages you as well.

Sound effects:
  Place any of these files in this folder (.mp3, .wav, or .ogg).
  Missing files are silent. Edit sounds.lua to use custom filenames.

  Event ID     Default filename   When it plays
  ----------   ----------------   -------------
  fire         fire               Cannon fired
  impact       impact             Shell impact
  tank_hit     tank_hit           Direct tank hit
  win          win                Victory
  lose         lose               Defeat

User mods are always unlocked — no cheat codes required.
