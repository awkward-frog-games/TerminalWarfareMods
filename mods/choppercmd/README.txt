Chopper Commando — User Minigame Mod
=====================================

Install:
  Copy this entire folder into your Terminal Warfare mods directory:

  Steam / fused build (Windows):
    %APPDATA%\terminal_warfare\mods\choppercmd\

  Development (love .):
    %APPDATA%\LOVE\terminal_warfare\mods\choppercmd\

  macOS fused:
    ~/Library/Application Support/terminal_warfare/mods/choppercmd/

  Linux:
    ~/.local/share/love/terminal_warfare/mods/choppercmd/

Folder layout:
  choppercmd.lua    — main module (required)
  sounds.lua        — sound event → filename mapping (optional overrides)
  *.wav / *.mp3     — optional sound files (see Sound effects below)

Run:
  Restart the game (mods load at startup), then type: choppercmd

Controls (Chopper Commando / chopper258 style):
  Arrow keys / WASD / stick — fly (momentum-based)
  Space (pad A)              — machine gun (uses ammo)
  B (pad X)                  — drop bomb (uses ammo)
  M (pad Y)                  — homing missile
  N (pad RB)                 — nuke
  G (pad LB)                 — toggle landing gear
  Up (hold)                  — take off when landed
  P / pad Start              — pause
  ESC                        — quit

Campaign missions (press SPACE at each briefing):
  1A — Destroy the P-77 helicopter east of Ocale Base
  2A — Stop the inbound cruise missile before it hits base
  4A — Destroy the Enemy Intelligence building
  5A — Take out the enemy radar installation

Complete the objective, then return and land at Ocale Base.
Press 1-4 at the briefing screen to jump to a specific mission.
Press R (or SPACE) after a failed mission to retry it from the score you
started it with. Bombs, missiles and nukes damage everything in their blast,
including your own chopper; enemy tanks can be destroyed.

Based on Mark Currie's Chopper Commando (1990), via the chopper258 port:
  https://github.com/loadzero/chopper258

Sound effects:
  Place any of these files in this folder (.mp3, .wav, or .ogg).
  Missing files are silent. Edit sounds.lua to use custom filenames.

  Event ID          Default filename    When it plays
  ---------------   -----------------   ---------------------------
  shoot             shoot               Machine gun fired
  bomb_drop         bomb_drop           Bomb released
  missile           missile             Missile launched
  nuke              nuke                Nuke released
  explosion         explosion           Explosion
  enemy_destroyed   enemy_destroyed     Target destroyed
  land              land                Landed on pad
  rearm             rearm               Rearmed at Ocale Base
  status_hit        status_hit          Chopper damaged
  crash             crash               Chopper crashed
  mission_complete  mission_complete    Mission complete

User mods are always unlocked — no cheat codes required.
