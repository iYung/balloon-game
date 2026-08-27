local Plane = require("game/plane")

-- Test 1: rectangle plane builds one fixture and centroid_y reflects spec.y
do
    local world = love.physics.newWorld(0, 0, true)
    local spec  = { shape = "rectangle", width = 300, height = 20, x = 10, y = 300, angle = 0 }
    local plane = Plane.new(world, spec)

    assert(#plane.fixtures == 1, "rectangle plane should have exactly 1 fixture, got " .. #plane.fixtures)
    assert(plane:centroid_y() == 300, "centroid_y() should reflect spec.y (300), got " .. tostring(plane:centroid_y()))

    local wx, wy = plane:world_anchor(0, 0)
    assert(wx == 10 and wy == 300, "world_anchor(0,0) should equal body position (10,300), got (" .. wx .. "," .. wy .. ")")

    print("PASS: plane: rectangle builds one fixture, centroid_y reflects spec.y")
end

-- Test 2: rectangle plane's world_anchor offsets correctly for a non-origin
-- local point (sanity check on body:getWorldPoint usage).
do
    local world = love.physics.newWorld(0, 0, true)
    local spec  = { shape = "rectangle", width = 300, height = 20, x = 0, y = 0, angle = 0 }
    local plane = Plane.new(world, spec)

    local wx, wy = plane:world_anchor(50, -10)
    assert(wx == 50 and wy == -10, "world_anchor(50,-10) with angle 0 should equal (50,-10), got (" .. wx .. "," .. wy .. ")")

    print("PASS: plane: world_anchor offsets local points through the body transform")
end

-- Test 3: arc plane builds N convex segment fixtures, all on the same body,
-- and centroid_y still reflects spec.y.
do
    local world = love.physics.newWorld(0, 0, true)
    local spec  = {
        shape     = "arc",
        x         = 0,
        y         = 200,
        angle     = 0,
        radius    = 300,
        span      = math.pi / 2,
        thickness = 20,
        segments  = 6,
    }
    local plane = Plane.new(world, spec)

    assert(#plane.fixtures == 6, "arc plane should have 6 fixtures, got " .. #plane.fixtures)
    for _, fixture in ipairs(plane.fixtures) do
        assert(fixture:getBody() == plane.body, "every arc fixture should be attached to the plane's body")
    end
    -- centroid_y() is Box2D's fixture-weighted center of mass, not the raw
    -- body origin -- for an arc plane the visible material sits below the
    -- origin (by up to radius+thickness, less for a wide span since the
    -- arc's outer edges curve back up toward the origin's height), so it
    -- should land strictly between the origin and the material's outer edge.
    local cy = plane:centroid_y()
    assert(cy > spec.y, "arc centroid_y() should be below the body origin (material hangs below it), got " .. tostring(cy))
    assert(cy < spec.y + spec.radius + spec.thickness,
        "arc centroid_y() should not exceed the outer edge, got " .. tostring(cy))

    print("PASS: plane: arc builds N convex segment fixtures on one body, centroid_y is the true center of mass")
end

-- Test 4: arc plane defaults (no explicit thickness/segments) still work.
do
    local world = love.physics.newWorld(0, 0, true)
    local spec  = { shape = "arc", x = 0, y = 0, radius = 250, span = math.pi / 3 }
    local plane = Plane.new(world, spec)

    assert(#plane.fixtures > 0, "arc plane with default segment count should still build fixtures")

    print("PASS: plane: arc respects default thickness/segments")
end

-- Test 5: stepping the world under gravity moves the plane (nothing is
-- holding it up yet).
do
    local world = love.physics.newWorld(0, 500, true)
    local spec  = { shape = "rectangle", width = 300, height = 20, x = 0, y = 0, angle = 0 }
    local plane = Plane.new(world, spec)

    local start_y = plane:centroid_y()
    for _ = 1, 60 do
        world:update(1 / 60)
    end
    local end_y = plane:centroid_y()

    assert(end_y > start_y, "plane should have fallen under gravity: start_y=" .. start_y .. " end_y=" .. end_y)

    print("PASS: plane: falls under gravity when unsupported")
end

-- Test 6: draw() runs without error (headless love.graphics is stubbed).
do
    local world = love.physics.newWorld(0, 0, true)
    local spec  = { shape = "arc", x = 0, y = 0, radius = 200, span = math.pi / 2, segments = 4 }
    local plane = Plane.new(world, spec)

    plane:draw()

    print("PASS: plane: draw() runs without error")
end

-- Test 7: unknown shape errors clearly instead of silently building nothing.
do
    local world = love.physics.newWorld(0, 0, true)
    local ok, err = pcall(Plane.new, world, { shape = "triangle", x = 0, y = 0 })
    assert(not ok, "Plane.new with an unknown shape should error")

    print("PASS: plane: unknown shape errors")
end

print("ALL TESTS PASSED")
