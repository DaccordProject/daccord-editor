# daccord Editor

A Godot 4.5 development harness for creating and testing Lua-based multiplayer activity plugins for the [daccord](https://github.com/daccordproject) platform. Load plugin source, render it in a sandboxed viewport, simulate multiple virtual users, and loop actions back so multiplayer logic can be tested locally — no server required.

## Table of contents

- [Getting started](#getting-started)
- [Editor usage](#editor-usage)
- [Plugin development guide](#plugin-development-guide)
  - [Project structure](#project-structure)
  - [plugin.json manifest](#pluginjson-manifest)
  - [Lifecycle functions](#lifecycle-functions)
  - [API reference](#api-reference)
  - [Data passing between Lua and the host](#data-passing-between-lua-and-the-host)
  - [Multiplayer sync model](#multiplayer-sync-model)
  - [Structuring larger activities](#structuring-larger-activities)
  - [Sandboxing](#sandboxing)
  - [Resource limits](#resource-limits)
  - [Build scripts](#build-scripts)
- [Deploying to a server](#deploying-to-a-server)
  - [Installing a plugin](#installing-a-plugin)
  - [Managing plugins](#managing-plugins)
  - [Activity sessions](#activity-sessions)
  - [Gateway events](#gateway-events)
- [Editor architecture](#editor-architecture)
- [Example plugins](#example-plugins)
- [Tips](#tips)

---

## Getting started

### Prerequisites

- [Godot 4.5](https://godotengine.org/) or later
- The [lua-gdextension](https://github.com/WeaselGames/lua) addon (included in `addons/`)

### Running the editor

```bash
# Open the editor with a plugin loaded directly
godot --plugin ./games/codenames/src/main.lua

# Or launch the editor UI and use the file picker
godot
```

The main scene is `scenes/editor.tscn`.

### Quick example

Create a minimal plugin to verify everything works:

```
hello/
├── plugin.json
└── src/
    └── main.lua
```

**plugin.json:**
```json
{
  "id": "hello",
  "name": "Hello World",
  "type": "activity",
  "format": "lua",
  "entry": "src/main.lua",
  "canvas_size": [640, 480],
  "max_participants": 1,
  "lobby": false
}
```

**src/main.lua:**
```lua
function _draw()
    api.draw_rect(0, 0, api.canvas_width, api.canvas_height, "#1a1a2e", true)
    api.draw_text(50, 50, "Hello, daccord!", "white", 24)
end
```

```bash
godot --plugin ./hello/src/main.lua
```

---

## Editor usage

The editor provides a local testing environment that simulates the daccord server.

- **Load plugins** from Lua source files or `.daccord-plugin` bundles via the file picker or `--plugin` flag
- **Reload** instantly with the Reload button — no restart needed
- **Simulate multiple users** by adding virtual participants and switching between them
- **Action loopback** — actions sent via `api.send_action()` are echoed back as `_on_event("action", data)` events, simulating server broadcast

---

## Plugin development guide

### Project structure

```
my-activity/
├── plugin.json       # Activity metadata (required)
├── src/
│   └── main.lua      # Entry point (required)
├── assets/           # Images, sounds (optional)
└── build.sh          # Build script (optional)
```

### plugin.json manifest

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

| Field | Required | Description |
|---|---|---|
| `id` | Yes | Unique identifier (lowercase, no spaces) |
| `name` | Yes | Display name shown to users |
| `type` | Yes | Plugin type: `activity`, `bot`, `theme`, or `command` |
| `format` | Yes | Always `"lua"` for scripted plugins |
| `entry` | Yes | Path to the main Lua file inside the bundle |
| `description` | No | Short description |
| `version` | No | Semver version string |
| `canvas_size` | No | `[width, height]` in pixels (min 64x64, max 1920x1080) |
| `max_participants` | No | Maximum active players (0 = unlimited) |
| `max_spectators` | No | Maximum spectators (-1 = unlimited) |
| `lobby` | No | Whether sessions start in a lobby before running |
| `permissions` | No | Permissions the plugin requests (e.g. `"voice_activity"`) |
| `data_topics` | No | Data topics the plugin subscribes to |

### Lifecycle functions

Your activity communicates with the daccord runtime through four global functions. All are optional — only define the ones you need.

#### `_ready()`

Called once after the Lua source is loaded. Use this to initialize state, seed the RNG, and load assets.

```lua
function _ready()
    math.randomseed(os.clock() * 1000)
    bg_image = api.load_image(api.read_asset("assets/background.png"))
end
```

#### `_draw()`

Called every frame (~60fps). Render your activity using `api.draw_*` functions. The canvas is cleared automatically before each frame.

**Keep `_draw()` fast.** Do logic in `_input` and `_on_event`, store results in state variables, and let `_draw` just read and render.

```lua
function _draw()
    api.draw_rect(0, 0, api.canvas_width, api.canvas_height, "#1a1a2e", true)
    api.draw_text(100, 200, "Score: " .. score, "white", 20)
end
```

#### `_input(event)`

Called on mouse or keyboard input. The `event` parameter is a table with a `"type"` field.

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

**Important**: Always use bracket notation (`event["type"]`), not dot notation (`event.type`). Data from the host runtime uses dictionary-style tables.

#### `_on_event(event_type, data)`

Called when the server broadcasts an action to all participants. Every client receives every action — apply them deterministically to keep state in sync.

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

### API reference

All API functions are accessed through the global `api` table.

#### Drawing

Drawing functions should only be called inside `_draw()`. There is a limit of **4,096 draw commands per frame**.

##### `api.draw_rect(x, y, width, height, color, filled)`

Draw a rectangle.

| Parameter | Type | Description |
|---|---|---|
| `x`, `y` | number | Top-left corner position |
| `width`, `height` | number | Dimensions |
| `color` | color | Fill/stroke color (see [Colors](#colors)) |
| `filled` | boolean | `true` for filled, `false` for outline only |

##### `api.draw_circle(x, y, radius, color)`

Draw a filled circle.

##### `api.draw_line(x1, y1, x2, y2, color, width)`

Draw a line between two points.

| Parameter | Type | Description |
|---|---|---|
| `x1`, `y1` | number | Start point |
| `x2`, `y2` | number | End point |
| `color` | color | Line color |
| `width` | number | Line width in pixels |

##### `api.draw_text(x, y, text, color, font_size)`

Draw a text string. Text is left-aligned, and `y` is the baseline position. Font size is clamped between 4 and 128.

##### `api.draw_pixel(x, y, color)`

Draw a single pixel. For bulk pixel work, use [pixel buffers](#pixel-buffers) instead.

#### Images

Load and draw PNG, JPEG, and WebP images. Limit: **64 loaded images**.

##### `api.load_image(data) → handle`

Load an image from raw byte data (typically from `api.read_asset`). Returns an integer handle, or `-1` on failure.

```lua
local img = api.load_image(api.read_asset("assets/sprite.png"))
```

##### `api.draw_image(handle, x, y)`

Draw a loaded image at its original size.

##### `api.draw_image_scaled(handle, x, y, width, height)`

Draw a loaded image stretched to fit the given dimensions.

##### `api.draw_image_region(handle, x, y, sx, sy, sw, sh)`

Draw a rectangular sub-region of an image (useful for sprite sheets).

| Parameter | Type | Description |
|---|---|---|
| `handle` | int | Image handle from `load_image` |
| `x`, `y` | number | Destination position on canvas |
| `sx`, `sy` | number | Top-left corner of source region |
| `sw`, `sh` | number | Size of source region |

#### Pixel buffers

For per-pixel rendering (particle effects, procedural art, etc.), pixel buffers are much faster than calling `draw_pixel` thousands of times. Limit: **4 buffers**.

##### `api.create_buffer(width, height) → handle`

Create an RGBA pixel buffer. Returns a handle, or `-1` on failure.

##### `api.set_buffer_pixel(handle, x, y, color)`

Set a single pixel in a buffer.

##### `api.set_buffer_data(handle, data)`

Replace the entire buffer contents with raw RGBA8 byte data (row-major, 4 bytes per pixel).

##### `api.draw_buffer(handle, x, y)`

Draw a buffer at its original size.

##### `api.draw_buffer_scaled(handle, x, y, width, height)`

Draw a buffer stretched to fit the given dimensions.

#### Colors

Colors can be specified in three formats:

| Format | Example | Notes |
|---|---|---|
| Hex string | `"#c62828"`, `"#ff000080"` | Standard CSS hex (RGB or RGBA) |
| Named string | `"white"`, `"red"`, `"black"` | Supported: `white`, `black`, `red`, `green`, `blue`, `yellow`, `transparent` |
| RGBA array | `{0.78, 0.16, 0.16, 0.35}` | Float values 0.0-1.0. Alpha defaults to 1.0 if omitted |

#### Multiplayer / state

##### `api.send_action(data)`

Send an action to the server. The server broadcasts it to all participants (including the sender) via `_on_event("action", data)`.

The `data` parameter must be a Godot Dictionary. Use the `Dictionary{}` constructor:

```lua
api.send_action(Dictionary{
    action = "place_piece",
    x = 3,
    y = 5,
    player = api.get_user_id(),
})
```

##### `api.get_user_id() → string`

Returns the current user's unique ID.

##### `api.get_role() → string`

Returns the current user's role (e.g. `"player"`, `"spectator"`).

##### `api.get_participants() → array`

Returns a 0-indexed Godot Array of all participants. Each entry is a dictionary with `user_id`, `display_name`, and `role` fields.

```lua
local participants = api.get_participants()
local first = participants[0]  -- NOT participants[1]
local user_id = first["user_id"]
```

##### `api.get_participant_count() → int`

Returns the number of participants.

##### `api.get_participant(index) → dictionary`

Returns a single participant by 0-based index. Returns an empty dictionary if out of bounds.

##### `api.get_state() → dictionary`

Returns the activity manifest (the contents of `plugin.json`).

#### Assets

##### `api.read_asset(path) → bytes`

Read a file from the activity's `assets/` directory. Returns raw byte data.

```lua
local png_data = api.read_asset("assets/board.png")
local img = api.load_image(png_data)
```

#### Audio

Load and play OGG Vorbis audio. Limit: **16 loaded sounds**.

##### `api.load_sound(data) → handle`

Load a sound from raw OGG Vorbis byte data. Returns a handle, or `-1` on failure.

```lua
local click_sfx = api.load_sound(api.read_asset("assets/click.ogg"))
```

##### `api.play_sound(handle)`

Play a loaded sound.

##### `api.stop_sound(handle)`

Stop a playing sound.

#### Timers

##### `api.set_interval(callback_name, ms) → timer_id`

Call a global function repeatedly at the given interval (minimum 16ms).

```lua
function tick()
    elapsed = elapsed + 1
end

local timer = api.set_interval("tick", 1000)  -- call tick() every second
```

**Important**: The callback is specified by **name** (a string), not by reference. The function must be a global.

##### `api.set_timeout(callback_name, ms) → timer_id`

Call a global function once after a delay. Automatically cleaned up after firing.

##### `api.clear_timer(timer_id)`

Cancel a timer created by `set_interval` or `set_timeout`.

#### Constants

| Constant | Description |
|---|---|
| `api.canvas_width` | Canvas width in pixels (from `plugin.json` `canvas_size`) |
| `api.canvas_height` | Canvas height in pixels |

#### Utilities

##### `print(...)`

Prints to the Godot console. Useful for debugging.

##### `Dictionary(table) → dictionary`

Convert a Lua table to a Godot Dictionary. Required when passing structured data to `api.send_action()`.

```lua
local d = Dictionary{ action = "move", x = 10 }
```

##### `Array(table) → array`

Convert a Lua table (sequential, 1-indexed) to a Godot Array.

```lua
local a = Array{ "red", "blue", "green" }
```

##### `require(module_name)`

Load a Lua module from the activity's `src/` directory. Modules are resolved by filename without extension (e.g. `require("utils")` loads `src/utils.lua`). Modules are cached after first load.

---

### Data passing between Lua and the host

There are a few important quirks when working with data that crosses the Lua/host boundary:

1. **Dictionaries use bracket notation**: Access fields with `data["key"]`, not `data.key`.
2. **Godot Arrays are 0-indexed**: Unlike native Lua tables (which start at 1), arrays returned by `api.get_participants()` and similar functions start at index 0.
3. **Sending structured data**: Use `Dictionary{...}` and `Array{...}` constructors when building data to pass back to the runtime.

---

### Multiplayer sync model

Activities run **locally on every client**. When a player takes an action:

```
Player input → api.send_action(data) → Server broadcasts → _on_event("action", data)
                                                            (on ALL clients, including sender)
```

Key rules:

- **All state changes must go through actions.** Don't mutate shared state directly in `_input` — send an action and handle it in `_on_event`.
- **Actions must be deterministic.** Given the same sequence of actions, every client must arrive at the same state. Avoid `math.random()` in `_on_event` — generate random values on one client (typically the host) and include them in the action data.
- **One client is the host.** The first participant is the host:

```lua
function is_host()
    local first = api.get_participant(0)
    return first["user_id"] == api.get_user_id()
end
```

---

### Structuring larger activities

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

### Sandboxing

Activities run in a restricted Lua environment. Only these standard libraries are available:

- `base` (print, type, tostring, pairs, ipairs, pcall, etc.)
- `coroutine`
- `string`
- `math`
- `table`

**Not available**: `io`, `os`, `package`, `debug`, `ffi`. There is no filesystem access, no network access, and no way to break out of the sandbox.

---

### Resource limits

| Resource | Limit |
|---|---|
| Draw commands per frame | 4,096 |
| Loaded images | 64 |
| Pixel buffers | 4 |
| Loaded sounds | 16 |
| Canvas size | 64x64 to 1920x1080 |
| Font size | 4-128 |
| Timer minimum interval | 16ms |

---

### Build scripts

A build script packages your activity into a `.daccord-plugin` file (a ZIP archive):

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
- `assets/` — images, sounds, and other static files (if present)

---

## Deploying to a server

Once your plugin is built and tested locally, you can deploy it to a running [Accord server](https://github.com/daccordproject/accordserver). Plugins are installed per-space and managed through the REST API.

### Installing a plugin

Upload a `.daccord-plugin` bundle to a space. The installing user must have the `manage_space` permission.

```bash
curl -X POST /api/v1/spaces/{space_id}/plugins \
  -H "Authorization: Bearer <token>" \
  -F "bundle=@my-activity.daccord-plugin"
```

The server validates the bundle, extracts the manifest, and stores the plugin. A `plugin.installed` gateway event is broadcast to space members.

### Managing plugins

```bash
# List plugins in a space (optionally filter by type)
curl /api/v1/spaces/{space_id}/plugins?type=activity \
  -H "Authorization: Bearer <token>"

# Uninstall a plugin (requires manage_space)
curl -X DELETE /api/v1/spaces/{space_id}/plugins/{plugin_id} \
  -H "Authorization: Bearer <token>"

# Download the full plugin bundle
curl /api/v1/plugins/{plugin_id}/bundle \
  -H "Authorization: Bearer <token>" -o plugin.zip

# Get plugin icon
curl /api/v1/plugins/{plugin_id}/icon \
  -H "Authorization: Bearer <token>" -o icon.png
```

### Activity sessions

Activity plugins support multiplayer sessions with lobby, running, and ended states.

```bash
# Create a session (starts in "lobby" if the plugin has lobby enabled)
curl -X POST /api/v1/plugins/{plugin_id}/sessions \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"channel_id": "123"}'

# Join as a player or spectator
curl -X POST /api/v1/plugins/{plugin_id}/sessions/{session_id}/roles \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "456", "role": "player"}'

# Start the session (host only, transitions lobby → running)
curl -X PATCH /api/v1/plugins/{plugin_id}/sessions/{session_id} \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"state": "running"}'

# Send an action to other participants (running sessions only)
curl -X POST /api/v1/plugins/{plugin_id}/sessions/{session_id}/actions \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"type": "move", "x": 10, "y": 20}'

# End a session (host or manage_space permission)
curl -X DELETE /api/v1/plugins/{plugin_id}/sessions/{session_id} \
  -H "Authorization: Bearer <token>"
```

Session state transitions: `lobby` → `running` → `ended` (or `lobby` → `ended` to cancel).

### Gateway events

Plugin events are broadcast over the WebSocket gateway under the `plugins` intent:

| Event | Description |
|---|---|
| `plugin.installed` | A plugin was installed in a space |
| `plugin.uninstalled` | A plugin was removed from a space |
| `plugin.session_state` | A session was created, changed state, or ended |
| `plugin.role_changed` | A participant's role changed in a session |
| `plugin.event` | An action was relayed to session participants |

---

## Editor architecture

Three core GDScript files handle everything:

| File | Role |
|---|---|
| `scripts/editor.gd` | Editor UI: file loading, plugin reload, virtual user simulation, action loopback |
| `scenes/plugins/scripted_runtime.gd` | Core Lua runtime: sandboxed `LuaState` (via lua-gdextension), bridge `api` table injection, lifecycle management, timers, audio |
| `scenes/plugins/plugin_canvas.gd` | Draw backend: accumulates draw commands per frame, renders shapes/text/images/buffers |

### How the editor simulates multiplayer

The editor replaces the real server with a local action loopback:

1. Plugin calls `api.send_action(data)`
2. Editor captures the action
3. Editor immediately calls `_on_event("action", data)` on every loaded runtime instance

This lets you test the full multiplayer flow — including host logic, turn taking, and state sync — without deploying to a server.

---

## Example plugins

Two complete example activities are included in the `games/` directory:

### Codenames (`games/codenames/`)

A word-guessing party game for up to 8 players. Teams take turns giving one-word clues to help their teammates identify secret agents on a 5x5 grid.

- Team selection and role assignment (spymaster vs operative)
- Turn-based clue giving and guessing
- Spymaster view with color overlays on unrevealed cards
- Asset loading (tiled background pattern)

### Battleships (`games/battleships/`)

Classic naval combat for 2 players. Place your fleet on a 10x10 grid, then take turns firing at your opponent.

- Ship placement phase with rotation and validation
- Turn-based firing with hit/miss/sunk feedback
- Dual grid display (own board + enemy board)
- Win detection when all enemy ships are sunk

Both follow the recommended module structure (`main.lua`, `state.lua`, `constants.lua`, `drawing.lua`, `input.lua`, `events.lua`) and serve as practical references for building your own activities.

```bash
# Try them out
godot --plugin ./games/codenames/src/main.lua
godot --plugin ./games/battleships/src/main.lua

# Build a distributable bundle
cd games/codenames && ./build.sh
```

---

## Tips

- **Start simple.** Get a rectangle on screen, then add input, then multiplayer.
- **Use the editor's user simulation.** Add virtual users and switch between them to test multiplayer flows without deploying.
- **Keep `_draw()` lean.** Do logic in `_input` and `_on_event`, store results in state, and let `_draw` just read and render.
- **Debug with `print()`.** Output appears in the Godot console.
- **Reload often.** Hit the Reload button in the editor to pick up changes instantly.
- **Use `pcall` for robustness.** Wrap asset loading or anything that might fail:
  ```lua
  local ok, img = pcall(function()
      return api.load_image(api.read_asset("assets/sprite.png"))
  end)
  if ok and img >= 0 then
      sprite = img
  end
  ```

## License

See [LICENSE](LICENSE) for details.
