-- game/scenes/level_scene.lua
-- The main gameplay scene for Balloon Lift. Owns one love.physics world and
-- all the level's game objects (plane, egg, balloons, pump). Starts paused
-- ("setup" phase): the player drags loose balloons around, holds them over
-- the pump to inflate, and attaches them to the plane. Pressing Play starts
-- stepping the physics world; attached balloons apply lift each step, and
-- the scene watches for the win line (plane risen high enough) and the fail
-- line (egg fallen too far), per docs/design/balloon-lift.md's "Level flow".

local Scene   = require("lua/core/scene")
local Sprite  = require("lua/core/sprite")
local Plane   = require("game/plane")
local Egg     = require("game/egg")
local Balloon = require("game/balloon")
local Pump    = require("game/pump")
local Levels  = require("game/levels/init")

local LevelScene = {}
LevelScene.__index = LevelScene

-- How close (world units) a dropped balloon must land to the plane's
-- surface to snap-attach, rather than being left loose where dropped.
local SNAP_DISTANCE = 50

-- Horizontal spacing between loose balloons parked on the shelf.
local SHELF_SPACING = Balloon.MAX_RADIUS * 2 + 10

-- Width of the win/fail line bars (world units) -- generously wide so they
-- span comfortably past any level's plane.
local LINE_BAR_WIDTH = 4000

-- Screen-space HUD button rects.
local PLAY_BUTTON = { x = 1100, y = 16, w = 160, h = 40 }
local NEXT_BUTTON = { x = 1100, y = 70, w = 160, h = 40 }

local function screen_to_world(camera, sx, sy)
    local wx = (sx - camera._w / 2) / camera.zoom + camera.x
    local wy = (sy - camera._h / 2) / camera.zoom + camera.y
    return wx, wy
end

local function point_in_rect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w
       and y >= rect.y and y <= rect.y + rect.h
end

local function point_segment_distance_sq(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local apx, apy = px - ax, py - ay
    local ab_len_sq = abx * abx + aby * aby
    local t = 0
    if ab_len_sq > 0 then
        t = (apx * abx + apy * aby) / ab_len_sq
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local cx, cy = ax + abx * t, ay + aby * t
    local dx, dy = px - cx, py - cy
    return dx * dx + dy * dy
end

function LevelScene.new(level)
    local self = Scene.new(1280, 720)
    setmetatable(self, LevelScene)
    self.level = level
    self:_build()
    return self
end

-- No-op: all scene state is built directly in the constructor via _build,
-- so there's nothing further to do on activation. LevelScene's metatable
-- doesn't chain to Scene (same pattern as other Scene subclasses in this
-- codebase), so Scene's default on_enter() isn't reachable and must be
-- defined here explicitly -- SceneManager:switch calls it unconditionally.
function LevelScene:on_enter() end

-- (Re)builds the entire scene state -- physics world, plane, egg, loose
-- balloons, pump, win/fail line sprites -- fresh from self.level. Used both
-- by the constructor and by the fail-reset flow.
function LevelScene:_build()
    self.drawer:clear()

    self.world = love.physics.newWorld(0, self.level.gravity, true)
    self.plane = Plane.new(self.world, self.level.plane)
    self.egg   = Egg.new(self.world, self.level.egg)
    self.pump  = Pump.new(self.level.pump)

    self.balloons = {}
    for i = 1, self.level.balloon_count do
        local bx = self.level.shelf.x + (i - 1) * SHELF_SPACING
        local by = self.level.shelf.y
        self.balloons[i] = Balloon.new(self.world, bx, by)
    end

    self.drawer:add(self.plane, 5)
    self.drawer:add(self.pump, 1)
    self.drawer:add(self.egg, 6)
    for _, balloon in ipairs(self.balloons) do
        self.drawer:add(balloon, 7)
    end

    local bar_x = -LINE_BAR_WIDTH / 2
    self.win_bar = Sprite.new(bar_x, self.level.win_line_y, LINE_BAR_WIDTH, 4)
    self.win_bar.color = { 0.2, 0.9, 0.3, 1 }
    self.drawer:add(self.win_bar, 2)

    self.fail_bar = Sprite.new(bar_x, self.level.fail_line_y, LINE_BAR_WIDTH, 4)
    self.fail_bar.color = { 0.9, 0.2, 0.2, 1 }
    self.drawer:add(self.fail_bar, 2)

    -- Reset the camera to the scene's default framing (matches Scene.new's
    -- initial Camera.new(0, 0, ...)). Without this, a fail-reset mid-run
    -- leaves the camera wherever it drifted to while following the falling
    -- plane, so the freshly-rebuilt plane/egg (back at their small starting
    -- y) end up off-screen even though the shelf/pump nearby still show.
    self.camera.x = 0
    self.camera.y = 0

    self.running  = false
    self.won      = false
    self.finished = false
    self.dragging = nil
end

-- Finds the balloon (loose or attached) whose center is under (wx, wy),
-- within its own radius. Returns the nearest match, or nil.
function LevelScene:_find_balloon_at(wx, wy)
    local nearest, nearest_dist_sq
    for _, balloon in ipairs(self.balloons) do
        local bx, by = balloon.body:getPosition()
        local dx, dy = wx - bx, wy - by
        local dist_sq = dx * dx + dy * dy
        if dist_sq <= balloon.radius * balloon.radius then
            if not nearest or dist_sq < nearest_dist_sq then
                nearest = balloon
                nearest_dist_sq = dist_sq
            end
        end
    end
    return nearest
end

-- True if (wx, wy) is within SNAP_DISTANCE of any edge of any plane
-- fixture, in world space. Doesn't need to be a pixel-perfect physics
-- raycast -- a reasonable snap zone around the plane's surface is enough.
function LevelScene:_near_plane(wx, wy)
    local snap_sq = SNAP_DISTANCE * SNAP_DISTANCE
    for _, fixture in ipairs(self.plane.fixtures) do
        local shape  = fixture:getShape()
        local points = { shape:getPoints() }
        local n = #points / 2
        local world_points = {}
        for i = 1, n do
            local lx, ly = points[2 * i - 1], points[2 * i]
            local wpx, wpy = self.plane.body:getWorldPoint(lx, ly)
            world_points[i] = { wpx, wpy }
        end
        for i = 1, n do
            local a = world_points[i]
            local b = world_points[(i % n) + 1]
            local dist_sq = point_segment_distance_sq(wx, wy, a[1], a[2], b[1], b[2])
            if dist_sq <= snap_sq then
                return true
            end
        end
    end
    return false
end

function LevelScene:_advance_level()
    local next_level = Levels.next(self.level)
    if next_level then
        self.level = next_level
        self:_build()
    else
        self.finished = true
    end
end

function LevelScene:mousepressed(x, y, button)
    if button ~= 1 then return end

    if self.won then
        if not self.finished and point_in_rect(x, y, NEXT_BUTTON) then
            self:_advance_level()
        end
        return
    end

    if point_in_rect(x, y, PLAY_BUTTON) then
        self.running = not self.running
        return
    end

    if self.running then return end

    local wx, wy = screen_to_world(self.camera, x, y)
    local balloon = self:_find_balloon_at(wx, wy)
    if balloon then
        if balloon.state == "attached" then
            balloon:detach()
        end
        self.dragging = balloon
        balloon:drag_to(wx, wy)
    end
end

function LevelScene:mousemoved(x, y)
    if not self.dragging or self.running then return end
    local wx, wy = screen_to_world(self.camera, x, y)
    self.dragging:drag_to(wx, wy)
end

function LevelScene:mousereleased(x, y, button)
    if button ~= 1 then return end
    if not self.dragging then return end

    local balloon = self.dragging
    self.dragging = nil

    if self.running then return end

    local wx, wy = screen_to_world(self.camera, x, y)
    balloon:drag_to(wx, wy)

    if self:_near_plane(wx, wy) then
        local local_x, local_y = self.plane.body:getLocalPoint(wx, wy)
        balloon:attach(self.plane, local_x, local_y)
    end
end

function LevelScene:update(dt)
    if self._fail_flash_timer and self._fail_flash_timer > 0 then
        self._fail_flash_timer = self._fail_flash_timer - dt
    end

    -- Drag/inflate bookkeeping runs regardless of pause state (though
    -- dragging can only be initiated while paused, per mousepressed).
    if self.dragging and not self.running then
        local bx, by = self.dragging.body:getPosition()
        if self.pump:overlaps(bx, by) then
            self.dragging:inflate(dt)
        end
    end

    if not self.running or self.won then return end

    for _, balloon in ipairs(self.balloons) do
        balloon:apply_lift()
    end
    self.world:update(dt)

    if self.egg:y() > self.level.fail_line_y then
        self:_build()
        self._fail_flash_timer = 1.0
        return
    end

    if self.plane:centroid_y() < self.level.win_line_y then
        self.won     = true
        self.running = false
        return
    end

    local px, py = self.plane.body:getPosition()
    self.camera:follow({ x = px, y = py }, 0.85)
end

function LevelScene:draw()
    Scene.draw(self)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.level.name, 16, 16)

    love.graphics.rectangle("line", PLAY_BUTTON.x, PLAY_BUTTON.y, PLAY_BUTTON.w, PLAY_BUTTON.h)
    love.graphics.print(self.running and "Pause" or "Play", PLAY_BUTTON.x + 10, PLAY_BUTTON.y + 10)

    if self.won and self.finished then
        love.graphics.print("You Win! All levels complete.", 460, 300)
    elseif self.won then
        love.graphics.print("Level Complete!", 500, 300)
        love.graphics.rectangle("line", NEXT_BUTTON.x, NEXT_BUTTON.y, NEXT_BUTTON.w, NEXT_BUTTON.h)
        love.graphics.print("Next Level", NEXT_BUTTON.x + 10, NEXT_BUTTON.y + 10)
    end

    if self._fail_flash_timer and self._fail_flash_timer > 0 then
        love.graphics.print("Egg Broke!", 500, 300)
    end
end

return LevelScene
