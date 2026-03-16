-- Constants for Battleships

local M = {}

-- Canvas
M.CW = 640
M.CH = 480

-- Grid
M.GRID_SIZE = 10
M.CELL_SIZE = 24
M.GRID_PX = M.GRID_SIZE * M.CELL_SIZE  -- 240

-- Grid positions
M.OWN_GRID_X = 16
M.OWN_GRID_Y = 70
M.ENEMY_GRID_X = 384
M.ENEMY_GRID_Y = 70

-- Top bar
M.TOP_BAR_H = 50

-- Colors
M.BG_COLOR = "#0a1628"
M.PANEL_COLOR = "#111d33"
M.TOP_BAR_COLOR = "#0d1a2e"
M.GRID_BG = "#0c1a30"
M.GRID_LINE = "#1a3050"
M.CELL_WATER = "#0e2240"
M.CELL_SHIP = "#3a5a7a"
M.CELL_HIT = "#c62828"
M.CELL_MISS = "#37474f"
M.CELL_SUNK = "#8b0000"
M.CELL_HOVER = "#1e4060"
M.CELL_HOVER_VALID = "#1a5a2a"
M.CELL_HOVER_INVALID = "#5a1a1a"
M.CELL_SHIP_PREVIEW = "#2a5a3a"
M.TEXT_COLOR = "#ffffff"
M.TEXT_DIM = "#607888"
M.LABEL_OWN = "#4a90d9"
M.LABEL_ENEMY = "#d94a4a"
M.BTN_COLOR = "#0d7377"
M.BTN_HOVER = "#14a3a8"
M.BTN_DISABLED = "#2a3a4a"

-- Hit/miss markers
M.HIT_MARKER = "#ff3333"
M.MISS_MARKER = "#556677"

-- Ship definitions: {name, size}
M.SHIPS = {
    {name = "Carrier",    size = 5},
    {name = "Battleship", size = 4},
    {name = "Cruiser",    size = 3},
    {name = "Submarine",  size = 3},
    {name = "Destroyer",  size = 2},
}
M.TOTAL_SHIP_CELLS = 5 + 4 + 3 + 3 + 2  -- 17

-- Cell states
M.EMPTY = 0
M.SHIP = 1
M.HIT = 2
M.MISS = 3
M.SUNK = 4

-- Row/column labels
M.COL_LABELS = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J"}
M.ROW_LABELS = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}

return M
