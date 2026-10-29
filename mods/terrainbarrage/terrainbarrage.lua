-- Terrain Barrage — artillery duel across destructible terrain (single-player gauntlet)
--
-- The terminal host handles P (pause), R (retry after a game over) and high scores.
-- Shells, the AI's aiming simulation and the aim preview all step on the same fixed
-- SIM_DT, so what the preview and the AI predict is what the shell actually does.

local PANEL_W = 850
local PANEL_H = 650
local GAME_TOP = 90
local GAME_H = 500
local GAME_BOTTOM = GAME_TOP + GAME_H
local GRAVITY = 320
local MAX_HP = 100
local MAX_OPPONENTS = 5
local SIM_DT = 0.016
local WIND_SCALE = 12
local BLAST_RADIUS = 55
local MAX_DAMAGE = 50
-- Aim limits and held-key rates (a tap moves one step; holding repeats after AIM_REPEAT_DELAY)
local MIN_ANGLE, MAX_ANGLE = 5, 85
local MIN_POWER, MAX_POWER = 80, 420
local ANGLE_STEP, POWER_STEP = 1, 4
local ANGLE_RATE, POWER_RATE = 30, 120
local AIM_REPEAT_DELAY = 0.25
-- Seconds of flight the dotted aim guide shows; wind and the shot markers do the rest
local PREVIEW_TIME = 0.5

local TERRAIN_POINTS = 64
local TERRAIN_X0 = 20
local TERRAIN_STEP = (PANEL_W - 40) / (TERRAIN_POINTS - 1)

local atan2 = math.atan2 or math.atan

local OPPONENTS = {
    { name = "Scout", hp = 80, aim_noise = 28, power_noise = 35 },
    { name = "Gunner", hp = 90, aim_noise = 18, power_noise = 25 },
    { name = "Veteran", hp = 100, aim_noise = 12, power_noise = 18 },
    { name = "Ace", hp = 110, aim_noise = 8, power_noise = 12 },
    { name = "Commander", hp = 120, aim_noise = 5, power_noise = 8 },
}

local function generate_terrain()
    local terrain = {}
    local base_y = GAME_BOTTOM - 80
    for i = 1, TERRAIN_POINTS do
        local x = TERRAIN_X0 + (i - 1) * TERRAIN_STEP
        local y = base_y - 60 - math.sin(i * 0.35) * 50 - math.cos(i * 0.12) * 30 - math.random() * 25
        terrain[i] = { x = x, y = y }
    end
    return terrain
end

--- Ground height at x. Points are evenly spaced and only their y changes, so the segment
--- is found by index instead of a scan (the AI runs hundreds of simulated shots per turn).
local function terrain_height_at(terrain, x)
    local n = #terrain
    if n < 2 then return GAME_BOTTOM end
    local pos = (x - TERRAIN_X0) / TERRAIN_STEP
    if pos < 0 or pos > n - 1 then return GAME_BOTTOM end
    local i = math.min(n - 1, math.floor(pos) + 1)
    local p1, p2 = terrain[i], terrain[i + 1]
    local t = pos - (i - 1)
    return p1.y + (p2.y - p1.y) * t
end

local function terrain_slope_at(terrain, x)
    local eps = 4
    local y1 = terrain_height_at(terrain, x - eps)
    local y2 = terrain_height_at(terrain, x + eps)
    return atan2(y2 - y1, eps * 2)
end

local function place_tank(terrain, x_ratio)
    local x = 20 + (PANEL_W - 40) * x_ratio
    return { x = x, y = terrain_height_at(terrain, x) - 6, hp = MAX_HP }
end

local function settle_tanks(state)
    state.player.y = terrain_height_at(state.terrain, state.player.x) - 6
    state.enemy.y = terrain_height_at(state.terrain, state.enemy.x) - 6
end

local function deform_terrain(terrain, cx, radius, depth)
    for _, p in ipairs(terrain) do
        local dx = p.x - cx
        if math.abs(dx) < radius then
            local factor = 1 - (math.abs(dx) / radius)
            p.y = math.min(GAME_BOTTOM - 4, p.y + depth * factor * factor)
        end
    end
end

--- True when (x, y) is inside a tank's hull box.
local function shell_hits_tank(x, y, tank)
    return math.abs(x - tank.x) <= 18 and y >= tank.y - 14 and y <= tank.y + 7
end

local function new_shell(tank, angle, power, facing)
    local rad = math.rad(angle)
    return {
        x = tank.x,
        y = tank.y - 8,
        vx = math.cos(rad) * power * facing,
        vy = -math.sin(rad) * power,
    }
end

--- Advance a shell one SIM_DT step.
local function step_shell(shell, wind)
    shell.vy = shell.vy + GRAVITY * SIM_DT
    shell.vx = shell.vx + wind * WIND_SCALE * SIM_DT
    shell.x = shell.x + shell.vx * SIM_DT
    shell.y = shell.y + shell.vy * SIM_DT
end

local function shell_out_of_bounds(shell)
    return shell.x < 0 or shell.x > PANEL_W or shell.y > GAME_BOTTOM + 40
end

--- Fly a shell to its end. Returns impact x, y and what it hit: "tank", "ground" or nil (off-screen).
local function simulate_shot(terrain, tank, angle, power, wind, facing, target)
    local shell = new_shell(tank, angle, power, facing)
    for _ = 1, 2000 do
        step_shell(shell, wind)
        if shell_out_of_bounds(shell) then
            return shell.x, shell.y, nil
        end
        if target and shell_hits_tank(shell.x, shell.y, target) then
            return shell.x, shell.y, "tank"
        end
        local ground = terrain_height_at(terrain, shell.x)
        if shell.y >= ground then
            return shell.x, ground, "ground"
        end
    end
    return shell.x, shell.y, nil
end

local function solve_ai_shot(state, tank, target, noise)
    local best_dist = math.huge
    local best_angle, best_power = 45, 250
    local facing = (target.x >= tank.x) and 1 or -1

    for angle = 15, 85, 3 do
        for power = 120, 420, 12 do
            local ix, iy, hit = simulate_shot(state.terrain, tank, angle, power, state.wind, facing, target)
            if hit then
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
    end

    best_angle = best_angle + (math.random() - 0.5) * (noise.aim_noise or 15)
    best_power = best_power + (math.random() - 0.5) * (noise.power_noise or 20)
    return best_angle, best_power, facing
end

local function fire_projectile(state, tank, angle, power, owner, facing)
    local shell = new_shell(tank, angle, power, facing)
    shell.owner = owner
    shell.power = power
    shell.angle = angle
    shell.active = true
    shell.trail = {}
    shell.acc = 0
    -- The shell spawns inside its own tank; it can only hit the shooter after leaving the hull
    shell.armed = false
    state.projectile = shell
end

local function proximity_damage(impact_x, impact_y, tank)
    local dx = impact_x - tank.x
    local dy = impact_y - (tank.y - 8)
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > BLAST_RADIUS then return 0 end
    local factor = 1 - (dist / BLAST_RADIUS)
    return math.floor(MAX_DAMAGE * factor * factor)
end

local function record_shot(state, angle, power, impact_x, impact_y)
    table.insert(state.shot_history, 1, { angle = angle, power = power, ix = impact_x, iy = impact_y })
    while #state.shot_history > 3 do
        table.remove(state.shot_history)
    end
end

local function start_new_round(state)
    state.terrain = generate_terrain()
    state.player = state.player or { hp = MAX_HP }
    local player_hp = state.player.hp
    state.player = place_tank(state.terrain, 0.12)
    state.player.hp = player_hp
    state.enemy = place_tank(state.terrain, 0.88)
    state.enemy.hp = OPPONENTS[state.opponent_index].hp
    state.enemy.max_hp = state.enemy.hp
    state.wind = math.random(-22, 22)
    state.turn = "player"
    state.phase = "aim"
    state.angle = 45
    state.power = 250
    state.enemy_angle = 45
    state.enemy_facing = -1
    state.projectile = nil
    state.shot_history = {}
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
    state.message = "Enemy turn..."
end

--- Settle a finished shot: crater and splash at (hit_x, hit_y), or a clean miss when it
--- left the screen (hit_x nil). Then hand the turn over or end the round.
local function resolve_shot(terminal, state, proj, hit_x, hit_y)
    local shooter = proj.owner == "player" and state.player or state.enemy
    local target = proj.owner == "player" and state.enemy or state.player
    local target_damage, self_damage = 0, 0

    if hit_x then
        local crater_r = 30 + (proj.power or 250) * 0.04
        local crater_d = 14 + (proj.power or 250) * 0.025
        deform_terrain(state.terrain, hit_x, crater_r, crater_d)
        MinigameUI.spawn_particles(state, hit_x, hit_y, { count = 14, colors = { { 1, 0.5, 0.1, 1 } } })
        MinigameUI.trigger_shake(state, 5, 0.2)
        MinigameSfx.play(terminal, state, "impact")
        target_damage = proximity_damage(hit_x, hit_y, target)
        self_damage = proximity_damage(hit_x, hit_y, shooter)
        if target_damage > 0 or self_damage > 0 then MinigameSfx.play(terminal, state, "tank_hit") end
        target.hp = math.max(0, target.hp - target_damage)
        shooter.hp = math.max(0, shooter.hp - self_damage)
        if target_damage > 0 then
            MinigameUI.spawn_floater(state, target.x - 10, target.y - 40, "-" .. target_damage, { 1, 0.4, 0.3, 1 })
        end
        if self_damage > 0 then
            MinigameUI.spawn_floater(state, shooter.x - 10, shooter.y - 40, "-" .. self_damage, { 1, 0.4, 0.3, 1 })
        end
        settle_tanks(state)
    end

    if proj.owner == "player" then
        record_shot(state, proj.angle, proj.power, hit_x or math.max(0, math.min(PANEL_W, proj.x)),
            hit_y or GAME_BOTTOM - 10)
        state.score = state.score + target_damage
    end
    state.projectile = nil

    if state.player.hp <= 0 then
        state.game_over = true
        state.won = false
        state.message = ""
        MinigameSfx.play(terminal, state, "lose")
        return
    end

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
        return
    end

    if proj.owner == "player" then
        start_ai_turn(state)
        if not hit_x then state.message = "Shot went wide — enemy turn..." end
    else
        state.turn = "player"
        state.phase = "aim"
        state.wind = math.max(-28, math.min(28, state.wind + math.random(-8, 8)))
        state.message = hit_x and "Your turn — aim and fire!" or "Enemy shot went wide — your turn!"
    end
end

--- Advance the live shell by whole SIM_DT steps. Returns true when the shot finished.
local function update_projectile(terminal, state, dt)
    local proj = state.projectile
    if not proj or not proj.active then return false end
    local shooter = proj.owner == "player" and state.player or state.enemy
    local target = proj.owner == "player" and state.enemy or state.player

    proj.acc = proj.acc + dt
    while proj.acc >= SIM_DT do
        proj.acc = proj.acc - SIM_DT
        step_shell(proj, state.wind)
        proj.trail[#proj.trail + 1] = { x = proj.x, y = proj.y }
        if #proj.trail > 40 then table.remove(proj.trail, 1) end

        if not proj.armed and not shell_hits_tank(proj.x, proj.y, shooter) then
            proj.armed = true
        end
        if shell_out_of_bounds(proj) then
            resolve_shot(terminal, state, proj, nil, nil)
            return true
        end
        if shell_hits_tank(proj.x, proj.y, target) or (proj.armed and shell_hits_tank(proj.x, proj.y, shooter)) then
            resolve_shot(terminal, state, proj, proj.x, proj.y)
            return true
        end
        local ground_y = terrain_height_at(state.terrain, proj.x)
        if proj.y >= ground_y then
            resolve_shot(terminal, state, proj, proj.x, ground_y)
            return true
        end
    end
    return false
end

local function fire_player_shot(terminal, state)
    fire_projectile(state, state.player, state.angle, state.power, "player", 1)
    state.phase = "flying"
    MinigameSfx.play(terminal, state, "fire")
    state.message = "Shell in flight..."
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

    -- Angle is elevation above horizontal; facing mirrors it left or right
    local rad = math.rad(angle)
    local bl = 22
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(bx, by - 8, bx + math.cos(rad) * bl * facing, by - 8 - math.sin(rad) * bl)
    love.graphics.setLineWidth(1)
end

local function draw_hp_bar(tank, max_hp, color)
    local w = 40
    local x, y = tank.x - w / 2, tank.y - 34
    local frac = math.max(0, math.min(1, tank.hp / max_hp))
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x, y, w, 5)
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.rectangle("fill", x, y, w * frac, 5)
    love.graphics.print(tostring(tank.hp), x + w + 4, y - 6)
end

return {
    metadata = {
        command = "terrainbarrage",
        name = "Terrain Barrage",
        version = "2.1.0",
        author = "Terminal Warfare Community",
        description = "Artillery gauntlet across destructible terrain",
        score_unit = "score",
        requires_unlock = false,
        score_target = 1000,
        gamepad = { stick = "arrows", buttons = { a = "space" } },
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
            enemy = { x = 0, y = 0, hp = MAX_HP, max_hp = MAX_HP },
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
            enemy_angle = 45,
            enemy_facing = -1,
            shot_history = {},
            aim_hold = 0,
        }
    end,

    start = function(terminal, state)
        state.active = true
        state.game_over = false
        state.won = false
        state.score = 0
        state.opponent_index = 1
        state.player = { hp = MAX_HP }
        state.aim_hold = 0
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
            -- Held aim keys repeat after a short delay (the first step comes from keypressed)
            local da = (MinigameUI.is_down("left", "a") and 1 or 0) - (MinigameUI.is_down("right", "d") and 1 or 0)
            local dp = (MinigameUI.is_down("up", "w") and 1 or 0) - (MinigameUI.is_down("down", "s") and 1 or 0)
            if da ~= 0 or dp ~= 0 then
                state.aim_hold = state.aim_hold + dt
                if state.aim_hold > AIM_REPEAT_DELAY then
                    state.angle = math.max(MIN_ANGLE, math.min(MAX_ANGLE, state.angle + da * ANGLE_RATE * dt))
                    state.power = math.max(MIN_POWER, math.min(MAX_POWER, state.power + dp * POWER_RATE * dt))
                end
            else
                state.aim_hold = 0
            end
            return
        end

        update_projectile(terminal, state, dt)
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
            { text = MinigameUI.t(terminal, "minigames.common.hud_score_fmt", { score = state.score }, "SCORE: " .. state.score), align = "right" },
        }, "Left/Right: Angle | Up/Down: Power | Space: Fire | ESC: Quit", fonts, pal, panel)

        local sx, sy = MinigameUI.get_shake_offset(state)
        love.graphics.push()
        love.graphics.translate(panel.x + sx, panel.y + sy)

        love.graphics.setColor(0.05, 0.08, 0.05, 1)
        love.graphics.rectangle("fill", 0, GAME_TOP, PANEL_W, GAME_H)

        local terrain = state.terrain
        if #terrain >= 2 then
            for i = 1, #terrain - 1 do
                local p1, p2 = terrain[i], terrain[i + 1]
                love.graphics.setColor(0.12, 0.22, 0.1, 1)
                love.graphics.polygon("fill", p1.x, p1.y, p2.x, p2.y, p2.x, GAME_BOTTOM, p1.x, GAME_BOTTOM)
                love.graphics.setColor(tg[1], tg[2], tg[3], 1)
                love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            end
        end

        for _, shot in ipairs(state.shot_history) do
            love.graphics.setColor(cyan[1], cyan[2], cyan[3], 0.25)
            love.graphics.circle("line", shot.ix, shot.iy, 6)
        end

        if state.turn == "player" and state.phase == "aim" and not state.game_over then
            local shell = new_shell(state.player, state.angle, state.power, 1)
            love.graphics.setColor(cyan[1], cyan[2], cyan[3], 0.45)
            for i = 1, math.floor(PREVIEW_TIME / SIM_DT) do
                step_shell(shell, state.wind)
                if shell.y >= terrain_height_at(terrain, shell.x) or shell_out_of_bounds(shell) then break end
                if i % 3 == 0 then love.graphics.circle("fill", shell.x, shell.y, 1.5) end
            end
        end

        draw_tank(state.player, cyan, 1, state.angle, terrain)
        draw_tank(state.enemy, red, state.enemy_facing or -1, state.enemy_angle or 45, terrain)
        if fonts.small then love.graphics.setFont(fonts.small) end
        draw_hp_bar(state.player, MAX_HP, cyan)
        draw_hp_bar(state.enemy, state.enemy.max_hp or MAX_HP, red)

        local proj = state.projectile
        if proj and proj.active then
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
        love.graphics.print(string.format("ANGLE: %d  POWER: %d", math.floor(state.angle + 0.5), math.floor(state.power + 0.5)), 20, GAME_TOP + 8)
        love.graphics.print(state.message or "", 20, GAME_BOTTOM - 22)
        local opp_label = string.format("OPP %d/%d  %s", state.opponent_index, MAX_OPPONENTS,
            string.upper(OPPONENTS[state.opponent_index].name))
        love.graphics.setColor(red[1], red[2], red[3], 0.9)
        love.graphics.print(opp_label, PANEL_W - 20 - (fonts.small and fonts.small:getWidth(opp_label) or 140), GAME_TOP + 8)

        local wx, wy = PANEL_W / 2, GAME_TOP + 14
        love.graphics.setColor(cyan[1], cyan[2], cyan[3], 0.8)
        love.graphics.print("WIND " .. math.abs(state.wind), wx - 30, wy - 6)
        if state.wind ~= 0 then
            local dir = state.wind > 0 and 1 or -1
            local tip = wx + dir * (50 + math.min(40, math.abs(state.wind) * 2))
            love.graphics.line(wx + dir * 50, wy + 14, tip, wy + 14)
            love.graphics.polygon("fill", tip, wy + 14, tip - dir * 6, wy + 10, tip - dir * 6, wy + 18)
        end

        love.graphics.pop()
        MinigameUI.draw_particles(state, panel.x, panel.y)
        MinigameUI.draw_floaters(state, fonts, panel.x, panel.y)
        MinigameUI.draw_banner(state.banner_text, fonts, pal, panel, time, state.banner_timer or 0)

        if state.game_over then
            MinigameUI.draw_end_overlay(state.won and "win" or "lose", fonts, pal, panel, vw, vh, {
                time = time,
                title = state.won and "GAUNTLET COMPLETE" or "TANK DESTROYED",
                lines = { MinigameUI.t(terminal, "minigames.common.score_fmt", { score = state.score }, "Score: " .. state.score) },
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

        if key == "left" or key == "a" then state.angle = math.min(MAX_ANGLE, state.angle + ANGLE_STEP) return true end
        if key == "right" or key == "d" then state.angle = math.max(MIN_ANGLE, state.angle - ANGLE_STEP) return true end
        if key == "up" or key == "w" then state.power = math.min(MAX_POWER, state.power + POWER_STEP) return true end
        if key == "down" or key == "s" then state.power = math.max(MIN_POWER, state.power - POWER_STEP) return true end
        if key == "space" or key == "return" then
            fire_player_shot(terminal, state)
            return true
        end
        return false
    end,

    get_score = function(state)
        return state.score or 0
    end,

    help_text = "Terrain Barrage (Arrows/WASD aim, Space fire, ESC)",

    -- Pure helpers for test/test_user_mods.lua
    _test = {
        PANEL_W = PANEL_W,
        terrain_height_at = terrain_height_at,
        simulate_shot = simulate_shot,
        fire_projectile = fire_projectile,
        update_projectile = update_projectile,
        start_new_round = start_new_round,
    },
}
