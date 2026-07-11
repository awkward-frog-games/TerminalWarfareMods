-- Data Worm — user minigame mod (Snake)

local function is_on_snake(state, x, y)
    for _, seg in ipairs(state.segments) do
        if seg.x == x and seg.y == y then return true end
    end
    return false
end

local function spawn_data(state)
    repeat
        state.data.x = math.random(1, state.grid_width)
        state.data.y = math.random(1, state.grid_height)
    until not is_on_snake(state, state.data.x, state.data.y)
end

local function end_game(terminal, state, won)
    state.game_over = true
    MinigameSfx.play(terminal, state, "death")
    terminal:add_output(MinigameUI.t(terminal, "minigames.dataworm.crashed_fmt", { score = state.score }, "Data Worm crashed! Score: " .. state.score))
    local old_high = terminal.hiscores.dataworm or 0
    if state.score > old_high then
        terminal.hiscores.dataworm = state.score
        terminal:add_output(MinigameUI.t(terminal, "minigames.common.new_high_score", nil, "*** NEW HIGH SCORE! ***"))
        MinigameSfx.play(terminal, state, "high_score")
    end
end

local function move_snake(terminal, state)
    if state.game_over or state.paused or state.countdown > 0 then return end

    state.direction = state.next_direction
    local head = state.segments[1]
    local new_head = { x = head.x, y = head.y }

    if state.direction == "up" then new_head.y = new_head.y - 1
    elseif state.direction == "down" then new_head.y = new_head.y + 1
    elseif state.direction == "left" then new_head.x = new_head.x - 1
    elseif state.direction == "right" then new_head.x = new_head.x + 1 end

    if new_head.x < 1 or new_head.x > state.grid_width or
       new_head.y < 1 or new_head.y > state.grid_height or
       is_on_snake(state, new_head.x, new_head.y) then
        end_game(terminal, state, false)
        return
    end

    table.insert(state.segments, 1, new_head)

    if new_head.x == state.data.x and new_head.y == state.data.y then
        state.score = state.score + 10
        state.food_eaten = (state.food_eaten or 0) + 1
        if state.food_eaten % 5 == 0 then
            state.move_speed = math.max(0.05, state.move_speed - 0.008)
        end
        state.eat_flash = 0.15
        MinigameSfx.play(terminal, state, "eat")
        spawn_data(state)
    else
        table.remove(state.segments)
    end
end

return {
    metadata = {
        command = "dataworm",
        name = "Data Worm",
        version = "1.1.0",
        author = "Terminal Warfare Community",
        description = "Collect data packets without crashing",
        score_unit = "score",
        requires_unlock = false,
        sfx_events = {
            { id = "eat", description = "Snake collects food" },
            { id = "turn", description = "Direction change" },
            { id = "death", description = "Collision game over" },
            { id = "high_score", description = "New high score" },
        },
    },

    init_state = function(terminal)
        return {
            active = false, game_over = false, score = 0,
            grid_width = 25, grid_height = 20,
            direction = "right", next_direction = "right",
            move_timer = 0, move_speed = 0.15,
            segments = {}, data = { x = 0, y = 0 },
            paused = false, countdown = 3, food_eaten = 0, eat_flash = 0,
        }
    end,

    start = function(terminal, state)
        state.active = true
        state.game_over = false
        state.score = 0
        state.direction = "right"
        state.next_direction = "right"
        state.move_timer = 0
        state.move_speed = 0.15
        state.paused = false
        state.countdown = 3
        state.food_eaten = 0
        state.eat_flash = 0
        MinigameUI.init_common_state(state)
        MinigameSfx.attach(terminal, state, state.metadata.command, state.metadata.sfx_events)
        state.segments = {
            { x = math.floor(state.grid_width / 2), y = math.floor(state.grid_height / 2) },
            { x = math.floor(state.grid_width / 2) - 1, y = math.floor(state.grid_height / 2) },
            { x = math.floor(state.grid_width / 2) - 2, y = math.floor(state.grid_height / 2) },
        }
        spawn_data(state)
        terminal:add_output(MinigameUI.t(terminal, "minigames.dataworm.init", nil, "Data Worm protocol initializing..."))
    end,

    update = function(terminal, state, dt)
        if not state.active or state.game_over then return end
        if state.countdown > 0 then
            state.countdown = state.countdown - dt
            return
        end
        if state.paused then return end
        if state.eat_flash > 0 then state.eat_flash = state.eat_flash - dt end
        state.move_timer = state.move_timer + dt
        if state.move_timer >= state.move_speed then
            state.move_timer = 0
            move_snake(terminal, state)
        end
    end,

    draw = function(terminal, state, fonts, vw, vh)
        if not state.active then return end
        local panel, pal, time = MinigameUI.begin_panel(terminal, fonts, vw, vh, 700, 550)
        MinigameUI.draw_hud(MinigameUI.t(terminal, "minigames.dataworm.hud_title", nil, "DATA WORM"), {
            { text = "SCORE: " .. state.score, align = "right" },
        }, "Arrows: Move | P: Pause | ESC: Quit", fonts, pal, panel)

        local grid_x = panel.x + 50
        local grid_y = panel.y + 70
        local cell_size = 20
        local tg = pal.terminal_green or { 0.2, 1, 0.2, 1 }
        local cyan = pal.cyan or { 0.2, 1, 1, 1 }
        local yellow = pal.yellow or { 1, 1, 0.2, 1 }
        local amber = pal.amber or { 1, 0.75, 0.2, 1 }

        love.graphics.setColor(tg[1] * 0.15, tg[2] * 0.15, tg[3] * 0.15, 0.5)
        for gx = 0, state.grid_width do
            love.graphics.line(grid_x + gx * cell_size, grid_y, grid_x + gx * cell_size, grid_y + state.grid_height * cell_size)
        end
        for gy = 0, state.grid_height do
            love.graphics.line(grid_x, grid_y + gy * cell_size, grid_x + state.grid_width * cell_size, grid_y + gy * cell_size)
        end

        for i, seg in ipairs(state.segments) do
            local cx = grid_x + (seg.x - 1) * cell_size
            local cy = grid_y + (seg.y - 1) * cell_size
            local alpha = i == 1 and 1 or (0.5 + 0.5 * (1 - i / #state.segments))
            if i == 1 then
                love.graphics.setColor(cyan[1], cyan[2], cyan[3], alpha)
            else
                love.graphics.setColor(tg[1], tg[2], tg[3], alpha)
            end
            love.graphics.rectangle("fill", cx + 1, cy + 1, cell_size - 2, cell_size - 2)
        end

        local dx = grid_x + (state.data.x - 1) * cell_size
        local dy = grid_y + (state.data.y - 1) * cell_size
        local pulse = MinigameUI.pulse_alpha(time, 5, 0.6, 1)
        love.graphics.setColor(yellow[1], yellow[2], yellow[3], pulse)
        love.graphics.circle("fill", dx + cell_size / 2, dy + cell_size / 2, cell_size / 3)

        if state.eat_flash > 0 then
            love.graphics.setColor(amber[1], amber[2], amber[3], state.eat_flash * 4)
            love.graphics.rectangle("line", grid_x - 2, grid_y - 2, state.grid_width * cell_size + 4, state.grid_height * cell_size + 4)
        end

        if state.countdown > 0 then
            MinigameUI.draw_banner(string.format("READY %.0f", math.ceil(state.countdown)), fonts, pal, panel, time, state.countdown)
        elseif state.paused then
            MinigameUI.draw_banner("PAUSED", fonts, pal, panel, time, 1)
        end

        if state.game_over then
            MinigameUI.draw_end_overlay("lose", fonts, pal, panel, vw, vh, {
                time = time, title = "CRASHED!",
                lines = { "Score: " .. state.score },
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
        if key == "p" and not state.game_over then
            state.paused = not state.paused
            return true
        end
        if not state.game_over and state.countdown <= 0 and not state.paused then
            if key == "up" and state.direction ~= "down" then
                state.next_direction = "up"
                MinigameSfx.play(terminal, state, "turn")
                return true
            elseif key == "down" and state.direction ~= "up" then
                state.next_direction = "down"
                MinigameSfx.play(terminal, state, "turn")
                return true
            elseif key == "left" and state.direction ~= "right" then
                state.next_direction = "left"
                MinigameSfx.play(terminal, state, "turn")
                return true
            elseif key == "right" and state.direction ~= "left" then
                state.next_direction = "right"
                MinigameSfx.play(terminal, state, "turn")
                return true
            end
        end
        return false
    end,

    get_score = function(state) return state.score or 0 end,
    help_key = "minigames.dataworm.help",
    help_text = "Data Worm (Arrow keys, P pause, ESC to quit)",
}
