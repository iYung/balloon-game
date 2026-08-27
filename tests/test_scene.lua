local Scene      = require("lua/core/scene")
local LevelScene = require("game/scenes/level_scene")
local Levels     = require("game/levels/init")

-- Test 1: Scene.new(w, h) passes dimensions to its camera
do
    local s = Scene.new(800, 600)
    assert(s.camera ~= nil,    "Scene.new should create a camera")
    assert(s.camera._w == 800, "camera._w should be 800, got " .. tostring(s.camera._w))
    assert(s.camera._h == 600, "camera._h should be 600, got " .. tostring(s.camera._h))
    print("PASS: scene: Scene.new(w, h) threads dimensions to camera")
end

-- Test 2: Scene.new creates a drawer
do
    local s = Scene.new(1280, 720)
    assert(s.drawer ~= nil, "Scene.new should create a drawer")
    print("PASS: scene: Scene.new creates a drawer")
end

-- Test 3: LevelScene inherits drawer and camera from Scene
do
    local ls = LevelScene.new(Levels.list[1])
    assert(ls.drawer ~= nil,        "LevelScene should have a drawer from Scene")
    assert(ls.camera ~= nil,        "LevelScene should have a camera from Scene")
    assert(ls.camera._w == 1280,    "LevelScene camera._w should be 1280")
    assert(ls.camera._h == 720,     "LevelScene camera._h should be 720")
    print("PASS: scene: LevelScene inherits drawer and camera from Scene")
end

print("ALL TESTS PASSED")
