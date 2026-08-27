# Balloon Lift

A small physics puzzle game built with LÖVE 11.5. Each level is an egg
resting on a plane (a rigid platform — a curved bowl, a flat plank, a tilted
plank, or that same bowl flipped into a dome). Attach balloons to the plane
to lift it off the ground without spilling the egg.

## How to play

Each level starts **paused** so you can set up before the physics runs:

- **Drag a balloon** — click and hold a loose balloon (parked on the shelf)
  and drag it with the mouse.
- **Inflate** — while dragging, hold the balloon over the pump; it grows
  continuously up to a maximum size while it stays there.
- **Attach** — drop a balloon near the plane's surface to attach it there
  with a rope joint; bigger balloons pull harder, and where you attach them
  affects how the plane balances as it rises. Dropped elsewhere, it just
  stays loose where you left it.
- **Detach** — click and drag an already-attached balloon to pull it back
  off the plane and reposition it.
- **Play** — click the button in the top-right corner to start the
  simulation. Attached balloons apply lift, the plane rises, and the egg
  rolls with it. There's no pausing once you start — the pump and any
  still-loose balloons disappear, and the run plays out to a win or a
  fail-reset.

The level **fails** (and resets to its starting setup) if the egg falls off
the plane or out of the level. It's **won** when the *egg* rises above the
win line, at which point a "Next Level" button appears.

Press `Escape` to quit.

## Structure

```
lua/core/       Engine classes — no game knowledge (Camera, Drawer, Input, Scene,
                SceneManager, Sprite, SpriteSet, Timer, Fonts)
game/           Game code: Plane, Egg, Balloon, Pump, level data, LevelScene
lua/headless/   Headless test infrastructure (stubs, HeadlessInput, runner)
tests/          Test files — run with: love . --headless
assets/         Images and other assets
conf.lua        Window config; suppresses graphics/audio modules under --headless
main.lua        Entry point — canvas rendering with letterboxing, pixel-art filter
```

## Running

```bash
love .                  # play the game
love . --headless       # run tests and exit
```

## Web build

```bash
npm install
bash scripts/build_web.sh   # outputs to web/
```

`APP_TITLE` env var overrides the browser tab title (default: `"Love Exemplar"`).

## CI / Cloudflare Pages

Two GitHub Actions workflows are included:

- **`ci.yml`** — runs `love . --headless` on every push and PR
- **`web.yml`** — builds the web output and deploys to Cloudflare Pages

To activate the web deploy, see [`docs/setup-cloudflare.md`](docs/setup-cloudflare.md). In short, set these in your GitHub repository settings:

| Type | Name | Value |
|------|------|-------|
| Secret | `CLOUDFLARE_API_TOKEN` | your Cloudflare API token |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | your Cloudflare account ID |
| Variable | `CLOUDFLARE_PROJECT_NAME` | your Cloudflare Pages project name |
| Variable | `APP_TITLE` | browser tab title (optional) |

PR previews are deployed automatically and linked in a PR comment. Production deploys on push to `master`.

## Architecture notes

- **Fixed logical resolution** — game renders to a `1280×720` canvas; `main.lua` scales it to the window with letterboxing. Works with any window size.
- **Scene transitions** — `SceneManager` fades through black (0.3 s) between scene switches.
- **Physics** — one `love.physics` world per level (`game/scenes/level_scene.lua`); pause/run is just whether the world steps, not a body-type change.
- **Headless tests** — `lua/headless/stubs.lua` installs no-op love API replacements so test files run without a window. `HeadlessInput` lets tests script action presses frame-by-frame; mouse-driven tests (e.g. `tests/test_level_scene.lua`) instead call `mousepressed`/`mousemoved`/`mousereleased` directly with world coordinates. See `tests/test_basics.lua` for a minimal example.
