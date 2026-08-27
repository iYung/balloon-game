-- Level 3: the same rectangular plank as Level 2, but it starts pre-tilted
-- (angle = 0.05 rad ≈ 2.9°). A positive angle rotates the plank so its
-- positive-local-x end swings toward larger world y (lower on screen,
-- since Love2D's y axis grows downward) — that's the "low end". The egg
-- starts resting near that low end rather than dead center, matching where
-- it would naturally roll to.
--
-- Re-tuned twice since: angle was originally 0.3 rad (~17deg), unwinnable
-- outright (egg rolled off before the plane could rise, every strategy
-- failed). Dropped to 0.1 rad with the egg at local_x 60-90 and it became
-- winnable but only with a near-exact balloon cluster -- once win became
-- keyed off the egg's position instead of the plane's (see
-- game/scenes/level_scene.lua) and lift got stronger, a wide/naive balloon
-- spread sent the plane oscillating wildly (angle swinging +-0.6 rad) and
-- the egg rolled back and forth across it without ever climbing, even
-- though the plane itself cleared the line easily.
--
-- Fixed two ways together: game/plane.lua now gives every plane angular
-- damping so rotation actually settles instead of oscillating forever, and
-- this level's angle/egg position were re-searched against 8 different
-- balloon-cluster strategies (not just one) at low_x=30, angle=0.05 --
-- 7 of 8 reasonable placements now win in ~1.3-1.5s; only balloons
-- clustered entirely on the low end still fails, and a single balloon (or
-- 2 balloons) is still never enough -- so placement/count still matter,
-- just without demanding one exact magic cluster.
return {
    name = "Level 3",
    gravity = 900,
    plane = { shape = "rectangle", width = 300, height = 20, x = 0, y = 300, angle = 0.05 },
    egg = { x = 31.2, y = 277.5, radius = 14 },
    balloon_count = 4,
    shelf = { x = -500, y = 400 },
    pump = { x = -400, y = 450, w = 80, h = 80 },
    win_line_y = -600,
    fail_line_y = 700,
}
