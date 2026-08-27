-- tests/test_level_scene.lua
-- Unit tests for game/scenes/level_scene.lua, driven entirely by calling
-- mousepressed/mousemoved/mousereleased directly with screen coordinates
-- plus update(dt) -- the same "script the input directly" pattern
-- lua/headless/input.lua's HeadlessInput uses for keyboard actions, rather
-- than faking OS-level mouse events. Levels here are small synthetic
-- tables (not the real level_1/2/3) chosen to reach win/fail states fast.

local LevelScene = require("game/scenes/level_scene")
local Balloon    = require("game/balloon")

-- LevelScene's camera has a fixed 1280x720 viewport and zoom 1
-- (Scene.new(1280, 720)); while paused it sits dead-center on the level's
-- plane (see LevelScene:_build), not always (0, 0). Takes the scene so it
-- reflects that level's actual camera position rather than assuming a
-- fixed origin. Mirrors level_scene.lua's own screen_to_world math, inverted.
local function to_screen(scene, wx, wy)
    return wx - scene.camera.x + 640, wy - scene.camera.y + 360
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

    local sx, sy = to_screen(scene, 0, 0)
    scene:mousepressed(sx, sy, 1)
    assert(scene.dragging == balloon, "pressing on the shelf balloon should start dragging it")

    local px, py = to_screen(scene, 130, 130) -- inside the pump zone
    scene:mousemoved(px, py)

    for _ = 1, 20 do
        scene:update(0.1)
    end

    assert(balloon.radius > Balloon.MIN_RADIUS,
        "holding a dragged balloon over the pump should grow its radius, got " .. tostring(balloon.radius))
    assert(balloon.inflating == true,
        "balloon.inflating should be true while held over the pump (drives the ghost-preview draw)")

    scene:mousereleased(px, py, 1)
    assert(balloon.inflating == false, "balloon.inflating should clear on release")

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

    local sx, sy = to_screen(scene, 300, 300)
    scene:mousepressed(sx, sy, 1)
    assert(scene.dragging == balloon, "pressing on the shelf balloon should start dragging it")

    local dx, dy = to_screen(scene, 0, -10) -- just on the plane's top surface
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
-- bounded number of update ticks after pressing Play. Win is keyed off the
-- egg's position, not the plane's, so the egg has to actually be resting
-- on the plane (rather than parked out of the way) for this to reach win.
do
    local level = {
        name = "Test Level 4",
        gravity = 1,
        plane = { shape = "rectangle", width = 4, height = 2, x = 0, y = 0, angle = 0 },
        egg = { x = 0, y = -15, radius = 14 }, -- resting on the plane's top surface
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
        local sx, sy = to_screen(scene, bx, by)
        scene:mousepressed(sx, sy, 1)
        assert(scene.dragging == balloon, "should pick up balloon " .. i)

        local dx, dy = to_screen(scene, attach_points[i], -1) -- on the plane's top surface
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
-- leaving the Next Level button permanently inert. Win is keyed off the
-- egg, so it needs to actually be resting on the plane to reach win.
do
    local level = {
        name = "Test Level 6",
        gravity = 1,
        plane = { shape = "rectangle", width = 4, height = 2, x = 0, y = 0, angle = 0 },
        egg = { x = 0, y = -15, radius = 14 }, -- resting on the plane's top surface
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
        local sx, sy = to_screen(scene, bx, by)
        scene:mousepressed(sx, sy, 1)
        local dx, dy = to_screen(scene, attach_points[i], -1)
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

-- Test 7: a fail-reset restores the camera to its default setup framing
-- (dead-center on the plane -- see LevelScene:_build), not wherever it
-- drifted to while following the falling plane during the run -- otherwise
-- the freshly-rebuilt plane/egg end up off-screen after a failed attempt
-- even though they're back at their normal starting size.
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
    local start_camera_x, start_camera_y = scene.camera.x, scene.camera.y
    assert(start_camera_x == level.plane.x, "camera should start centered on the plane's x")
    assert(start_camera_y == level.plane.y, "camera should start centered on the plane's y")

    scene:mousepressed(PLAY_X, PLAY_Y, 1)

    local drifted = false
    local reset_happened = false
    for _ = 1, 200 do
        scene:update(1 / 60)
        if scene.camera.y ~= start_camera_y then drifted = true end
        if scene.running == false then
            reset_happened = true
            break
        end
    end

    assert(drifted, "camera should have followed the falling plane away from its starting position before the fail-reset")
    assert(reset_happened, "egg falling past fail_line_y should trigger a reset within a bounded number of ticks")
    assert(scene.camera.x == start_camera_x and scene.camera.y == start_camera_y,
        "fail-reset should restore the camera to its starting position, got (" ..
        tostring(scene.camera.x) .. ", " .. tostring(scene.camera.y) .. ")")

    print("PASS: level_scene: fail-reset restores the camera to its default framing")
end

-- Test 8: on construction, the paused camera frames the plane, egg, pump,
-- and every loose shelf balloon within the 1280x720 viewport -- the
-- design's requirement for the setup screen. Uses a level shaped like the
-- real ones (shelf/pump well below the plane) to catch the regression
-- where a fixed (0, 0) camera left the pump/shelf off the bottom edge.
do
    local level = {
        name = "Test Level 8",
        gravity = 900,
        plane = { shape = "rectangle", width = 300, height = 20, x = 0, y = 300, angle = 0 },
        egg = { x = 0, y = 270, radius = 14 },
        balloon_count = 4,
        shelf = { x = -500, y = 400 },
        pump = { x = -400, y = 450, w = 80, h = 80 },
        win_line_y = -300,
        fail_line_y = 700,
    }

    local scene = LevelScene.new(level)

    local function in_view(wx, wy)
        local sx, sy = to_screen(scene, wx, wy)
        return sx >= 0 and sx <= 1280 and sy >= 0 and sy <= 720
    end

    assert(in_view(level.plane.x, level.plane.y), "plane should be in view on setup")
    assert(in_view(level.egg.x, level.egg.y), "egg should be in view on setup")
    assert(in_view(level.pump.x, level.pump.y), "pump top-left should be in view on setup")
    assert(in_view(level.pump.x + level.pump.w, level.pump.y + level.pump.h),
        "pump bottom-right should be in view on setup")
    for i, balloon in ipairs(scene.balloons) do
        local bx, by = balloon.body:getPosition()
        assert(in_view(bx, by), "shelf balloon " .. i .. " should be in view on setup")
    end

    print("PASS: level_scene: paused setup view frames plane, egg, pump, and shelf balloons")
end

-- Test 9: pressing Play hides the pump and every still-loose balloon (the
-- setup phase is over, nothing left to do with them), but an already-
-- attached balloon stays visible since it's actively part of the mechanism.
do
    local level = {
        name = "Test Level 9",
        gravity = 900,
        plane = { shape = "rectangle", width = 60, height = 10, x = 0, y = 0, angle = 0 },
        egg = { x = 5000, y = 5000, radius = 14 },
        balloon_count = 2,
        shelf = { x = 300, y = 300 },
        pump = { x = 1000, y = 1000, w = 60, h = 60 },
        win_line_y = -100000,
        fail_line_y = 100000,
    }

    local scene = LevelScene.new(level)
    assert(scene.pump.visible == true, "pump should be visible while paused")
    assert(scene.balloons[1].visible == true, "loose balloons should be visible while paused")

    -- Attach balloon 1, leave balloon 2 loose.
    local bx, by = scene.balloons[1].body:getPosition()
    local sx, sy = to_screen(scene, bx, by)
    scene:mousepressed(sx, sy, 1)
    local dx, dy = to_screen(scene, 0, -5) -- on the plane's top surface
    scene:mousemoved(dx, dy)
    scene:mousereleased(dx, dy, 1)
    assert(scene.balloons[1].state == "attached", "balloon 1 should have attached")

    scene:mousepressed(PLAY_X, PLAY_Y, 1)
    assert(scene.running == true, "Play should start the run")

    assert(scene.pump.visible == false, "pump should hide once running")
    assert(scene.balloons[1].visible == true, "the attached balloon should stay visible while running")
    assert(scene.balloons[2].visible == false, "the still-loose balloon should hide once running")

    print("PASS: level_scene: pressing Play hides the pump and loose balloons, keeps attached ones visible")
end

-- Test 10: once running, clicking the Play button again does nothing --
-- there's no pausing mid-run, only a win or a fail-reset.
do
    local level = {
        name = "Test Level 10",
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
    scene:mousepressed(PLAY_X, PLAY_Y, 1)
    assert(scene.running == true, "Play should start the run")

    scene:mousepressed(PLAY_X, PLAY_Y, 1)
    assert(scene.running == true, "clicking Play again while running should not pause it")

    print("PASS: level_scene: clicking Play again while running does not pause")
end

-- Test 11: winning is keyed off the egg's position, not the plane's. Rig a
-- level where the plane (tiny, near-massless, two maxed balloons) rockets
-- straight past the win line almost immediately, but the egg is parked far
-- away, untouched by any of it, and never reaches anywhere near that line.
-- The plane alone crossing must NOT set scene.won.
do
    local level = {
        name = "Test Level 11",
        gravity = 1,
        plane = { shape = "rectangle", width = 4, height = 2, x = 0, y = 0, angle = 0 },
        egg = { x = 5000, y = 5000, radius = 14 }, -- far away, unrelated to the plane
        balloon_count = 2,
        shelf = { x = 300, y = 300 },
        pump = { x = 1000, y = 1000, w = 60, h = 60 },
        win_line_y = -5,
        fail_line_y = 1000000, -- effectively unreachable, so the egg free-falling doesn't trigger a reset
    }

    local scene = LevelScene.new(level)
    local attach_points = { -1, 1 }
    for i, balloon in ipairs(scene.balloons) do
        local bx, by = balloon.body:getPosition()
        local sx, sy = to_screen(scene, bx, by)
        scene:mousepressed(sx, sy, 1)
        local dx, dy = to_screen(scene, attach_points[i], -1)
        scene:mousemoved(dx, dy)
        scene:mousereleased(dx, dy, 1)
    end

    scene:mousepressed(PLAY_X, PLAY_Y, 1)
    for _ = 1, 300 do
        scene:update(1 / 60)
    end

    assert(scene.plane:centroid_y() < level.win_line_y,
        "setup check: the plane should have cleared the win line on its own, centroid_y=" ..
        tostring(scene.plane:centroid_y()))
    assert(scene.won == false,
        "the plane alone crossing the win line should NOT win the level -- only the egg reaching it should")

    print("PASS: level_scene: the plane crossing the win line alone does not win (egg must reach it)")
end

print("ALL TESTS PASSED")
