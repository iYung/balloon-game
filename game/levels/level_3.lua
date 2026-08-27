-- Level 3: the same rectangular plank as Level 2, but it starts pre-tilted
-- (angle = 0.1 rad ≈ 5.7°). A positive angle rotates the plank so its
-- positive-local-x end swings toward larger world y (lower on screen,
-- since Love2D's y axis grows downward) — that's the "low end". The egg
-- starts resting near that low end rather than dead center, matching where
-- it would naturally roll to.
--
-- angle was originally 0.3 rad (~17deg), which turned out to be unwinnable:
-- balloon-induced rotation compounds the initial tilt fast enough that the
-- egg rolls off before the plane can rise, regardless of attach strategy
-- (verified: multiple placements, all failed). At 0.1 rad with the egg
-- pulled in from the very edge (local_x 60 instead of 90), a sensible
-- 4-balloon spread wins in ~2.2s while 3 balloons or a lopsided placement
-- (all on one end) still fails -- placement and balloon count both matter,
-- same as the design intends, without being unwinnable outright. (Egg
-- position re-tuned again after excluding egg/balloon collisions -- the
-- egg no longer gets an incidental assist from bumping into a balloon near
-- the low edge, so it needed a bit more margin from the edge than before.)
return {
    name = "Level 3",
    gravity = 900,
    plane = { shape = "rectangle", width = 300, height = 20, x = 0, y = 300, angle = 0.1 },
    egg = { x = 62.1, y = 282.1, radius = 14 },
    balloon_count = 4,
    shelf = { x = -500, y = 400 },
    pump = { x = -400, y = 450, w = 80, h = 80 },
    win_line_y = -600,
    fail_line_y = 700,
}
