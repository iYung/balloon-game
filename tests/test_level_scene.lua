-- tests/test_level_scene.lua
-- Unit tests for game/scenes/level_scene.lua, driven entirely by calling
-- mousepressed/mousemoved/mousereleased directly with screen coordinates
-- plus update(dt) -- the same "script the input directly" pattern
-- lua/headless/input.lua's HeadlessInput uses for keyboard actions, rather
-- than faking OS-level mouse events. Levels here are small synthetic
-- tables (not the real level_1/2/3) chosen to reach win/fail states fast.

local LevelScene = require("game/scenes/level_scene")
local Balloon    = require("game/balloon")

-- LevelScene's camera starts at (0, 0) with a fixed 1280x720 viewport and
-- zoom 1 (Scene.new(1280, 720), never moved while paused), so screen (640,
-- 360) is world (0, 0). Mirrors level_scene.lua's own screen_to_world math.
local function to_screen(wx, wy)
    return wx + 640, wy + 360
end

-- The Play/Pause button's screen rect in level_scene.lua is
-- { x = 1100, y = 16, w = 160, h = 40 }; click comfortably inside it.
local PLAY_X, PLAY_Y = 1150, 30

-- The Next Level button's screen rect is { x = 1100, y = 70, w = 160, h = 40 }.
local NEXT_X, NEXT_Y = 1150, 90

-- Test 1: dragging a loose balloon onto the pump and holding it there over
-- several update calls grows its radius.
do
    local level = {
        name = "Test Level 1",
        gravity = 0,
        plane = { shape = "rectangle", width = 60, height = 10, x = 0, y = 300, angle = 0 },
        egg = { x = 5000, y = 5000, radius = 14 },
        balloon_count = 1,
        shelf = { x = 0, y = 0 },
        pump = { x = 100, y = 100, w = 60, h = 60 },
        win_line_y = -100000,
        fail_line_y = 100000,
    }

    local scene   = LevelScene.new(level)
    local balloon = scene.balloons[1]
    assert(balloon.radius == Balloon.MIN_RADIUS, "balloon should start at MIN_RADIUS")

    local sx, sy = to_screen(0, 0)
    scene:mousepressed(sx, sy, 1)
    assert(scene.dragging == balloon, "pressing on the shelf balloon should start dragging it")

    local px, py = to_screen(130, 130) -- inside the pump zone
    scene:mousemoved(px, py)

    for _ = 1, 20 do
        scene:update(0.1)
    end

    assert(balloon.radius > Balloon.MIN_RADIUS,
        "holding a dragged balloon over the pump should grow its radius, got " .. tostring(balloon.radius))

    scene:mousereleased(px, py, 1)

    print("PASS: level_scene: dragging a balloon onto the pump grows its radius")
end

-- Test 2: dragging a balloon and releasing it near the plane attaches it.
do
    local level = {
        name = "Test Level 2",
        gravity = 0,
        plane = { shape = "rectangle", width = 200, height = 20, x = 0, y = 0, angle = 0 },
        egg = { x = 5000, y = 5000, radius = 14 },
        balloon_count = 1,
        shelf = { x = 300, y = 300 },
        pump = { x = 1000, y = 1000, w = 60, h = 60 },
        win_line_y = -100000,
        fail_line_y = 100000,
    }

    local scene   = LevelScene.new(level)
    local balloon = scene.balloons[1]

    local sx, sy = to_screen(300, 300)
    scene:mousepressed(sx, sy, 1)
    assert(scene.dragging == balloon, "pressing on the shelf balloon should start dragging it")

    local dx, dy = to_screen(0, -10) -- just on the plane's top surface
    scene:mousemoved(dx, dy)
    scene:mousereleased(dx, dy, 1)

    assert(balloon.state == "attached",
        "balloon dropped near the plane surface should attach, state=" .. tostring(balloon.state))
    assert(balloon.joint ~= nil, "attached balloon should have a joint")
    assert(scene.dragging == nil, "dragging should be cleared after release")

    print("PASS: level_scene: dragging a balloon onto the plane attaches it")
end

-- Test 3: clicking the Play button flips self.running to true and starts
-- stepping the physics world (nothing holds the plane up, so it moves).
do
    local level = {
        name = "Test Level 3",
        gravity = 900,
        plane = { shape = "rectangle", width = 60, height = 10, x = 0, y = 0, angle = 0 },
        egg = { x = 5000, y = 5000, radius = 14 },
        balloon_count = 0,
        shelf = { x = -500, y = -500 },
        pump = { x = 1000, y = 1000, w = 60, h = 60 },
        win_line_y = -100000,
        fail_line_y = 100000,
    }

    local scene = LevelScene.new(level)
    assert(scene.running == false, "scene should start paused")

    local start_y = scene.plane:centroid_y()

    scene:mousepressed(PLAY_X, PLAY_Y, 1)
    assert(scene.running == true, "clicking Play should flip running to true")

    for _ = 1, 30 do
        scene:update(1 / 60)
    end

    local end_y = scene.plane:centroid_y()
    assert(end_y ~= start_y,
        "physics should be stepping once running: plane y should change, start=" ..
        tostring(start_y) .. " end=" .. tostring(end_y))

    print("PASS: level_scene: clicking Play starts stepping the physics world")
end

-- Test 4: a level rigged with enough attached-balloon lift (a tiny,
-- near-weightless plane vs. two attached balloons) reaches win within a
-- bounded number of update ticks after pressing Play.
do
    local level = {
        name = "Test Level 4",
        gravity = 1,
        plane = { shape = "rectangle", width = 4, height = 2, x = 0, y = 0, angle = 0 },
        egg = { x = 5000, y = 5000, radius = 14 },
        balloon_count = 2,
        shelf = { x = 300, y = 300 },
        pump = { x = 1000, y = 1000, w = 60, h = 60 },
        win_line_y = -5,
        fail_line_y = 100000,
    }

    local scene = LevelScene.new(level)

    local attach_points = { -1, 1 }
    for i, balloon in ipairs(scene.balloons) do
        local bx, by = balloon.body:getPosition()
        local sx, sy = to_screen(bx, by)
        scene:mousepressed(sx, sy, 1)
        assert(scene.dragging == balloon, "should pick up balloon " .. i)

        local dx, dy = to_screen(attach_points[i], -1) -- on the plane's top surface
        scene:mousemoved(dx, dy)
        scene:mousereleased(dx, dy, 1)

        assert(balloon.state == "attached", "balloon " .. i .. " should have attached")
    end

    scene:mousepressed(PLAY_X, PLAY_Y, 1)
    assert(scene.running == true, "Play should start the run")

    local won = false
    for _ = 1, 2000 do
        scene:update(1 / 60)
        if scene.won then
            won = true
            break
        end
    end

    assert(won, "level rigged with strong lift should reach win within a bounded number of ticks")
    assert(scene.running == false, "scene should stop stepping once won")

    print("PASS: level_scene: a level rigged with enough lift reaches win within bounded ticks")
end

-- Test 5: a level where the egg free-falls past fail_line_y resets the
-- scene to its starting state (egg position, loose balloon count, paused).
do
    local level = {
        name = "Test Level 5",
        gravity = 200,
        plane = { shape = "rectangle", width = 60, height = 10, x = 1000, y = 1000, angle = 0 },
        egg = { x = 0, y = 0, radius = 14 },
        balloon_count = 2,
        shelf = { x = -500, y = -500 },
        pump = { x = -600, y = -600, w = 60, h = 60 },
        win_line_y = -100000,
        fail_line_y = 5,
    }

    local scene = LevelScene.new(level)

    scene:mousepressed(PLAY_X, PLAY_Y, 1)
    assert(scene.running == true, "Play should start the run")

    local reset_happened = false
    for _ = 1, 200 do
        scene:update(1 / 60)
        if scene.running == false then
            reset_happened = true
            break
        end
    end

    assert(reset_happened, "egg falling past fail_line_y should trigger a reset within a bounded number of ticks")
    assert(scene.egg:y() == level.egg.y,
        "reset should restore the egg to its starting y, got " .. tostring(scene.egg:y()))
    assert(#scene.balloons == level.balloon_count,
        "reset should restore the starting loose balloon count")
    for i, balloon in ipairs(scene.balloons) do
        assert(balloon.state == "loose", "balloon " .. i .. " should be loose again after reset")
    end

    print("PASS: level_scene: egg falling past fail_line_y resets the scene to its starting state")
end

-- Test 6: clicking Next Level when there is no next level (Levels.next
-- returns nil, since this synthetic level is never in the real
-- game/levels/init.lua list) reaches a "finished" end state instead of
-- leaving the Next Level button permanently inert.
do
    local level = {
        name = "Test Level 6",
        gravity = 1,
        plane = { shape = "rectangle", width = 4, height = 2, x = 0, y = 0, angle = 0 },
        egg = { x = 5000, y = 5000, radius = 14 },
        balloon_count = 2,
        shelf = { x = 300, y = 300 },
        pump = { x = 1000, y = 1000, w = 60, h = 60 },
        win_line_y = -5,
        fail_line_y = 100000,
    }

    local scene = LevelScene.new(level)

    local attach_points = { -1, 1 }
    for i, balloon in ipairs(scene.balloons) do
        local bx, by = balloon.body:getPosition()
        local sx, sy = to_screen(bx, by)
        scene:mousepressed(sx, sy, 1)
        local dx, dy = to_screen(attach_points[i], -1)
        scene:mousemoved(dx, dy)
        scene:mousereleased(dx, dy, 1)
    end

    scene:mousepressed(PLAY_X, PLAY_Y, 1)
    for _ = 1, 2000 do
        scene:update(1 / 60)
        if scene.won then break end
    end
    assert(scene.won, "setup for test 6 should reach win")
    assert(scene.finished == false, "should not be finished yet, just won")

    scene:mousepressed(NEXT_X, NEXT_Y, 1)
    assert(scene.finished == true, "advancing past the last level should set finished")
    assert(scene.won == true, "finished state should still read as won")

    print("PASS: level_scene: advancing past the last level reaches the finished end state")
end

-- Test 7: a fail-reset restores the camera to its default framing (0, 0),
-- not wherever it drifted to while following the falling plane during the
-- run -- otherwise the freshly-rebuilt plane/egg end up off-screen after a
-- failed attempt even though they're back at their normal starting size.
do
    local level = {
        name = "Test Level 7",
        gravity = 400,
        plane = { shape = "rectangle", width = 60, height = 10, x = 0, y = 0, angle = 0 },
        egg = { x = 0, y = 0, radius = 14 },
        balloon_count = 0,
        shelf = { x = -500, y = -500 },
        pump = { x = -600, y = -600, w = 60, h = 60 },
        win_line_y = -100000,
        fail_line_y = 150,
    }

    local scene = LevelScene.new(level)
    assert(scene.camera.x == 0 and scene.camera.y == 0, "camera should start at (0, 0)")

    scene:mousepressed(PLAY_X, PLAY_Y, 1)

    local drifted = false
    local reset_happened = false
    for _ = 1, 200 do
        scene:update(1 / 60)
        if scene.camera.y ~= 0 then drifted = true end
        if scene.running == false then
            reset_happened = true
            break
        end
    end

    assert(drifted, "camera should have followed the falling plane away from (0, 0) before the fail-reset")
    assert(reset_happened, "egg falling past fail_line_y should trigger a reset within a bounded number of ticks")
    assert(scene.camera.x == 0 and scene.camera.y == 0,
        "fail-reset should restore the camera to (0, 0), got (" ..
        tostring(scene.camera.x) .. ", " .. tostring(scene.camera.y) .. ")")

    print("PASS: level_scene: fail-reset restores the camera to its default framing")
end

print("ALL TESTS PASSED")
