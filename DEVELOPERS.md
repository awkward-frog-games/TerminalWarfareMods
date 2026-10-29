# User Mods — Developer Reference

This document is the primary reference for creating and publishing user mods for Terminal Warfare. It covers both mod types, the minigame module API, asset loading, and the security sandbox that protects players from malicious Lua code.

---

## Overview

Terminal Warfare supports two kinds of user-installed mods under `<save_directory>/mods/`:

| Mod type | Discovery | Runs Lua? | Terminal entry point |
|----------|-----------|-----------|----------------------|
| **Minigame mod** | `<name>/<name>.lua` (or sole `.lua` in folder) | Yes — sandboxed | `/usr/games/<command>` |
| **Content mod** | `mod.json` manifest in mod folder | No — assets only | `/bin/avatar`, `/bin/prompt` |

Both types share the same install directory. Folders that contain `mod.json` are treated as content mods and are **not** scanned for minigame Lua.

Use the in-game `mods` command to list installed mods, their versions, source (CORE vs USER), and load status.

---

## Install Location

Copy a mod folder into your save-directory `mods/` path and restart the game.

```
mods/
  choppercmd/
    choppercmd.lua
    launch.wav
    sounds.lua
  pokemon-colorscripts/
    mod.json
    pokemon.json
    small/regular/
      ...
```

| Build | Directory |
|-------|-----------|
| Dev (`love .`) Linux | `~/.local/share/love/terminal_warfare/mods/` |
| Fused / Steam Linux | `~/.local/share/love/terminal_warfare/mods/` |
| Windows (dev) | `%APPDATA%/LOVE/terminal_warfare/mods/` |
| Windows (fused) | `%APPDATA%/terminal_warfare/mods/` |
| macOS (dev) | `~/Library/Application Support/LOVE/terminal_warfare/mods/` |
| macOS (fused) | `~/Library/Application Support/terminal_warfare/mods/` |

---

## Minigame Mods

Minigame mods are self-contained Lua modules that add arcade games to the terminal.

### Folder Layout

Recommended layout (folder name should match the main `.lua` file):

```
mods/
  mygame/
    mygame.lua          # required — main module
    shoot.wav           # optional — sound by event id
    sounds.lua          # optional — filename mapping for SFX
    hero.png            # optional — sprite assets
    README.txt          # optional — player-facing notes
```

**Discovery rules:**

- `mods/<name>/<name>.lua` is the preferred layout
- A folder with a single `.lua` file (any name) is also accepted
- Flat `mods/<name>.lua` at the mods root is supported
- Files and folders starting with `_` are ignored
- Folders containing `mod.json` are skipped (content mod)
- Duplicate `metadata.command` values are rejected — core modules take precedence

**User mod policy:**

- User mods are **always unlocked** at load time (`requires_unlock` is forced to `false`)
- Sound and image assets live in the mod folder (sibling to the `.lua` file), not in a subfolder named after the command

### Module API

A minigame module is a Lua file that **returns a table**.

#### Metadata (required fields)

| Field | Type | Description |
|-------|------|-------------|
| `command` | string | Terminal command to launch the game (e.g. `"choppercmd"`) |
| `name` | string | Display name shown in `mods` and UI |
| `version` | string | Semver string (e.g. `"1.0.0"`) |

#### Metadata (optional fields)

| Field | Type | Description |
|-------|------|-------------|
| `author` | string | Author attribution |
| `description` | string | Short description |
| `requires_unlock` | boolean | Ignored for user mods; honored for core modules |
| `score_unit` | string | Label for high-score display (default: `"score"`) |
| `score_target` | number | Target score for the game (all bundled mods set one) |
| `gamepad` | table | Gamepad-to-key mapping — see [Gamepad Input](#gamepad-input) |
| `sfx_events` | table | Sound event catalog — see [MINIGAME_SFX.md](MINIGAME_SFX.md) |

#### Module fields (optional, top level)

| Field | Type | Description |
|-------|------|-------------|
| `help_key` | string | Localization key for help text |
| `help_text` | string | Plain help text fallback |
| `_test` | table | Pure helper functions exported for the upstream test suite (`test/test_user_mods.lua`); ignored at runtime |

#### Required functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `init_state` | `function(terminal) → table` | Create and return initial game state |
| `start` | `function(terminal, state)` | Start or reset a play session |
| `update` | `function(terminal, state, dt)` | Per-frame logic |
| `draw` | `function(terminal, state, fonts, virtual_width, virtual_height)` | Render the game |
| `keypressed` | `function(terminal, state, key) → boolean` | Handle keyboard input; return `true` if consumed |
| `get_score` | `function(state) → number` | Return current score for high-score tracking |

#### Optional functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `restart` | `function(terminal, state)` | Called when the player presses R after a game over or from the pause menu. Implement it when a retry should differ from a fresh `start()` (e.g. Chopper Commando retries the current mission instead of the whole campaign) |
| `mousepressed` | `function(terminal, state, x, y, button) → boolean` | Mouse button down |
| `mousemoved` | `function(terminal, state, x, y, dx, dy)` | Mouse movement |
| `mousereleased` | `function(terminal, state, x, y, button) → boolean` | Mouse button up |
| `process_command` | `function(terminal, state, args)` | Text command handling (not yet wired to shell input) |

Mouse coordinates are in the same virtual space you draw in. For hit testing, save the `panel` returned by `MinigameUI.begin_panel` on `state` during `draw()` and measure against it, rather than recomputing the layout from `terminal.virtual_width` / `terminal.virtual_height` (see `cell_at` in [`mods/pipedream/pipedream.lua`](mods/pipedream/pipedream.lua)).

#### State fields the host reads

| Field | Meaning |
|-------|---------|
| `state.active` | The game is running. Set to `false` on ESC to return to the terminal |
| `state.game_over` | The session has ended. While it is `true`, the host offers R / gamepad A to retry |
| `state.won` | Pass `state.won and "win" or "lose"` to `MinigameUI.draw_end_overlay` |

Only set `game_over` when a retry makes sense. Chopper Commando, for example, leaves it unset on a mission-complete debrief so the host does not offer a retry there.

#### Minimal example

```lua
return {
    metadata = {
        command = "mygame",
        name = "My Minigame",
        version = "1.0.0",
        author = "Your Name",
        description = "A custom terminal arcade game",
    },

    init_state = function(terminal)
        return { active = false, game_over = false, won = false, score = 0 }
    end,

    start = function(terminal, state)
        state.active = true
        state.game_over = false
        state.won = false
        state.score = 0
        MinigameUI.init_common_state(state)
        MinigameSfx.attach(terminal, state, state.metadata.command, state.metadata.sfx_events)
        terminal:add_output("My Minigame starting...")
    end,

    update = function(terminal, state, dt)
        if not state then return end
        MinigameUI.tick_frame(state, dt)
        if not state.active or state.game_over then return end
        -- game logic; set state.game_over (and state.won) when the session ends
    end,

    draw = function(terminal, state, fonts, vw, vh)
        if not state.active then return end
        local panel, pal, time = MinigameUI.begin_panel(terminal, fonts, vw, vh, 850, 650)
        state.panel = panel -- for mouse hit testing
        MinigameUI.draw_hud("MY GAME", {
            { text = "SCORE: " .. state.score, align = "right" },
        }, "Arrows/WASD: Move | P: Pause | ESC: Quit", fonts, pal, panel)
        MinigameUI.draw_banner(state.banner_text, fonts, pal, panel, time, state.banner_timer or 0)
        if state.game_over then
            MinigameUI.draw_end_overlay(state.won and "win" or "lose", fonts, pal, panel, vw, vh, {
                time = time,
                lines = { "Score: " .. state.score },
                terminal = terminal,
            })
        end
    end,

    keypressed = function(terminal, state, key)
        if not state.active then return false end
        if key == "escape" then
            state.active = false
            terminal:add_output("Game ended. Score: " .. state.score)
            return true
        end
        return false
    end,

    get_score = function(state)
        return state.score or 0
    end,

    help_text = "My Minigame (Arrows/WASD move, P pause, ESC quit)",
}
```

The module does not handle P, R, or high scores itself. The host does that, as described in the next section.

### Host-Managed Controls

The terminal host now runs the parts every minigame used to implement itself. **Don't reimplement them in your mod.** If you do, the player gets a double pause or a double retry.

| Concern | Host behavior | What the mod does |
|---------|---------------|-------------------|
| **Pause** | P / gamepad Start opens the pause menu, which has R to restart. `update()` is not called while paused | Nothing. Do not keep a `state.paused` flag or handle `"p"` in `keypressed` |
| **Retry** | R / gamepad A while `state.game_over` is `true` restarts the game, through `restart()` if the module defines one | Set `state.game_over` (and `state.won`). Implement `restart()` if needed |
| **High scores** | Reads `get_score()` and records the best score after `update()` returns | Do not write `terminal.hiscores`. Read it if you want to detect a new best: during `update()` it still holds the previous best |
| **ESC** | Delivered to `keypressed` as normal | Set `state.active = false` and print a final line with `terminal:add_output` |

Mention P, R, and ESC in your HUD footer and `help_text` so players can find them.

### Gamepad Input

Gamepads are mapped onto keyboard keys, so a mod still receives everything through `keypressed` and doesn't need gamepad callbacks. Declare the mapping in metadata:

```lua
metadata = {
    -- ...
    gamepad = {
        stick = "arrows",  -- left stick and d-pad are delivered as up/down/left/right
        buttons = {        -- LÖVE GamepadButton name → key passed to keypressed
            a = "space",
            x = "b",
            y = "m",
            leftshoulder = "g",
            rightshoulder = "n",
        },
    },
},
```

- **Reserved buttons:** Start is pause. A also retries after a game over, so map it to your primary action (usually `"space"`).
- **Key remapping:** keys reach `keypressed` after the host applies the player's key remapping.
- **WASD:** accept `w`/`a`/`s`/`d` alongside the arrow keys. All bundled mods do.
- **Held input:** use `MinigameUI.is_down(...)` (true if any of the listed keys is held). It also covers the mapped stick, so `MinigameUI.is_down("left", "a")` handles arrows, WASD, and gamepad together.

### Sandbox Globals (Injected Helpers)

Minigame modules must **not** use `require()`. The loader injects these globals into the sandbox environment:

| Global | Purpose |
|--------|---------|
| `love` | Full LÖVE 2D framework API |
| `math`, `table`, `string` | Standard Lua libraries |
| `pairs`, `ipairs`, `tostring`, `tonumber`, `type`, `print` | Basic builtins |
| `MinigameUI` | Desktop chrome, panels, HUD, particles, screen shake, end overlays |
| `MinigameSfx` | Per-command sound catalog and playback |
| `MinigameSprites` | Load PNG sprites from the mod folder |
| `Desktop_chrome` | Desktop backdrop chrome |
| `ButtonJuice` | Button animation helper |

Initialize UI and SFX in `start()`:

```lua
MinigameUI.init_common_state(state)
MinigameSfx.attach(terminal, state, state.metadata.command, state.metadata.sfx_events)
```

#### Common helper calls

These signatures come from the bundled mods:

| Call | Purpose |
|------|---------|
| `MinigameUI.init_common_state(state)` | Reset shared banner, particle, floater, and shake state. Call it in `start()` and `restart()` |
| `MinigameUI.tick_frame(state, dt)` | Advance the shared effects. Call it every `update()`, even after a game over, so the overlays keep animating |
| `MinigameUI.begin_panel(terminal, fonts, vw, vh, w, h) → panel, pal, time` | Draw the backdrop and a centered panel; returns its rect, the palette, and the animation time |
| `MinigameUI.draw_hud(title, items, footer, fonts, pal, panel)` | Title bar and footer. Each item is `{ text, align = "right", color }` |
| `MinigameUI.color(pal, name)` | Palette color, e.g. `"terminal_green"`, `"cyan"`, `"yellow"`, `"amber"`, `"red"` |
| `MinigameUI.show_banner(state, text, seconds)` | Queue a center banner (e.g. `"WAVE 3"`) |
| `MinigameUI.draw_banner(state.banner_text, fonts, pal, panel, time, state.banner_timer or 0)` | Draw the active banner |
| `MinigameUI.spawn_floater(state, x, y, text [, color])` | Floating score text, in panel-relative coordinates |
| `MinigameUI.draw_floaters(state, fonts, panel.x, panel.y)` | Draw floaters offset to the panel |
| `MinigameUI.spawn_particles(state, x, y, { count, colors })` | Particle burst |
| `MinigameUI.trigger_shake(state, magnitude, seconds)` / `MinigameUI.get_shake_offset(state) → sx, sy` | Screen shake. Add the offset to your draw origin |
| `MinigameUI.pulse_alpha(time, speed, min, max)` | Oscillating alpha for blinking elements |
| `MinigameUI.draw_end_overlay("win" \| "lose", fonts, pal, panel, vw, vh, opts)` | Game-over overlay. `opts`: `time`, `lines`, `terminal`, and optionally `title` and `subtitle` |
| `MinigameUI.is_down(key, ...)` | True if any listed key (or a mapped gamepad input) is held |
| `MinigameUI.t(terminal, key, params, fallback)` | Localized string, with `fallback` when the key is missing. Shared keys include `minigames.common.score_fmt`, `hud_score_fmt`, `wave_fmt`, `hud_stage_of_fmt` |
| `MinigameSfx.play(terminal, state, event_id [, { overlap = true }])` | Play a declared sound event. `overlap` lets rapid repeats stack |

See `src/minigames/_template.lua` in the game source for a complete usage example, or any of the [reference mods](#reference-mods) in this repo.

### Asset Loading

Load assets through scoped terminal APIs rather than direct filesystem access:

| API | Purpose |
|-----|---------|
| `terminal:load_module_image(command, asset_name)` | Load a PNG from the mod folder |
| `terminal:load_module_image_data(command, asset_name)` | Load raw image data |
| `terminal:load_module_sound(command, asset_name, source_type)` | Load audio (`"static"` or `"stream"`) |
| `MinigameSfx.attach(terminal, state, command, sfx_events)` | Wire up sound events |
| `MinigameSprites.load_module_sprites(terminal, ...)` | Batch-load sprites |

**Sound files:** Place `<event_id>.wav` (or `.mp3`, `.ogg`) beside the module file, or map filenames in `sounds.lua`:

```lua
return {
    shoot = "laser_blast.mp3",
    enemy_hit = "pop.wav",
}
```

**Convention:** Do not call `love.filesystem` directly from mod code. Use the terminal asset APIs so paths resolve correctly for both user and core modules.

### Terminal Callback Argument

Every module callback receives a `terminal` argument — the full `Terminal` instance. Common uses:

- `terminal:add_output(text)` — write lines to the in-game terminal
- `terminal:load_module_image(...)` — load mod assets (see above)
- `terminal.game_ref` — access broader game state (creds, achievements, etc.)

Treat `terminal` as a privileged capability: it reaches game internals beyond the sandbox globals.

### Testing

1. Install the mod folder into your save-directory `mods/` path
2. Restart the game
3. Open the terminal and run `mods` — your mod should appear as `USER` / `LOADED`
4. Launch with the command name (e.g. `mygame`) or `ls /usr/games`

If load fails, `mods` shows `INVALID` with an error message explaining why.

---

## Content Mods

Content mods are asset packs with **no executable Lua**. They are discovered via a `mod.json` manifest and validated as JSON + assets only.

Supported types:

- **colorscript** — ANSI art startup avatars (`avatar` command)
- **prompt_theme** — oh-my-zsh-style shell prompt themes (`prompt` command)

Content mods do not go through the Lua sandbox because no user code runs. Security is enforced by design: the engine reads manifests and assets, never executes mod-supplied scripts.

---

## Security Sandbox

Minigame mods run in a restricted Lua environment. The sandbox protects players from mods that attempt filesystem access, process execution, sandbox escape, or loading arbitrary game engine code.

### How Enforcement Works

Security is applied in three layers:

```
User mod .lua source
        │
        ▼
┌───────────────────────────┐
│ 1. Static source scan     │  Regex check for banned API calls
│    (validate_security)    │  before compile
└───────────┬───────────────┘
            │ pass
            ▼
┌───────────────────────────┐
│ 2. Restricted compile env │  Chunk compiled with sandbox_env only;
│    (compile_minigame_     │  banned libs absent from scope
│     chunk)                │
└───────────┬───────────────┘
            │ pass
            ▼
┌───────────────────────────┐
│ 3. Runtime pcall guards   │  Every callback wrapped; crashes
│    (terminal.lua)         │  deactivate the mod, not the game
└───────────────────────────┘
```

**Static scan details:**

- Runs on source text **before** the module is compiled
- Matches direct call patterns: `func(`, `func{`, `func"`, `func'`
- Uses word boundaries so identifiers like `requires_unlock` do not false-positive on `require`
- Failure produces status `INVALID` with message `Security check failed: Contains banned function: <name>`

**Compile environment:**

- Lua 5.2+: `load(code, name, "t", env)` — text chunks only, custom environment
- Lua 5.1 / love.js: `loadstring` + `setfenv(chunk, env)`
- Only the [sandbox globals](#sandbox-globals-injected-helpers) listed above are in `env`

**Runtime guards:**

- `start`, `update`, `draw`, `keypressed`, and mouse handlers run inside `pcall`
- Uncaught errors deactivate the mod and log a runtime error
- `MinigameUI.wrap_for_sandbox` prevents nil-state UI calls from crashing the terminal

### Blocked Functions (Complete List)

These 20 APIs are rejected if called directly in mod source:

#### File I/O — `io.*`

| Function | Why blocked |
|----------|-------------|
| `io.open` | Read or write arbitrary host filesystem paths outside the mod's asset folder |
| `io.popen` | Spawn shell subprocesses and read their output |
| `io.write` | Write to stdout or open file handles |
| `io.close` | Close file handles opened outside the sandbox |

Mods should load assets only through scoped APIs (`terminal:load_module_image`, `terminal:load_module_sound`, `MinigameSprites`, `MinigameSfx`).

#### OS / Process — `os.*`

| Function | Why blocked |
|----------|-------------|
| `os.execute` | Run arbitrary shell commands on the host machine |
| `os.remove` | Delete files on the host filesystem |
| `os.rename` | Move or rename files on the host filesystem |
| `os.exit` | Terminate the entire game process |

#### Dynamic Code Loading

| Function | Why blocked |
|----------|-------------|
| `loadstring` | Compile and run arbitrary Lua from a string at runtime |
| `load` | Compile arbitrary bytecode or source |
| `dofile` | Execute an arbitrary `.lua` file from disk |
| `loadfile` | Compile an arbitrary file (enables staged escape) |

If mods could load new code at runtime, they could bypass the static ban-list scan entirely.

#### Module / Native Loading

| Function | Why blocked |
|----------|-------------|
| `require` | Pull in any game engine module (`terminal`, `game_state`, etc.) |
| `package.loadlib` | Load C/native shared libraries |
| `package.load` | Custom module loader hook |

#### Debug Library (Sandbox Escape)

| Function | Why blocked |
|----------|-------------|
| `debug.getinfo` | Introspect call stacks and upvalues |
| `debug.setmetatable` | Replace metatables on protected objects |
| `debug.setupvalue` | Modify closed-over variables in other functions |
| `debug.setlocal` | Modify local variables in other stack frames |
| `debug.setfenv` | Change a function's environment (classic Lua 5.1 escape) |

The full `debug` table is also absent from the sandbox environment, so these functions are unreachable unless escaped through other means.

### What Is Allowed

**Sandbox globals:** `love`, `math`, `table`, `string`, `pairs`, `ipairs`, `tostring`, `tonumber`, `type`, `print`, plus the injected helpers (`MinigameUI`, `MinigameSfx`, `MinigameSprites`, `Desktop_chrome`, `ButtonJuice`).

**Via the `terminal` callback:** terminal output, scoped asset loading, and game state access through `terminal.game_ref`.

**Content mods:** No Lua execution — JSON manifests and asset files only.

### Security Limitations

Be aware of these constraints when evaluating or extending the sandbox:

1. **Static scan only** — Dynamic access such as `_G["os"]["execute"]()` or building a function name in a string may bypass the pattern matcher. The restricted compile environment mitigates direct calls but not all indirect escape paths.
2. **`love` is fully exposed** — APIs like `love.filesystem` and `love.system.openURL` are not in the ban list. Mods can access LÖVE's filesystem mount points.
3. **`terminal` is a privileged surface** — Callbacks receive the full `Terminal` instance, which can reach game internals.
4. **Content mods have no Lua sandbox** — Security is enforced by not executing user code.
5. **Ban list is exact** — Five specific `debug.*` functions are listed, not a wildcard. The README summarizes this as `debug.*`, but the code targets individual calls.

### Verifying Security Locally

Create a test mod that calls a banned function:

```lua
return {
    metadata = {
        command = "badmod",
        name = "Bad Mod",
        version = "0.0.1",
    },
    init_state = function() os.execute("echo pwned") end,
    start = function() end,
    update = function() end,
    draw = function() end,
    keypressed = function() return false end,
    get_score = function() return 0 end,
}
```

Run `mods` in the terminal. The mod should appear as `INVALID` with a security check failure message.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Mod not listed | Wrong install path; forgot to restart; folder has `mod.json` (content mod) |
| `INVALID` + security message | Banned function call in source |
| `INVALID` + validation message | Missing required metadata field or callback function |
| `INVALID` + duplicate command | A core or other mod already owns `metadata.command` |
| `INVALID` + init_state failed | Runtime error during state initialization |
| Mod loads but crashes on play | Runtime error in `start`/`update`/`draw`; check console output |
| Assets not loading | Wrong filename; use `terminal:load_module_*` APIs; place files beside `.lua` |
| Sounds silent | Missing audio file; check `sfx_events` and `sounds.lua` mapping |
| P toggles pause twice / R retries twice | Mod still handles `"p"` or `"r"` itself; remove it and let the host do it (see [Host-Managed Controls](#host-managed-controls)) |
| R does nothing after the game ends | `state.game_over` was never set to `true` |
| Gamepad does nothing | Missing `metadata.gamepad` mapping |
| Clicks land on the wrong cell | Hit test doesn't match the drawn layout; store the `panel` from `begin_panel` and measure against it |

---

## Reference Mods

The repo includes sample mods for local testing.

### Minigame mods

| Mod | Command | Path |
|-----|---------|------|
| Intercept Command | `interceptcmd` | [`mods/interceptcmd/`](mods/interceptcmd/) |
| Terrain Barrage | `terrainbarrage` | [`mods/terrainbarrage/`](mods/terrainbarrage/) |
| Chopper Commando | `choppercmd` | [`mods/choppercmd/`](mods/choppercmd/) |
| Data Worm | `dataworm` | [`mods/dataworm/`](mods/dataworm/) |
| Pipe Dream | `pipedream` | [`mods/pipedream/`](mods/pipedream/) |

### Content mods

| Mod | Type | Path |
|-----|------|------|
| Pokemon Colorscripts | colorscript | [`mods/pokemon-colorscripts/`](mods/pokemon-colorscripts/) |
| Oh My Zsh Prompts | prompt_theme | [`mods/ohmyzsh-prompts/`](mods/ohmyzsh-prompts/) |

---

## Publishing Checklist

Before sharing a minigame mod:

- [ ] Folder name matches `<name>.lua` inside it
- [ ] `metadata.command`, `name`, and `version` are set
- [ ] All six required callbacks are implemented
- [ ] Pause, retry, and high scores are left to the host (no `"p"`/`"r"` handling, no writes to `terminal.hiscores`)
- [ ] `state.game_over` / `state.won` are set when a session ends
- [ ] `metadata.gamepad` maps your controls, with A on the primary action
- [ ] WASD works alongside the arrow keys
- [ ] No banned functions appear in source (run `mods` to verify `LOADED`)
- [ ] Assets use `terminal:load_module_*` or `MinigameSprites` / `MinigameSfx`
- [ ] Include a `README.txt` with install instructions and controls
- [ ] Test on a clean save directory without dev-only paths

Before sharing a content mod:

- [ ] Valid `mod.json` with required fields for the mod type
- [ ] No `.lua` files that could be mistaken for a minigame module
- [ ] Manifest paths resolve relative to the mod folder
- [ ] Test `avatar` or `prompt` commands after install
