-- Level 1: a curved bowl. Ships first -- the concave shape naturally
-- cradles the egg (a ball settles toward the bottom-center on its own,
-- restoring itself instead of rolling away), and it tolerates a smaller or
-- lopsided balloon loadout better than the other two shapes -- making it
-- the easiest and most forgiving level to start on.
--
-- `radius`/`span`/`segments` describe a circular
-- arc centered above the plane's (x, y) anchor: radius is the circle's
-- radius, span is the total angular width in radians, and segments is how
-- many convex slices approximate that curve (Box2D fixtures must be convex,
-- so the concave bowl is built from several flat segments rather than one
-- curved shape). `angle` is the plane body's own starting rotation (kept at
-- 0 here — the bowl doesn't start tilted, only curved). A wide span on a
-- shallow radius reads as a rounded bowl with plenty of segments to hide
-- the facets; the egg starts at the bottom-center, where a ball naturally
-- settles in a concave-up shape.
--
-- egg.y was originally 280 -- ~280 units above the bowl's actual surface
-- (the bottom-center surface point is at world y = plane.y + radius = 600,
-- so resting requires egg center at 600 - egg.radius). The level still
-- "worked" because both start in free-fall under gravity and the lifted
-- plane rose up fast enough to meet the still-falling egg mid-air, but the
-- egg visibly floated apart from the bowl for the whole paused setup view.
-- Fixed to actually rest on the surface from the start.
return {
    name = "Level 1",
    gravity = 900,
    plane = { shape = "arc", radius = 300, span = 1.05, segments = 10, x = 0, y = 300, angle = 0 },
    egg = { x = 0, y = 586, radius = 14 },
    balloon_count = 5,
    shelf = { x = -500, y = 400 },
    pump = { x = -400, y = 450, w = 80, h = 80 },
    win_line_y = -600,
    fail_line_y = 700,
}
