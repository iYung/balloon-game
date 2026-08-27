-- tests/test_balloon.lua
-- Unit tests for game/balloon.lua, run directly against love.physics
-- (headless — no window needed).

local Balloon = require("game/balloon")

-- Minimal fake "plane" for these tests: a Plane instance only needs to
-- expose `.body` and `plane:world_anchor(local_x, local_y)` as far as
-- Balloon is concerned, so we stub that shape here rather than depending
-- on game/plane.lua (a separate, independently-developed task).
local FakePlane = {}
FakePlane.__index = FakePlane

function FakePlane.new(world, x, y)
    local self = setmetatable({}, FakePlane)
    self.body  = love.physics.newBody(world, x, y, "static")
    love.physics.newFixture(self.body, love.physics.newRectangleShape(200, 20), 1)
    return self
end

function FakePlane:world_anchor(local_x, local_y)
    return self.body:getWorldPoint(local_x, local_y)
end

-- Test 1: inflate grows radius at a fixed rate and clamps at MAX_RADIUS.
do
    local world   = love.physics.newWorld(0, 0, true)
    local balloon = Balloon.new(world, 0, 0)

    assert(balloon.radius == Balloon.MIN_RADIUS,
        "balloon should start at MIN_RADIUS, got " .. tostring(balloon.radius))

    balloon:inflate(1)
    assert(balloon.radius > Balloon.MIN_RADIUS,
        "inflate should grow radius, got " .. tostring(balloon.radius))
    assert(balloon.shape:getRadius() == balloon.radius,
        "fixture's circle shape should match balloon.radius after inflate")

    -- Inflate well past MAX_RADIUS worth of time; should clamp, not overshoot.
    for _ = 1, 20 do
        balloon:inflate(1)
    end
    assert(balloon.radius == Balloon.MAX_RADIUS,
        "radius should clamp at MAX_RADIUS, got " .. tostring(balloon.radius))
    assert(balloon.shape:getRadius() == Balloon.MAX_RADIUS,
        "fixture's circle shape should be recreated at MAX_RADIUS")

    -- Further inflate calls are a no-op at the cap.
    balloon:inflate(1)
    assert(balloon.radius == Balloon.MAX_RADIUS,
        "inflate should no-op once at MAX_RADIUS")

    print("PASS: balloon: inflate grows radius and clamps at MAX_RADIUS")
end

-- Test 1b: inflate is a no-op once attached.
do
    local world   = love.physics.newWorld(0, 0, true)
    local balloon = Balloon.new(world, 0, 0)
    local plane   = FakePlane.new(world, 0, 100)

    balloon:attach(plane, 0, 0)
    local radius_before = balloon.radius
    balloon:inflate(5)
    assert(balloon.radius == radius_before,
        "inflate should no-op once attached")

    print("PASS: balloon: inflate no-ops once attached")
end

-- Test 2: attach/detach create and destroy a joint.
do
    local world   = love.physics.newWorld(0, 0, true)
    local balloon = Balloon.new(world, 0, 0)
    local plane   = FakePlane.new(world, 0, 100)

    assert(balloon.joint == nil, "joint should be nil before attach")
    assert(balloon.state == "loose", "balloon should start loose")

    balloon:attach(plane, 0, 0)
    assert(balloon.joint ~= nil, "joint should exist after attach")
    assert(balloon.state == "attached", "state should be 'attached' after attach")

    balloon:detach()
    assert(balloon.joint == nil, "joint should be nil after detach")
    assert(balloon.state == "loose", "state should be 'loose' after detach")

    print("PASS: balloon: attach/detach create and destroy a joint")
end

-- Test 3: a lone attached balloon pulls itself upward (y decreases) over
-- several simulated steps when apply_lift() is called each physics step.
do
    local world   = love.physics.newWorld(0, 0, true) -- no gravity: isolate lift
    local start_y = 200
    local balloon = Balloon.new(world, 0, start_y)
    local plane   = FakePlane.new(world, 0, start_y)

    balloon:attach(plane, 0, 0)

    local dt = 1 / 60
    for _ = 1, 180 do
        balloon:apply_lift()
        world:update(dt)
    end

    local _, final_y = balloon.body:getPosition()
    assert(final_y < start_y,
        "attached balloon under apply_lift should rise (y decrease), start=" ..
        tostring(start_y) .. " final=" .. tostring(final_y))

    print("PASS: balloon: attached balloon rises under apply_lift over several steps")
end

-- Test 4: the "inflating" ghost-preview flag defaults to false, doesn't
-- error when drawn in either state, and draw() still works once maxed out
-- (no ghost should render past MAX_RADIUS, but nothing should error either).
do
    local world   = love.physics.newWorld(0, 0, true)
    local balloon = Balloon.new(world, 0, 0)

    assert(balloon.inflating == false, "balloon should not start inflating")
    balloon:draw() -- not inflating: just the solid circle

    balloon.inflating = true
    balloon:draw() -- inflating, below MAX_RADIUS: solid circle + ghost ring

    while balloon.radius < Balloon.MAX_RADIUS do
        balloon:inflate(1 / 60)
    end
    balloon:draw() -- inflating, at MAX_RADIUS: no ghost to draw, must not error

    print("PASS: balloon: inflating ghost preview draws without error in all states")
end

print("ALL TESTS PASSED")
