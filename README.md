# daccord Activity Development Guide

This guide covers everything you need to build multiplayer activities for the daccord platform. Activities are written in Lua and run inside a sandboxed runtime — no compilation, no engine knowledge required.

## Quick start

### 1. Set up the project

Create a directory for your activity:

```
my-activity/
├── plugin.json       # Activity metadata
├── src/
│   └── main.lua      # Entry point
├── assets/           # Images, sounds (optional)
└── build.sh          # Build script
```

### 2. Write plugin.json

```json
{
  "id": "my-activity",
  "name": "My Activity",
  "type": "activity",
  "format": "lua",
  "entry": "src/main.lua",
  "description": "A short description of your activity.",
  "version": "1.0.0",
  "canvas_size": [640, 480],
  "max_participants": 8,
  "max_spectators": -1,
  "lobby": true,
  "permissions": []
}
```

| Field | Description |
|---|---|
| `id` | Unique identifier (lowercase, no spaces) |
| `name` | Display name shown to users |
| `type` | Always `"activity"` |
| `format` | Always `"lua"` |
| `entry` | Path to your main Lua file inside the bundle |
| `canvas_size` | `[width, height]` in pixels. Min 64, max 1920x1080 |
| `max_participants` | Maximum number of active players |
| `max_spectators` | Maximum spectators (`-1` for unlimited) |
| `lobby` | Whether to show a lobby/waiting room before the activity starts |
| `permissions` | Array of requested permissions (e.g. `"voice_activity"`) |

### 3. Write your activity

```lua
function _ready()
    -- Called once when the activity loads.
    -- Initialize state, load assets, seed RNG, etc.
end

function _draw()
    -- Called every frame. Use api.draw_* to render.
    api.draw_rect(0, 0, api.canvas_width, api.canvas_height, "#1a1a2e", true)
    api.draw_text(50, 50, "Hello, daccord!", "white", 24)
end

function _input(event)
    -- Called on mouse or keyboard input.
    if event["type"] == "mouse_button" and event["pressed"] then
        local x = event["position_x"]
        local y = event["position_y"]
        -- handle click at (x, y)
    end
end

function _on_event(event_type, data)
    -- Called when the server broadcasts an action to all participants.
    if event_type == "action" then
        -- Apply the action to local state
    end
end
```

### 4. Test locally

```bash
# Run directly from source (recommended during development)
godot --plugin ./my-activity/src/main.lua

# Or open the editor UI and use the file browser
godot
```

The editor simulates multiple virtual users and loops actions back locally — no server required.

### 5. Build and distribute

```bash
cd my-activity && ./build.sh    # → export/my-activity.daccord-plugin
```

The `.daccord-plugin` file is a ZIP bundle ready for upload. See [Build scripts](#build-scripts) for details.

---

## Lifecycle functions

Your activity communicates with the daccord runtime through four global functions. All are optional — only define the ones you need.

### `_ready()`

Called once after the Lua source is loaded. Use this to:
- Initialize game state
- Seed the random number generator
- Load images and sounds from assets

```lua
function _ready()
    math.randomseed(os.clock() * 1000)
    bg_image = api.load_image(api.read_asset("assets/background.png"))
end
```

### `_draw()`

Called every frame (~60fps). This is where you render your activity using the `api.draw_*` functions. The canvas is cleared to black automatically before each frame.

**Important**: `_draw()` must be fast. Avoid heavy computation here — do your logic in `_on_event` or `_input` and store results in state variables that `_draw` reads.

```lua
function _draw()
    api.draw_rect(0, 0, api.canvas_width, api.canvas_height, "#1a1a2e", true)
    api.draw_text(100, 200, "Score: " .. score, "white", 20)
end
```

### `_input(event)`

Called when the user interacts with the canvas. The `event` parameter is a table with a `"type"` field.

**Mouse button event:**
```lua
{
    type = "mouse_button",
    button_index = 1,       -- 1 = left, 2 = right, 3 = middle
    pressed = true,         -- true on press, false on release
    position_x = 320.0,
    position_y = 240.0,
}
```

**Mouse motion event:**
```lua
{
    type = "mouse_motion",
    position_x = 320.0,
    position_y = 240.0,
    relative_x = 2.0,      -- movement delta since last frame
    relative_y = -1.0,
}
```

**Key event:**
```lua
{
    type = "key",
    keycode = 65,           -- Godot keycode
    physical_keycode = 65,
    unicode = 65,           -- Unicode codepoint (use for text input)
    pressed = true,
    echo = false,           -- true if this is a key-repeat event
}
```

**Accessing event fields**: Always use bracket notation (`event["type"]`), not dot notation (`event.type`). Data passed from the host runtime uses dictionary-style tables.

### `_on_event(event_type, data)`

Called when the server broadcasts an action to all participants. In multiplayer, every client receives every action, so apply them deterministically to keep state in sync.

```lua
function _on_event(event_type, data)
    if event_type == "action" then
        local action = data["action"]
        if action == "move" then
            board[data["x"]][data["y"]] = data["player"]
        end
    end
end
```

---

## API Reference

All API functions are accessed through the global `api` table.

### Drawing

Drawing functions should only be called inside `_draw()`. There is a limit of **4,096 draw commands per frame**.

#### `api.draw_rect(x, y, width, height, color, filled)`

Draw a rectangle.

| Parameter | Type | Description |
|---|---|---|
| `x`, `y` | number | Top-left corner position |
| `width`, `height` | number | Dimensions |
| `color` | color | Fill/stroke color (see [Colors](#colors)) |
| `filled` | boolean | `true` for filled, `false` for outline only |

#### `api.draw_circle(x, y, radius, color)`

Draw a filled circle.

#### `api.draw_line(x1, y1, x2, y2, color, width)`

Draw a line between two points.

| Parameter | Type | Description |
|---|---|---|
| `x1`, `y1` | number | Start point |
| `x2`, `y2` | number | End point |
| `color` | color | Line color |
| `width` | number | Line width in pixels |

#### `api.draw_text(x, y, text, color, font_size)`

Draw a text string. Text is left-aligned, and `y` is the baseline position. Font size is clamped between 4 and 128.

#### `api.draw_pixel(x, y, color)`

Draw a single pixel. For bulk pixel work, use [pixel buffers](#pixel-buffers) instead.

### Images

Activities can load and draw PNG, JPEG, and WebP images. There is a limit of **64 loaded images**.

#### `api.load_image(data) → handle`

Load an image from raw byte data (typically from `api.read_asset`). Returns an integer handle, or `-1` on failure.

```lua
local img = api.load_image(api.read_asset("assets/sprite.png"))
```

#### `api.draw_image(handle, x, y)`

Draw a loaded image at its original size.

#### `api.draw_image_scaled(handle, x, y, width, height)`

Draw a loaded image stretched to fit the given dimensions.

#### `api.draw_image_region(handle, x, y, sx, sy, sw, sh)`

Draw a rectangular sub-region of an image. Useful for sprite sheets.

| Parameter | Type | Description |
|---|---|---|
| `handle` | int | Image handle from `load_image` |
| `x`, `y` | number | Destination position on canvas |
| `sx`, `sy` | number | Top-left corner of source region |
| `sw`, `sh` | number | Size of source region |

### Pixel buffers

For per-pixel rendering (e.g. particle effects, procedural art), pixel buffers are much faster than calling `draw_pixel` thousands of times. There is a limit of **4 buffers**.

#### `api.create_buffer(width, height) → handle`

Create an RGBA pixel buffer. Returns a handle, or `-1` on failure. Buffer dimensions are clamped to the canvas size.

#### `api.set_buffer_pixel(handle, x, y, color)`

Set a single pixel in a buffer.

#### `api.set_buffer_data(handle, data)`

Replace the entire buffer contents with raw RGBA8 byte data (row-major, 4 bytes per pixel).

#### `api.draw_buffer(handle, x, y)`

Draw a buffer at its original size.

#### `api.draw_buffer_scaled(handle, x, y, width, height)`

Draw a buffer stretched to fit the given dimensions.

### Colors

Colors can be specified in three formats:

| Format | Example | Notes |
|---|---|---|
| Hex string | `"#c62828"`, `"#ff000080"` | Standard CSS hex (RGB or RGBA) |
| Named string | `"white"`, `"red"`, `"black"` | Supported: `white`, `black`, `red`, `green`, `blue`, `yellow`, `transparent` |
| RGBA array | `{0.78, 0.16, 0.16, 0.35}` | Float values 0.0–1.0. Alpha defaults to 1.0 if omitted |

### Multiplayer / state

#### `api.send_action(data)`

Send an action to the server. The server broadcasts it to all participants (including the sender) via `_on_event("action", data)`.

The `data` parameter must be a Godot Dictionary. Use the `Dictionary{}` constructor to build one from a Lua table:

```lua
api.send_action(Dictionary{
    action = "place_piece",
    x = 3,
    y = 5,
    player = api.get_user_id(),
})
```

#### `api.get_user_id() → string`

Returns the current user's unique ID.

#### `api.get_role() → string`

Returns the current user's role (e.g. `"player"`, `"spectator"`).

#### `api.get_participants() → array`

Returns an array of all participants. Each entry is a dictionary with `user_id`, `display_name`, and `role` fields.

**Important**: This returns a Godot Array, which is **0-indexed** in Lua:

```lua
local participants = api.get_participants()
local first = participants[0]  -- NOT participants[1]
local user_id = first["user_id"]
```

#### `api.get_participant_count() → int`

Returns the number of participants.

#### `api.get_participant(index) → dictionary`

Returns a single participant by 0-based index. Returns an empty dictionary if out of bounds.

#### `api.get_state() → dictionary`

Returns the activity manifest (the contents of `plugin.json`).

### Assets

#### `api.read_asset(path) → bytes`

Read a file from the activity's `assets/` directory. Returns raw byte data (a `PackedByteArray`).

```lua
local png_data = api.read_asset("assets/board.png")
local img = api.load_image(png_data)
```

The path must start with `assets/` and matches the directory structure in your activity folder.

### Audio

Activities can load and play OGG Vorbis audio. There is a limit of **16 loaded sounds**.

#### `api.load_sound(data) → handle`

Load a sound from raw OGG Vorbis byte data. Returns a handle, or `-1` on failure.

```lua
local click_sfx = api.load_sound(api.read_asset("assets/click.ogg"))
```

#### `api.play_sound(handle)`

Play a loaded sound.

#### `api.stop_sound(handle)`

Stop a playing sound.

### Timers

#### `api.set_interval(callback_name, ms) → timer_id`

Call a global function repeatedly at the given interval (in milliseconds). Minimum interval is 16ms.

```lua
function tick()
    elapsed = elapsed + 1
end

local timer = api.set_interval("tick", 1000)  -- call tick() every second
```

**Important**: The callback is specified by **name** (a string), not by reference. The function must be a global.

#### `api.set_timeout(callback_name, ms) → timer_id`

Call a global function once after a delay. The timer is automatically cleaned up after firing.

#### `api.clear_timer(timer_id)`

Cancel a timer created by `set_interval` or `set_timeout`.

### Constants

| Constant | Description |
|---|---|
| `api.canvas_width` | Canvas width in pixels (from `plugin.json` `canvas_size`) |
| `api.canvas_height` | Canvas height in pixels |

### Utilities

#### `print(...)`

Prints to the Godot console (overridden to work within the sandbox). Useful for debugging.

#### `Dictionary(table) → dictionary`

Convert a Lua table to a Godot Dictionary. Required when passing structured data to `api.send_action()`.

```lua
local d = Dictionary{ action = "move", x = 10 }
```

#### `Array(table) → array`

Convert a Lua table (sequential, 1-indexed) to a Godot Array.

```lua
local a = Array{ "red", "blue", "green" }
```

#### `require(module_name)`

Load a Lua module from the activity's `src/` directory. Modules are resolved by filename without extension (e.g. `require("utils")` loads `src/utils.lua`). Modules are cached after first load.

---

## Data passing between Lua and the host

There are a few important quirks when working with data that crosses the Lua/host boundary:

1. **Dictionaries use bracket notation**: When you receive data from the runtime (event data, participant info, etc.), access fields with `data["key"]`, not `data.key`.

2. **Godot Arrays are 0-indexed**: Unlike native Lua tables (which start at 1), arrays returned by `api.get_participants()` and similar functions start at index 0.

3. **Sending structured data**: Use `Dictionary{...}` and `Array{...}` constructors when building data to pass back to the runtime (e.g. in `api.send_action`).

---

## Multiplayer sync model

Activities run **locally on every client**. When a player takes an action, the flow is:

```
Player input → api.send_action(data) → Server broadcasts → _on_event("action", data)
                                                            (on ALL clients, including sender)
```

Every client receives every action and applies it to their local state. This means:

- **All state changes must go through actions.** Don't mutate shared state directly in `_input` — send an action and handle it in `_on_event`.
- **Actions must be deterministic.** Given the same sequence of actions, every client must arrive at the same state. Avoid using `math.random()` in `_on_event` — if you need randomness, generate it on one client (typically the host) and include the result in the action data.
- **One client is the host.** The first participant in the list is the host. Use this for tasks that should only happen once (like generating a board):

```lua
function is_host()
    local first = api.get_participant(0)
    return first["user_id"] == api.get_user_id()
end
```

---

## Structuring larger activities

For anything beyond a trivial demo, split your code into modules:

```
src/
├── main.lua        # Entry point — lifecycle functions only
├── state.lua       # Game state variables and helpers
├── constants.lua   # Colors, layout values, static data
├── drawing.lua     # All rendering logic
├── input.lua       # Input handling
└── events.lua      # Action/event processing
```

**main.lua** stays minimal:

```lua
local state = require("state")
local drawing = require("drawing")
local input = require("input")
local events = require("events")

function _ready()
    -- initialization
end

function _draw()
    drawing.render()
end

function _input(event)
    input.handle(event)
end

function _on_event(event_type, data)
    events.dispatch(event_type, data)
end
```

**Modules** return a table:

```lua
-- state.lua
local M = {}
M.score = 0
M.phase = "lobby"
return M
```

---

## Sandboxing

Activities run in a restricted Lua environment. Only these standard libraries are available:

- `base` (print, type, tostring, pairs, ipairs, pcall, etc.)
- `coroutine`
- `string`
- `math`
- `table`

The following are **not available**: `io`, `os`, `package`, `debug`, `ffi`. There is no filesystem access, no network access, and no way to break out of the sandbox.

---

## Resource limits

| Resource | Limit |
|---|---|
| Draw commands per frame | 4,096 |
| Loaded images | 64 |
| Pixel buffers | 4 |
| Loaded sounds | 16 |
| Canvas size | 64×64 to 1920×1080 |
| Font size | 4–128 |
| Timer minimum interval | 16ms |

---

## Build scripts

A build script packages your activity into a `.daccord-plugin` file (a ZIP archive). Here's a template:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

EXPORT_DIR="export"
BUNDLE_NAME="my-activity.daccord-plugin"

echo "==> Packaging ${BUNDLE_NAME}..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp plugin.json "$TMPDIR/"
mkdir -p "$TMPDIR/src"
cp src/*.lua "$TMPDIR/src/"

if [[ -d assets ]]; then
    cp -r assets "$TMPDIR/"
fi

mkdir -p "${EXPORT_DIR}"
cd "$TMPDIR"
zip -r "/tmp/${BUNDLE_NAME}" plugin.json src/ assets/ 2>/dev/null || \
    zip -r "/tmp/${BUNDLE_NAME}" plugin.json src/
cd - > /dev/null

mv "/tmp/${BUNDLE_NAME}" "${EXPORT_DIR}/${BUNDLE_NAME}"
echo "==> Built: ${EXPORT_DIR}/${BUNDLE_NAME}"
```

The resulting `.daccord-plugin` contains:
- `plugin.json` — metadata
- `src/*.lua` — all Lua source files
- `assets/` — images, sounds, and other static files

---

## Tips

- **Start simple.** Get a rectangle drawing on screen, then add input, then multiplayer.
- **Use the editor's user simulation.** Add virtual users and switch between them to test multiplayer flows without deploying.
- **Keep `_draw()` lean.** Do logic in `_input` and `_on_event`, store results in state, and let `_draw` just read state and render.
- **Debug with `print()`.** Output appears in the Godot console.
- **Reload often.** Hit the Reload button in the editor (or re-run with `--plugin`) to pick up changes instantly — no restart needed.
- **Use `pcall` for robustness.** Wrap asset loading or anything that might fail in `pcall` to avoid crashing the whole activity:
  ```lua
  local ok, img = pcall(function()
      return api.load_image(api.read_asset("assets/sprite.png"))
  end)
  if ok and img >= 0 then
      sprite = img
  end
  ```
