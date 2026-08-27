## Balloon Lift Checklist

Design doc: `docs/design/balloon-lift.md` — read it in full before starting
any task below; it has the exact API shapes, level data format, and
gameplay rules referenced here.

Repo conventions to follow (look at `lua/core/camera.lua` and
`game/player.lua` for the pattern): classes are plain Lua tables with
`Class.__index = Class`, a `Class.new(...)` constructor using
`setmetatable`, methods defined as `function Class:method(...)`, modules
`return Class` at the end. Run tests with `love . --headless
tests/test_X.lua` (single file) or `love . --headless` (whole suite) from
the repo root at `/root/balloon-game`.

### Round 1 — independent, can run in parallel

- [x] Task 1 — `game/plane.lua`, `tests/test_plane.lua` — Plane class: builds
  a `love.physics` dynamic body from level data (`shape = "rectangle"`:
  one `PolygonShape` fixture; `shape = "arc"`: N convex segment fixtures
  approximating a curved bowl, all on the same body). Methods:
  `Plane.new(world, spec)`, `plane:world_anchor(local_x, local_y)` (via
  `body:getWorldPoint`), `plane:centroid_y()`, `plane:draw()` (fill each
  fixture's polygon via `love.graphics.polygon`). Test constructs both
  shapes in a headless `love.physics.newWorld`, asserts fixtures exist and
  `centroid_y()` reflects `spec.y`, and that stepping the world under
  gravity moves it (nothing is holding it up yet).

- [x] Task 2 — `game/egg.lua`, `tests/test_egg.lua` — Egg class: dynamic
  body with a single circle fixture. `Egg.new(world, spec)` (`spec = {x,
  y, radius}`), `egg:y()`, `egg:draw()` (ellipse, slightly taller than
  wide, for the egg silhouette — physics shape stays a circle). Test
  asserts initial `egg:y() == spec.y` and that it falls under gravity when
  the world is stepped with nothing beneath it.

- [x] Task 3 — `game/balloon.lua`, `tests/test_balloon.lua` — Balloon
  class: dynamic body, circle fixture, starts at `MIN_RADIUS`. States
  `loose`/`attached`. `Balloon.new(world, x, y)`. `balloon:drag_to(x, y)`
  — `body:setPosition`, only meaningful while loose. `balloon:inflate(dt)`
  — grows `radius` at a fixed rate up to `MAX_RADIUS`, recreating the
  circle fixture at the new radius (no-op once attached). `balloon:attach(plane,
  local_x, local_y)` — creates a `love.physics.newRopeJoint(balloon.body,
  plane.body, bx, by, wx, wy, LEASH_LENGTH, false)` where `wx,wy =
  plane:world_anchor(local_x, local_y)`; sets state to `"attached"`.
  `balloon:detach()` — destroys the joint (`joint:destroy()`), sets state
  back to `"loose"`. `balloon:apply_lift()` — while attached, `body:applyForce(0,
  -LIFT_PER_RADIUS * self.radius, ...)` at the body's center; call once per
  physics step from the owning scene, not internally on a timer.
  `balloon:draw()` — filled circle, plus a thin line from balloon to its
  plane anchor when attached. Test: inflate grows radius and stops at
  `MAX_RADIUS`; attach/detach create and destroy a joint (assert
  `balloon.joint ~= nil` / `== nil`); a lone attached balloon with
  `apply_lift()` called each step pulls itself upward over several
  simulated steps (assert its y decreases).

- [x] Task 4 — `game/pump.lua`, `tests/test_pump.lua` — Pump class: no
  physics body, just a static AABB from level data (`spec = {x, y, w,
  h}`). `Pump.new(spec)`, `pump:overlaps(x, y)` (point-in-rect, for
  checking a balloon's center against the zone — the scene decides what
  counts as "held over the pump"), `pump:draw()` (simple rectangle/icon).
  Test: points inside/outside/on-edge of the zone.

- [x] Task 5 — `game/levels/level_1.lua`, `game/levels/level_2.lua`,
  `game/levels/level_3.lua`, `game/levels/init.lua` — level data tables
  exactly matching the shape in the design doc's "Level data" section.
  Level 1: `plane.shape = "rectangle"`, `angle = 0` (flat). Level 2: same
  rectangle shape, nonzero starting `plane.angle` (pre-tilted), egg placed
  nearer the low end per `plane.angle`. Level 3: `plane.shape = "arc"`
  with enough segments to look bowl-shaped (concave, egg settles in the
  middle). All three set `balloon_count`, `shelf`, `pump`, `win_line_y`
  (above/less-than the plane's starting y), `fail_line_y` (below/greater-than
  the egg's starting y). `game/levels/init.lua` returns `{ list = {level_1,
  level_2, level_3}, next = function(level) ... end }` — `next` returns the
  following level in `list`, or `nil` past the last one. No test file
  needed — these are plain data plus one trivial function; note in this
  task's completion that `init.next` was manually sanity-checked (called
  in a scratch `love . --headless` snippet) since there's no dedicated
  test file for it.

- [x] Task 6 — `lua/core/scene_manager.lua`, `tests/test_scene_manager.lua`
  — add passthrough methods mirroring the existing `update`/`draw`
  delegation pattern already in this file:
  ```lua
  function SceneManager:mousepressed(x, y, button)
      if self.current and self.current.mousepressed then
          self.current:mousepressed(x, y, button)
      end
  end
  ```
  Same shape for `mousemoved(x, y)` and `mousereleased(x, y, button)`. All
  three must no-op safely when `self.current` is nil or doesn't implement
  the method (don't error). New test file constructs a `SceneManager`,
  switches in a fake scene table that records calls, invokes all three
  methods, and asserts the fake scene received them with the right args;
  also asserts calling them with no current scene doesn't error.

### Round 2 — after all of Round 1 is done

- [x] Task 7 — `game/scenes/level_scene.lua`, `tests/test_level_scene.lua`
  — the main gameplay scene, per the design doc's "Level flow" section in
  full. Owns one `love.physics.newWorld(0, level.gravity, true)`; builds
  `Plane`, `Egg`, `balloon_count` loose `Balloon`s parked spaced out at
  `shelf`, and a `Pump` from the level spec; `self.running = false`
  initially (paused). `LevelScene.new(level)`.
  - `mousepressed(x, y, button)` / `mousemoved(x, y)` / `mousereleased(x,
    y, button)` — screen coords converted to world via
    `self.camera:to_world`; while paused, picks up the loose balloon under
    the pointer (nearest hit within its radius) on press, calls
    `balloon:drag_to` on move, and on release either attaches it (if
    within a small snap distance of the plane's surface) or leaves it
    loose at the drop point; while a balloon is being dragged and
    overlaps the pump with the mouse still down, calls
    `balloon:inflate(dt)` each `update`. Also handles clicks on the
    Play/Pause button (screen-space rect, not world coords).
  - `update(dt)` — if `self.running`, step `world:update(dt)`, call
    `apply_lift()` on every attached balloon first, then check fail
    (`egg:y() > level.fail_line_y` → reload this level fresh: rebuild the
    whole scene state from `self.level`, same as `on_enter` would) and win
    (`plane:centroid_y() < level.win_line_y` → show complete banner, stop
    stepping); if paused, only the drag/inflate logic above runs (no
    `world:update`); while running, `camera:follow(plane's centre, lerp)`.
  - `draw()` — `Scene.draw(self)` for the world-space layer (plane, egg,
    balloons, pump, and two thin `Sprite` bars for the win/fail lines, all
    registered on `self.drawer` at construction), then screen-space HUD:
    level name, Play/Pause button, win/fail banners.
  - Win/fail lines: build them as `Sprite.new(x, level.win_line_y, wide,
    4)` / similar for fail, colored distinctly, added to the drawer —
    reuse the existing `Sprite` class, no new drawing primitive.
  - Test file: construct a `LevelScene` with a small synthetic level table
    (not necessarily one of the real levels — cheaper to reach win/fail
    fast), drive it entirely through `mousepressed/mousemoved/mousereleased`
    plus `update(dt)` calls (this is the "script the input directly"
    pattern used by `HeadlessInput`, no headless mouse shim needed).
    Cover: dragging a balloon onto the pump grows its radius;
    dragging-and-releasing onto the plane attaches it (joint exists);
    clicking Play starts stepping the world; a level rigged with enough
    lift reaches win (`self.won` or equivalent becomes true) within a
    bounded number of ticks; a level with an egg given a shove reaches the
    fail line and the scene resets (loose balloon count and egg position
    back to the level's starting spec).

### Round 3 — after Round 2 is done

- [x] Task 8 — `main.lua`, plus removals — boot the real game and retire the
  placeholder demo.
  - In `main.lua`: `require("game/scenes/level_scene")` and
    `require("game/levels/init")` instead of `game/scenes/game_scene`;
    `manager:switch(LevelScene.new(Levels.list[1]))` in `love.load()`.
    Forward `love.mousepressed(x, y, button)`, `love.mousemoved(x, y)`,
    `love.mousereleased(x, y, button)` to `manager:mousepressed(...)` /
    `manager:mousemoved(...)` / `manager:mousereleased(...)` (add these
    three top-level functions; they didn't exist before).
  - Delete `game/player.lua`, `game/scenes/game_scene.lua`,
    `assets/player.png` — fully superseded, nothing else references them
    after this task.
  - Rewrite `tests/test_basics.lua`: same "a fresh scene can be ticked
    without error" shape as today, but construct
    `require("game/scenes/level_scene").new(require("game/levels/init").list[1])`
    instead of `GameScene.new()`.
  - Rewrite `tests/test_scene.lua` Test 3 ("GameScene inherits
    drawer/camera from Scene"): same assertions, against a `LevelScene`
    instance instead of `GameScene`. Keep Tests 1 and 2 (`Scene.new`
    itself) unchanged.
  - After this task, `love . --headless` (full suite) must pass and `grep
    -rn "game_scene\|player\.lua\|GameScene" --include=*.lua .` (from repo
    root, excluding this checklist/design doc) must return nothing.
