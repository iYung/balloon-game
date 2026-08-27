-- game/balloon.lua
-- Draggable, inflatable, attachable balloon. Dynamic love.physics body with
-- a circle fixture. States: "loose" (free, can be dragged/inflated) and
-- "attached" (locked to a plane via a rope joint, applies lift each step).

local MIN_RADIUS      = 10
local MAX_RADIUS       = 40
local INFLATE_RATE     = 20   -- radius units per second
-- Rope joint max length. Kept comfortably larger than MAX_RADIUS (40) on
-- purpose: the connecting line drawn in Balloon:draw() runs from the
-- balloon's center to this anchor, and once the rope goes taut the
-- steady-state distance sits at ~LEASH_LENGTH -- if that were smaller than
-- MAX_RADIUS (it originally was, at 30), the anchor point would sit
-- entirely inside a well-inflated balloon's own filled circle and the line
-- would be completely hidden. Re-verified this doesn't reintroduce the
-- rotation instability a shorter leash helped avoid (see plane.lua's
-- angular damping) -- level_3 still wins with the same 7 of 8 tried
-- balloon-cluster placements at this length.
local LEASH_LENGTH     = 60
-- love.physics runs Box2D at its default scale of 30 pixels/meter, so a
-- fixture's mass is computed from its area IN METERS, not pixels -- a
-- radius-40 circle is really a ~1.33m-radius circle. At the ordinary
-- density of 1 that gives it a mass of ~5.6 and a weight (mass * gravity)
-- of several thousand: far more than any reasonable lift force, so every
-- balloon would be a net anchor instead of a lifter regardless of count.
-- A real balloon's shell+gas weighs a small fraction of what it can lift,
-- so it needs a much lower density than the plane/egg it's trying to move.
local DENSITY          = 0.01
-- Upward force per unit of radius. Tuned against the flat-plank plane
-- (mass ~6.7, gravity 900 -> weight ~6030): a full, well-spread, maxed-out
-- balloon loadout gives a strong ~2.65x margin over the plane's weight
-- (4 * 40 * 100 = 16000) for a fast, satisfying climb, while a loadout
-- missing 2 balloons (or one badly lopsided on the pre-tilted level) still
-- generally fails -- so balloon count and placement still matter, without
-- every level demanding a near-perfect loadout to win at all. (Raised from
-- an original 60, which -- combined with DENSITY above only landing right
-- after a separate fix -- made every level require an unforgivingly exact
-- setup; see git history for the balance search across candidate values.)
-- This math only holds because DENSITY above keeps each balloon's own
-- weight negligible next to its lift (e.g. ~50 out of 4000 at max radius)
-- -- otherwise the balloons' own weight would swamp the lift entirely.
local LIFT_PER_RADIUS  = 100
-- Collision category balloons register their fixtures under, so the egg
-- can exclude them (see game/egg.lua) -- the egg should rest on the plane,
-- not bump into balloons floating around/above it.
local CATEGORY         = 2

local Balloon = {}
Balloon.__index = Balloon

Balloon.MIN_RADIUS     = MIN_RADIUS
Balloon.MAX_RADIUS     = MAX_RADIUS
Balloon.INFLATE_RATE   = INFLATE_RATE
Balloon.LEASH_LENGTH   = LEASH_LENGTH
Balloon.LIFT_PER_RADIUS = LIFT_PER_RADIUS
Balloon.CATEGORY       = CATEGORY

function Balloon.new(world, x, y)
    local self   = setmetatable({}, Balloon)
    self.world   = world
    self.radius  = MIN_RADIUS
    self.state   = "loose"
    self.joint   = nil
    self.plane   = nil
    self.visible = true

    self.body    = love.physics.newBody(world, x, y, "dynamic")
    self.shape   = love.physics.newCircleShape(self.radius)
    self.fixture = love.physics.newFixture(self.body, self.shape, DENSITY)
    self.fixture:setCategory(CATEGORY)

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
    self.fixture = love.physics.newFixture(self.body, self.shape, DENSITY)
    self.fixture:setCategory(CATEGORY)
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
    if not self.visible then
        return
    end

    local x, y = self.body:getPosition()

    love.graphics.circle("fill", x, y, self.radius)

    if self.state == "attached" and self.plane then
        -- Line to the anchor point on the plane side of the joint
        -- (getAnchors returns x1,y1 on the balloon body, x2,y2 on the plane).
        -- Drawn a bit thicker than the 1px default so it reads clearly
        -- against the plane/egg -- reset afterward so it doesn't bleed
        -- into unrelated draws later in the frame (e.g. the pump's outline).
        local _, _, ax, ay = self.joint:getAnchors()
        love.graphics.setLineWidth(2)
        love.graphics.line(x, y, ax, ay)
        love.graphics.setLineWidth(1)
    end
end

return Balloon
