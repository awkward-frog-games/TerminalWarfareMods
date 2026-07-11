Pokemon Colorscripts — User Content Mod for Terminal Warfare
============================================================

This optional user mod adds ANSI colorscript startup avatars to the terminal.
It is NOT bundled with the game to avoid shipping third-party trademarked content.

Install
-------
Copy this entire folder into your Terminal Warfare save-directory mods path:

  Linux:   ~/.local/share/love/terminal_warfare/mods/pokemon-colorscripts/
  macOS:   ~/Library/Application Support/LOVE/terminal_warfare/mods/pokemon-colorscripts/
  Windows: %APPDATA%/LOVE/terminal_warfare/mods/pokemon-colorscripts/

For local development from the repo:

  ./scripts/install_sample_mods.sh

Restart the game after installing.

Usage
-----
Once installed, the terminal gains an `avatar` command:

  avatar              Show current startup avatar preference
  avatar list         List available sprite names
  avatar show <name>  Preview a sprite in the terminal
  avatar set random   Show a random sprite on each terminal open
  avatar set <name>   Show a fixed sprite on each terminal open
  avatar off          Disable startup avatar (default)

Attribution
-----------
Sprite data from pokemon-colorscripts (MIT License):
  https://gitlab.com/phoneybadger/pokemon-colorscripts

Box art sprites from PokeSprite:
  https://msikma.github.io/pokesprite/

Pokemon designs, names, and branding are trademarks of The Pokemon Company.
This mod is provided separately for users who choose to install it.

Maintainers
-----------
Run vendor.sh from this folder to refresh sprites from upstream.
