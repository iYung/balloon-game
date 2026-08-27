-- game/plane.lua
-- The rigid platform the egg rests on. Built from level data as one
-- love.physics dynamic body with one or more convex PolygonShape fixtures
-- (Box2D fixtures must be convex, so a concave shape like the bowl level is
-- approximated as several convex segment fixtures on the same body).
--
-- Supported spec.shape values:
--   "rectangle" — flat or pre-tilted plank.
--     spec = { shape = "rectangle", width, height, x, y, angle }
--     A single PolygonShape fixture, centered on the body origin.
--
--   "arc" — curved bowl, procedurally sliced into N convex quad segments
--   that approximate a ring slice of a circle. spec.x/spec.y place the
--   *circle's center* (above the visible bowl surface); the surface itself
--   lies `radius` units below that point, curving up on either side.
--     spec = { shape = "arc", x, y, angle, radius, span, thickness, segments }
--       radius    — distance from the body origin to the inner (surface) edge
--       span      — total angular width of the bowl, in radians
--       thickness — radial thickness of the bowl's material (default 20)
--       segments  — number of convex slices to approximate the curve with
--                   (default 8; each slice is a 4-vertex convex quad, well
--                   under Box2D's 8-vertex-per-fixture limit)

local ARC_DEFAULT_THICKNESS = 20
local ARC_DEFAULT_SEGMENTS  = 8
local FIXTURE_DENSITY       = 1

local Plane = {}
Plane.__index = Plane

function Plane.new(world, spec)
    local self = setmetatable({}, Plane)
    self.spec     = spec
    self.body     = love.physics.newBody(world, spec.x, spec.y, "dynamic")
    self.body:setAngle(spec.angle or 0)
    self.fixtures = {}

    if spec.shape == "rectangle" then
        self:_build_rectangle(spec)
    elseif spec.shape == "arc" then
        self:_build_arc(spec)
    else
        error("Plane.new: unknown shape '" .. tostring(spec.shape) .. "'")
    end

    return self
end

function Plane:_add_fixture(shape)
    local fixture = love.physics.newFixture(self.body, shape, FIXTURE_DENSITY)
    self.fixtures[#self.fixtures + 1] = fixture
    return fixture
end

function Plane:_build_rectangle(spec)
    local shape = love.physics.newRectangleShape(spec.width, spec.height)
    self:_add_fixture(shape)
end

-- Slices a ring sector (centered on the body origin, spanning `span`
-- radians, from radius `radius` to `radius + thickness`) into `segments`
-- convex quad fixtures. Angle 0 points straight down (+y, matching this
-- project's y-down/gravity-down convention), so the sector curves up and
-- away from the origin on both sides — a bowl the egg can settle into.
function Plane:_build_arc(spec)
    local radius    = spec.radius
    local span      = spec.span
    local thickness = spec.thickness or ARC_DEFAULT_THICKNESS
    local segments  = spec.segments or ARC_DEFAULT_SEGMENTS

    local inner_r = radius
    local outer_r = radius + thickness

    for i = 1, segments do
        local theta_a = -span / 2 + (i - 1) * (span / segments)
        local theta_b = -span / 2 + i * (span / segments)

        local ax, ay = inner_r * math.sin(theta_a), inner_r * math.cos(theta_a)
        local bx, by = inner_r * math.sin(theta_b), inner_r * math.cos(theta_b)
        local cx, cy = outer_r * math.sin(theta_b), outer_r * math.cos(theta_b)
        local dx, dy = outer_r * math.sin(theta_a), outer_r * math.cos(theta_a)

        local shape = love.physics.newPolygonShape(ax, ay, bx, by, cx, cy, dx, dy)
        self:_add_fixture(shape)
    end
end

-- Converts a point in the plane's local body space to world space, via the
-- physics body's transform. Used by balloons to compute a stable attach
-- anchor that stays fixed relative to the plane as it moves/rotates.
function Plane:world_anchor(local_x, local_y)
    return self.body:getWorldPoint(local_x, local_y)
end

-- Vertical position used for the win check ("has the plane risen above the
-- win line"). Uses the body's actual world-space center of mass, not the
-- body origin -- for a centered "rectangle" plane those coincide, but for
-- an "arc" plane the origin sits `radius` units *above* the visible bowl
-- material (see _build_arc), so using getY() there made the win line
-- trigger long before the visible bowl actually reached it. getWorldCenter
-- is Box2D's own fixture-weighted center of mass, correct for any shape.
function Plane:centroid_y()
    local _, wy = self.body:getWorldCenter()
    return wy
end

function Plane:draw()
    for _, fixture in ipairs(self.fixtures) do
        local shape  = fixture:getShape()
        local points = { shape:getPoints() }
        local world_points = {}
        for i = 1, #points, 2 do
            local wx, wy = self.body:getWorldPoint(points[i], points[i + 1])
            world_points[#world_points + 1] = wx
            world_points[#world_points + 1] = wy
        end
        love.graphics.polygon("fill", world_points)
    end
end

return Plane
