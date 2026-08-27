-- game/balloon.lua
-- Draggable, inflatable, attachable balloon. Dynamic love.physics body with
-- a circle fixture. States: "loose" (free, can be dragged/inflated) and
-- "attached" (locked to a plane via a rope joint, applies lift each step).

local MIN_RADIUS      = 10
local MAX_RADIUS       = 40
local INFLATE_RATE     = 20   -- radius units per second
local LEASH_LENGTH     = 30   -- rope joint max length
local LIFT_PER_RADIUS  = 400  -- upward force per unit of radius

local Balloon = {}
Balloon.__index = Balloon

Balloon.MIN_RADIUS     = MIN_RADIUS
Balloon.MAX_RADIUS     = MAX_RADIUS
Balloon.INFLATE_RATE   = INFLATE_RATE
Balloon.LEASH_LENGTH   = LEASH_LENGTH
Balloon.LIFT_PER_RADIUS = LIFT_PER_RADIUS

function Balloon.new(world, x, y)
    local self   = setmetatable({}, Balloon)
    self.world   = world
    self.radius  = MIN_RADIUS
    self.state   = "loose"
    self.joint   = nil
    self.plane   = nil

    self.body    = love.physics.newBody(world, x, y, "dynamic")
    self.shape   = love.physics.newCircleShape(self.radius)
    self.fixture = love.physics.newFixture(self.body, self.shape, 1)

    return self
end

-- Directly reposition the balloon. Only meaningful while loose and while
-- the owning scene is paused (the scene enforces the paused rule; this
-- method just performs the move).
function Balloon:drag_to(x, y)
    self.body:setPosition(x, y)
end

-- Grows the balloon's radius at a fixed rate, up to MAX_RADIUS. Box2D
-- fixture shapes are immutable once created, so growing means destroying
-- and recreating the circle fixture at the new radius. No-op once attached.
function Balloon:inflate(dt)
    if self.state == "attached" then
        return
    end

    local new_radius = math.min(self.radius + INFLATE_RATE * dt, MAX_RADIUS)
    if new_radius == self.radius then
        return
    end

    self.radius = new_radius

    self.fixture:destroy()
    self.shape   = love.physics.newCircleShape(self.radius)
    self.fixture = love.physics.newFixture(self.body, self.shape, 1)
end

-- Attaches this balloon to a plane at plane-local coordinates (local_x,
-- local_y) via a rope joint. `plane` must expose `.body` and
-- `plane:world_anchor(local_x, local_y)`.
function Balloon:attach(plane, local_x, local_y)
    local bx, by = self.body:getPosition()
    local wx, wy = plane:world_anchor(local_x, local_y)

    self.joint = love.physics.newRopeJoint(
        self.body, plane.body,
        bx, by, wx, wy,
        LEASH_LENGTH, false
    )

    self.plane = plane
    self.state = "attached"
end

-- Destroys the rope joint and returns the balloon to the loose state.
function Balloon:detach()
    if self.joint then
        self.joint:destroy()
        self.joint = nil
    end
    self.plane = nil
    self.state = "loose"
end

-- Applies upward lift force scaled by radius. Called once per physics step
-- by the owning scene (not on an internal timer). No-op while loose.
function Balloon:apply_lift()
    if self.state ~= "attached" then
        return
    end

    local cx, cy = self.body:getWorldCenter()
    self.body:applyForce(0, -LIFT_PER_RADIUS * self.radius, cx, cy)
end

function Balloon:draw()
    local x, y = self.body:getPosition()

    love.graphics.circle("fill", x, y, self.radius)

    if self.state == "attached" and self.plane then
        -- Thin line to the anchor point on the plane side of the joint
        -- (getAnchors returns x1,y1 on the balloon body, x2,y2 on the plane).
        local _, _, ax, ay = self.joint:getAnchors()
        love.graphics.line(x, y, ax, ay)
    end
end

return Balloon
