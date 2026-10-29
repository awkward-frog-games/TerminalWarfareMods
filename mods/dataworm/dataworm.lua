-- Data Worm — user minigame mod (Snake)
--
-- The terminal host handles P (pause), R (retry after a crash) and high scores, so this
-- module only plays the game. Held input and turns come from keypresses, which the host
-- feeds from the keyboard (after remapping) and the gamepad stick/d-pad.

local GRID_W = 25
local GRID_H = 20
local START_SPEED = 0.15
local MIN_SPEED = 0.05
-- Turns pressed faster than the worm moves are queued, up to this many
local MAX_QUEUED_TURNS = 2

local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }
local KEY_DIRECTION = {
    up = "up", w = "up",
    down = "down", s = "down",
    left = "left", a = "left",
    right = "right", d = "right",
}

local function is_on_snake(state, x, y)
    for _, seg in ipairs(state.segments) do
        if seg.x == x and seg.y == y then return true end
    end
    return false
end

--- Place the next data packet on a free cell. Returns false when the worm fills the board.
local function spawn_data(state)
    local free = {}
    for y = 1, state.grid_height do
        for x = 1, state.grid_width do
            if not is_on_snake(state, x, y) then
                free[#free + 1] = { x = x, y = y }
            end
        end
    end
    if #free == 0 then
        return false
    end
    local cell = free[math.random(#free)]
    state.data.x, state.data.y = cell.x, cell.y
    return true
end

--- Queue a turn. It is checked against the last queued direction, so two quick turns
--- (e.g. up then left while moving right) both land, but a 180° reversal never does.
--- @return boolean true when the turn was queued
local function queue_turn(state, direction)
    local queue = state.turn_queue
    local last = queue[#queue] or state.direction
    if direction == last or direction == OPPOSITE[last] or #queue >= MAX_QUEUED_TURNS then
        return false
    end
    queue[#queue + 1] = direction
    return true
end

local function end_game(terminal, state, won)
    state.game_over = true
    state.won = won
    -- The host records the score after update() returns, so hiscores still holds the old best
    local old_high = (terminal.hiscores and terminal.hiscores.dataworm) or 0
    if won then
        MinigameSfx.play(terminal, state, "high_score")
    else
        MinigameSfx.play(terminal, state, "death")
        MinigameUI.trigger_shake(state, 6, 0.3)
        terminal:add_output(MinigameUI.t(terminal, "minigames.dataworm.crashed_fmt", { score = state.score }, "Data Worm crashed! Score: " .. state.score))
        if state.score > old_high then
            MinigameSfx.play(terminal, state, "high_score")
        end
    end
end

local function move_snake(terminal, state)
    if #state.turn_queue > 0 then
        state.direction = table.remove(state.turn_queue, 1)
    end
    local head = state.segments[1]
    local new_head = { x = head.x, y = head.y }

    if state.direction == "up" then new_head.y = new_head.y - 1
    elseif state.direction == "down" then new_head.y = new_head.y + 1
    elseif state.direction == "left" then new_head.x = new_head.x - 1
    elseif state.direction == "right" then new_head.x = new_head.x + 1 end

    local eating = new_head.x == state.data.x and new_head.y == state.data.y
    -- The tail moves out of the way this step unless the worm is growing
    local tail = state.segments[#state.segments]
    local hits_body = is_on_snake(state, new_head.x, new_head.y)
        and not (not eating and tail.x == new_head.x and tail.y == new_head.y)

    if new_head.x < 1 or new_head.x > state.grid_width or
       new_head.y < 1 or new_head.y > state.grid_height or hits_body then
        end_game(terminal, state, false)
        return
    end

    table.insert(state.segments, 1, new_head)

    if eating then
        state.score = state.score + 10
        state.food_eaten = state.food_eaten + 1
        if state.food_eaten % 5 == 0 then
            state.move_speed = math.max(MIN_SPEED, state.move_speed - 0.008)
        end
        state.eat_flash = 0.15
        MinigameSfx.play(terminal, state, "eat")
        if not spawn_data(state) then
            end_game(terminal, state, true)
        end
    else
        table.remove(state.segments)
    end
end

return {
    metadata = {
        command = "dataworm",
        name = "Data Worm",
        version = "1.2.0",
        author = "Terminal Warfare Community",
        description = "Collect data packets without crashing",
        score_unit = "score",
        requires_unlock = false,
        score_target = 400,
        gamepad = { stick = "arrows" },
        sfx_events = {
            { id = "eat", description = "Snake collects food" },
            { id = "turn", description = "Direction change" },
            { id = "death", description = "Collision game over" },
            { id = "high_score", description = "New high score" },
        },
    },

    init_state = function(terminal)
        return {
            active = false, game_over = false, won = false, score = 0,
            grid_width = GRID_W, grid_height = GRID_H,
            direction = "right", turn_queue = {},
            move_timer = 0, move_speed = START_SPEED,
            segments = {}, data = { x = 0, y = 0 },
            countdown = 3, food_eaten = 0, eat_flash = 0,
        }
    end,

    start = function(terminal, state)
        state.active = true
        state.game_over = false
        state.won = false
        state.score = 0
        state.direction = "right"
        state.turn_queue = {}
        state.move_timer = 0
        state.move_speed = START_SPEED
        state.countdown = 3
        state.food_eaten = 0
        state.eat_flash = 0
        MinigameUI.init_common_state(state)
        MinigameSfx.attach(terminal, state, state.metadata.command, state.metadata.sfx_events)
        local cx, cy = math.floor(state.grid_width / 2), math.floor(state.grid_height / 2)
        state.segments = {
            { x = cx, y = cy },
            { x = cx - 1, y = cy },
            { x = cx - 2, y = cy },
        }
        spawn_data(state)
        terminal:add_output(MinigameUI.t(terminal, "minigames.dataworm.init", nil, "Data Worm protocol initializing..."))
    end,

    update = function(terminal, state, dt)
        if not state then return end
        MinigameUI.tick_frame(state, dt)
        if not state.active or state.game_over then return end
        if state.countdown > 0 then
            state.countdown = state.countdown - dt
            return
        end
        if state.eat_flash > 0 then state.eat_flash = state.eat_flash - dt end
        state.move_timer = state.move_timer + dt
        -- Carry the remainder so speed doesn't depend on frame rate
        while state.move_timer >= state.move_speed and not state.game_over do
            state.move_timer = state.move_timer - state.move_speed
            move_snake(terminal, state)
        end
    end,

    draw = function(terminal, state, fonts, vw, vh)
        if not state.active then return end
        local panel, pal, time = MinigameUI.begin_panel(terminal, fonts, vw, vh, 700, 550)
        MinigameUI.draw_hud(MinigameUI.t(terminal, "minigames.dataworm.hud_title", nil, "DATA WORM"), {
            { text = MinigameUI.t(terminal, "minigames.common.hud_score_fmt", { score = state.score }, "SCORE: " .. state.score), align = "right" },
        }, "Arrows/WASD: Move | P: Pause | ESC: Quit", fonts, pal, panel)

        local cell_size = 20
        local sx, sy = MinigameUI.get_shake_offset(state)
        local grid_x = panel.x + (panel.w - state.grid_width * cell_size) / 2 + sx
        local grid_y = panel.y + 70 + sy
        local tg = MinigameUI.color(pal, "terminal_green")
        local cyan = MinigameUI.color(pal, "cyan")
        local yellow = MinigameUI.color(pal, "yellow")
        local amber = MinigameUI.color(pal, "amber")

        love.graphics.setColor(tg[1] * 0.15, tg[2] * 0.15, tg[3] * 0.15, 0.5)
        for gx = 0, state.grid_width do
            love.graphics.line(grid_x + gx * cell_size, grid_y, grid_x + gx * cell_size, grid_y + state.grid_height * cell_size)
        end
        for gy = 0, state.grid_height do
            love.graphics.line(grid_x, grid_y + gy * cell_size, grid_x + state.grid_width * cell_size, grid_y + gy * cell_size)
        end

        local count = #state.segments
        for i, seg in ipairs(state.segments) do
            local cx = grid_x + (seg.x - 1) * cell_size
            local cy = grid_y + (seg.y - 1) * cell_size
            local alpha = i == 1 and 1 or (0.5 + 0.5 * (1 - i / count))
            if i == 1 then
                love.graphics.setColor(cyan[1], cyan[2], cyan[3], alpha)
            else
                love.graphics.setColor(tg[1], tg[2], tg[3], alpha)
            end
            love.graphics.rectangle("fill", cx + 1, cy + 1, cell_size - 2, cell_size - 2)
        end

        if not state.won then
            local dx = grid_x + (state.data.x - 1) * cell_size
            local dy = grid_y + (state.data.y - 1) * cell_size
            local pulse = MinigameUI.pulse_alpha(time, 5, 0.6, 1)
            love.graphics.setColor(yellow[1], yellow[2], yellow[3], pulse)
            love.graphics.circle("fill", dx + cell_size / 2, dy + cell_size / 2, cell_size / 3)
        end

        if state.eat_flash > 0 then
            love.graphics.setColor(amber[1], amber[2], amber[3], state.eat_flash * 4)
            love.graphics.rectangle("line", grid_x - 2, grid_y - 2, state.grid_width * cell_size + 4, state.grid_height * cell_size + 4)
        end

        if state.countdown > 0 and not state.game_over then
            MinigameUI.draw_banner(string.format("READY %d", math.ceil(state.countdown)), fonts, pal, panel, time, state.countdown)
        else
            MinigameUI.draw_banner(state.banner_text, fonts, pal, panel, time, state.banner_timer or 0)
        end

        if state.game_over then
            MinigameUI.draw_end_overlay(state.won and "win" or "lose", fonts, pal, panel, vw, vh, {
                time = time,
                lines = { MinigameUI.t(terminal, "minigames.common.score_fmt", { score = state.score }, "Score: " .. state.score) },
                terminal = terminal,
            })
        end
    end,

    keypressed = function(terminal, state, key)
        if not state.active then return false end
        if key == "escape" then
            state.active = false
            terminal:add_output(MinigameUI.t(terminal, "minigames.dataworm.terminated_fmt", { score = state.score }, "Data Worm terminated. Score: " .. state.score))
            return true
        end
        local direction = KEY_DIRECTION[key]
        if direction and not state.game_over then
            -- Turns queued during the countdown apply on the first step
            if queue_turn(state, direction) then
                MinigameSfx.play(terminal, state, "turn")
            end
            return true
        end
        return false
    end,

    get_score = function(state) return state.score or 0 end,
    help_key = "minigames.dataworm.help",
    help_text = "Data Worm (Arrows/WASD move, P pause, ESC quit)",

    -- Pure helpers for test/test_user_mods.lua
    _test = {
        queue_turn = queue_turn,
        move_snake = move_snake,
        spawn_data = spawn_data,
    },
}
