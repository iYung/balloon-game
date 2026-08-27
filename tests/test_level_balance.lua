-- tests/test_level_balance.lua
-- Regression coverage for the actual shipped levels (game/levels/level_1..3),
-- not just tuned synthetic levels. Every other level_scene test uses a
-- small synthetic level chosen to reach win/fail fast; none of them ever
-- exercised real level data against real balloon mass/lift, which is
-- exactly where two real bugs slipped through:
--   1. Balloon fixtures used the same density as everything else, so at
--      love.physics's default 30px/meter scale each balloon's own weight
--      vastly exceeded its lift force -- every balloon was a net anchor,
--      not a lifter, regardless of count (game/balloon.lua's DENSITY).
--   2. The pre-tilted plank's original 0.3 rad tilt let balloon-induced
--      rotation compound the tilt fast enough that the egg rolled off
--      before the plane could rise, under every attach strategy tried --
--      the level was unwinnable outright (now 0.1 rad; this is level_3,
--      not level_2 -- levels were reordered afterward, easiest first).
-- These tests attach+inflate all of a level's balloons at a reasonable
-- evenly-spread placement and assert the level is actually winnable within
-- a bounded time, and that a single balloon alone is not -- so a regression
-- toward "impossible" or "any single balloon wins" fails loudly here
-- instead of only surfacing in a screenshot. The "1 balloon" floor (rather
-- than a fixed fraction of balloon_count) is deliberately loose: levels are
-- allowed to have genuinely different difficulty curves by design -- e.g.
-- level_1's bowl is meant to be the most forgiving shape and wins with as
-- few as 2 of its 5 balloons, which is a feature (see its file comment),
-- not a regression -- so this only guards against balloons becoming so
-- overpowered that count/placement stop mattering anywhere at all.

local LevelScene = require("game/scenes/level_scene")
local Balloon    = require("game/balloon")
local Levels     = require("game/levels/init")

-- Evenly spaced attach points, shape-aware: a "rectangle" plane's surface
-- is a flat local y=-10 regardless of x, but an "arc" plane's surface
-- curves (and, for a flipped/dome plane like level_4, can sit far from the
-- body origin -- see level_4.lua) so points must be computed along the
-- actual arc at its outer radius, not blindly copied from the rectangle
-- convention. Points spread across local x in [-100, 100] (rectangle) or
-- across the arc's actual span (arc) -- both manually verified against
-- their respective levels during balance tuning.
local function spread_attach_points(plane_spec, n)
    if plane_spec.shape == "arc" then
        local outer_r = plane_spec.radius + (plane_spec.thickness or 20)
        local span    = plane_spec.span
        local points  = {}
        for i = 1, n do
            local theta = (n == 1) and 0 or (-span / 2 + (i - 1) * (span / (n - 1)))
            points[i] = { x = outer_r * math.sin(theta), y = outer_r * math.cos(theta) }
        end
        return points
    end

    local points = {}
    for i = 1, n do
        local x = (n == 1) and 0 or (-100 + (i - 1) * (200 / (n - 1)))
        points[i] = { x = x, y = -10 }
    end
    return points
end

local function attach_all(scene, n, attach_points)
    for i = 1, n do
        local balloon = scene.balloons[i]
        while balloon.radius < Balloon.MAX_RADIUS do
            balloon:inflate(1 / 60)
        end
        balloon:attach(scene.plane, attach_points[i].x, attach_points[i].y)
    end
end

local function run_until_settled(scene, max_ticks)
    for i = 1, max_ticks do
        scene:update(1 / 60)
        if scene.won then return true, i end
        if not scene.running then return false, i end
    end
    return false, max_ticks
end

local MAX_TICKS = 600 -- 10 simulated seconds

for _, level in ipairs(Levels.list) do
    -- All balloons, well-spread and fully inflated, should win.
    do
        local scene = LevelScene.new(level)
        attach_all(scene, level.balloon_count, spread_attach_points(level.plane, level.balloon_count))
        scene.running = true
        local won, ticks = run_until_settled(scene, MAX_TICKS)
        assert(won, level.name .. ": a full, well-spread, fully-inflated balloon loadout should win, but it "
            .. (scene.won == false and not scene.running and "failed" or "never resolved")
            .. " after " .. (ticks / 60) .. "s")
        print(("PASS: level_balance: %s wins with a full balloon loadout (%.2fs)"):format(level.name, ticks / 60))
    end

    -- A single balloon alone should never be enough to win any level --
    -- guards against the lift-vs-weight balance drifting back to "one
    -- balloon trivially overpowers it," without assuming every level must
    -- share the same difficulty curve (see comment above re: level_1).
    do
        local scene = LevelScene.new(level)
        attach_all(scene, 1, spread_attach_points(level.plane, 1))
        scene.running = true
        local won = run_until_settled(scene, MAX_TICKS)
        assert(not won, level.name ..
            ": a single balloon should not be enough to win -- balance may have drifted back to trivially easy")
        print(("PASS: level_balance: %s does not win with only 1 balloon"):format(level.name))
    end

    -- The paused setup view (camera centered horizontally, offset toward
    -- the bottom third vertically -- see level_scene.lua's
    -- VERTICAL_FRAMING_OFFSET) must still show the plane, egg, pump, and
    -- every shelf balloon. The offset is deliberately capped at exactly the
    -- value that keeps every shipped level's pump in frame; if a level's
    -- pump/shelf distance from its plane ever changes, this is what would
    -- catch the regression instead of it only surfacing in a screenshot.
    do
        local scene = LevelScene.new(level)

        local function in_view(wx, wy)
            local sx = wx - scene.camera.x + 640
            local sy = wy - scene.camera.y + 360
            return sx >= 0 and sx <= 1280 and sy >= 0 and sy <= 720
        end

        assert(in_view(level.egg.x, level.egg.y), level.name .. ": egg should be in view on setup")
        assert(in_view(level.pump.x, level.pump.y), level.name .. ": pump top-left should be in view on setup")
        assert(in_view(level.pump.x + level.pump.w, level.pump.y + level.pump.h),
            level.name .. ": pump bottom-right should be in view on setup")
        for i, balloon in ipairs(scene.balloons) do
            local bx, by = balloon.body:getPosition()
            assert(in_view(bx, by), level.name .. ": shelf balloon " .. i .. " should be in view on setup")
        end

        print(("PASS: level_balance: %s paused setup view frames plane, egg, pump, and shelf balloons"):format(level.name))
    end
end

print("ALL TESTS PASSED")
