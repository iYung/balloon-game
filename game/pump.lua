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

-- Simple line-art hand pump, drawn within the zone's bounding box: a T
-- handle up top (with end-cap ticks so it reads as a grip, not just a
-- line), a plunger rod down into a barrel, and a base with a short nozzle
-- stub -- recognizable as "a pump" while staying in the same white-line
-- silhouette style as the rest of the game (no filled shapes but the
-- balloons/HUD, no images).
function Pump:draw()
    if not self.visible then
        return
    end

    local x, y, w, h = self.x, self.y, self.w, self.h

    local barrel_x, barrel_y = x + w * 0.3, y + h * 0.35
    local barrel_w, barrel_h = w * 0.4, h * 0.5
    love.graphics.rectangle("line", barrel_x, barrel_y, barrel_w, barrel_h)

    -- Plunger rod connecting the handle down into the barrel.
    love.graphics.line(x + w * 0.5, y + h * 0.12, x + w * 0.5, barrel_y)

    -- T-handle, with short end-cap ticks so it reads as a grip.
    love.graphics.line(x + w * 0.2, y + h * 0.12, x + w * 0.8, y + h * 0.12)
    love.graphics.line(x + w * 0.2, y + h * 0.12, x + w * 0.2, y + h * 0.2)
    love.graphics.line(x + w * 0.8, y + h * 0.12, x + w * 0.8, y + h * 0.2)

    -- Base plate.
    love.graphics.line(x + w * 0.15, y + h * 0.95, x + w * 0.85, y + h * 0.95)

    -- Nozzle stub from the barrel down to the base.
    love.graphics.line(x + w * 0.5, barrel_y + barrel_h, x + w * 0.5, y + h * 0.95)
end

return Pump
