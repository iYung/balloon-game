-- test_egg.lua
-- Unit tests for game/egg.lua against love.physics directly (headless,
-- no window/scene needed).

local Egg     = require("game/egg")
local Balloon = require("game/balloon")

-- Test 1: initial position matches spec, fixture/shape exist.
do
    local world = love.physics.newWorld(0, 900, true)
    local egg   = Egg.new(world, { x = 10, y = 50, radius = 14 })

    assert(egg:y() == 50, "egg:y() should equal spec.y, got " .. tostring(egg:y()))
    assert(egg.body ~= nil, "egg.body should exist")
    assert(egg.fixture ~= nil, "egg.fixture should exist")
    assert(egg.shape ~= nil, "egg.shape should exist")
    assert(egg.body:getX() == 10, "egg body x should equal spec.x")

    print("PASS: egg: initial state matches spec")
end

-- Test 2: with nothing beneath it, the egg falls under gravity when the
-- world is stepped.
do
    local world = love.physics.newWorld(0, 900, true)
    local egg   = Egg.new(world, { x = 0, y = 0, radius = 14 })

    local start_y = egg:y()
    for _ = 1, 30 do
        world:update(1 / 60)
    end

    assert(egg:y() > start_y, "egg should have fallen (y increased), start=" ..
        tostring(start_y) .. " end=" .. tostring(egg:y()))

    print("PASS: egg: falls under gravity")
end

-- Test 3: draw() does not error (love.graphics is stubbed under headless).
do
    local world = love.physics.newWorld(0, 900, true)
    local egg   = Egg.new(world, { x = 0, y = 0, radius = 14 })
    egg:draw()
    print("PASS: egg: draw() does not error")
end

-- Test 4: the egg does not physically collide with a balloon -- they can
-- overlap without Box2D forcing them apart. Balloons float around/above
-- the plane and shouldn't act as obstacles for the egg resting on it.
-- Starting them at the exact same position is the clearest check: with
-- only gravity acting on both (mass-independent acceleration, so they'd
-- fall identically and stay at ~0 separation regardless), a real collision
-- would immediately show up as a strong separation impulse pushing them
-- apart (Box2D resolves deep penetration aggressively); no collision means
-- they simply stay together.
do
    local world   = love.physics.newWorld(0, 900, true)
    local egg     = Egg.new(world, { x = 0, y = 0, radius = 14 })
    local balloon = Balloon.new(world, 0, 0) -- exact same position/overlap

    for _ = 1, 30 do
        world:update(1 / 60)
    end

    local ex, ey = egg.body:getPosition()
    local bx, by = balloon.body:getPosition()
    local dist = math.sqrt((ex - bx) ^ 2 + (ey - by) ^ 2)

    assert(dist < 1,
        "egg and balloon should stay together under gravity alone (no collision separating them), dist=" ..
        tostring(dist))

    print("PASS: egg: does not collide with a balloon (no separation impulse)")
end

print("ALL TESTS PASSED")
