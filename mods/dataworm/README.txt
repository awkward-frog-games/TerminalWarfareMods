Data Worm — User Minigame Mod
=============================

Install:
  Copy this entire folder into your Terminal Warfare mods directory:

  Steam / fused build (Windows):
    %APPDATA%\terminal_warfare\mods\dataworm\

  Development (love .):
    %APPDATA%\LOVE\terminal_warfare\mods\dataworm\

  macOS fused:
    ~/Library/Application Support/terminal_warfare/mods/dataworm/

  Linux:
    ~/.local/share/love/terminal_warfare/mods/dataworm/

Folder layout:
  dataworm.lua        — main module (required)
  sounds.lua          — sound event → filename mapping (optional overrides)
  *.wav / *.mp3       — optional sound files (see Sound effects below)
  dataworm-icon.png   — optional desktop shortcut icon
  dataworm.png        — optional boot splash screen

Run:
  Restart the game (mods load at startup), then type: dataworm

Controls:
  Arrow keys — move | P — pause | ESC — quit

Sound effects:
  Place any of these files in this folder (.mp3, .wav, or .ogg).
  Missing files are silent. Edit sounds.lua to use custom filenames.

  Event ID     Default filename   When it plays
  ----------   ----------------   -------------
  eat          eat                Snake collects food
  turn         turn               Direction change
  death        death              Collision game over
  high_score   high_score         New high score

User mods are always unlocked — no cheat codes required.
