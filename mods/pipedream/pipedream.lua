-- Pipe Dream (Data Pipeline) — rotate pipe tiles to connect IN to OUT before time runs out
--
-- The terminal host handles P (pause), R (retry after a game over) and high scores.

local GRID_W = 8
local GRID_H = 6
local CELL = 56
local MAX_STAGE = 10
local GRID_TOP = 136
local PANEL_W = GRID_W * CELL + 60
local PANEL_H = GRID_TOP + GRID_H * CELL + 44

-- Sides: 1=N 2=S 3=E 4=W. Tile bits list which sides are open, in canonical orientation;
-- rot 0–3 turns the tile 90° clockwise that many times.
local TILES = {
    empty = { 0, 0, 0, 0 },
    straight = { 0, 0, 1, 1 },   -- horizontal at rot 0/2, vertical at rot 1/3
    corner = { 1, 0, 1, 0 },     -- N/E bend at rot 0
    tee = { 1, 0, 1, 1 },        -- open N/E/W at rot 0
    cross = { 1, 1, 1, 1 },
}

local TILE_KEYS = { "straight", "corner", "tee", "cross" }

-- Neighbour offset per side, and the side of that neighbour that faces back
local DIR_OFFSET = {
    [1] = { 0, -1, 2 }, [2] = { 0, 1, 1 }, [3] = { 1, 0, 4 }, [4] = { -1, 0, 3 },
}
local OPPOSITE = { [1] = 2, [2] = 1, [3] = 4, [4] = 3 }

-- Rotate connection bits 90° clockwise: N->E, E->S, S->W, W->N.
local function rotate_bits(bits, times)
    local b = { bits[1], bits[2], bits[3], bits[4] }
    for _ = 1, (times or 0) % 4 do
        b = { b[4], b[3], b[1], b[2] }
    end
    return b
end

local function cell_bits(cell)
    return rotate_bits(TILES[cell.type] or TILES.empty, cell.rot or 0)
end

--- True when `cell` is open on `side`.
local function has_side(cell, side)
    return cell_bits(cell)[side] == 1
end

--- First rotation of `tile_type` open on both sides a and b, or nil.
local function rotation_for(tile_type, a, b)
    for rot = 0, 3 do
        local bits = rotate_bits(TILES[tile_type], rot)
        if bits[a] == 1 and bits[b] == 1 then
            return rot
        end
    end
    return nil
end

--- Flood the pipe network from IN. Fills state.flow_filled and returns true when OUT is
--- reached through matching openings on both sides of every joint.
local function check_flow(state)
    local filled = {}
    for y = 1, GRID_H do filled[y] = {} end

    local sx, sy = state.start_x, state.start_y
    local queue = { { sx, sy } }
    local head = 1
    filled[sy][sx] = true
    local reached = false

    while head <= #queue do
        local cur = queue[head]
        head = head + 1
        local x, y = cur[1], cur[2]
        if x == state.end_x and y == state.end_y then reached = true end
        local bits = cell_bits(state.grid[y][x])
        for side = 1, 4 do
            if bits[side] == 1 then
                local off = DIR_OFFSET[side]
                local nx, ny = x + off[1], y + off[2]
                if nx >= 1 and nx <= GRID_W and ny >= 1 and ny <= GRID_H and not filled[ny][nx]
                    and has_side(state.grid[ny][nx], off[3]) then
                    filled[ny][nx] = true
                    queue[#queue + 1] = { nx, ny }
                end
            end
        end
    end

    state.flow_filled = filled
    state.connected = reached
    return reached
end

--- Random path through the inner columns from (2, sy) to (GRID_W - 1, ey). Neighbours are
--- tried closest-to-goal first with noise that grows each stage, so later paths wander more.
local function carve_path(sy, ey, stage)
    local goal_x, goal_y = GRID_W - 1, ey
    local visited = {}
    for y = 1, GRID_H do visited[y] = {} end
    local path = {}
    local wander = 0.6 + stage * 0.5

    local function walk(x, y)
        visited[y][x] = true
        path[#path + 1] = { x = x, y = y }
        if x == goal_x and y == goal_y then
            return true
        end
        local options = {}
        for side = 1, 4 do
            local off = DIR_OFFSET[side]
            local nx, ny = x + off[1], y + off[2]
            if nx >= 2 and nx <= GRID_W - 1 and ny >= 1 and ny <= GRID_H and not visited[ny][nx] then
                local dist = math.abs(goal_x - nx) + math.abs(goal_y - ny)
                options[#options + 1] = { x = nx, y = ny, side = side, weight = dist + math.random() * wander }
            end
        end
        table.sort(options, function(a, b) return a.weight < b.weight end)
        for _, opt in ipairs(options) do
            path[#path].out_side = opt.side
            if walk(opt.x, opt.y) then
                return true
            end
        end
        path[#path] = nil
        return false
    end

    walk(2, sy)
    return path
end

local function scramble(state)
    for y = 1, GRID_H do
        for x = 1, GRID_W do
            local cell = state.grid[y][x]
            if not cell.fixed then
                cell.rot = math.random(0, 3)
            end
        end
    end
end

local function generate_stage(state)
    state.grid = {}
    for y = 1, GRID_H do
        state.grid[y] = {}
        for x = 1, GRID_W do
            state.grid[y][x] = { type = TILE_KEYS[math.random(#TILE_KEYS)], rot = 0, fixed = false }
        end
    end

    state.start_x, state.start_y = 1, math.random(1, GRID_H)
    state.end_x, state.end_y = GRID_W, math.random(1, GRID_H)
    state.grid[state.start_y][state.start_x] = { type = "straight", rot = 0, fixed = true, is_start = true }
    state.grid[state.end_y][state.end_x] = { type = "straight", rot = 0, fixed = true, is_end = true }

    -- Lay a solvable route: each path cell gets a tile that can join its entry and exit
    local path = carve_path(state.start_y, state.end_y, state.stage)
    local in_side = 4  -- the first path cell is entered from IN on its west side
    for _, step in ipairs(path) do
        local out_side = step.out_side or 3  -- the last cell exits east into OUT
        local tile_type
        if out_side == OPPOSITE[in_side] then
            tile_type = math.random() < 0.15 and "cross" or "straight"
        else
            tile_type = math.random() < 0.15 and "tee" or "corner"
        end
        state.grid[step.y][step.x] = {
            type = tile_type,
            rot = 0,
            fixed = false,
            solution_rot = rotation_for(tile_type, in_side, out_side),
        }
        in_side = OPPOSITE[out_side]
    end
    state.path = path

    -- Scramble until the board isn't already solved
    repeat
        scramble(state)
    until not check_flow(state)

    state.time_limit = math.floor(12 + #path * math.max(1.2, 2.4 - state.stage * 0.12))
    state.timer = 0
end

local function rotate_cell(terminal, state, col, row, steps)
    if col < 1 or col > GRID_W or row < 1 or row > GRID_H then return false end
    local cell = state.grid[row][col]
    if cell.fixed then return false end
    cell.rot = ((cell.rot or 0) + steps) % 4
    state.rotations = state.rotations + 1
    MinigameSfx.play(terminal, state, "rotate")
    check_flow(state)
    return true
end

--- Grid cell under a screen point, or nil.
local function cell_at(state, x, y)
    local panel = state.panel
    if not panel then return nil end
    local gx = x - panel.x - (panel.w - GRID_W * CELL) / 2
    local gy = y - panel.y - GRID_TOP
    if gx < 0 or gy < 0 then return nil end
    local col = math.floor(gx / CELL) + 1
    local row = math.floor(gy / CELL) + 1
    if col > GRID_W or row > GRID_H then return nil end
    return col, row
end

local CURSOR_MOVES = {
    up = { 0, -1 }, w = { 0, -1 },
    down = { 0, 1 }, s = { 0, 1 },
    left = { -1, 0 }, a = { -1, 0 },
    right = { 1, 0 }, d = { 1, 0 },
}

return {
    metadata = {
        command = "pipedream",
        name = "Data Pipeline",
        version = "1.1.0",
        author = "Terminal Warfare Team",
        description = "Rotate pipe tiles to connect the data flow",
        score_unit = "score",
        requires_unlock = false,
        score_target = 1200,
        gamepad = { stick = "arrows", buttons = { a = "space", x = "q" } },
        sfx_events = {
            { id = "rotate", description = "Tile rotated" },
            { id = "flow", description = "Flow connected" },
            { id = "stage_clear", description = "Stage cleared" },
            { id = "win", description = "All stages cleared" },
        },
    },

    init_state = function(terminal)
        return {
            active = false, game_over = false, won = false, score = 0, stage = 1,
            grid = {}, flow_filled = {}, connected = false,
            cursor_x = 2, cursor_y = 1, rotations = 0,
            timer = 0, time_limit = 30,
        }
    end,

    start = function(terminal, state)
        state.active = true
        state.game_over = false
        state.won = false
        state.score = 0
        state.stage = 1
        state.rotations = 0
        state.stage_clear_delay = nil
        MinigameUI.init_common_state(state)
        MinigameSfx.attach(terminal, state, state.metadata.command, state.metadata.sfx_events)
        generate_stage(state)
        state.cursor_x, state.cursor_y = 2, state.start_y
        MinigameUI.show_banner(state, MinigameUI.t(terminal, "minigames.common.hud_stage_of_fmt", { stage = 1, max = MAX_STAGE }, "STAGE: 1/" .. MAX_STAGE), 1.2)
        terminal:add_output("Data Pipeline — connect " .. MAX_STAGE .. " stages!")
    end,

    update = function(terminal, state, dt)
        if not state then return end
        MinigameUI.tick_frame(state, dt)
        if not state.active or state.game_over then return end

        -- The clock stops once the flow connects
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
                    MinigameUI.show_banner(state, MinigameUI.t(terminal, "minigames.common.hud_stage_of_fmt", { stage = state.stage, max = MAX_STAGE }, "STAGE: " .. state.stage .. "/" .. MAX_STAGE), 1.2)
                    generate_stage(state)
                end
            end
            return
        end

        if state.connected then
            local bonus = 80 + math.floor((state.time_limit - state.timer) * 2)
            state.stage_clear_delay = 0.8
            state.score = state.score + bonus
            MinigameSfx.play(terminal, state, "flow")
            if state.panel then
                local px = (state.panel.w - GRID_W * CELL) / 2 + (state.end_x - 1) * CELL
                MinigameUI.spawn_floater(state, px, GRID_TOP + (state.end_y - 1) * CELL, "+" .. bonus)
            end
            return
        end

        state.timer = state.timer + dt
        if state.timer >= state.time_limit then
            state.timer = state.time_limit
            state.game_over = true
            state.won = false
        end
    end,

    draw = function(terminal, state, fonts, vw, vh)
        if not state.active then return end

        local panel, pal, time = MinigameUI.begin_panel(terminal, fonts, vw, vh, PANEL_W, PANEL_H)
        state.panel = panel
        local remaining = math.max(0, math.ceil(state.time_limit - state.timer))
        local clock_color = remaining <= 5 and MinigameUI.color(pal, "red") or MinigameUI.color(pal, "yellow")

        MinigameUI.draw_hud("DATA PIPELINE", {
            { text = MinigameUI.t(terminal, "minigames.common.hud_score_fmt", { score = state.score }, "SCORE: " .. state.score), align = "right" },
            { text = MinigameUI.t(terminal, "minigames.common.hud_stage_of_fmt", { stage = state.stage, max = MAX_STAGE }, "STAGE: " .. state.stage .. "/" .. MAX_STAGE), align = "right", color = MinigameUI.color(pal, "cyan") },
            { text = MinigameUI.t(terminal, "minigames.common.hud_clock_fmt", { time = remaining .. "s" }, "TIME: " .. remaining .. "s"), align = "right", color = clock_color },
        }, "Click/Space: Rotate | Right-click/Q: Back | Arrows: Cursor | ESC: Quit", fonts, pal, panel)

        local ox = (panel.w - GRID_W * CELL) / 2
        love.graphics.push()
        love.graphics.translate(panel.x + ox, panel.y + GRID_TOP)
        if fonts.small then love.graphics.setFont(fonts.small) end

        for y = 1, GRID_H do
            for x = 1, GRID_W do
                local cell = state.grid[y][x]
                local cx, cy = (x - 1) * CELL, (y - 1) * CELL
                local flowing = state.flow_filled[y] and state.flow_filled[y][x]
                love.graphics.setColor(flowing and 0.1 or 0.05, flowing and 0.4 or 0.08, flowing and 0.45 or 0.08, 1)
                love.graphics.rectangle("fill", cx, cy, CELL - 2, CELL - 2)

                local bits = cell_bits(cell)
                local mx, my = cx + CELL / 2, cy + CELL / 2
                if cell.fixed then
                    love.graphics.setColor(0.9, 0.85, 0.3, 1)
                else
                    love.graphics.setColor(flowing and 0.2 or 0.3, flowing and 1 or 0.6, flowing and 1 or 0.6, 1)
                end
                love.graphics.setLineWidth(5)
                if bits[1] == 1 then love.graphics.line(mx, my, mx, cy) end
                if bits[2] == 1 then love.graphics.line(mx, my, mx, cy + CELL - 2) end
                if bits[3] == 1 then love.graphics.line(mx, my, cx + CELL - 2, my) end
                if bits[4] == 1 then love.graphics.line(mx, my, cx, my) end
                love.graphics.circle("fill", mx, my, 2.5)
                love.graphics.setLineWidth(1)

                if cell.is_start then
                    love.graphics.setColor(0.2, 1, 0.4, 0.9)
                    love.graphics.print("IN", cx + 4, cy + 4)
                elseif cell.is_end then
                    love.graphics.setColor(1, 0.8, 0.2, 0.9)
                    love.graphics.print("OUT", cx + 4, cy + 4)
                end
            end
        end

        if not state.game_over then
            local cx, cy = (state.cursor_x - 1) * CELL, (state.cursor_y - 1) * CELL
            love.graphics.setColor(1, 1, 1, MinigameUI.pulse_alpha(time, 6, 0.45, 0.95))
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx + 1, cy + 1, CELL - 4, CELL - 4)
            love.graphics.setLineWidth(1)
        end

        love.graphics.pop()
        MinigameUI.draw_particles(state, panel.x, panel.y)
        MinigameUI.draw_floaters(state, fonts, panel.x, panel.y)
        MinigameUI.draw_banner(state.banner_text, fonts, pal, panel, time, state.banner_timer or 0)

        if state.game_over then
            MinigameUI.draw_end_overlay(state.won and "win" or "lose", fonts, pal, panel, vw, vh, {
                time = time,
                title = state.won and "PIPELINE ONLINE" or "FLOW FAILED",
                lines = {
                    MinigameUI.t(terminal, "minigames.common.stage_line_fmt", { stage = state.stage }, "Stage: " .. state.stage),
                    MinigameUI.t(terminal, "minigames.common.score_fmt", { score = state.score }, "Score: " .. state.score),
                },
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
        if state.game_over or state.stage_clear_delay then return false end
        local move = CURSOR_MOVES[key]
        if move then
            state.cursor_x = math.max(1, math.min(GRID_W, state.cursor_x + move[1]))
            state.cursor_y = math.max(1, math.min(GRID_H, state.cursor_y + move[2]))
            return true
        end
        if key == "space" or key == "return" or key == "kpenter" or key == "e" then
            rotate_cell(terminal, state, state.cursor_x, state.cursor_y, 1)
            return true
        end
        if key == "q" then
            rotate_cell(terminal, state, state.cursor_x, state.cursor_y, 3)
            return true
        end
        return false
    end,

    mousepressed = function(terminal, state, x, y, button)
        if not state.active or state.game_over or state.stage_clear_delay then return false end
        if button ~= 1 and button ~= 2 then return false end
        local col, row = cell_at(state, x, y)
        if not col then return false end
        state.cursor_x, state.cursor_y = col, row
        rotate_cell(terminal, state, col, row, button == 1 and 1 or 3)
        return true
    end,

    mousemoved = function(terminal, state, x, y)
        if not state.active or state.game_over then return false end
        local col, row = cell_at(state, x, y)
        if col then
            state.cursor_x, state.cursor_y = col, row
        end
        return false
    end,

    get_score = function(state) return state.score or 0 end,
    help_text = "Data Pipeline (Click/Space rotate, Arrows cursor, ESC)",

    -- Pure helpers for test/test_user_mods.lua
    _test = {
        GRID_W = GRID_W,
        GRID_H = GRID_H,
        has_side = has_side,
        check_flow = check_flow,
        generate_stage = generate_stage,
    },
}
