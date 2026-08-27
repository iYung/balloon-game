-- Level 3: a curved bowl. `radius`/`span`/`segments` describe a circular
-- arc centered above the plane's (x, y) anchor: radius is the circle's
-- radius, span is the total angular width in radians, and segments is how
-- many convex slices approximate that curve (Box2D fixtures must be convex,
-- so the concave bowl is built from several flat segments rather than one
-- curved shape). `angle` is the plane body's own starting rotation (kept at
-- 0 here — the bowl doesn't start tilted, only curved). A wide span on a
-- shallow radius reads as a rounded bowl with plenty of segments to hide
-- the facets; the egg starts at the bottom-center, where a ball naturally
-- settles in a concave-up shape.
return {
    name = "Level 3",
    gravity = 900,
    plane = { shape = "arc", radius = 300, span = 1.05, segments = 10, x = 0, y = 300, angle = 0 },
    egg = { x = 0, y = 280, radius = 14 },
    balloon_count = 5,
    shelf = { x = -500, y = 400 },
    pump = { x = -400, y = 450, w = 80, h = 80 },
    win_line_y = -300,
    fail_line_y = 700,
}
