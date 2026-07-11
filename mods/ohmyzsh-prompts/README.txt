Oh My Zsh Prompt Themes — User Content Mod for Terminal Warfare
================================================================

This optional user mod adds oh-my-zsh-inspired shell prompt themes to the
terminal. Themes are JSON ports of popular oh-my-zsh prompts and use Powerline
symbols supported by the game's Nerd Font.

Install
-------
Copy this entire folder into your Terminal Warfare save-directory mods path:

  Linux:   ~/.local/share/love/terminal_warfare/mods/ohmyzsh-prompts/
  macOS:   ~/Library/Application Support/LOVE/terminal_warfare/mods/ohmyzsh-prompts/
  Windows: %APPDATA%/LOVE/terminal_warfare/mods/ohmyzsh-prompts/

For local development from the repo:

  ./scripts/install_sample_mods.sh

Restart the game after installing.

Usage
-----
Once installed, the terminal gains a `prompt` command:

  prompt              Show current shell prompt preference
  prompt list         List available theme names
  prompt show <name>  Preview a theme
  prompt set random   Random theme each session (re-rolled on open)
  prompt set <name>   Fixed theme (e.g. prompt set agnoster)
  prompt off          Reset to default prompt

Themes included
---------------
  robbyrussell  — default oh-my-zsh look (status arrow + path)
  agnoster      — Powerline segments (user@host, path)
  ys            — clean Powerline blocks
  af-magic      — arrow + path
  bureau        — minimal user@host:path
  eastwood      — simple path + $

Prompt char
-----------
  agnoster  — no trailing $ (ends with Powerline arrow + space)
  ys        — trailing $ after the arrow (real ys uses a second line; we fold it inline)

Attribution
-----------
Theme designs ported from oh-my-zsh (MIT License):
  https://github.com/ohmyzsh/ohmyzsh/tree/master/themes

This mod is provided separately for users who choose to install it.

Creating custom themes
----------------------
Add a JSON file under themes/ and register it in themes.json. See
docs/USER_CONTENT_MODS.md for the segment schema.
