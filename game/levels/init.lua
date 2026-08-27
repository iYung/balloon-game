local Level1 = require("game/levels/level_1")
local Level2 = require("game/levels/level_2")
local Level3 = require("game/levels/level_3")

local Levels = {
    list = { Level1, Level2, Level3 },
}

-- Returns the level following `level` in Levels.list (matched by identity),
-- or nil if `level` is the last one (or not found).
function Levels.next(level)
    for i, entry in ipairs(Levels.list) do
        if entry == level then
            return Levels.list[i + 1]
        end
    end
    return nil
end

return Levels
