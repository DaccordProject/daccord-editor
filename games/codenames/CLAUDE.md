# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Codenames board game plugin for the daccord multiplayer activity platform. Two teams (red/blue) with spymasters and operatives compete to find their word cards on a 5×5 grid. Runs as a "scripted" plugin inside daccord's Godot-based sandbox runtime.

## Plugin format

Plugins use the **SGD (SafeGDScript)** format. Game logic is written as plain GDScript in `.sgd` files. The `gdscript.elf` runtime in `addons/godot_sandbox/` handles compilation and execution inside the sandbox — no separate build/compile step is needed.

## Build & package

```bash
./build.sh              # Package plugin into export/codenames.daccord-plugin
```

The build output is `export/codenames.daccord-plugin` (a ZIP bundle containing `plugin.json` and `src/main.sgd`).

There are no tests or linting tools configured.

## Architecture

**Single-file game**: All logic lives in `src/main.sgd` — a GDScript source file that the daccord ScriptedRuntime hosts via `gdscript.elf`. There is no scene tree; everything is drawn imperatively via a bridge API dictionary (`api`).

**Bridge API**: The host runtime injects an `api` dictionary (via `_set_api()`) providing: `draw_rect`, `draw_text`, `draw_line`, `draw_circle`, `send_action`, `get_participants`, `get_role`, `get_user_id`, `canvas_width`, `canvas_height`.

**State sync model**: No server-side game logic. The host client generates the board and broadcasts it via `api.send_action`. All clients receive actions through `_on_event()` and apply them deterministically. Actions: `join_team`, `start_game`, `give_clue`, `guess_card`, `end_guessing`, `new_game`.

**Game phases**: `lobby` → `clue` → `guess` → (back to `clue` or `game_over`). Phase transitions happen inside action handlers.

**Rendering**: `_draw()` is called each frame. All UI (lobby, board, overlays, buttons) is drawn procedurally with hardcoded pixel coordinates against a 640×480 canvas. Input is handled via `_input()` with manual hit-testing (`_hit_rect`, `_hit_test_card`).

**Plugin metadata**: `plugin.json` defines the plugin ID, format (`sgd`), entry point (`src/main.sgd`), canvas size (640×480), max 8 participants, unlimited spectators, and required permissions.
