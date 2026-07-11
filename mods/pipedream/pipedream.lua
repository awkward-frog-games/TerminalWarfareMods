-- Pipe Dream (Data Pipeline) — connect pipe tiles before time runs out

local GRID_W = 8
local GRID_H = 6
local CELL = 56
local MAX_STAGE = 10

-- Tile types: NESW connection bits (canonical orientation; use rot 0–3 for other orientations)
local TILES = {
    empty = { 0, 0, 0, 0 },
    straight = { 0, 0, 1, 1 },   -- horizontal at rot 0/2, vertical at rot 1/3
    corner = { 1, 0, 0, 1 },     -- 90° bend at rot 0
    tee = { 1, 0, 1, 1 },        -- T-junction (open N/E/W) at rot 0
    cross = { 1, 1, 1, 1 },
}

local TILE_KEYS = { "straight", "corner", "tee", "cross" }

-- Rotate connection bits 90° clockwise (N=1, S=2, E=3, W=4).
local function rotate_bits(bits, times)
    local b = { bits[1], bits[2], bits[3], bits[4] }
    for _ = 1, times do
        b = { b[4], b[3], b[1], b[2] }
    end
    return b
end

local function tile_connects(cell, from_dir)
    -- from_dir: 1=N 2=S 3=E 4=W — does cell accept connection FROM that direction?
    local bits = rotate_bits(TILES[cell.type] or TILES.empty, cell.rot or 0)
    local opp = { [1] = 2, [2] = 1, [3] = 4, [4] = 3 }
    return bits[opp[from_dir]] == 1
end

local function out_dirs(cell)
    local bits = rotate_bits(TILES[cell.type] or TILES.empty, cell.rot or 0)
    local dirs = {}
    if bits[1] == 1 then table.insert(dirs, 1) end
    if bits[2] == 1 then table.insert(dirs, 2) end
    if bits[3] == 1 then table.insert(dirs, 3) end
    if bits[4] == 1 then table.insert(dirs, 4) end
    return dirs
end

local DIR_OFFSET = {
    [1] = { 0, -1, 2 }, [2] = { 0, 1, 1 }, [3] = { 1, 0, 4 }, [4] = { -1, 0, 3 },
}

local function check_flow(state)
    local filled = {}
    for y = 1, GRID_H do filled[y] = {} end

    local sx, sy = state.start_x, state.start_y
    local queue = { { sx, sy, 0 } }
    filled[sy][sx] = true
    local reached = false

    while #queue > 0 do
        local cur = table.remove(queue, 1)
        local x, y = cur[1], cur[2]
        if x == state.end_x and y == state.end_y then reached = true end
        local cell = state.grid[y][x]
        for _, d in ipairs(out_dirs(cell)) do
            local off = DIR_OFFSET[d]
            local nx, ny, nd = x + off[1], y + off[2], off[3]
            if nx >= 1 and nx <= GRID_W and ny >= 1 and ny <= GRID_H and not filled[ny][nx] then
                if tile_connects(state.grid[ny][nx], nd) then
                    filled[ny][nx] = true
                    table.insert(queue, { nx, ny, nd })
                end
            end
        end
    end

    state.flow_filled = filled
    return reached
end

local function generate_stage(state)
    state.grid = {}
    for y = 1, GRID_H do
        state.grid[y] = {}
        for x = 1, GRID_W do
            state.grid[y][x] = {
                type = TILE_KEYS[math.random(#TILE_KEYS)],
                rot = math.random(0, 3),
                fixed = false,
            }
        end
    end

    state.start_x, state.start_y = 1, math.floor(GRID_H / 2)
    state.end_x, state.end_y = GRID_W, math.floor(GRID_H / 2)
    state.grid[state.start_y][state.start_x] = { type = "straight", rot = 0, fixed = true, is_start = true }
    state.grid[state.end_y][state.end_x] = { type = "straight", rot = 0, fixed = true, is_end = true }

    -- Carve a guaranteed horizontal path at mid row
    local mid = state.start_y
    for x = 2, GRID_W - 1 do
        state.grid[mid][x] = { type = "straight", rot = 0, fixed = false }
    end

    state.time_limit = math.max(20, 45 - state.stage * 2)
    state.timer = 0
    state.flow_filled = {}
    check_flow(state)
end

return {
    metadata = {
        command = "pipedream",
        name = "Data Pipeline",
        version = "1.0.0",
        author = "Terminal Warfare Team",
        description = "Rotate pipe tiles to connect the data flow",
        score_unit = "score",
        requires_unlock = false,
        sfx_events = {
            { id = "rotate", description = "Tile rotated" },
            { id = "flow", description = "Flow connected" },
            { id = "stage_clear", description = "Stage cleared" },
            { id = "win", description = "All stages cleared" },
        },
    },

    init_state = function(terminal)
        return { active = false, game_over = false, won = false, score = 0, stage = 1 }
    end,

    start = function(terminal, state)
        state.active = true
        state.game_over = false
        state.won = false
        state.score = 0
        state.stage = 1
        generate_stage(state)
        MinigameUI.init_common_state(state)
        MinigameSfx.attach(terminal, state, state.metadata.command, state.metadata.sfx_events)
        terminal:add_output("Data Pipeline — connect " .. MAX_STAGE .. " stages!")
    end,

    update = function(terminal, state, dt)
        if not state then return end
        MinigameUI.tick_frame(state, dt)
        if not state.active or state.game_over then return end

        state.timer = state.timer + dt
        if state.timer >= state.time_limit then
            state.game_over = true
            state.won = false
            return
        end

        if check_flow(state) and not state.stage_clear_delay then
            state.stage_clear_delay = 0.8
            state.score = state.score + 80 + math.floor((state.time_limit - state.timer) * 2)
            MinigameSfx.play(terminal, state, "flow")
        end

        if state.stage_clear_delay then
            state.stage_clear_delay = state.stage_clear_delay - dt
            if state.stage_clear_delay <= 0 then
                state.stage_clear_delay = nil
                if state.stage >= MAX_STAGE then
                    state.game_over = true
                    state.won = true
                    state.score = state.score + 300
                    MinigameSfx.play(terminal, state, "win")
                else
                    state.stage = state.stage + 1
                    MinigameSfx.play(terminal, state, "stage_clear")
                    MinigameUI.show_banner(state, "STAGE " .. state.stage, 1.2)
                    generate_stage(state)
                end
            end
        end
    end,

    draw = function(terminal, state, fonts, vw, vh)
        if not state.active then return end

        local panel_w = GRID_W * CELL + 60
        local panel_h = GRID_H * CELL + 130
        local panel, pal, time = MinigameUI.begin_panel(terminal, fonts, vw, vh, panel_w, panel_h)

        MinigameUI.draw_hud("DATA PIPELINE", {
            { text = "SCORE: " .. state.score, align = "right" },
            { text = "STAGE: " .. state.stage .. "/" .. MAX_STAGE, align = "right", color = pal.cyan },
            { text = string.format("TIME: %ds", math.max(0, math.floor(state.time_limit - state.timer))), align = "right", color = pal.yellow },
        }, "Click tiles to rotate | ESC: Quit", fonts, pal, panel)

        local ox = (panel.w - GRID_W * CELL) / 2
        local oy = 78
        love.graphics.push()
        love.graphics.translate(panel.x + ox, panel.y + oy)

        for y = 1, GRID_H do
            for x = 1, GRID_W do
                local cell = state.grid[y][x]
                local cx, cy = (x - 1) * CELL, (y - 1) * CELL
                local flowing = state.flow_filled[y] and state.flow_filled[y][x]
                love.graphics.setColor(flowing and 0.1 or 0.05, flowing and 0.4 or 0.08, flowing and 0.45 or 0.08, 1)
                love.graphics.rectangle("fill", cx, cy, CELL - 2, CELL - 2)

                local bits = rotate_bits(TILES[cell.type] or TILES.empty, cell.rot or 0)
                local mx, my = cx + CELL / 2, cy + CELL / 2
                love.graphics.setColor(flowing and 0.2 or 0.3, flowing and 1 or 0.6, flowing and 1 or 0.6, 1)
                love.graphics.setLineWidth(3)
                if bits[1] == 1 then love.graphics.line(mx, my, mx, cy + 4) end
                if bits[2] == 1 then love.graphics.line(mx, my, mx, cy + CELL - 6) end
                if bits[3] == 1 then love.graphics.line(mx, my, cx + CELL - 6, my) end
                if bits[4] == 1 then love.graphics.line(mx, my, cx + 4, my) end
                love.graphics.setLineWidth(1)

                if cell.is_start then
                    love.graphics.setColor(0.2, 1, 0.4, 0.8)
                    love.graphics.print("IN", cx + 4, cy + 4)
                elseif cell.is_end then
                    love.graphics.setColor(1, 0.8, 0.2, 0.8)
                    love.graphics.print("OUT", cx + 4, cy + 4)
                end
            end
        end

        love.graphics.pop()
        MinigameUI.draw_particles(state, panel.x, panel.y)

        if state.game_over then
            MinigameUI.draw_end_overlay(state.won and "win" or "lose", fonts, pal, panel, vw, vh, {
                time = time,
                title = state.won and "PIPELINE ONLINE" or "FLOW FAILED",
                lines = { "Stage: " .. state.stage, "Score: " .. state.score },
                terminal = terminal,
            })
        end
    end,

    keypressed = function(terminal, state, key)
        if not state.active then return false end
        if key == "escape" then
            state.active = false
            terminal:add_output("Data Pipeline ended. Score: " .. state.score)
            return true
        end
        return false
    end,

    mousepressed = function(terminal, state, x, y, button)
        if not state.active or state.game_over or button ~= 1 or state.stage_clear_delay then return false end
        local panel_w = GRID_W * CELL + 60
        local panel_h = GRID_H * CELL + 130
        local vw = terminal.virtual_width or 1920
        local vh = terminal.virtual_height or 1080
        local px = vw / 2 - panel_w / 2
        local py = vh / 2 - panel_h / 2
        local ox = (panel_w - GRID_W * CELL) / 2
        local oy = 78
        local gx = x - px - ox
        local gy = y - py - oy
        local col = math.floor(gx / CELL) + 1
        local row = math.floor(gy / CELL) + 1
        if col < 1 or col > GRID_W or row < 1 or row > GRID_H then return false end
        local cell = state.grid[row][col]
        if cell.fixed then return false end
        cell.rot = ((cell.rot or 0) + 1) % 4
        MinigameSfx.play(terminal, state, "rotate")
        check_flow(state)
        return true
    end,

    get_score = function(state) return state.score or 0 end,
    help_text = "Data Pipeline (Click rotate, ESC)",
}
