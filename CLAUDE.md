# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **Godot 4.5 development harness** for creating and testing Lua-based multiplayer game plugins for the daccord platform. The editor loads plugin source, renders it in a sandboxed viewport, simulates multiple virtual users, and loops actions back so multiplayer logic can be tested locally.

## Running the editor

```bash
# Open editor with a plugin
godot --plugin ./games/codenames/src/main.lua

# Or run the editor scene and use the file picker UI
godot
```

The main scene is `scenes/editor.tscn`. No tests or linting are configured.

## Building plugins

```bash
cd games/codenames && ./build.sh    # → export/codenames.daccord-plugin (ZIP bundle)
```

A `.daccord-plugin` is a ZIP containing `plugin.json` (metadata) and `src/main.lua` (source).

## Architecture

Three core GDScript files handle everything:

- **`scripts/editor.gd`** — Editor UI: file loading, plugin reload, virtual user simulation, action loopback (actions sent by plugins are echoed back as server events for local testing)
- **`scenes/plugins/scripted_runtime.gd`** — Core Lua runtime. Creates a sandboxed `LuaState` (via lua-gdextension), injects the bridge `api` table, caches lifecycle functions (`_ready`, `_draw`, `_input`, `_on_event`), manages timers and audio
- **`scenes/plugins/plugin_canvas.gd`** — Draw backend. Accumulates draw commands per frame (max 4096), renders rects/circles/lines/text/pixels/images/buffers. Manages up to 64 images and 4 pixel buffers

### Plugin lifecycle

Plugins are pure Lua files. The runtime calls these global functions:

```lua
function _ready()           -- Once after load
function _draw()            -- Every frame; emit draw commands via api.*
function _input(event)      -- On input (mouse_button, mouse_motion, key)
function _on_event(type, data)  -- On server action broadcast
```

### Bridge API (`api` table)

Drawing: `draw_rect`, `draw_circle`, `draw_line`, `draw_text`, `draw_pixel`, `draw_image`, `draw_image_region`, `draw_image_scaled`, `create_buffer`, `set_buffer_pixel`, `set_buffer_data`, `draw_buffer`

State: `send_action(data)`, `get_state()`, `get_participants()`, `get_role()`, `get_user_id()`

Assets: `read_asset(path)` — returns raw bytes from the plugin's `assets/` folder (e.g. `api.read_asset("assets/board.png")`)

Resources: `load_image(bytes)`, `load_sound(ogg_bytes)`, `play_sound(handle)`, `stop_sound(handle)`

Timers: `set_interval(callback_name, ms)`, `set_timeout(callback_name, ms)`, `clear_timer(id)`

Constants: `canvas_width`, `canvas_height`

## Lua sandboxing

Only safe libraries are loaded: `base`, `coroutine`, `string`, `math`, `table`. No `io`, `os`, `package`, `debug`, or `ffi`.

## Godot ↔ Lua data passing

- GDScript Dictionaries in Lua: use `data["key"]` (not dot notation)
- Godot Arrays in Lua are **0-indexed** (unlike native Lua tables which are 1-indexed)
- To send structured data back: use `Dictionary{...}` and `Array{...}` constructors
