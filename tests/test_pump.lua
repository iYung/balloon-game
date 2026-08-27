local Pump = require("game/pump")

-- Test 1: points inside the zone (including near-edges) overlap.
do
    local p = Pump.new({ x = -400, y = 450, w = 80, h = 80 })
    assert(p:overlaps(-400, 450), "top-left corner should overlap")
    assert(p:overlaps(-360, 490), "center should overlap")
    assert(p:overlaps(-320, 530), "bottom-right corner should overlap")
    print("PASS: pump: points inside the zone overlap")
end

-- Test 2: points clearly outside the zone do not overlap.
do
    local p = Pump.new({ x = -400, y = 450, w = 80, h = 80 })
    assert(not p:overlaps(-500, 490), "point left of zone should not overlap")
    assert(not p:overlaps(-300, 490), "point right of zone should not overlap")
    assert(not p:overlaps(-360, 400), "point above zone should not overlap")
    assert(not p:overlaps(-360, 600), "point below zone should not overlap")
    print("PASS: pump: points outside the zone do not overlap")
end

-- Test 3: points exactly on each edge are treated as inside (inclusive).
do
    local p = Pump.new({ x = 0, y = 0, w = 100, h = 50 })
    assert(p:overlaps(0, 25),    "left edge should overlap")
    assert(p:overlaps(100, 25),  "right edge should overlap")
    assert(p:overlaps(50, 0),    "top edge should overlap")
    assert(p:overlaps(50, 50),   "bottom edge should overlap")
    assert(p:overlaps(0, 0),     "top-left corner (edge/edge) should overlap")
    assert(p:overlaps(100, 50),  "bottom-right corner (edge/edge) should overlap")
    print("PASS: pump: on-edge points are inclusive")
end

-- Test 4: points just past each edge (off by an epsilon) do not overlap.
do
    local p = Pump.new({ x = 0, y = 0, w = 100, h = 50 })
    assert(not p:overlaps(-0.01, 25),  "just left of left edge should not overlap")
    assert(not p:overlaps(100.01, 25), "just right of right edge should not overlap")
    assert(not p:overlaps(50, -0.01),  "just above top edge should not overlap")
    assert(not p:overlaps(50, 50.01),  "just below bottom edge should not overlap")
    print("PASS: pump: just-past-edge points do not overlap")
end

-- Test 5: draw() runs without error (headless love.graphics is stubbed).
do
    local p = Pump.new({ x = -400, y = 450, w = 80, h = 80 })
    p:draw()
    print("PASS: pump: draw() runs without error")
end

print("ALL TESTS PASSED")
