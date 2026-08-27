-- test_egg.lua
-- Unit tests for game/egg.lua against love.physics directly (headless,
-- no window/scene needed).

local Egg = require("game/egg")

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

print("ALL TESTS PASSED")
