local Balloon = require("game/balloon")

local Egg = {}
Egg.__index = Egg

-- Visual-only stretch factor for the egg silhouette; the physics fixture
-- stays a plain circle of spec.radius.
local HEIGHT_SCALE = 1.2

-- world: a love.physics World
-- spec: { x, y, radius }
function Egg.new(world, spec)
    local self   = setmetatable({}, Egg)
    self.radius  = spec.radius
    self.body    = love.physics.newBody(world, spec.x, spec.y, "dynamic")
    self.shape   = love.physics.newCircleShape(spec.radius)
    self.fixture = love.physics.newFixture(self.body, self.shape)
    -- The egg should rest on the plane, not physically bump into balloons
    -- floating around/above it -- exclude Balloon.CATEGORY from collision.
    self.fixture:setMask(Balloon.CATEGORY)
    return self
end

function Egg:y()
    return self.body:getY()
end

function Egg:draw()
    local x, y = self.body:getPosition()
    love.graphics.ellipse("fill", x, y, self.radius, self.radius * HEIGHT_SCALE)
end

return Egg
