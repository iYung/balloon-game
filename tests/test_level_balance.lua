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
--   2. Level 2's original 0.3 rad pre-tilt let balloon-induced rotation
--      compound the tilt fast enough that the egg rolled off before the
--      plane could rise, under every attach strategy tried -- the level
--      was unwinnable outright (now 0.1 rad).
-- These tests attach+inflate all of a level's balloons at a reasonable
-- evenly-spread placement and assert the level is actually winnable within
-- a bounded time, and that a meaningfully smaller loadout is not -- so a
-- regression toward "impossible" or "trivially easy" fails loudly here
-- instead of only surfacing in a screenshot.

local LevelScene = require("game/scenes/level_scene")
local Balloon    = require("game/balloon")
local Levels     = require("game/levels/init")

-- Evenly spaced attach points across local x in [-100, 100], matching the
-- placements manually verified against all 3 levels during balance tuning.
local function spread_attach_points(n)
    local points = {}
    for i = 1, n do
        points[i] = (n == 1) and 0 or (-100 + (i - 1) * (200 / (n - 1)))
    end
    return points
end

local function attach_all(scene, n, attach_points)
    for i = 1, n do
        local balloon = scene.balloons[i]
        while balloon.radius < Balloon.MAX_RADIUS do
            balloon:inflate(1 / 60)
        end
        balloon:attach(scene.plane, attach_points[i], -10)
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
        attach_all(scene, level.balloon_count, spread_attach_points(level.balloon_count))
        scene.running = true
        local won, ticks = run_until_settled(scene, MAX_TICKS)
        assert(won, level.name .. ": a full, well-spread, fully-inflated balloon loadout should win, but it "
            .. (scene.won == false and not scene.running and "failed" or "never resolved")
            .. " after " .. (ticks / 60) .. "s")
        print(("PASS: level_balance: %s wins with a full balloon loadout (%.2fs)"):format(level.name, ticks / 60))
    end

    -- A meaningfully smaller loadout (2 fewer balloons, or 1 if the level
    -- only has 2-3) should NOT win within the same budget -- guards against
    -- the lift-vs-weight balance drifting back to "any single balloon wins."
    do
        local reduced_n = math.max(1, level.balloon_count - 2)
        local scene = LevelScene.new(level)
        attach_all(scene, reduced_n, spread_attach_points(reduced_n))
        scene.running = true
        local won = run_until_settled(scene, MAX_TICKS)
        assert(not won, level.name .. ": " .. reduced_n
            .. " balloon(s) should not be enough to win -- balance may have drifted back to trivially easy")
        print(("PASS: level_balance: %s does not win with only %d balloon(s)"):format(level.name, reduced_n))
    end
end

print("ALL TESTS PASSED")
