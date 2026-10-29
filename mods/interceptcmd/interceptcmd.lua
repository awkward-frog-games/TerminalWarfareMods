-- Intercept Command — Missile Command-style defense mod

local MAX_WAVE = 8
local PANEL_W = 850
local PANEL_H = 650
local GAME_H = 520
local GROUND_Y = GAME_H - 30
local SKY_Y = 20
local AMMO_PER_SILO = 10
local INTERCEPT_RADIUS = 35
local NUKE_RADIUS = 50
local COUNTER_SPEED = 380
local AIM_SPEED = 420
local AIM_MIN_Y = 40
local AIM_MAX_Y = GAME_H - 50
-- End-of-wave bonus per surviving node and per unspent counter-missile
local NODE_BONUS = 25
local AMMO_BONUS = 2

local function init_nodes()
    local nodes = {}
    -- Three nodes between each pair of silos, clear of the silo blast radius
    local xs = { 150, 240, 330, 520, 610, 700 }
    for _, x in ipairs(xs) do
        table.insert(nodes, { x = x, y = GROUND_Y, alive = true })
    end
    return nodes
end

local function init_silos()
    return {
        { x = 60, y = GAME_H - 10, ammo = AMMO_PER_SILO, alive = true },
        { x = 425, y = GAME_H - 10, ammo = AMMO_PER_SILO, alive = true },
        { x = 790, y = GAME_H - 10, ammo = AMMO_PER_SILO, alive = true },
    }
end

local function alive_node_count(nodes)
    local n = 0
    for _, node in ipairs(nodes) do
        if node.alive then n = n + 1 end
    end
    return n
end

local function total_ammo(silos)
    local n = 0
    for _, s in ipairs(silos) do
        if s.alive then n = n + (s.ammo or 0) end
    end
    return n
end

local function pick_target_x(nodes)
    local alive = {}
    for _, node in ipairs(nodes) do
        if node.alive then table.insert(alive, node) end
    end
    if #alive == 0 then return math.random(60, PANEL_W - 60) end
    local node = alive[math.random(#alive)]
    return node.x + (math.random() - 0.5) * 40
end

local function spawn_incoming(state)
    local target_x = pick_target_x(state.nodes)
    local start_x = 60 + math.random() * (PANEL_W - 120)
    table.insert(state.incoming, {
        x = start_x,
        y = SKY_Y,
        ox = start_x,
        oy = SKY_Y,
        tx = target_x,
        ty = GROUND_Y,
        speed = 55 + state.wave * 8 + math.random() * 20,
        split = false,
    })
end

local function plan_wave_spawns(state)
    local count = math.min(6 + state.wave * 2 + math.floor(state.wave / 2), 22)
    state.spawns_remaining = count
    state.spawn_timer = 0.4
    state.spawn_interval = math.max(0.35, 1.4 - state.wave * 0.12)
end

local function spawn_explosion(state, x, y, max_radius, is_intercept)
    table.insert(state.explosions, {
        x = x,
        y = y,
        radius = 4,
        max_radius = max_radius,
        expand_rate = is_intercept and 180 or 140,
        hold_timer = is_intercept and 0.08 or 0.15,
        phase = "expand",
        is_intercept = is_intercept,
        alpha = 1,
    })
end

--- Index of the closest silo to x that can still fire, or nil.
local function nearest_ready_silo(silos, x)
    local best, best_dist
    for i, silo in ipairs(silos) do
        if silo.alive and (silo.ammo or 0) > 0 then
            local d = math.abs(silo.x - x)
            if not best_dist or d < best_dist then
                best, best_dist = i, d
            end
        end
    end
    return best
end

--- Launch a counter-missile from silo `index` (nil = nearest silo with ammo) at the target.
--- @return boolean true when a missile launched
local function fire_counter(terminal, state, index, target_x, target_y)
    index = index or nearest_ready_silo(state.silos, target_x)
    local silo = index and state.silos[index]
    if not silo or not silo.alive or (silo.ammo or 0) <= 0 then return false end
    local dx = target_x - silo.x
    local dy = target_y - silo.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 8 then return false end
    state.selected_silo = index
    table.insert(state.counters, {
        x = silo.x,
        y = silo.y,
        ox = silo.x,
        oy = silo.y,
        tx = target_x,
        ty = target_y,
        vx = dx / dist * COUNTER_SPEED,
        vy = dy / dist * COUNTER_SPEED,
    })
    silo.ammo = silo.ammo - 1
    MinigameSfx.play(terminal, state, "launch")
    return true
end

--- Advance a counter-missile. Returns true when it reached its target this frame; checking
--- the remaining distance against the step keeps fast frames from flying past the target.
local function step_counter(c, dt)
    local dx, dy = c.tx - c.x, c.ty - c.y
    local remaining = math.sqrt(dx * dx + dy * dy)
    if remaining <= COUNTER_SPEED * dt then
        c.x, c.y = c.tx, c.ty
        return true
    end
    c.x = c.x + c.vx * dt
    c.y = c.y + c.vy * dt
    return false
end

--- Advance an incoming missile toward its ground target. Returns true on impact.
local function step_incoming(m, dt)
    local dx, dy = m.tx - m.x, m.ty - m.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = m.speed * dt
    if dist <= step then
        m.x, m.y = m.tx, m.ty
        return true
    end
    m.x = m.x + dx / dist * step
    m.y = m.y + dy / dist * step
    return false
end

local function destroy_missile_in_radius(terminal, state, x, y, radius)
    for i = #state.incoming, 1, -1 do
        local m = state.incoming[i]
        local dx = m.x - x
        local dy = m.y - y
        if dx * dx + dy * dy <= radius * radius then
            table.remove(state.incoming, i)
            state.score = state.score + 10 + state.wave * 3
            MinigameUI.spawn_particles(state, m.x, m.y, { count = 6, colors = { { 1, 0.8, 0.2, 1 } } })
            MinigameSfx.play(terminal, state, "explode", { overlap = true })
        end
    end
end

local function damage_nearby(terminal, state, x, y, radius, is_friendly)
    for _, node in ipairs(state.nodes) do
        if node.alive then
            local dx = node.x - x
            local dy = node.y - y
            if dx * dx + dy * dy <= radius * radius then
                node.alive = false
                MinigameUI.trigger_shake(state, 8, 0.3)
                MinigameSfx.play(terminal, state, "node_hit")
                state.score = math.max(0, state.score - 40)
            end
        end
    end
    for _, silo in ipairs(state.silos) do
        if silo.alive and not is_friendly then
            local dx = silo.x - x
            local dy = silo.y - y
            if dx * dx + dy * dy <= (radius * 0.7) * (radius * 0.7) then
                silo.alive = false
                silo.ammo = 0
            end
        end
    end
end

return {
    metadata = {
        command = "interceptcmd",
        name = "Intercept Command",
        version = "2.1.0",
        author = "Terminal Warfare Community",
        description = "Defend terminal nodes from incoming attack packets",
        score_unit = "score",
        requires_unlock = false,
        score_target = 2500,
        -- Stick steers the crosshair; A fires from the nearest silo, LB/Y/RB pick a silo
        gamepad = { stick = "arrows", buttons = { a = "space", leftshoulder = "1", y = "2", rightshoulder = "3" } },
        sfx_events = {
            { id = "launch", description = "Counter-missile launched" },
            { id = "explode", description = "Intercept explosion" },
            { id = "node_hit", description = "Node destroyed" },
            { id = "wave_start", description = "New wave" },
            { id = "win", description = "All waves cleared" },
            { id = "game_over", description = "All nodes lost" },
        },
    },

    init_state = function(terminal)
        return {
            active = false,
            game_over = false,
            won = false,
            score = 0,
            wave = 1,
            selected_silo = 2,
            silos = init_silos(),
            nodes = init_nodes(),
            incoming = {},
            counters = {},
            explosions = {},
            panel = nil,
            aim_x = 425,
            aim_y = 260,
            wave_delay = 0,
            spawns_remaining = 0,
            spawn_timer = 0,
            spawn_interval = 1,
        }
    end,

    start = function(terminal, state)
        state.active = true
        state.game_over = false
        state.won = false
        state.score = 0
        state.wave = 1
        state.selected_silo = 2
        state.silos = init_silos()
        state.nodes = init_nodes()
        state.incoming = {}
        state.counters = {}
        state.explosions = {}
        state.aim_x = PANEL_W / 2
        state.aim_y = 260
        state.wave_delay = 0.8
        plan_wave_spawns(state)
        MinigameUI.init_common_state(state)
        MinigameSfx.attach(terminal, state, state.metadata.command, state.metadata.sfx_events)
        MinigameSfx.play(terminal, state, "wave_start")
        terminal:add_output("Intercept Command online — defend the nodes!")
    end,

    update = function(terminal, state, dt)
        if not state then return end
        MinigameUI.tick_frame(state, dt)
        if not state.active or state.game_over then return end

        -- Crosshair: held arrows/WASD or the gamepad stick
        local ax = (MinigameUI.is_down("right", "d") and 1 or 0) - (MinigameUI.is_down("left", "a") and 1 or 0)
        local ay = (MinigameUI.is_down("down", "s") and 1 or 0) - (MinigameUI.is_down("up", "w") and 1 or 0)
        if ax ~= 0 or ay ~= 0 then
            state.aim_x = math.max(10, math.min(PANEL_W - 10, state.aim_x + ax * AIM_SPEED * dt))
            state.aim_y = math.max(AIM_MIN_Y, math.min(AIM_MAX_Y, state.aim_y + ay * AIM_SPEED * dt))
        end

        if state.wave_delay > 0 then
            state.wave_delay = state.wave_delay - dt
            return
        end

        if state.spawns_remaining and state.spawns_remaining > 0 then
            state.spawn_timer = state.spawn_timer - dt
            if state.spawn_timer <= 0 then
                spawn_incoming(state)
                state.spawns_remaining = state.spawns_remaining - 1
                state.spawn_timer = state.spawn_interval
            end
        end

        for i = #state.counters, 1, -1 do
            local c = state.counters[i]
            if step_counter(c, dt) then
                spawn_explosion(state, c.tx, c.ty, INTERCEPT_RADIUS, true)
                table.remove(state.counters, i)
            end
        end

        for i = #state.explosions, 1, -1 do
            local ex = state.explosions[i]
            if ex.phase == "expand" then
                ex.radius = math.min(ex.max_radius, ex.radius + ex.expand_rate * dt)
                destroy_missile_in_radius(terminal, state, ex.x, ex.y, ex.radius)
                if ex.radius >= ex.max_radius then
                    ex.phase = "hold"
                end
            elseif ex.phase == "hold" then
                ex.hold_timer = ex.hold_timer - dt
                destroy_missile_in_radius(terminal, state, ex.x, ex.y, ex.radius)
                if not ex.is_intercept then
                    damage_nearby(terminal, state, ex.x, ex.y, ex.radius, false)
                end
                if ex.hold_timer <= 0 then
                    ex.phase = "fade"
                end
            else
                ex.alpha = ex.alpha - dt * 2
                if ex.alpha <= 0 then
                    table.remove(state.explosions, i)
                end
            end
        end

        for i = #state.incoming, 1, -1 do
            local m = state.incoming[i]
            if step_incoming(m, dt) then
                spawn_explosion(state, m.tx, m.ty, NUKE_RADIUS, false)
                table.remove(state.incoming, i)
            else
                if state.wave >= 6 and not m.split and m.y > GAME_H * 0.45 then
                    m.split = true
                    for _ = 1, 2 do
                        table.insert(state.incoming, {
                            x = m.x, y = m.y, ox = m.x, oy = m.y,
                            tx = pick_target_x(state.nodes), ty = GROUND_Y,
                            speed = m.speed * 1.15, split = true,
                        })
                    end
                end
            end
        end

        if alive_node_count(state.nodes) <= 0 then
            state.game_over = true
            MinigameSfx.play(terminal, state, "game_over")
            return
        end

        local wave_active = (state.spawns_remaining or 0) > 0 or #state.incoming > 0
        if not wave_active and #state.explosions == 0 then
            if state.wave >= MAX_WAVE then
                state.game_over = true
                state.won = true
                state.score = state.score + 200 + total_ammo(state.silos) * 5
                MinigameSfx.play(terminal, state, "win")
            else
                local nodes_left = alive_node_count(state.nodes)
                local bonus = nodes_left * NODE_BONUS + total_ammo(state.silos) * AMMO_BONUS
                state.score = state.score + bonus
                MinigameUI.spawn_floater(state, PANEL_W / 2 - 30, GAME_H - 90, "+" .. bonus)
                state.wave = state.wave + 1
                state.wave_delay = 1.2
                for _, silo in ipairs(state.silos) do
                    if silo.alive then silo.ammo = AMMO_PER_SILO end
                end
                plan_wave_spawns(state)
                MinigameUI.show_banner(state, MinigameUI.t(terminal, "minigames.common.wave_fmt", { wave = state.wave }, "WAVE " .. state.wave), 1.2)
                MinigameSfx.play(terminal, state, "wave_start")
            end
        end
    end,

    draw = function(terminal, state, fonts, vw, vh)
        if not state.active then return end

        local panel, pal, time = MinigameUI.begin_panel(terminal, fonts, vw, vh, PANEL_W, PANEL_H)
        state.panel = panel

        local tg = MinigameUI.color(pal, "terminal_green")
        local cyan = MinigameUI.color(pal, "cyan")
        local red = MinigameUI.color(pal, "red")
        local yellow = MinigameUI.color(pal, "yellow")
        local nodes_alive = alive_node_count(state.nodes)

        MinigameUI.draw_hud("INTERCEPT COMMAND", {
            { text = MinigameUI.t(terminal, "minigames.common.hud_score_fmt", { score = state.score }, "SCORE: " .. state.score), align = "right" },
            { text = MinigameUI.t(terminal, "minigames.common.hud_wave_of_fmt", { wave = state.wave, max = MAX_WAVE }, "WAVE: " .. state.wave .. "/" .. MAX_WAVE), align = "right", color = cyan },
            { text = "AMMO: " .. total_ammo(state.silos), align = "right", color = yellow },
            { text = "NODES: " .. nodes_alive, align = "right", color = tg },
        }, "Mouse/Arrows: Aim | Click/Space: Fire | 1/2/3: Fire from silo | ESC: Quit", fonts, pal, panel)

        local sx, sy = MinigameUI.get_shake_offset(state)
        love.graphics.push()
        love.graphics.translate(panel.x + sx, panel.y + sy)

        love.graphics.setColor(0.08, 0.12, 0.08, 1)
        love.graphics.rectangle("fill", 0, GAME_H - 40, PANEL_W, 40)
        love.graphics.setColor(tg[1], tg[2], tg[3], 0.4)
        love.graphics.line(0, SKY_Y, PANEL_W, SKY_Y)

        for _, node in ipairs(state.nodes) do
            if node.alive then
                love.graphics.setColor(cyan[1], cyan[2], cyan[3], 1)
                love.graphics.rectangle("fill", node.x - 18, node.y - 8, 36, 16)
                love.graphics.setColor(tg[1], tg[2], tg[3], 0.8)
                love.graphics.rectangle("line", node.x - 18, node.y - 8, 36, 16)
            else
                love.graphics.setColor(red[1], red[2], red[3], 0.35)
                love.graphics.rectangle("fill", node.x - 18, node.y, 36, 4)
            end
        end

        for i, silo in ipairs(state.silos) do
            if silo.alive then
                local selected = (i == state.selected_silo)
                love.graphics.setColor(selected and yellow[1] or tg[1], selected and yellow[2] or tg[2], selected and yellow[3] or tg[3], 1)
                love.graphics.polygon("fill", silo.x, silo.y - 18, silo.x - 10, silo.y, silo.x + 10, silo.y)
                love.graphics.rectangle("fill", silo.x - 6, silo.y, 12, 8)
                if fonts.small then love.graphics.setFont(fonts.small) end
                love.graphics.print(tostring(silo.ammo or 0), silo.x - 4, silo.y - 32)
            else
                love.graphics.setColor(red[1], red[2], red[3], 0.4)
                love.graphics.rectangle("fill", silo.x - 8, silo.y - 4, 16, 8)
            end
        end

        love.graphics.setColor(red[1], red[2], red[3], 1)
        for _, m in ipairs(state.incoming) do
            love.graphics.line(m.ox, m.oy, m.x, m.y)
            love.graphics.circle("fill", m.x, m.y, 4)
        end

        love.graphics.setColor(yellow[1], yellow[2], yellow[3], 1)
        for _, c in ipairs(state.counters) do
            love.graphics.line(c.ox, c.oy, c.x, c.y)
            love.graphics.circle("fill", c.x, c.y, 3)
        end

        for _, ex in ipairs(state.explosions) do
            local alpha = ex.alpha or 1
            local col = ex.is_intercept and { 1, 1, 0.4 } or { 1, 0.3, 0.1 }
            love.graphics.setColor(col[1], col[2], col[3], alpha * 0.7)
            love.graphics.circle("fill", ex.x, ex.y, ex.radius)
            love.graphics.setColor(col[1], col[2], col[3], alpha)
            love.graphics.circle("line", ex.x, ex.y, ex.radius)
        end

        love.graphics.setColor(cyan[1], cyan[2], cyan[3], 0.35)
        love.graphics.line(state.aim_x, GAME_H - 40, state.aim_x, state.aim_y)
        love.graphics.circle("line", state.aim_x, state.aim_y, 10)

        love.graphics.pop()
        MinigameUI.draw_particles(state, panel.x, panel.y)
        MinigameUI.draw_floaters(state, fonts, panel.x, panel.y)
        MinigameUI.draw_banner(state.banner_text, fonts, pal, panel, time, state.banner_timer or 0)

        if state.game_over then
            MinigameUI.draw_end_overlay(state.won and "win" or "lose", fonts, pal, panel, vw, vh, {
                time = time,
                title = state.won and "NODES SECURED" or "NODES LOST",
                lines = {
                    MinigameUI.t(terminal, "minigames.common.wave_line_fmt", { wave = state.wave }, "Wave: " .. state.wave),
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
            terminal:add_output("Intercept Command ended. Score: " .. state.score)
            return true
        end
        if state.game_over then return false end
        local silo = tonumber(key)
        if silo and silo >= 1 and silo <= #state.silos then
            fire_counter(terminal, state, silo, state.aim_x, state.aim_y)
            return true
        end
        if key == "space" or key == "return" then
            fire_counter(terminal, state, nil, state.aim_x, state.aim_y)
            return true
        end
        return false
    end,

    mousepressed = function(terminal, state, x, y, button)
        if not state.active or state.game_over or button ~= 1 then return false end
        if not state.panel then return false end
        local px = x - state.panel.x
        local py = y - state.panel.y
        if px < 0 or py < 0 or px > PANEL_W or py > GAME_H then return false end
        state.aim_x = px
        state.aim_y = math.max(AIM_MIN_Y, py)
        fire_counter(terminal, state, nil, state.aim_x, state.aim_y)
        return true
    end,

    mousemoved = function(terminal, state, x, y)
        if not state.active or state.game_over or not state.panel then return false end
        local px = x - state.panel.x
        local py = y - state.panel.y
        if px >= 0 and py >= 0 and px <= PANEL_W and py <= GAME_H then
            state.aim_x = px
            state.aim_y = math.max(AIM_MIN_Y, py)
        end
        return false
    end,

    get_score = function(state)
        return state.score or 0
    end,

    help_text = "Intercept Command (mouse/arrows aim, Space/1/2/3 fire, ESC)",

    -- Pure helpers for test/test_user_mods.lua
    _test = {
        init_silos = init_silos,
        init_nodes = init_nodes,
        nearest_ready_silo = nearest_ready_silo,
        fire_counter = fire_counter,
        step_counter = step_counter,
        step_incoming = step_incoming,
    },
}
