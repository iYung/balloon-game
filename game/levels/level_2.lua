-- Level 2: the same rectangular plank as Level 1, but it starts pre-tilted
-- (angle = 0.3 rad ≈ 17°). A positive angle rotates the plank so its
-- positive-local-x end swings toward larger world y (lower on screen,
-- since Love2D's y axis grows downward) — that's the "low end". The egg
-- starts resting near that low end rather than dead center, matching where
-- it would naturally roll to.
return {
    name = "Level 2",
    gravity = 900,
    plane = { shape = "rectangle", width = 300, height = 20, x = 0, y = 300, angle = 0.3 },
    egg = { x = 90, y = 304, radius = 14 },
    balloon_count = 4,
    shelf = { x = -500, y = 400 },
    pump = { x = -400, y = 450, w = 80, h = 80 },
    win_line_y = -300,
    fail_line_y = 700,
}
