-- Chopper Commando — user minigame mod (based on Mark Currie's Chopper Commando / chopper258)

local PANEL_W = 850
local PANEL_H = 650
local GAME_TOP = 80
local GAME_H = 480
local BASE_X = 120
local BASE_PAD_W = 140
local SCREEN_W = PANEL_W
-- World must extend past the farthest mission objective (5A is five screens east).
local WORLD_W = BASE_X + SCREEN_W * 5 + 200
local GRAVITY = 165
local MAX_SPEED = 210
local ACCEL = 380
local FALL_RATE = 95

local STATUS_LABELS = { [4] = "PERFECT", [3] = "POOR", [2] = "INJURED", [1] = "CRITICAL", [0] = "TRASHED" }

local function terrain_height_at(terrain, x)
    for i = 1, #terrain - 1 do
        local p1, p2 = terrain[i], terrain[i + 1]
        if x >= p1.x and x <= p2.x then
            local t = (p2.x == p1.x) and 0 or (x - p1.x) / (p2.x - p1.x)
            return p1.y + (p2.y - p1.y) * t
        end
    end
    return GAME_TOP + GAME_H - 40
end

local function generate_terrain()
    local terrain = {}
    local n = 72
    local flat_y = GAME_TOP + GAME_H - 52
    for i = 1, n do
        local x = (i - 1) * (WORLD_W / (n - 1))
        local y = flat_y
        if x > BASE_PAD_W + 40 and x < WORLD_W - 120 then
            y = flat_y - 40 - math.sin(i * 0.28) * 35 - math.cos(i * 0.11) * 22 - math.sin(i * 0.55) * 12
            y = y - math.max(0, math.sin(i * 0.08) * 18)
        end
        if x < BASE_PAD_W then
            y = flat_y
        end
        table.insert(terrain, { x = x, y = y })
    end
    return terrain
end

local MISSIONS = {
    {
        id = "1A",
        title = "P-77 INTERCEPT",
        brief = {
            "An enemy P-77 guards the border east of Ocale Base.",
            "Fly two screens east and destroy the helicopter.",
            "Return to Ocale Base and land to confirm the kill.",
        },
        score_bonus = 500,
        setup = function(state)
            state.message = "Mission 1A — destroy P-77, return to Ocale Base"
            state.objective_done = false
            state.enemy_heli = {
                alive = true, label = "P-77", hp = 8,
                x = BASE_X + SCREEN_W * 2 + 80,
                y = GAME_TOP + 70, vx = -55, vy = 0,
                shoot_rate = 1.2,
            }
            state.cruise = { alive = false }
            state.buildings = {
                { alive = true, x = BASE_X + SCREEN_W * 1.4, y = terrain_height_at(state.terrain, BASE_X + SCREEN_W * 1.4), hp = 4, kind = "radar", objective = false },
            }
            state.tanks = {
                { alive = true, x = BASE_X + SCREEN_W * 1.1, y = terrain_height_at(state.terrain, BASE_X + SCREEN_W * 1.1) - 6, vx = -20 },
            }
        end,
        check_objective = function(state)
            return not state.enemy_heli.alive
        end,
        win_banner = "P-77 DESTROYED",
    },
    {
        id = "2A",
        title = "CRUISE MISSILE",
        brief = {
            "A cruise missile is inbound toward Ocale Base.",
            "It is approaching from the far east at high speed.",
            "Destroy it before it reaches our base, then return home.",
        },
        score_bonus = 600,
        setup = function(state)
            state.message = "Mission 2A — stop the cruise missile!"
            state.objective_done = false
            state.enemy_heli = { alive = false }
            state.cruise = {
                alive = true,
                x = WORLD_W - 180,
                y = GAME_TOP + 100,
                vx = -140,
                vy = 0,
                hp = 10,
            }
            state.buildings = {}
            state.tanks = {
                { alive = true, x = BASE_X + SCREEN_W * 0.8, y = terrain_height_at(state.terrain, BASE_X + SCREEN_W * 0.8) - 6, vx = -15 },
            }
        end,
        check_objective = function(state)
            return not state.cruise.alive
        end,
        win_banner = "MISSILE STOPPED",
    },
    {
        id = "4A",
        title = "E.I. BUILDING",
        brief = {
            "Terrorist Kuremee-Gabaree-Ushaad hides in the",
            "Enemy Intelligence building four screens east.",
            "Destroy the E.I. Building and return to Ocale Base.",
        },
        score_bonus = 650,
        setup = function(state)
            state.message = "Mission 4A — destroy the E.I. Building"
            state.objective_done = false
            state.enemy_heli = { alive = false }
            state.cruise = { alive = false }
            local bx = BASE_X + SCREEN_W * 4
            state.buildings = {
                { alive = true, x = bx, y = terrain_height_at(state.terrain, bx), hp = 10, kind = "hq", objective = true },
                { alive = true, x = bx - 120, y = terrain_height_at(state.terrain, bx - 120), hp = 4, kind = "barracks", objective = false },
            }
            state.tanks = {
                { alive = true, x = bx - 200, y = terrain_height_at(state.terrain, bx - 200) - 6, vx = -25 },
                { alive = true, x = bx - 80, y = terrain_height_at(state.terrain, bx - 80) - 6, vx = -18 },
            }
        end,
        check_objective = function(state)
            return state.objective_done
        end,
        win_banner = "BUILDING DESTROYED",
    },
    {
        id = "5A",
        title = "ENEMY RADAR",
        brief = {
            "Enemy radar blocks surprise attacks on their territory.",
            "Fly five screens east and destroy the radar installation.",
            "Return safely to Ocale Base when the site is down.",
        },
        score_bonus = 700,
        setup = function(state)
            state.message = "Mission 5A — destroy enemy radar"
            state.objective_done = false
            state.enemy_heli = { alive = false }
            state.cruise = { alive = false }
            local rx = BASE_X + SCREEN_W * 5
            state.buildings = {
                { alive = true, x = rx, y = terrain_height_at(state.terrain, rx), hp = 8, kind = "radar", objective = true },
            }
            state.tanks = {
                { alive = true, x = rx - 160, y = terrain_height_at(state.terrain, rx - 160) - 6, vx = -22 },
                { alive = true, x = rx - 60, y = terrain_height_at(state.terrain, rx - 60) - 6, vx = -20 },
            }
        end,
        check_objective = function(state)
            return state.objective_done
        end,
        win_banner = "RADAR DESTROYED",
    },
}

local crash_chopper

local function world_to_screen(state, wx, wy)
    return wx - state.camera_x, wy
end

local function clamp_velocity(vx, vy, landed)
    local max = landed >= 1 and MAX_SPEED * 0.75 or MAX_SPEED
    local cx = math.max(-max, math.min(max, vx))
    local cy = math.max(-max, math.min(max, vy))
    return cx, cy
end

local function chopper_ground_y(state)
    return terrain_height_at(state.terrain, state.chopper.x) - 6
end

local function spawn_explosion(state, x, y, radius, power)
    table.insert(state.explosions, {
        x = x, y = y,
        radius = 6,
        max_radius = radius,
        power = power or 1,
        life = 0.45 + radius * 0.004,
    })
end

local function damage_status(terminal, state, amount)
    state.status = math.max(0, state.status - amount)
    MinigameUI.trigger_shake(state, 6 + amount * 2, 0.25)
    MinigameSfx.play(terminal, state, "status_hit")
    if state.status <= 0 then
        crash_chopper(terminal, state)
    end
end

crash_chopper = function(terminal, state)
    state.status = 0
    state.game_over = true
    state.won = false
    state.phase = "debrief"
    state.message = "Chopper down — press R to retry"
    spawn_explosion(state, state.chopper.x, state.chopper.y, 45, 3)
    MinigameSfx.play(terminal, state, "crash")
end

local function fire_gun(terminal, state)
    if state.ammo <= 0 or state.landed == 2 then return end
    local c = state.chopper
    local dir = c.vx >= 0 and 1 or -1
    table.insert(state.projectiles, {
        kind = "bullet",
        x = c.x + dir * 18,
        y = c.y - 4,
        vx = c.vx + dir * 340,
        vy = c.vy - 40,
        owner = "player",
    })
    state.ammo = state.ammo - 1
    MinigameSfx.play(terminal, state, "shoot")
end

local function drop_bomb(terminal, state)
    if state.ammo <= 0 or state.bomb_count >= 12 then return end
    local c = state.chopper
    table.insert(state.projectiles, {
        kind = "bomb",
        x = c.x + 6,
        y = c.y + 4,
        vx = c.vx,
        vy = c.vy + 90,
        power = 5,
        owner = "player",
    })
    state.ammo = state.ammo - 1
    state.bomb_count = state.bomb_count + 1
    MinigameSfx.play(terminal, state, "bomb_drop")
end

local function fire_missile(terminal, state)
    if state.missiles <= 0 or state.bomb_count >= 12 then return end
    local c = state.chopper
    table.insert(state.projectiles, {
        kind = "missile",
        x = c.x + 8,
        y = c.y,
        vx = c.vx + (c.vx >= 0 and 120 or -120),
        vy = c.vy,
        power = 8,
        homing = true,
        owner = "player",
    })
    state.missiles = state.missiles - 1
    state.bomb_count = state.bomb_count + 1
    MinigameSfx.play(terminal, state, "missile")
end

local function fire_nuke(terminal, state)
    if state.nukes <= 0 or state.bomb_count >= 12 then return end
    local c = state.chopper
    table.insert(state.projectiles, {
        kind = "nuke",
        x = c.x + 6,
        y = c.y + 4,
        vx = c.vx,
        vy = c.vy + 110,
        power = 15,
        owner = "player",
    })
    state.nukes = state.nukes - 1
    state.bomb_count = state.bomb_count + 1
    MinigameSfx.play(terminal, state, "nuke")
end

local function draw_helicopter(cx, cy, facing, time, landed)
    local dir = facing >= 0 and 1 or -1
    local body = { 0.52, 0.55, 0.32 }
    local dark = { 0.34, 0.36, 0.22 }
    local rotor_y = cy - 12

    love.graphics.setColor(0.2, 0.2, 0.22, 1)
    love.graphics.line(cx - 9 * dir, cy + 4, cx - 9 * dir, cy + 7)
    love.graphics.line(cx + 9 * dir, cy + 4, cx + 9 * dir, cy + 7)
    love.graphics.line(cx - 11 * dir, cy + 7, cx + 11 * dir, cy + 7)

    love.graphics.setColor(dark[1], dark[2], dark[3], 1)
    local tail_x = dir > 0 and (cx - 20) or (cx + 4)
    love.graphics.rectangle("fill", tail_x, cy - 1, 16, 3)

    love.graphics.setColor(body[1], body[2], body[3], 1)
    if dir > 0 then
        love.graphics.polygon("fill",
            cx + 14, cy - 1,
            cx + 4, cy - 7,
            cx - 6, cy - 4,
            cx - 8, cy + 2,
            cx + 2, cy + 5,
            cx + 12, cy + 3)
    else
        love.graphics.polygon("fill",
            cx - 14, cy - 1,
            cx - 4, cy - 7,
            cx + 6, cy - 4,
            cx + 8, cy + 2,
            cx - 2, cy + 5,
            cx - 12, cy + 3)
    end

    love.graphics.setColor(0.45, 0.62, 0.78, 0.85)
    if dir > 0 then
        love.graphics.polygon("fill", cx + 6, cy - 5, cx + 2, cy - 3, cx + 4, cy - 1)
    else
        love.graphics.polygon("fill", cx - 6, cy - 5, cx - 2, cy - 3, cx - 4, cy - 1)
    end

    love.graphics.setColor(0.75, 0.75, 0.78, 0.9)
    love.graphics.line(cx, rotor_y + 4, cx, cy - 4)
    local blur = math.sin(time * 24) * 2
    love.graphics.line(cx - 16 * dir + blur, rotor_y, cx + 16 * dir + blur, rotor_y)
    love.graphics.line(cx - 14 * dir - blur, rotor_y - 1, cx + 14 * dir - blur, rotor_y - 1)

    if dir > 0 then
        love.graphics.line(cx - 20, cy - 1, cx - 20, cy - 5)
    else
        love.graphics.line(cx + 20, cy - 1, cx + 20, cy - 5)
    end

    if landed == 0 then
        love.graphics.setColor(0.9, 0.75, 0.2, 0.7)
        love.graphics.print("G", cx - 4, cy + 9)
    end
end

local function draw_enemy_helicopter(ex, ey, time)
    local body = { 0.62, 0.22, 0.2 }
    love.graphics.setColor(body[1], body[2], body[3], 1)
    love.graphics.polygon("fill", ex + 12, ey, ex - 10, ey + 5, ex - 6, ey - 3, ex + 8, ey - 5)
    love.graphics.setColor(0.75, 0.75, 0.78, 0.85)
    love.graphics.line(ex - 14, ey - 10, ex + 14, ey - 10)
    love.graphics.line(ex, ey - 10, ex, ey - 4)
end

local function draw_terrain_fill(terrain, cam)
    local bottom = GAME_TOP + GAME_H
    for i = 1, #terrain - 1 do
        local p1, p2 = terrain[i], terrain[i + 1]
        local x1, x2 = p1.x - cam, p2.x - cam
        if x2 >= -4 and x1 <= PANEL_W + 4 then
            love.graphics.setColor(0.34, 0.3, 0.18, 1)
            love.graphics.polygon("fill", x1, p1.y, x2, p2.y, x2, bottom, x1, bottom)
            love.graphics.setColor(0.48, 0.42, 0.26, 1)
            love.graphics.line(x1, p1.y, x2, p2.y)
        end
    end
end

local function current_mission(state)
    return MISSIONS[state.campaign_index]
end

local function mission_objective_met(state)
    local m = current_mission(state)
    return m and m.check_objective(state)
end

local function on_base_pad(state)
    return state.chopper.x <= BASE_PAD_W
end

local function complete_mission(terminal, state)
    local m = current_mission(state)
    state.game_over = true
    state.won = true
    state.phase = "debrief"
    state.score = state.score + (m and m.score_bonus or 400)
    MinigameSfx.play(terminal, state, "mission_complete")
    if state.campaign_index >= #MISSIONS then
        state.campaign_complete = true
        state.message = "All missions complete — press SPACE to exit"
    else
        state.message = "Mission " .. m.id .. " complete — press SPACE for next briefing"
    end
end

local function rearm_at_base(terminal, state)
    if not on_base_pad(state) or state.landed ~= 2 then return end
    state.chopper.y = chopper_ground_y(state)
    state.chopper.vx = 0
    state.chopper.vy = 0
    local needs_rearm = state.ammo < 150 or state.missiles < 5 or state.nukes < 5
    state.ammo = 150
    state.missiles = 5
    state.nukes = 5
    if needs_rearm then
        MinigameSfx.play(terminal, state, "rearm")
    end
    if mission_objective_met(state) and state.mission_step >= 1 then
        complete_mission(terminal, state)
    end
end

local function try_confirm_landing_at_base(terminal, state)
    if state.phase ~= "playing" or state.game_over then return end

    local c = state.chopper
    if state.landed == 2 then
        if on_base_pad(state) then
            local ground = chopper_ground_y(state)
            if c.y >= ground - 12 then
                c.y = ground
            end
        end
        return
    end

    if not mission_objective_met(state) or state.mission_step < 1 or not on_base_pad(state) then
        return
    end

    local ground = chopper_ground_y(state)
    if c.y < ground - 6 then return end

    local vel = math.abs(c.vx) + math.abs(c.vy)
    if state.landed < 1 then
        if vel < 40 then
            state.message = "Lower landing gear (G) to confirm at Ocale Base"
        end
        return
    end
    if vel > 70 then
        if vel < 120 then
            state.message = "Slow down to land at Ocale Base"
        end
        return
    end

    c.y = ground
    c.vx = 0
    c.vy = 0
    state.landed = 2
    MinigameSfx.play(terminal, state, "land")
    rearm_at_base(terminal, state)
end

local function hit_enemy_heli(terminal, state, power)
    local eh = state.enemy_heli
    if not eh or not eh.alive then return end
    eh.hp = eh.hp - power
    if eh.hp <= 0 then
        eh.alive = false
        state.score = state.score + 200
        state.mission_step = math.max(state.mission_step, 2)
        local m = current_mission(state)
        state.message = (eh.label or "Target") .. " destroyed — return to Ocale Base!"
        spawn_explosion(state, eh.x, eh.y, 40, 2)
        MinigameSfx.play(terminal, state, "enemy_destroyed")
        MinigameUI.show_banner(state, m and m.win_banner or "TARGET DOWN", 1.5)
    end
end

local function hit_cruise(terminal, state, power)
    local cr = state.cruise
    if not cr or not cr.alive then return end
    cr.hp = cr.hp - power
    if cr.hp <= 0 then
        cr.alive = false
        state.score = state.score + 250
        state.mission_step = math.max(state.mission_step, 2)
        state.message = "Cruise missile destroyed — return to Ocale Base!"
        spawn_explosion(state, cr.x, cr.y, 50, 3)
        MinigameSfx.play(terminal, state, "enemy_destroyed")
        MinigameUI.show_banner(state, "MISSILE STOPPED", 1.5)
    end
end

local function hit_building(terminal, state, b, power)
    if not b.alive then return end
    b.hp = b.hp - power
    if b.hp <= 0 then
        b.alive = false
        state.score = state.score + (b.objective and 150 or 40)
        spawn_explosion(state, b.x, b.y - 15, 35, 2)
        MinigameSfx.play(terminal, state, "enemy_destroyed")
        if b.objective then
            state.objective_done = true
            state.mission_step = math.max(state.mission_step, 2)
            local m = current_mission(state)
            state.message = "Objective destroyed — return to Ocale Base!"
            MinigameUI.show_banner(state, m and m.win_banner or "OBJECTIVE DOWN", 1.5)
        end
    end
end

local function reset_chopper_for_mission(state)
    state.chopper = { x = BASE_X, y = chopper_ground_y(state) - 60, vx = 0, vy = 0 }
    state.camera_x = 0
    state.status = 4
    state.ammo = 150
    state.missiles = 5
    state.nukes = 5
    state.landed = 1
    state.bomb_count = 0
    state.projectiles = {}
    state.explosions = {}
    state.enemy_shoot_timer = 2
    state.mission_step = 0
end

local function begin_mission(state, index)
    state.campaign_index = index
    state.phase = "playing"
    state.game_over = false
    state.won = false
    state.campaign_complete = false
    reset_chopper_for_mission(state)
    MISSIONS[index].setup(state)
end

local function show_briefing(state, index)
    state.campaign_index = index
    state.phase = "briefing"
    state.game_over = false
    state.won = false
end

local function resolve_projectile_hit(terminal, state, p, x, y)
    if p.owner == "player" then
        local eh = state.enemy_heli
        if eh and eh.alive then
            local dx, dy = x - eh.x, y - eh.y
            if dx * dx + dy * dy < 24 * 24 then
                hit_enemy_heli(terminal, state, p.power or 1)
                return true
            end
        end
        local cr = state.cruise
        if cr and cr.alive then
            local dx, dy = x - cr.x, y - cr.y
            if dx * dx + dy * dy < 28 * 28 then
                hit_cruise(terminal, state, p.power or 1)
                return true
            end
        end
        for _, b in ipairs(state.buildings) do
            if b.alive then
                local dx, dy = x - b.x, y - (b.y - 20)
                if dx * dx + dy * dy < 30 * 30 then
                    hit_building(terminal, state, b, p.power or 1)
                    return true
                end
            end
        end
        if p.kind ~= "bullet" then
            spawn_explosion(state, x, y, 12 + (p.power or 5) * 2, p.power or 5)
            MinigameSfx.play(terminal, state, "explosion", { overlap = true })
            local c = state.chopper
            local dx, dy = x - c.x, y - c.y
            if dx * dx + dy * dy < (20 + p.power * 2) ^ 2 then
                damage_status(terminal, state, p.power >= 10 and 2 or 1)
            end
            return true
        end
    elseif p.owner == "enemy" then
        local c = state.chopper
        local dx, dy = x - c.x, y - c.y
        if dx * dx + dy * dy < 18 * 18 then
            damage_status(terminal, state, 1)
            return true
        end
    end
    return false
end

local function draw_cruise_missile(cx, cy)
    love.graphics.setColor(0.55, 0.55, 0.58, 1)
    love.graphics.rectangle("fill", cx - 18, cy - 4, 36, 8, 2, 2)
    love.graphics.setColor(0.9, 0.25, 0.15, 1)
    love.graphics.polygon("fill", cx + 18, cy, cx + 26, cy - 5, cx + 26, cy + 5)
    love.graphics.setColor(0.75, 0.75, 0.78, 0.8)
    love.graphics.line(cx - 10, cy - 8, cx + 10, cy - 8)
end

local function draw_building(b, bx, cyan)
    if b.kind == "hq" then
        love.graphics.setColor(0.42, 0.32, 0.24, 1)
        love.graphics.rectangle("fill", bx - 18, b.y - 48, 36, 48)
        love.graphics.setColor(0.55, 0.65, 0.75, 0.7)
        for row = 0, 3 do
            for col = 0, 1 do
                love.graphics.rectangle("fill", bx - 12 + col * 14, b.y - 42 + row * 10, 8, 6)
            end
        end
    elseif b.kind == "radar" then
        love.graphics.setColor(0.4, 0.38, 0.35, 1)
        love.graphics.rectangle("fill", bx - 10, b.y - 28, 20, 28)
        love.graphics.setColor(cyan[1], cyan[2], cyan[3], 0.85)
        love.graphics.arc("line", "open", bx, b.y - 34, 14, math.pi, math.pi * 2)
        love.graphics.line(bx, b.y - 34, bx + 10, b.y - 26)
    else
        love.graphics.setColor(0.45, 0.35, 0.25, 1)
        love.graphics.rectangle("fill", bx - 14, b.y - 30, 28, 30)
    end
end

return {
    metadata = {
        command = "choppercmd",
        name = "Chopper Commando",
        version = "1.2.0",
        author = "Terminal Warfare Community",
        description = "Chopper Commando campaign — missions 1A, 2A, 4A, and 5A from Ocale Base",
        score_unit = "score",
        requires_unlock = false,
        sfx_events = {
            { id = "shoot", description = "Machine gun fired" },
            { id = "bomb_drop", description = "Bomb released" },
            { id = "missile", description = "Missile launched" },
            { id = "nuke", description = "Nuke released" },
            { id = "explosion", description = "Explosion" },
            { id = "enemy_destroyed", description = "Target destroyed" },
            { id = "land", description = "Landed on pad" },
            { id = "rearm", description = "Rearmed at Ocale Base" },
            { id = "status_hit", description = "Chopper damaged" },
            { id = "crash", description = "Chopper crashed" },
            { id = "mission_complete", description = "Mission complete" },
        },
    },

    init_state = function(terminal)
        return {
            active = false,
            game_over = false,
            won = false,
            score = 0,
            terrain = {},
            chopper = { x = BASE_X, y = 0, vx = 0, vy = 0 },
            camera_x = 0,
            status = 4,
            ammo = 150,
            missiles = 5,
            nukes = 5,
            landed = 1,
            bomb_count = 0,
            campaign_index = 1,
            mission_step = 0,
            phase = "briefing",
            objective_done = false,
            campaign_complete = false,
            message = "",
            enemy_heli = { alive = false },
            cruise = { alive = false },
            buildings = {},
            tanks = {},
            projectiles = {},
            explosions = {},
            panel = nil,
            enemy_shoot_timer = 2,
        }
    end,

    start = function(terminal, state)
        state.active = true
        state.game_over = false
        state.won = false
        state.score = 0
        state.terrain = generate_terrain()
        state.chopper = { x = BASE_X, y = 0, vx = 0, vy = 0 }
        state.chopper.y = chopper_ground_y(state) - 60
        state.camera_x = 0
        show_briefing(state, 1)
        MinigameUI.init_common_state(state)
        MinigameSfx.attach(terminal, state, state.metadata.command, state.metadata.sfx_events)
        terminal:add_output("Chopper Commando — 4-mission campaign. Press SPACE at briefing to launch.")
    end,

    update = function(terminal, state, dt)
        if not state then return end
        MinigameUI.tick_frame(state, dt)
        if not state.active or state.phase == "briefing" then return end
        if state.phase == "debrief" or state.game_over then return end

        local c = state.chopper
        local up = love.keyboard.isDown("up") or love.keyboard.isDown("w")
        local down = love.keyboard.isDown("down") or love.keyboard.isDown("s")
        local left = love.keyboard.isDown("left") or love.keyboard.isDown("a")
        local right = love.keyboard.isDown("right") or love.keyboard.isDown("d")

        if state.landed < 2 then
            if up then c.vy = c.vy - ACCEL * dt end
            if down then c.vy = c.vy + ACCEL * dt end
            if left then c.vx = c.vx - ACCEL * dt end
            if right then c.vx = c.vx + ACCEL * dt end
            if state.landed == 0 then
                c.vy = c.vy + GRAVITY * dt
            else
                c.vy = c.vy + FALL_RATE * dt * 0.35
            end
        else
            c.vx = c.vx * (1 - dt * 4)
            c.vy = 0
        end

        c.vx, c.vy = clamp_velocity(c.vx, c.vy, state.landed)
        c.x = c.x + c.vx * dt
        c.y = c.y + c.vy * dt

        if c.y < GAME_TOP + 20 then
            c.y = GAME_TOP + 20
            c.vy = 0
        end

        local ground = chopper_ground_y(state)
        if c.y >= ground then
            local on_pad = on_base_pad(state)
            local vel = math.abs(c.vx) + math.abs(c.vy)
            local soft_limit = on_pad and 130 or 80
            if state.landed >= 1 and vel < soft_limit then
                c.y = ground
                if state.landed == 1 then
                    state.landed = 2
                    c.vx = 0
                    c.vy = 0
                    MinigameSfx.play(terminal, state, "land")
                    rearm_at_base(terminal, state)
                elseif state.landed == 2 and on_pad then
                    rearm_at_base(terminal, state)
                end
            else
                c.y = ground
                damage_status(terminal, state, math.ceil(math.abs(c.vy) / 60))
                c.vy = -c.vy * 0.3
                if c.vy > -20 then c.vy = -60 end
            end
        end

        if c.x < 20 then c.x = 20; c.vx = math.max(0, c.vx) end
        if c.x > WORLD_W - 40 then c.x = WORLD_W - 40; c.vx = math.min(0, c.vx) end

        state.camera_x = math.max(0, math.min(WORLD_W - PANEL_W, c.x - PANEL_W * 0.28))

        if c.x > BASE_PAD_W + 200 and state.mission_step == 0 then
            state.mission_step = 1
        end

        local eh = state.enemy_heli
        if eh and eh.alive then
            if eh.y < c.y - 30 then eh.vy = eh.vy + 40 * dt else eh.vy = eh.vy - 40 * dt end
            if eh.x > c.x then eh.vx = eh.vx - 30 * dt else eh.vx = eh.vx + 30 * dt end
            eh.vx = math.max(-90, math.min(-35, eh.vx))
            eh.vy = math.max(-60, math.min(60, eh.vy))
            eh.x = eh.x + eh.vx * dt
            eh.y = eh.y + eh.vy * dt
            eh.y = math.max(GAME_TOP + 40, math.min(ground - 30, eh.y))

            state.enemy_shoot_timer = state.enemy_shoot_timer - dt
            if state.enemy_shoot_timer <= 0 then
                local dx, dy = c.x - eh.x, c.y - eh.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < 500 then
                    table.insert(state.projectiles, {
                        kind = "bullet", x = eh.x, y = eh.y,
                        vx = dx / dist * 220, vy = dy / dist * 220,
                        owner = "enemy",
                    })
                end
                state.enemy_shoot_timer = (eh.shoot_rate or 1.2) + math.random() * 0.8
            end
        end

        local cr = state.cruise
        if cr and cr.alive then
            cr.x = cr.x + cr.vx * dt
            cr.y = cr.y + cr.vy * dt
            cr.y = math.max(GAME_TOP + 50, math.min(GAME_TOP + 160, cr.y))
            if cr.x < BASE_X + 160 then
                state.game_over = true
                state.won = false
                state.phase = "debrief"
                state.message = "Cruise missile hit Ocale Base — mission failed"
                spawn_explosion(state, BASE_X, chopper_ground_y(state), 60, 4)
                MinigameSfx.play(terminal, state, "crash")
            end
        end

        for _, tank in ipairs(state.tanks) do
            if tank.alive then
                tank.x = tank.x + tank.vx * dt
                tank.y = terrain_height_at(state.terrain, tank.x) - 6
            end
        end

        for i = #state.projectiles, 1, -1 do
            local p = state.projectiles[i]
            if p.kind == "missile" and p.homing then
                local tx, ty
                if eh and eh.alive then
                    tx, ty = eh.x, eh.y
                elseif cr and cr.alive then
                    tx, ty = cr.x, cr.y
                end
                if tx then
                    local dx, dy = tx - p.x, ty - p.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 4 then
                        p.vx = p.vx + dx / dist * 280 * dt
                        p.vy = p.vy + dy / dist * 280 * dt
                    end
                end
            end
            if p.kind == "bomb" or p.kind == "nuke" then
                p.vy = p.vy + GRAVITY * dt
            end
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt

            local hit_ground = p.y >= terrain_height_at(state.terrain, p.x)
            local oob = p.x < 0 or p.x > WORLD_W or p.y < GAME_TOP or p.y > GAME_TOP + GAME_H + 40
            if p.kind == "bullet" then
                if resolve_projectile_hit(terminal, state, p, p.x, p.y) or oob or hit_ground then
                    table.remove(state.projectiles, i)
                end
            elseif hit_ground or oob then
                local hx = math.max(20, math.min(WORLD_W - 20, p.x))
                local hy = hit_ground and terrain_height_at(state.terrain, hx) or p.y
                resolve_projectile_hit(terminal, state, p, hx, hy)
                state.bomb_count = math.max(0, state.bomb_count - 1)
                table.remove(state.projectiles, i)
            end
        end

        for i = #state.explosions, 1, -1 do
            local ex = state.explosions[i]
            ex.life = ex.life - dt
            ex.radius = math.min(ex.max_radius, ex.radius + 200 * dt)
            if ex.life <= 0 then table.remove(state.explosions, i) end
        end

        try_confirm_landing_at_base(terminal, state)

        if state.landed == 2 and on_base_pad(state) then
            rearm_at_base(terminal, state)
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
        local cam = state.camera_x

        local m = current_mission(state)
        local hud_title = "CHOPPER COMMANDO"
        local hud_footer = "Arrows: Fly | Space: Fire | B/M/N: Weapons | G: Gear | ESC"
        if state.phase == "briefing" and m then
            hud_footer = "SPACE: Launch mission | 1-4: Jump to mission | ESC: Quit"
        elseif state.phase == "debrief" then
            hud_footer = state.campaign_complete and "SPACE: Exit | ESC: Quit" or "SPACE: Next briefing | R: Retry | ESC: Quit"
        elseif m then
            hud_title = "MISSION " .. m.id
        end

        MinigameUI.draw_hud(hud_title, {
            { text = "SCORE: " .. state.score, align = "right" },
            { text = state.phase == "playing" and ("AMMO: " .. state.ammo) or ("OPS: " .. state.campaign_index .. "/" .. #MISSIONS), align = "right", color = cyan },
            { text = state.phase == "playing" and (STATUS_LABELS[state.status] or "???") or (m and m.title or ""), align = "right", color = tg },
        }, hud_footer, fonts, pal, panel)

        local sx, sy = MinigameUI.get_shake_offset(state)
        love.graphics.push()
        love.graphics.translate(panel.x + sx, panel.y + sy)

        if state.phase == "briefing" and m then
            love.graphics.setColor(0.04, 0.08, 0.12, 1)
            love.graphics.rectangle("fill", 40, 120, PANEL_W - 80, 360)
            love.graphics.setColor(cyan[1], cyan[2], cyan[3], 0.9)
            if fonts.large then love.graphics.setFont(fonts.large) end
            love.graphics.print("MISSION " .. m.id .. " — " .. m.title, 60, 140)
            if fonts.small then love.graphics.setFont(fonts.small) end
            love.graphics.setColor(0.85, 0.9, 0.95, 0.92)
            for i, line in ipairs(m.brief) do
                love.graphics.print(line, 60, 190 + (i - 1) * 24)
            end
            love.graphics.setColor(tg[1], tg[2], tg[3], 0.75)
            love.graphics.print("Press SPACE to launch from Ocale Base", 60, 420)
            love.graphics.pop()
            MinigameUI.draw_particles(state, panel.x, panel.y)
            return
        end

        for row = 0, GAME_H, 6 do
            local t = row / GAME_H
            love.graphics.setColor(0.18 + t * 0.08, 0.38 + t * 0.12, 0.62 + t * 0.06, 1)
            love.graphics.rectangle("fill", 0, GAME_TOP + row, PANEL_W, 6)
        end

        love.graphics.setScissor(panel.x, panel.y + GAME_TOP, PANEL_W, GAME_H)

        local terrain = state.terrain
        if #terrain >= 2 then
            draw_terrain_fill(terrain, cam)
        end

        local function draw_base()
            local bx = BASE_X - cam
            if bx > PANEL_W + 60 or bx < -80 then return end
            local by = terrain_height_at(terrain, BASE_X)
            love.graphics.setColor(0.55, 0.55, 0.58, 1)
            love.graphics.rectangle("fill", bx - 8, by - 36, 44, 30)
            love.graphics.polygon("fill", bx + 4, by - 40, bx + 24, by - 34, bx + 16, by - 28, bx, by - 30)
            love.graphics.setColor(0.75, 0.78, 0.55, 0.9)
            love.graphics.rectangle("fill", bx, by - 3, 52, 4)
            love.graphics.setColor(0.9, 0.9, 0.5, 0.8)
            love.graphics.print("H", bx + 20, by - 2)
            if fonts.small then love.graphics.setFont(fonts.small) end
            love.graphics.setColor(0.85, 0.9, 0.95, 0.9)
            love.graphics.print("OCALE BASE", bx - 4, by - 52)
        end
        draw_base()

        for _, b in ipairs(state.buildings) do
            if b.alive then
                local bx = b.x - cam
                if bx > -50 and bx < PANEL_W + 50 then
                    draw_building(b, bx, cyan)
                end
            end
        end

        local cr = state.cruise
        if cr and cr.alive then
            local cx = cr.x - cam
            if cx > -60 and cx < PANEL_W + 60 then
                draw_cruise_missile(cx, cr.y)
                love.graphics.setColor(1, 0.5, 0.3, 0.95)
                if fonts.small then love.graphics.setFont(fonts.small) end
                love.graphics.print("CRUISE", cx - 18, cr.y - 22)
            end
        end

        for _, tank in ipairs(state.tanks) do
            if tank.alive then
                local tx = tank.x - cam
                if tx > -30 and tx < PANEL_W + 30 then
                    love.graphics.setColor(red[1], red[2], red[3], 1)
                    love.graphics.rectangle("fill", tx - 12, tank.y - 8, 24, 10)
                end
            end
        end

        local eh = state.enemy_heli
        if eh and eh.alive then
            local ex = eh.x - cam
            if ex > -40 and ex < PANEL_W + 40 then
                draw_enemy_helicopter(ex, eh.y, time)
                love.graphics.setColor(1, 0.85, 0.3, 0.95)
                if fonts.small then love.graphics.setFont(fonts.small) end
                love.graphics.print(eh.label or "HOSTILE", ex - 14, eh.y - 24)
            end
        end

        for _, p in ipairs(state.projectiles) do
            local px = p.x - cam
            if p.kind == "bullet" then
                love.graphics.setColor(p.owner == "player" and yellow[1] or red[1], p.owner == "player" and yellow[2] or red[2], p.owner == "player" and yellow[3] or red[3], 1)
                love.graphics.circle("fill", px, p.y, 2)
            elseif p.kind == "missile" then
                love.graphics.setColor(1, 0.6, 0.2, 1)
                love.graphics.rectangle("fill", px - 4, p.y - 2, 8, 4)
            else
                love.graphics.setColor(0.2, 0.2, 0.2, 1)
                love.graphics.circle("fill", px, p.y, p.kind == "nuke" and 5 or 4)
            end
        end

        for _, ex in ipairs(state.explosions) do
            local alpha = math.min(1, ex.life * 2.5)
            love.graphics.setColor(1, 0.5, 0.1, alpha * 0.7)
            love.graphics.circle("fill", ex.x - cam, ex.y, ex.radius)
        end

        local c = state.chopper
        local cx = c.x - cam
        local facing = c.vx >= 0 and 1 or -1
        draw_helicopter(cx, c.y, facing, time, state.landed)
        if state.landed == 2 then
            love.graphics.setColor(0.9, 0.95, 0.7, 0.9)
            if fonts.small then love.graphics.setFont(fonts.small) end
            love.graphics.print("LANDED", cx - 18, c.y + 10)
        end

        if fonts.small then love.graphics.setFont(fonts.small) end
        love.graphics.setColor(0.92, 0.94, 0.98, 0.95)
        love.graphics.print("M:" .. state.missiles .. "  N:" .. state.nukes, 16, GAME_TOP + 8)
        love.graphics.setColor(0.85, 0.9, 0.75, 0.95)
        love.graphics.print(state.message or "", 16, GAME_TOP + GAME_H - 22)

        love.graphics.setScissor()
        love.graphics.pop()
        MinigameUI.draw_particles(state, panel.x, panel.y)
        MinigameUI.draw_banner(state.banner_text, fonts, pal, panel, time, state.banner_timer or 0)

        if state.phase == "debrief" or (state.game_over and state.phase ~= "playing") then
            local title = state.won and (state.campaign_complete and "CAMPAIGN WON" or "MISSION COMPLETE") or "MISSION FAILED"
            local lines = { "Score: " .. state.score }
            if not state.won then
                table.insert(lines, "Press R to retry")
            elseif not state.campaign_complete then
                table.insert(lines, "Press SPACE for next mission")
            end
            MinigameUI.draw_end_overlay(state.won and "win" or "lose", fonts, pal, panel, vw, vh, {
                time = time,
                title = title,
                lines = lines,
                terminal = terminal,
            })
        end
    end,

    keypressed = function(terminal, state, key)
        if not state.active then return false end
        if key == "escape" then
            state.active = false
            terminal:add_output("Chopper Commando ended. Score: " .. state.score)
            return true
        end

        if state.phase == "briefing" then
            if key == "space" then
                begin_mission(state, state.campaign_index)
                MinigameUI.show_banner(state, "LAUNCHING", 1.0)
                return true
            end
            local jump = tonumber(key)
            if jump and jump >= 1 and jump <= #MISSIONS then
                show_briefing(state, jump)
                return true
            end
            return false
        end

        if state.phase == "debrief" then
            if state.won and key == "space" then
                if state.campaign_complete then
                    state.active = false
                    terminal:add_output("Chopper Commando campaign complete! Score: " .. state.score)
                else
                    show_briefing(state, state.campaign_index + 1)
                end
                return true
            end
            if key == "r" or (key == "space" and not state.won) then
                begin_mission(state, state.campaign_index)
                return true
            end
            return false
        end

        if state.game_over then return false end

        if key == "space" then fire_gun(terminal, state); return true end
        if key == "b" then drop_bomb(terminal, state); return true end
        if key == "m" then fire_missile(terminal, state); return true end
        if key == "n" then fire_nuke(terminal, state); return true end
        if key == "g" then
            if state.landed == 2 then
                state.landed = 1
                state.message = "Gear down — take off with Up"
            else
                state.landed = (state.landed == 0) and 1 or 0
            end
            return true
        end
        if key == "up" and state.landed == 2 then
            state.landed = 1
            state.chopper.vy = -120
            return true
        end
        return false
    end,

    get_score = function(state)
        return state.score or 0
    end,

    help_text = "Chopper Commando (Campaign 1A-5A, Arrows fly, Space/B/M/N, G gear, ESC quit)",
}
