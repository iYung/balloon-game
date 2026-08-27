-- test_scene_manager.lua
-- Unit tests for lua/core/scene_manager.lua mouse passthrough methods.

local SceneManager = require("lua/core/scene_manager")

-- Test 1: mousepressed/mousemoved/mousereleased delegate to the current
-- scene with the right arguments.
do
    local sm = SceneManager.new(1280, 720)

    local calls = {}
    local fake_scene = {
        on_enter = function() end,
        on_exit  = function() end,
        update   = function() end,
        draw     = function() end,
        mousepressed = function(self, x, y, button)
            calls.mousepressed = { x = x, y = y, button = button }
        end,
        mousemoved = function(self, x, y)
            calls.mousemoved = { x = x, y = y }
        end,
        mousereleased = function(self, x, y, button)
            calls.mousereleased = { x = x, y = y, button = button }
        end,
    }

    sm:switch(fake_scene)

    sm:mousepressed(10, 20, 1)
    sm:mousemoved(30, 40)
    sm:mousereleased(50, 60, 2)

    assert(calls.mousepressed ~= nil, "fake scene should have received mousepressed")
    assert(calls.mousepressed.x == 10 and calls.mousepressed.y == 20 and
        calls.mousepressed.button == 1,
        "mousepressed should forward args unchanged")

    assert(calls.mousemoved ~= nil, "fake scene should have received mousemoved")
    assert(calls.mousemoved.x == 30 and calls.mousemoved.y == 40,
        "mousemoved should forward args unchanged")

    assert(calls.mousereleased ~= nil, "fake scene should have received mousereleased")
    assert(calls.mousereleased.x == 50 and calls.mousereleased.y == 60 and
        calls.mousereleased.button == 2,
        "mousereleased should forward args unchanged")

    print("PASS: scene_manager: mouse methods delegate to current scene with correct args")
end

-- Test 2: calling the mouse methods with no current scene set does not
-- error (no-op).
do
    local sm = SceneManager.new(1280, 720)
    assert(sm.current == nil, "sm.current should be nil before any switch")

    sm:mousepressed(1, 2, 1)
    sm:mousemoved(3, 4)
    sm:mousereleased(5, 6, 1)

    print("PASS: scene_manager: mouse methods no-op safely with no current scene")
end

-- Test 3: calling the mouse methods when the current scene does not
-- implement them does not error (no-op).
do
    local sm = SceneManager.new(1280, 720)
    local bare_scene = {
        on_enter = function() end,
        on_exit  = function() end,
        update   = function() end,
        draw     = function() end,
    }
    sm:switch(bare_scene)

    sm:mousepressed(1, 2, 1)
    sm:mousemoved(3, 4)
    sm:mousereleased(5, 6, 1)

    print("PASS: scene_manager: mouse methods no-op safely when scene lacks them")
end

print("ALL TESTS PASSED")
