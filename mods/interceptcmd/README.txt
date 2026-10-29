Intercept Command — User Minigame Mod
======================================

Install:
  Copy this entire folder into your Terminal Warfare mods directory:

  Steam / fused build (Windows):
    %APPDATA%\terminal_warfare\mods\interceptcmd\

  Development (love .):
    %APPDATA%\LOVE\terminal_warfare\mods\interceptcmd\

  macOS fused:
    ~/Library/Application Support/terminal_warfare/mods/interceptcmd/

  Linux:
    ~/.local/share/love/terminal_warfare/mods/interceptcmd/

Folder layout:
  interceptcmd.lua    — main module (required)
  sounds.lua          — sound event → filename mapping (optional overrides)
  *.wav / *.mp3       — optional sound files (see Sound effects below)

Run:
  Restart the game (mods load at startup), then type: interceptcmd

Controls:
  Mouse / Arrows / WASD / stick — move the crosshair
  Click / Space / pad A         — fire from the nearest silo with ammo
  1 / 2 / 3 (pad LB / Y / RB)   — fire from the left / centre / right silo
  P / gamepad Start — pause (R in the pause menu restarts)
  R / gamepad A      — retry after a game over
  ESC                — quit

Surviving nodes and unspent counter-missiles score a bonus at the end of each wave.

Sound effects:
  Place any of these files in this folder (.mp3, .wav, or .ogg).
  Missing files are silent. Edit sounds.lua to use custom filenames.

  Event ID     Default filename   When it plays
  ----------   ----------------   -------------
  launch       launch             Counter-missile launched
  explode      explode            Intercept explosion
  node_hit     node_hit           Node destroyed
  wave_start   wave_start         New wave begins
  win          win                All waves cleared
  game_over    game_over          All nodes lost

User mods are always unlocked — no cheat codes required.
