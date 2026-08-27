-- Level 1: a flat plank. Simplest case — no starting tilt at all, the egg
-- rests dead center.
return {
    name = "Level 1",
    gravity = 900,
    plane = { shape = "rectangle", width = 300, height = 20, x = 0, y = 300, angle = 0 },
    egg = { x = 0, y = 270, radius = 14 },
    balloon_count = 4,
    shelf = { x = -500, y = 400 },
    pump = { x = -400, y = 450, w = 80, h = 80 },
    win_line_y = -600,
    fail_line_y = 700,
}
