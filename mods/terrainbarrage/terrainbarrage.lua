-- Terrain Barrage — Scorched Earth-style artillery (single-player gauntlet)

local PANEL_W = 850
local PANEL_H = 650
local GAME_TOP = 90
local GAME_H = 500
local GRAVITY = 320
local MAX_HP = 100
local MAX_OPPONENTS = 5
local SIM_DT = 0.016

local OPPONENTS = {
    { name = "Scout", hp = 80, aim_noise = 28, power_noise = 35 },
    { name = "Gunner", hp = 90, aim_noise = 18, power_noise = 25 },
    { name = "Veteran", hp = 100, aim_noise = 12, power_noise = 18 },
    { name = "Ace", hp = 110, aim_noise = 8, power_noise = 12 },
    { name = "Commander", hp = 120, aim_noise = 5, power_noise = 8 },
}

local function generate_terrain()
    local terrain = {}
    local num_points = 64
    local width = PANEL_W - 40
    local base_y = GAME_TOP + GAME_H - 80
    for i = 1, num_points do
        local x = 20 + (i - 1) * (width / (num_points - 1))
        local y = base_y - 60 - math.sin(i * 0.35) * 50 - math.cos(i * 0.12) * 30 - math.random() * 25
        table.insert(terrain, { x = x, y = y })
    end
    return terrain
end

local function terrain_height_at(terrain, x)
    for i = 1, #terrain - 1 do
        local p1, p2 = terrain[i], terrain[i + 1]
        if x >= p1.x and x <= p2.x then
            local t = (p2.x == p1.x) and 0 or (x - p1.x) / (p2.x - p1.x)
            return p1.y + (p2.y - p1.y) * t
        end
    end
    return GAME_TOP + GAME_H
end

local function terrain_slope_at(terrain, x)
    local eps = 4
    local y1 = terrain_height_at(terrain, x - eps)
    local y2 = terrain_height_at(terrain, x + eps)
    return math.atan2(y2 - y1, eps * 2)
end

local function place_tank(terrain, x_ratio)
    local x = 20 + (PANEL_W - 40) * x_ratio
    return { x = x, y = terrain_height_at(terrain, x) - 6, hp = MAX_HP }
end

local function deform_terrain(terrain, cx, cy, radius, depth)
    for _, p in ipairs(terrain) do
        local dx = p.x - cx
        if math.abs(dx) < radius then
            local factor = 1 - (math.abs(dx) / radius)
            p.y = p.y + depth * factor * factor
        end
    end
end

local function simulate_shot(terrain, ox, oy, angle, power, wind, facing)
    local rad = math.rad(angle)
    local px, py = ox, oy - 8
    local vx = math.cos(rad) * power * facing
    local vy = -math.sin(rad) * power
    local wind_force = wind * 12

    while py < GAME_TOP + GAME_H + 40 and px > -20 and px < PANEL_W + 20 do
        vy = vy + GRAVITY * SIM_DT
        vx = vx + wind_force * SIM_DT
        px = px + vx * SIM_DT
        py = py + vy * SIM_DT
        local ground = terrain_height_at(terrain, px)
        if py >= ground then
            return px, ground, true
        end
    end
    return px, py, false
end

local function solve_ai_shot(state, tank, target, noise)
    local best_dist = math.huge
    local best_angle, best_power = 45, 250
    local ox, oy = tank.x, tank.y
    local facing = (target.x >= ox) and 1 or -1

    for angle = 15, 85, 3 do
        for power = 120, 420, 12 do
            local ix, iy = simulate_shot(state.terrain, ox, oy, angle, power, state.wind, facing)
            local dx = ix - target.x
            local dy = iy - (target.y - 8)
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < best_dist then
                best_dist = dist
                best_angle = angle
                best_power = power
            end
        end
    end

    best_angle = best_angle + (math.random() - 0.5) * (noise.aim_noise or 15)
    best_power = best_power + (math.random() - 0.5) * (noise.power_noise or 20)
    return best_angle, best_power, facing
end

local function fire_projectile(state, tank, angle, power, owner, facing)
    local rad = math.rad(angle)
    state.projectile = {
        x = tank.x,
        y = tank.y - 8,
        vx = math.cos(rad) * power * facing,
        vy = -math.sin(rad) * power,
        owner = owner,
        power = power,
        active = true,
        trail = {},
    }
end

local function proximity_damage(impact_x, impact_y, tank, max_dmg)
    local dx = impact_x - tank.x
    local dy = impact_y - (tank.y - 8)
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 55 then return 0 end
    local factor = 1 - (dist / 55)
    return math.floor(max_dmg * factor * factor)
end

local function record_shot(state, angle, power, impact_x, impact_y)
    table.insert(state.shot_history, 1, { angle = angle, power = power, ix = impact_x, iy = impact_y })
    while #state.shot_history > 3 do
        table.remove(state.shot_history)
    end
end

local function start_new_round(state)
    state.terrain = generate_terrain()
    state.player = place_tank(state.terrain, 0.12)
    state.enemy = place_tank(state.terrain, 0.88)
    state.enemy.hp = OPPONENTS[state.opponent_index].hp
    state.player.y = terrain_height_at(state.terrain, state.player.x) - 6
    state.enemy.y = terrain_height_at(state.terrain, state.enemy.x) - 6
    state.wind = math.random(-22, 22)
    state.turn = "player"
    state.phase = "aim"
    state.angle = 45
    state.power = 250
    state.projectile = nil
    state.message = string.format("Opponent %d/%d — %s", state.opponent_index, MAX_OPPONENTS,
        OPPONENTS[state.opponent_index].name)
end

local function start_ai_turn(state)
    state.turn = "enemy"
    state.phase = "ai_aim"
    state.ai_timer = 1.2
    local opp = OPPONENTS[state.opponent_index]
    local angle, power, facing = solve_ai_shot(state, state.enemy, state.player, opp)
    state.enemy_angle = angle
    state.enemy_facing = facing
    state.ai_angle = angle
    state.ai_power = power
end

local function draw_tank(tank, color, facing, angle, terrain)
    local slope = terrain_slope_at(terrain, tank.x)
    local bx, by = tank.x, tank.y

    love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 1)
    love.graphics.rectangle("fill", bx - 18, by + 2, 36, 5)
    love.graphics.rectangle("fill", bx - 14, by - 2, 8, 5)
    love.graphics.rectangle("fill", bx + 6, by - 2, 8, 5)

    love.graphics.setColor(color[1], color[2], color[3], 1)
    local hw, hh = 16, 7
    love.graphics.push()
    love.graphics.translate(bx, by - 4)
    love.graphics.rotate(slope)
    love.graphics.rectangle("fill", -hw, -hh, hw * 2, hh * 2)
    love.graphics.pop()

    love.graphics.setColor(color[1] * 0.85, color[2] * 0.85, color[3] * 0.85, 1)
    love.graphics.circle("fill", bx, by - 8, 5)

    local rad = math.rad(angle * facing)
    local bl = 22
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(bx, by - 8, bx + math.cos(rad) * bl * facing, by - 8 - math.sin(rad) * bl)
    love.graphics.setLineWidth(1)
end

return {
    metadata = {
        command = "terrainbarrage",
        name = "Terrain Barrage",
        version = "2.0.0",
        author = "Terminal Warfare Community",
        description = "Artillery gauntlet across destructible terrain",
        score_unit = "score",
        requires_unlock = false,
        sfx_events = {
            { id = "fire", description = "Cannon fired" },
            { id = "impact", description = "Shell impact" },
            { id = "tank_hit", description = "Direct tank hit" },
            { id = "win", description = "Victory" },
            { id = "lose", description = "Defeat" },
        },
    },

    init_state = function(terminal)
        return {
            active = false,
            game_over = false,
            won = false,
            score = 0,
            terrain = {},
            player = { x = 0, y = 0, hp = MAX_HP },
            enemy = { x = 0, y = 0, hp = MAX_HP },
            turn = "player",
            phase = "aim",
            angle = 45,
            power = 250,
            wind = 0,
            projectile = nil,
            panel = nil,
            ai_timer = 0,
            message = "",
            opponent_index = 1,
            enemy_angle = 135,
            enemy_facing = -1,
            shot_history = {},
            preview_points = {},
        }
    end,

    start = function(terminal, state)
        state.active = true
        state.game_over = false
        state.won = false
        state.score = 0
        state.opponent_index = 1
        state.player.hp = MAX_HP
        state.shot_history = {}
        start_new_round(state)
        MinigameUI.init_common_state(state)
        MinigameSfx.attach(terminal, state, state.metadata.command, state.metadata.sfx_events)
        terminal:add_output("Terrain Barrage — defeat all 5 opponents!")
    end,

    update = function(terminal, state, dt)
        if not state then return end
        MinigameUI.tick_frame(state, dt)
        if not state.active or state.game_over then return end

        if state.phase == "ai_aim" then
            state.ai_timer = state.ai_timer - dt
            if state.ai_timer <= 0 then
                fire_projectile(state, state.enemy, state.ai_angle, state.ai_power, "enemy", state.enemy_facing or -1)
                state.phase = "flying"
                MinigameSfx.play(terminal, state, "fire")
            end
            return
        end

        if state.turn == "player" and state.phase == "aim" then
            state.preview_points = {}
            local px, py = state.player.x, state.player.y
            local ix, iy, hit = simulate_shot(state.terrain, px, py, state.angle, state.power, state.wind, 1)
            if hit then
                table.insert(state.preview_points, { ix, iy })
            end
        end

        local proj = state.projectile
        if not proj or not proj.active then return end

        table.insert(proj.trail, { x = proj.x, y = proj.y })
        if #proj.trail > 40 then table.remove(proj.trail, 1) end

        proj.vy = proj.vy + GRAVITY * dt
        proj.vx = proj.vx + state.wind * 12 * dt
        proj.x = proj.x + proj.vx * dt
        proj.y = proj.y + proj.vy * dt

        local ground_y = terrain_height_at(state.terrain, proj.x)
        local out_of_bounds = proj.x < 0 or proj.x > PANEL_W or proj.y > GAME_TOP + GAME_H + 40

        if proj.y >= ground_y or out_of_bounds then
            local hit_x = math.max(20, math.min(PANEL_W - 20, proj.x))
            local hit_y = out_of_bounds and (GAME_TOP + GAME_H - 20) or ground_y
            local crater_r = 30 + (proj.power or 250) * 0.04
            local crater_d = 14 + (proj.power or 250) * 0.025
            deform_terrain(state.terrain, hit_x, hit_y, crater_r, crater_d)
            MinigameUI.spawn_particles(state, hit_x, hit_y, { count = 14, colors = { { 1, 0.5, 0.1, 1 } } })
            MinigameUI.trigger_shake(state, 5, 0.2)
            MinigameSfx.play(terminal, state, "impact")

            if proj.owner == "player" then
                record_shot(state, state.angle, state.power, hit_x, hit_y)
            end

            local damage = 0
            if proj.owner == "player" then
                damage = proximity_damage(hit_x, hit_y, state.enemy, 50)
            else
                damage = proximity_damage(hit_x, hit_y, state.player, 50)
            end
            if damage > 0 then MinigameSfx.play(terminal, state, "tank_hit") end

            if proj.owner == "player" then
                state.enemy.hp = math.max(0, state.enemy.hp - damage)
                state.score = state.score + damage
                state.player.y = terrain_height_at(state.terrain, state.player.x) - 6
                state.enemy.y = terrain_height_at(state.terrain, state.enemy.x) - 6
                if state.enemy.hp <= 0 then
                    state.score = state.score + 100
                    if state.opponent_index >= MAX_OPPONENTS then
                        state.game_over = true
                        state.won = true
                        state.score = state.score + 200
                        MinigameSfx.play(terminal, state, "win")
                    else
                        state.opponent_index = state.opponent_index + 1
                        state.player.hp = math.min(MAX_HP, state.player.hp + 15)
                        start_new_round(state)
                        MinigameUI.show_banner(state, "OPPONENT DOWN", 1.5)
                    end
                    proj.active = false
                    state.projectile = nil
                    return
                end
                start_ai_turn(state)
                state.message = "Enemy turn..."
            else
                state.player.hp = math.max(0, state.player.hp - damage)
                state.player.y = terrain_height_at(state.terrain, state.player.x) - 6
                state.enemy.y = terrain_height_at(state.terrain, state.enemy.x) - 6
                if state.player.hp <= 0 then
                    state.game_over = true
                    MinigameSfx.play(terminal, state, "lose")
                    proj.active = false
                    state.projectile = nil
                    return
                end
                state.turn = "player"
                state.phase = "aim"
                state.wind = math.max(-28, math.min(28, state.wind + math.random(-8, 8)))
                state.message = "Your turn — aim and fire!"
            end

            proj.active = false
            state.projectile = nil
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

        MinigameUI.draw_hud("TERRAIN BARRAGE", {
            { text = "SCORE: " .. state.score, align = "right" },
            { text = string.format("OPP %d/%d", state.opponent_index, MAX_OPPONENTS), align = "right", color = cyan },
            { text = "WIND: " .. state.wind, align = "right", color = cyan },
            { text = string.upper(state.turn) .. " TURN", align = "right", color = tg },
        }, "A/D: Angle | W/S: Power | Space: Fire | ESC: Quit", fonts, pal, panel)

        local sx, sy = MinigameUI.get_shake_offset(state)
        love.graphics.push()
        love.graphics.translate(panel.x + sx, panel.y + sy)

        love.graphics.setColor(0.05, 0.08, 0.05, 1)
        love.graphics.rectangle("fill", 0, GAME_TOP, PANEL_W, GAME_H)

        if #state.terrain >= 2 then
            love.graphics.setColor(0.12, 0.22, 0.1, 1)
            love.graphics.polygon("fill",
                state.terrain[1].x, GAME_TOP + GAME_H,
                state.terrain[#state.terrain].x, GAME_TOP + GAME_H,
                state.terrain[#state.terrain].x, state.terrain[#state.terrain].y,
                state.terrain[1].x, state.terrain[1].y)
            for i = 1, #state.terrain - 1 do
                local p1, p2 = state.terrain[i], state.terrain[i + 1]
                love.graphics.setColor(tg[1], tg[2], tg[3], 1)
                love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            end
        end

        for _, shot in ipairs(state.shot_history) do
            love.graphics.setColor(cyan[1], cyan[2], cyan[3], 0.25)
            love.graphics.circle("line", shot.ix, shot.iy, 6)
        end

        if state.turn == "player" and state.phase == "aim" then
            local px, py = state.player.x, state.player.y - 8
            local sim_x, sim_y = px, py
            local rad = math.rad(state.angle)
            local vx = math.cos(rad) * state.power
            local vy = -math.sin(rad) * state.power
            local wind_force = state.wind * 12
            love.graphics.setColor(cyan[1], cyan[2], cyan[3], 0.35)
            for _ = 1, 80 do
                local nx = sim_x + vx * SIM_DT
                local ny = sim_y + vy * SIM_DT
                love.graphics.line(sim_x, sim_y, nx, ny)
                vy = vy + GRAVITY * SIM_DT
                vx = vx + wind_force * SIM_DT
                sim_x, sim_y = nx, ny
                if sim_y >= terrain_height_at(state.terrain, sim_x) then break end
            end
        end

        draw_tank(state.player, cyan, 1, state.angle, state.terrain)
        draw_tank(state.enemy, red, state.enemy_facing or -1, state.enemy_angle or 135, state.terrain)

        if state.projectile and state.projectile.active then
            local proj = state.projectile
            if #proj.trail >= 2 then
                love.graphics.setColor(yellow[1], yellow[2], yellow[3], 0.5)
                for i = 2, #proj.trail do
                    local a, b = proj.trail[i - 1], proj.trail[i]
                    love.graphics.line(a.x, a.y, b.x, b.y)
                end
            end
            love.graphics.setColor(yellow[1], yellow[2], yellow[3], 1)
            love.graphics.circle("fill", proj.x, proj.y, 4)
        end

        love.graphics.setColor(1, 1, 1, 0.9)
        if fonts.small then love.graphics.setFont(fonts.small) end
        love.graphics.print("P HP: " .. state.player.hp, 20, GAME_TOP + 8)
        love.graphics.print("E HP: " .. state.enemy.hp, PANEL_W - 100, GAME_TOP + 8)
        if state.phase == "aim" and state.turn == "player" then
            love.graphics.print(string.format("ANGLE: %d  POWER: %d", math.floor(state.angle), math.floor(state.power)), 20, GAME_TOP + 24)
        end
        love.graphics.print(state.message or "", 20, GAME_TOP + GAME_H - 22)

        if state.wind ~= 0 then
            local wx = PANEL_W / 2
            local wy = GAME_TOP + 12
            love.graphics.setColor(cyan[1], cyan[2], cyan[3], 0.8)
            local dir = state.wind > 0 and 1 or -1
            love.graphics.line(wx, wy, wx + dir * math.min(40, math.abs(state.wind) * 2), wy)
        end

        love.graphics.pop()
        MinigameUI.draw_particles(state, panel.x, panel.y)

        if state.game_over then
            MinigameUI.draw_end_overlay(state.won and "win" or "lose", fonts, pal, panel, vw, vh, {
                time = time,
                title = state.won and "GAUNTLET COMPLETE" or "TANK DESTROYED",
                lines = { "Score: " .. state.score },
                terminal = terminal,
            })
        end
    end,

    keypressed = function(terminal, state, key)
        if not state.active then return false end
        if key == "escape" then
            state.active = false
            terminal:add_output("Terrain Barrage ended. Score: " .. state.score)
            return true
        end
        if state.game_over then return false end
        if state.turn ~= "player" or state.phase ~= "aim" then return false end

        if key == "a" then state.angle = math.min(85, state.angle + 2) return true end
        if key == "d" then state.angle = math.max(5, state.angle - 2) return true end
        if key == "w" then state.power = math.min(420, state.power + 8) return true end
        if key == "s" then state.power = math.max(80, state.power - 8) return true end
        if key == "space" then
            fire_projectile(state, state.player, state.angle, state.power, "player", 1)
            state.phase = "flying"
            MinigameSfx.play(terminal, state, "fire")
            state.message = "Shell in flight..."
            return true
        end
        return false
    end,

    get_score = function(state)
        return state.score or 0
    end,

    help_text = "Terrain Barrage (A/D/W/S, Space, ESC)",
}
