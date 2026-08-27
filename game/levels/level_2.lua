-- Level 2: a flat plank. No starting tilt, the egg rests dead center --
-- simpler geometry than the bowl, but without the bowl's self-centering
-- forgiveness, so balloon placement starts to matter more here.
return {
    name = "Level 2",
    gravity = 900,
    plane = { shape = "rectangle", width = 300, height = 20, x = 0, y = 300, angle = 0 },
    egg = { x = 0, y = 270, radius = 14 },
    balloon_count = 4,
    shelf = { x = -500, y = 400 },
    pump = { x = -400, y = 450, w = 80, h = 80 },
    win_line_y = -600,
    fail_line_y = 700,
}
