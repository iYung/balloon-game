-- game/pump.lua
-- Static inflation zone. Not a physics body -- just an axis-aligned
-- rectangle from level data, used for point-in-rect overlap checks. The
-- owning scene decides what counts as "a balloon is held over the pump"
-- (e.g. testing the balloon's center against pump:overlaps); this class
-- only answers the point-in-rect question.

local Pump = {}
Pump.__index = Pump

-- spec: { x, y, w, h } -- (x, y) is the top-left corner of the zone in
-- world coordinates, (w, h) its width/height.
function Pump.new(spec)
    local self   = setmetatable({}, Pump)
    self.x       = spec.x
    self.y       = spec.y
    self.w       = spec.w
    self.h       = spec.h
    self.visible = true
    return self
end

-- Point-in-rect check against the zone, world coordinates. Edges count as
-- inside (inclusive).
function Pump:overlaps(x, y)
    return x >= self.x and x <= self.x + self.w
       and y >= self.y and y <= self.y + self.h
end

function Pump:draw()
    if not self.visible then
        return
    end

    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

    -- A simple T-handle above the pump body -- a rod up from the top edge
    -- ending in a short crossbar -- just enough to read as "a pump" without
    -- changing the original box silhouette.
    local handle_x = self.x + self.w * 0.5
    local handle_y = self.y - self.h * 0.15
    love.graphics.line(handle_x, self.y, handle_x, handle_y)
    love.graphics.line(handle_x - self.w * 0.15, handle_y, handle_x + self.w * 0.15, handle_y)
end

return Pump
