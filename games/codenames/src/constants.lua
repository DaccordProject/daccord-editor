-- Constants and word list for Codenames

local M = {}

-- Canvas
M.CW = 640
M.CH = 480

-- Grid layout
M.GRID_COLS = 5
M.GRID_ROWS = 5
M.CARD_COUNT = 25

M.CARD_W = 118.0
M.CARD_H = 70.0
M.CARD_GAP_X = 8.0
M.CARD_GAP_Y = 6.0

M.GRID_X = 7.0
M.GRID_Y = 46.0
M.TOP_BAR_H = 40.0
M.BOTTOM_BAR_Y = 430.0

-- Colors
M.BG_COLOR = "#1a1a2e"
M.TOP_BAR_COLOR = "#16213e"
M.BOTTOM_BAR_COLOR = "#16213e"
M.CARD_UNREVEALED = "#37474f"
M.CARD_HOVER = "#546e7a"
M.CARD_RED = "#c62828"
M.CARD_BLUE = "#1565c0"
M.CARD_NEUTRAL = "#616161"
M.CARD_ASSASSIN = "#212121"
M.TEXT_COLOR = "#ffffff"
M.TEXT_DIM = "#90a4ae"
M.CLUE_BG = "#263238"
M.BTN_COLOR = "#0d7377"
M.BTN_HOVER = "#14a3a8"

-- Spymaster overlay colors (RGBA arrays)
M.SPY_RED = {0.78, 0.16, 0.16, 0.35}
M.SPY_BLUE = {0.08, 0.40, 0.75, 0.35}
M.SPY_NEUTRAL = {0.38, 0.38, 0.38, 0.25}
M.SPY_ASSASSIN = {0.0, 0.0, 0.0, 0.55}

-- Card color codes
M.CLR_RED = 0
M.CLR_BLUE = 1
M.CLR_NEUTRAL = 2
M.CLR_ASSASSIN = 3

-- Word list
M.WORDS = {
    "AGENT", "ALIEN", "ANGEL", "BANK", "BEACH", "BEAR", "BOMB", "BRIDGE", "CAR", "CAT",
    "CHURCH", "CLOCK", "CODE", "CRANE", "DEATH", "DIAMOND", "DRAGON", "EAGLE", "FIRE", "GHOST",
    "GOLD", "HEART", "ICE", "KING", "KNIFE", "LION", "MOON", "NINJA", "QUEEN", "ROBOT",
}

-- Color code helpers
function M.color_int_to_hex(c)
    if c == M.CLR_RED then return M.CARD_RED
    elseif c == M.CLR_BLUE then return M.CARD_BLUE
    elseif c == M.CLR_NEUTRAL then return M.CARD_NEUTRAL
    elseif c == M.CLR_ASSASSIN then return M.CARD_ASSASSIN
    end
    return M.CARD_UNREVEALED
end

function M.spy_tint_for_int(c)
    if c == M.CLR_RED then return M.SPY_RED
    elseif c == M.CLR_BLUE then return M.SPY_BLUE
    elseif c == M.CLR_NEUTRAL then return M.SPY_NEUTRAL
    elseif c == M.CLR_ASSASSIN then return M.SPY_ASSASSIN
    end
    return {0.0, 0.0, 0.0, 0.0}
end

return M
