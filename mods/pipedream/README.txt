Data Pipeline (pipedream) — User Minigame Mod
==============================================

Install:
  Copy this entire folder into your Terminal Warfare mods directory:

  Steam / fused build (Windows):
    %APPDATA%\terminal_warfare\mods\pipedream\

  Development (love .):
    %APPDATA%\LOVE\terminal_warfare\mods\pipedream\

  When developing from the repo, mods in ./mods/pipedream/ load automatically.

  macOS fused:
    ~/Library/Application Support/terminal_warfare/mods/pipedream/

  Linux:
    ~/.local/share/love/terminal_warfare/mods/pipedream/

Folder layout:
  pipedream.lua   — main module (required)
  sounds.lua      — sound event → filename mapping (optional overrides)
  *.wav / *.mp3   — optional sound files (see Sound effects below)

Run:
  Restart the game (mods load at startup), then type: pipedream

Controls:
  Left-click a tile         — rotate pipe 90° clockwise
  Right-click a tile        — rotate pipe 90° counter-clockwise
  Arrows / WASD / stick     — move the tile cursor
  Space / Enter / pad A     — rotate the cursor tile clockwise
  Q / pad X                 — rotate the cursor tile counter-clockwise
  P / gamepad Start — pause (R in the pause menu restarts)
  R / gamepad A      — retry after a game over
  ESC                — quit

Goal:
  Connect the IN port to OUT before the timer runs out. Every stage has
  at least one route; the clock stops as soon as the flow connects.
  Clear 10 stages to win. Straights, corners, tees, and crosses each
  rotate in place — a corner stays a corner.

Sound effects:
  Place any of these files in this folder (.mp3, .wav, or .ogg).
  Missing files are silent. Edit sounds.lua to use custom filenames.

  Event ID     Default filename   When it plays
  ----------   ----------------   -------------
  rotate       rotate             Tile rotated
  flow         flow               Path connected to OUT
  stage_clear  stage_clear        Stage completed
  win          win                All 10 stages cleared

User mods are always unlocked — no cheat codes required.
