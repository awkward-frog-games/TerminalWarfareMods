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

local function init_nodes()
    local nodes = {}
    local xs = { 90, 200, 310, 540, 650, 760 }
    for _, x in ipairs(xs) do
        table.insert(nodes, { x = x, y = GROUND_Y, alive = true })
    end
    return nodes
end

local function init_silos()
    return {
        { x = 200, y = GAME_H - 10, ammo = AMMO_PER_SILO, alive = true },
        { x = 425, y = GAME_H - 10, ammo = AMMO_PER_SILO, alive = true },
        { x = 650, y = GAME_H - 10, ammo = AMMO_PER_SILO, alive = true },
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
    state.spawn_queue = state.spawn_queue or {}
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

local function fire_counter(terminal, state, target_x, target_y)
    local silo = state.silos[state.selected_silo]
    if not silo or not silo.alive or (silo.ammo or 0) <= 0 then return end
    local dx = target_x - silo.x
    local dy = target_y - silo.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 8 then return end
    local speed = 380
    table.insert(state.counters, {
        x = silo.x,
        y = silo.y,
        ox = silo.x,
        oy = silo.y,
        tx = target_x,
        ty = target_y,
        vx = dx / dist * speed,
        vy = dy / dist * speed,
    })
    silo.ammo = silo.ammo - 1
    MinigameSfx.play(terminal, state, "launch")
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

local function damage_nearby(state, x, y, radius, is_friendly)
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
        version = "2.0.0",
        author = "Terminal Warfare Community",
        description = "Defend terminal nodes from incoming attack packets",
        score_unit = "score",
        requires_unlock = false,
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
            c.x = c.x + c.vx * dt
            c.y = c.y + c.vy * dt
            if c.y < 0 or c.x < 0 or c.x > PANEL_W then
                table.remove(state.counters, i)
            elseif math.sqrt((c.x - c.tx) ^ 2 + (c.y - c.ty) ^ 2) < 14 then
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
                    damage_nearby(state, ex.x, ex.y, ex.radius, false)
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
            local dx = m.tx - m.x
            local dy = m.ty - m.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < 6 then
                spawn_explosion(state, m.tx, m.ty, NUKE_RADIUS, false)
                table.remove(state.incoming, i)
            else
                m.x = m.x + dx / dist * m.speed * dt
                m.y = m.y + dy / dist * m.speed * dt
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
                state.wave = state.wave + 1
                state.wave_delay = 1.2
                for _, silo in ipairs(state.silos) do
                    if silo.alive then silo.ammo = AMMO_PER_SILO end
                end
                plan_wave_spawns(state)
                MinigameUI.show_banner(state, "WAVE " .. state.wave, 1.2)
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
            { text = "SCORE: " .. state.score, align = "right" },
            { text = "WAVE: " .. state.wave .. "/" .. MAX_WAVE, align = "right", color = cyan },
            { text = "AMMO: " .. total_ammo(state.silos), align = "right", color = yellow },
            { text = "NODES: " .. nodes_alive, align = "right", color = tg },
        }, "1/2/3: Silo | Click/Space: Fire | ESC: Quit", fonts, pal, panel)

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
        MinigameUI.draw_banner(state.banner_text, fonts, pal, panel, time, state.banner_timer or 0)

        if state.game_over then
            MinigameUI.draw_end_overlay(state.won and "win" or "lose", fonts, pal, panel, vw, vh, {
                time = time,
                title = state.won and "NODES SECURED" or "NODES LOST",
                lines = { "Wave: " .. state.wave, "Score: " .. state.score },
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
        if key == "1" then state.selected_silo = 1 return true end
        if key == "2" then state.selected_silo = 2 return true end
        if key == "3" then state.selected_silo = 3 return true end
        if key == "space" then
            fire_counter(terminal, state, state.aim_x, state.aim_y)
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
        state.aim_y = py
        fire_counter(terminal, state, px, py)
        return true
    end,

    mousemoved = function(terminal, state, x, y)
        if not state.active or state.game_over or not state.panel then return false end
        local px = x - state.panel.x
        local py = y - state.panel.y
        if px >= 0 and py >= 0 and px <= PANEL_W and py <= GAME_H then
            state.aim_x = px
            state.aim_y = math.max(40, py)
        end
        return false
    end,

    get_score = function(state)
        return state.score or 0
    end,

    help_text = "Intercept Command (1/2/3, mouse, Space, ESC)",
}
