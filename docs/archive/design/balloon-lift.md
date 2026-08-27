## Goal

Turn the love-exemplar template into a real game: **Balloon Lift**, a physics
puzzle. Each level is an egg resting on a plane (a rigid platform of some
shape). The level starts paused. The player drags balloons around, holds
them over a pump to inflate them, and attaches them to the plane. Unpausing
starts the physics simulation: attached balloons pull the plane upward by an
amount based on their size, the egg rolls around on the plane as it tilts,
and the level is won when the plane rises above a win line. If the egg falls
off the plane (or off the bottom of the level) while running, the level
fails and resets to its paused starting state.

v1 ships 3 hand-built levels that vary the plane's shape: a flat plank, a
plank that starts pre-tilted, and a curved bowl.

## Affected files

**New — physics/game objects** (`game/`)
- `game/plane.lua` — the rigid platform the egg sits on
- `game/egg.lua` — the egg
- `game/balloon.lua` — draggable, inflatable, attachable balloon
- `game/pump.lua` — static inflation zone

**New — levels** (`game/levels/`)
- `game/levels/level_1.lua` — flat plank
- `game/levels/level_2.lua` — pre-tilted plank
- `game/levels/level_3.lua` — curved bowl
- `game/levels/init.lua` — ordered level list + "next level" helper

**New — scene**
- `game/scenes/level_scene.lua` — owns the `love.physics` world, all game
  objects, pause/run state, mouse-driven drag/inflate/attach, win/fail
  detection, HUD

**New — tests** (`tests/`)
- `tests/test_plane.lua`, `tests/test_egg.lua`, `tests/test_balloon.lua` —
  unit tests against the physics objects directly (no window needed —
  `love.physics` works headless)
- `tests/test_level_scene.lua` — pause/run toggle, drag → inflate → attach
  flow, win line trigger, fail-and-reset flow, all driven by calling
  `level_scene:mousepressed/mousemoved/mousereleased` directly with world
  coordinates (same pattern `HeadlessInput` uses for keyboard: script the
  input, don't fake the device)

**Modified**
- `main.lua` — boot into `LevelScene.new(Levels[1])` instead of `GameScene`;
  forward `love.mousepressed/mousemoved/mousereleased` to the active scene
- `lua/core/scene_manager.lua` — add `mousepressed/mousemoved/mousereleased`
  passthrough methods (delegate to `self.current` if it defines them),
  mirroring the existing `update`/`draw` delegation pattern
- `tests/test_scene.lua` — Test 3 currently asserts `GameScene` inherits
  `drawer`/`camera` from `Scene`; repoint it at `LevelScene` since
  `GameScene` is removed
- `tests/test_basics.lua` — currently ticks a bare `GameScene`; rewrite to
  tick a `LevelScene` instead

**Removed**
- `game/player.lua`, `game/scenes/game_scene.lua` — placeholder demo content
  superseded by the real game
- `assets/player.png` — only used by the removed `Player`

**Untouched**
- `lua/core/camera.lua`, `drawer.lua`, `scene.lua`, `sprite.lua`,
  `spriteset.lua`, `timer.lua`, `fonts.lua`, `input.lua` (keyboard input
  stays available for anything that wants it, unused by this feature)
- `lua/headless/*` — no new headless infrastructure needed (see testing
  note above)
- `conf.lua` — `love.physics` is not in the headless module-disable list,
  so it already works under `--headless` with no config change

## What changes

### Physics world

`LevelScene` creates one `love.physics.newWorld(0, GRAVITY, true)`. Bodies
for the plane, egg, and every balloon are created as **dynamic** from the
start. The pause/run distinction is *not* modeled with body types — it's
simply whether `world:update(dt)` is called at all. While paused nothing
steps, so nothing moves regardless of body type; the only extra rule is that
direct drag repositioning (`body:setPosition`) is only allowed while paused.
This keeps the object model uniform (no type-swapping) and matches the
"physics starts when you unpause" framing directly.

### Plane

Built from level data as one physics body with one or more convex
`PolygonShape` fixtures (Box2D fixtures must be convex; a concave shape like
the bowl level is approximated as several convex segments on the same
body). Two shape generators cover all 3 v1 levels:
- `rectangle` — flat or pre-tilted plank (a single fixture; "pre-tilted"
  just means the level data sets a nonzero starting `angle`)
- `arc` — curved bowl, procedurally sliced into N convex segment fixtures
  spanning a radius/angle given in level data

Exposes `plane:world_anchor(local_x, local_y)` (via `body:getWorldPoint`) so
balloons can compute a stable attach anchor, and `plane:centroid_y()` used
for the win check.

### Egg

A dynamic body with a circle fixture (rolls naturally; drawn as a slightly
taller ellipse for the egg silhouette — visual only, physics stays a
circle). Starts resting on the plane per level data. `egg:y()` is used for
the fail check.

### Balloon

Dynamic body, circle fixture, radius starts at `MIN_RADIUS`. States:
- **loose** — not attached; while paused and dragged, position follows the
  mouse (world-space, via `camera:to_world`) directly through
  `body:setPosition`; while overlapping the pump with the mouse held down,
  `radius` grows at a fixed rate up to `MAX_RADIUS`
- **attached** — dragging a loose balloon and releasing it near the plane's
  surface creates a `love.physics.newRopeJoint(balloon_body, plane_body,
  ..., maxLength, false)` at the drop point; `maxLength` is a short leash so
  lift transmits to the plane almost directly, but the plane can still swing
  a little, which is what gives placement (not just count) a physical
  effect on balance. Radius is locked once attached — no re-inflating after
  attaching.
- Re-dragging an already-attached balloon destroys its rope joint (detach)
  and returns it to loose state, so setup can be freely redone while paused.

Every physics step while running, each attached balloon applies an upward
force scaled by its radius (`body:applyForce(0, -LIFT_PER_RADIUS *
balloon.radius, ...)`), approximating buoyancy — bigger balloon, more lift,
per the ask. Loose (unattached) balloons still get gravity/lift like normal
bodies but contribute nothing to the plane since they have no joint to it.

### Pump

Not a physics body — just a static rectangular zone from level data, used
only for the overlap check described above. Drawn as a simple sprite/icon.

### Level data

Plain Lua tables (`game/levels/level_N.lua`), one per level:

```lua
return {
  name = "Level 1",
  gravity = 900,
  plane = { shape = "rectangle", width = 300, height = 20, x = 0, y = 300, angle = 0 },
  egg = { x = 0, y = 270, radius = 14 },
  balloon_count = 4,
  shelf = { x = -500, y = 400 },       -- where unused balloons start, spaced out
  pump = { x = -400, y = 450, w = 80, h = 80 },
  win_line_y = -300,                    -- plane centroid must rise above this
  fail_line_y = 700,                    -- egg falling below this fails the level
}
```

`game/levels/init.lua` exports the ordered list `{level_1, level_2,
level_3}` plus `next(current_level)` used by `LevelScene` on win.

### Level flow (`LevelScene`)

- **Paused (setup)** — camera fixed on the initial view (plane, egg, shelf
  of loose balloons, pump all visible). Player drags/inflates/attaches
  balloons per above. A "Play" button (also spacebar) unpauses.
- **Running** — `world:update(dt)` steps each frame; camera switches to
  `camera:follow(plane_centre, lerp)` so the plane stays in view as it
  rises; a "Pause" button re-pauses without resetting (freezes physics,
  player can inspect but per the fail-state answer there's no further
  mid-run editing needed — pausing mid-run is just a freeze/inspect,
  attaching more balloons only matters before the *first* unpause since a
  level failure is what resets the setup)
  - **Win check** — if `plane:centroid_y() < level.win_line_y`, show a
    "Level Complete" banner with a "Next Level" button that loads
    `Levels.next(current)` (or a "You Win" screen after the last level)
  - **Fail check** — if `egg:y() > level.fail_line_y`, show a brief "Egg
    Broke!" flash then reload the same level from scratch (fresh world,
    fresh bodies, fresh unattached balloons on the shelf) — matches the
    "restart level" answer
- Win/fail lines are drawn as thin colored `Sprite` bars spanning the level
  width at their respective world y, added to the scene's `Drawer` like any
  other object (no new drawing primitive needed).

### `SceneManager` mouse passthrough

```lua
function SceneManager:mousepressed(x, y, button)
    if self.current and self.current.mousepressed then
        self.current:mousepressed(x, y, button)
    end
end
-- mousemoved(x, y), mousereleased(x, y, button) follow the same shape
```

`main.lua` forwards the three `love.mouse*` callbacks to
`manager:mousepressed/mousemoved/mousereleased`. `LevelScene` is the only
scene that implements them for v1.

## What stays the same

- Camera, Drawer, Scene, SceneManager, Sprite, SpriteSet, Fonts, Timer — all
  reused as-is; no changes to their public API beyond the new
  `SceneManager` mouse methods
- Keyboard `Input` class is untouched and still available; this feature
  doesn't remove it, it just doesn't use it (mouse drag is the whole
  interaction model)
- Fixed 1280×720 logical canvas + letterboxing in `main.lua`
- Headless/visual test infrastructure (`lua/headless/*`) is reused
  unchanged — no headless *mouse* shim is needed because tests call
  `level_scene:mousepressed(...)` etc. directly with world coordinates,
  the same way `HeadlessInput` scripts keyboard actions directly rather
  than faking OS-level key events
- CI workflow, web build, save system (none exists yet, none added — no
  persistence requirement was raised for v1)

## Open questions

None — design decisions were resolved with the user up front:
- Egg falling off the plane (or level) fails and restarts the level from
  scratch
- Balloons inflate continuously while held over the pump, up to a max size
- Balloons attach to the plane via a rope/distance joint (springy, not
  welded), so attach *position* — not just balloon count — affects how the
  plane tilts under load
- v1 ships exactly 3 levels (flat plank, pre-tilted plank, curved bowl) to
  prove the mechanic generalizes across plane shapes before building more
  content
