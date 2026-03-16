# Codenames

A multiplayer [Codenames](https://en.wikipedia.org/wiki/Codenames_(board_game)) board game plugin for [daccord](https://github.com/daccord-projects).

## How it works

Two teams (red and blue) compete to identify their agents on a 5×5 grid of word cards. Each team has a **spymaster** who knows which cards belong to which team, and **operatives** who guess based on one-word clues.

- **25 cards**: 9 red, 8 blue, 7 neutral, 1 assassin
- Red team goes first (they have more cards to find)
- Spymasters give a single-word clue and a number indicating how many cards relate to it
- Operatives get `clue_count + 1` guesses per turn
- Guessing the assassin card instantly loses the game

## Game flow

1. **Lobby** — Players join a team and pick a role (spymaster or operative). The host starts the game once both teams have at least one player.
2. **Clue** — The current team's spymaster types a one-word clue and selects a number.
3. **Guess** — The current team's operatives click cards to guess. A wrong guess or neutral card ends the turn. Operatives can also choose to end guessing early.
4. **Game over** — A team wins by finding all their cards, or the other team loses by revealing the assassin.

## Technical details

- **Format**: Lua — executed in a sandboxed LuaState via [lua-gdextension](https://github.com/gilzoide/lua-gdextension)
- **Canvas**: 640×480
- **Max players**: 8 (unlimited spectators)
- **Sync model**: The host generates the board and broadcasts it. All clients apply actions deterministically to stay in sync.

## Project structure

```
├── plugin.json      # Plugin metadata (id, format, entry point, canvas size, etc.)
├── src/
│   └── main.lua     # All game logic, rendering, and input handling
├── assets/          # Game assets (if any)
├── export/          # Build output
└── build.sh         # Build & packaging script
```

## Building

```bash
./build.sh           # Creates export/codenames.daccord-plugin
```

The `.daccord-plugin` bundle is a ZIP containing `plugin.json` and the `.lua` source file. No compilation step is required — the daccord runtime creates a sandboxed LuaState and executes the Lua source directly.
