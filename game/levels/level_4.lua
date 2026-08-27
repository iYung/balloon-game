-- Level 4: level_1's bowl, flipped upside down into a dome (angle = pi
-- instead of 0) -- the hardest, final level. Ships last.
--
-- A literal full flip has a real physics consequence worth documenting: a
-- bowl's concave walls *contain* the egg regardless of how fast the plane
-- accelerates (the curved sides physically block it from escaping), but a
-- dome's convex walls curve *away* on both sides, so once the plane
-- accelerates upward faster than gravity (which any winning attempt
-- requires) the egg separates and gets left behind for good -- this isn't
-- a tuning problem, it's true at any lift strength or plane weight. A
-- steep dome at the bowl's original radius (300) is therefore only
-- winnable with a precise, well-inflated, well-placed loadout and almost
-- no margin for error. Flattening the curve (radius 600 instead of 300,
-- same span/segments) gives the egg a much wider stable-ish patch near the
-- apex to sit on, so a full 5-balloon loadout reliably wins (~2.3s) with
-- several different reasonable placements (full-span spread, a centered
-- cluster, a tighter centered cluster), while 4 balloons or any
-- off-center placement still fails -- hard, but fair.
--
-- Two geometry gotchas specific to a flipped arc, in case this shape gets
-- reused: (1) the egg rests on the *outer* surface (radius + thickness),
-- not the inner one a bowl's egg rests on -- flipping swaps which face is
-- "up". (2) plane.y is offset by (radius + thickness) so the dome's top
-- surface lands near world y=300 like every other level's material, since
-- the plane's origin itself ends up far from the visible surface once
-- flipped -- this is also why LevelScene centers the camera on the
-- plane's true centroid (Plane:centroid_y()'s getWorldCenter) rather than
-- its raw origin; centering on the origin here would frame empty space.
return {
    name = "Level 4",
    gravity = 900,
    plane = { shape = "arc", radius = 600, span = 1.05, segments = 10, x = 0, y = 920, angle = math.pi },
    egg = { x = 0, y = 286, radius = 14 },
    balloon_count = 5,
    shelf = { x = -500, y = 400 },
    pump = { x = -400, y = 450, w = 80, h = 80 },
    win_line_y = -600,
    fail_line_y = 700,
}
