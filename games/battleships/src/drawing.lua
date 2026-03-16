-- Drawing functions for Battleships

local C = require("constants")
local S = require("state")

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function draw_button(x, y, w, h, label, color)
    local bg = color
    if S.mouse_x >= x and S.mouse_x < x + w and S.mouse_y >= y and S.mouse_y < y + h then
        if color ~= C.BTN_DISABLED then
            bg = C.BTN_HOVER
        end
    end
    api.draw_rect(x, y, w, h, bg, true)
    local tx = x + (w - #label * 8) / 2
    local ty = y + h * 0.7
    api.draw_text(tx, ty, label, C.TEXT_COLOR, 14)
end

local function cell_to_px(grid_x, grid_y, row, col)
    local px = grid_x + (col - 1) * C.CELL_SIZE
    local py = grid_y + (row - 1) * C.CELL_SIZE
    return px, py
end

-- ---------------------------------------------------------------------------
-- Grid drawing
-- ---------------------------------------------------------------------------

local function draw_grid_frame(gx, gy, label, label_color)
    -- Label
    local lx = gx + (C.GRID_PX - #label * 10) / 2
    api.draw_text(lx, gy - 6, label, label_color, 16)

    -- Column labels (A-J)
    for c = 1, C.GRID_SIZE do
        local px = gx + (c - 1) * C.CELL_SIZE + C.CELL_SIZE * 0.35
        api.draw_text(px, gy + C.GRID_PX + 16, C.COL_LABELS[c], C.TEXT_DIM, 11)
    end

    -- Row labels (1-10)
    for r = 1, C.GRID_SIZE do
        local py = gy + (r - 1) * C.CELL_SIZE + C.CELL_SIZE * 0.7
        local lbl = C.ROW_LABELS[r]
        local off = #lbl == 1 and -14 or -20
        api.draw_text(gx + off, py, lbl, C.TEXT_DIM, 11)
    end

    -- Grid background
    api.draw_rect(gx, gy, C.GRID_PX, C.GRID_PX, C.GRID_BG, true)

    -- Grid lines
    for i = 0, C.GRID_SIZE do
        local x = gx + i * C.CELL_SIZE
        local y = gy + i * C.CELL_SIZE
        api.draw_line(x, gy, x, gy + C.GRID_PX, C.GRID_LINE, 1)
        api.draw_line(gx, y, gx + C.GRID_PX, y, C.GRID_LINE, 1)
    end
end

local function draw_cell_marker(px, py, state)
    if state == C.HIT or state == C.SUNK then
        local color = state == C.SUNK and C.CELL_SUNK or C.CELL_HIT
        api.draw_rect(px + 1, py + 1, C.CELL_SIZE - 2, C.CELL_SIZE - 2, color, true)
        -- X marker
        api.draw_line(px + 4, py + 4, px + C.CELL_SIZE - 4, py + C.CELL_SIZE - 4, C.TEXT_COLOR, 2)
        api.draw_line(px + C.CELL_SIZE - 4, py + 4, px + 4, py + C.CELL_SIZE - 4, C.TEXT_COLOR, 2)
    elseif state == C.MISS then
        api.draw_circle(px + C.CELL_SIZE / 2, py + C.CELL_SIZE / 2, 4, C.MISS_MARKER)
    end
end

-- Draw own board (shows ships + incoming hits)
local function draw_own_grid()
    draw_grid_frame(C.OWN_GRID_X, C.OWN_GRID_Y, "YOUR WATERS", C.LABEL_OWN)

    local board = S.my_board()
    local inc = S.my_incoming()

    for r = 1, C.GRID_SIZE do
        for c = 1, C.GRID_SIZE do
            local px, py = cell_to_px(C.OWN_GRID_X, C.OWN_GRID_Y, r, c)
            local ship = board and board[r] and board[r][c] or C.EMPTY
            local hit = inc and inc[r] and inc[r][c] or C.EMPTY

            -- Draw ship
            if ship == C.SHIP then
                api.draw_rect(px + 1, py + 1, C.CELL_SIZE - 2, C.CELL_SIZE - 2, C.CELL_SHIP, true)
            end

            -- Draw hit/miss overlay
            draw_cell_marker(px, py, hit)
        end
    end
end

-- Draw enemy board (shows my shots)
local function draw_enemy_grid()
    draw_grid_frame(C.ENEMY_GRID_X, C.ENEMY_GRID_Y, "ENEMY WATERS", C.LABEL_ENEMY)

    local my_shots = S.my_shots()

    for r = 1, C.GRID_SIZE do
        for c = 1, C.GRID_SIZE do
            local px, py = cell_to_px(C.ENEMY_GRID_X, C.ENEMY_GRID_Y, r, c)
            local state = my_shots and my_shots[r] and my_shots[r][c] or C.EMPTY

            draw_cell_marker(px, py, state)

            -- Hover highlight during battle
            if S.phase == "battle" and S.is_my_turn()
                and S.hover_grid == "enemy"
                and S.hover_row == r and S.hover_col == c
                and state == C.EMPTY then
                api.draw_rect(px + 1, py + 1, C.CELL_SIZE - 2, C.CELL_SIZE - 2, C.CELL_HOVER, true)
                -- Crosshair
                local cx = px + C.CELL_SIZE / 2
                local cy = py + C.CELL_SIZE / 2
                api.draw_line(cx - 6, cy, cx + 6, cy, C.HIT_MARKER, 1)
                api.draw_line(cx, cy - 6, cx, cy + 6, C.HIT_MARKER, 1)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Phase-specific drawing
-- ---------------------------------------------------------------------------

function M.draw_background()
    api.draw_rect(0, 0, C.CW, C.CH, C.BG_COLOR, true)
end

function M.draw_lobby()
    api.draw_text(210, 100, "BATTLESHIPS", C.TEXT_COLOR, 32)
    api.draw_text(195, 135, "Sink the enemy fleet to win!", C.TEXT_DIM, 14)

    -- Player slots
    api.draw_rect(170, 180, 300, 44, C.PANEL_COLOR, true)
    api.draw_rect(170, 180, 300, 44, C.LABEL_OWN, false)
    local p1_label = S.player1 ~= "" and ("Player 1: " .. string.sub(S.player1, 1, 12)) or "Player 1: (empty)"
    api.draw_text(185, 208, p1_label, S.player1 ~= "" and C.TEXT_COLOR or C.TEXT_DIM, 14)

    api.draw_rect(170, 234, 300, 44, C.PANEL_COLOR, true)
    api.draw_rect(170, 234, 300, 44, C.LABEL_ENEMY, false)
    local p2_label = S.player2 ~= "" and ("Player 2: " .. string.sub(S.player2, 1, 12)) or "Player 2: (empty)"
    api.draw_text(185, 262, p2_label, S.player2 ~= "" and C.TEXT_COLOR or C.TEXT_DIM, 14)

    -- Join button
    local uid = S.user_id()
    if uid ~= S.player1 and uid ~= S.player2 then
        draw_button(240, 300, 160, 40, "JOIN GAME", C.BTN_COLOR)
    else
        api.draw_text(260, 325, "You're in!", C.LABEL_OWN, 14)
    end

    -- Start button (any joined player, needs 2 players)
    local joined = (uid == S.player1 or uid == S.player2)
    local can_start = S.player1 ~= "" and S.player2 ~= "" and joined
    local btn_c = can_start and C.BTN_COLOR or C.BTN_DISABLED
    draw_button(240, 360, 160, 40, "START GAME", btn_c)
end

function M.draw_placement()
    draw_own_grid()

    local idx = S.my_ship_idx()

    -- Ship placement info on right side
    api.draw_text(384, 80, "PLACE YOUR SHIPS", C.TEXT_COLOR, 16)

    local y = 110
    for i, ship in ipairs(C.SHIPS) do
        local color = C.TEXT_DIM
        if i < idx then
            color = C.LABEL_OWN  -- placed
        elseif i == idx then
            color = C.TEXT_COLOR  -- current
        end
        local marker = i < idx and "[ok]" or "    "
        local txt = string.format("%s %s (%d)", marker, ship.name, ship.size)
        api.draw_text(390, y, txt, color, 13)
        y = y + 22
    end

    -- Orientation indicator
    if idx <= #C.SHIPS then
        local dir = S.my_ship_dir() and "Horizontal" or "Vertical"
        api.draw_text(390, y + 10, "Direction: " .. dir, C.TEXT_COLOR, 13)
        draw_button(390, y + 24, 130, 28, "ROTATE (R)", C.BTN_COLOR)

        -- Ship preview on own grid
        local board = S.my_board()
        if board and S.hover_grid == "own" and S.hover_row > 0 and S.hover_col > 0 then
            local ship = C.SHIPS[idx]
            local horiz = S.my_ship_dir()
            local valid = S.can_place_ship(board, S.hover_row, S.hover_col, ship.size, horiz)
            local preview_color = valid and C.CELL_HOVER_VALID or C.CELL_HOVER_INVALID

            if horiz then
                for c = S.hover_col, math.min(S.hover_col + ship.size - 1, C.GRID_SIZE) do
                    local px, py = cell_to_px(C.OWN_GRID_X, C.OWN_GRID_Y, S.hover_row, c)
                    api.draw_rect(px + 1, py + 1, C.CELL_SIZE - 2, C.CELL_SIZE - 2, preview_color, true)
                end
            else
                for r = S.hover_row, math.min(S.hover_row + ship.size - 1, C.GRID_SIZE) do
                    local px, py = cell_to_px(C.OWN_GRID_X, C.OWN_GRID_Y, r, S.hover_col)
                    api.draw_rect(px + 1, py + 1, C.CELL_SIZE - 2, C.CELL_SIZE - 2, preview_color, true)
                end
            end
        end
    else
        -- All ships placed
        if not S.my_ship_ready() then
            draw_button(390, y + 10, 150, 36, "READY!", C.BTN_COLOR)
        else
            api.draw_text(390, y + 30, "Waiting for opponent...", C.TEXT_DIM, 13)
        end
    end
end

function M.draw_battle()
    draw_own_grid()
    draw_enemy_grid()

    -- Status bar at bottom
    api.draw_rect(0, C.CH - 40, C.CW, 40, C.TOP_BAR_COLOR, true)

    if S.is_my_turn() then
        api.draw_text(20, C.CH - 15, "YOUR TURN - Fire at the enemy grid!", C.TEXT_COLOR, 14)
    else
        api.draw_text(20, C.CH - 15, "Opponent's turn... waiting", C.TEXT_DIM, 14)
    end

    -- Last shot info
    if S.last_hit_result ~= "" then
        local result_text = string.upper(S.last_hit_result) .. "!"
        local result_color = S.last_hit_result == "miss" and C.TEXT_DIM or C.CELL_HIT
        if S.last_hit_result == "sunk" then result_color = C.CELL_SUNK end
        api.draw_text(450, C.CH - 15, "Last: " .. result_text, result_color, 14)
    end

    -- Hit counters
    api.draw_text(20, C.OWN_GRID_Y + C.GRID_PX + 36,
        string.format("Hits taken: %d/%d", S.my_hits_taken(), C.TOTAL_SHIP_CELLS),
        C.LABEL_ENEMY, 12)
    api.draw_text(384, C.ENEMY_GRID_Y + C.GRID_PX + 36,
        string.format("Hits dealt: %d/%d", S.my_hits_dealt(), C.TOTAL_SHIP_CELLS),
        C.LABEL_OWN, 12)
end

function M.draw_game_over()
    draw_own_grid()
    draw_enemy_grid()

    -- Reveal opponent ships
    local opp_board = S.boards[S.opponent_id()]
    local my_shots = S.my_shots()
    if opp_board then
        for r = 1, C.GRID_SIZE do
            for c = 1, C.GRID_SIZE do
                if opp_board[r] and opp_board[r][c] == C.SHIP then
                    local px, py = cell_to_px(C.ENEMY_GRID_X, C.ENEMY_GRID_Y, r, c)
                    local state = my_shots and my_shots[r] and my_shots[r][c] or C.EMPTY
                    if state == C.EMPTY then
                        api.draw_rect(px + 1, py + 1, C.CELL_SIZE - 2, C.CELL_SIZE - 2,
                            {0.23, 0.35, 0.48, 0.5}, true)
                    end
                end
            end
        end
    end

    -- Overlay
    api.draw_rect(0, 0, C.CW, C.CH, {0.0, 0.0, 0.0, 0.55}, true)

    local is_winner = S.winner == S.user_id()
    local banner_color = is_winner and C.LABEL_OWN or C.LABEL_ENEMY
    local banner_text = is_winner and "VICTORY!" or "DEFEAT!"

    api.draw_rect(170, 180, 300, 80, C.PANEL_COLOR, true)
    api.draw_rect(170, 180, 300, 80, banner_color, false)
    api.draw_text(250, 225, banner_text, banner_color, 32)
    api.draw_text(230, 250,
        string.format("You: %d hits | Enemy: %d hits", S.my_hits_dealt(), S.my_hits_taken()),
        C.TEXT_DIM, 12)

    local uid = S.user_id()
    if uid == S.player1 or uid == S.player2 then
        draw_button(250, 290, 140, 40, "NEW GAME", C.BTN_COLOR)
    end
end

function M.draw_top_bar()
    api.draw_rect(0, 0, C.CW, C.TOP_BAR_H, C.TOP_BAR_COLOR, true)
    api.draw_text(12, 30, "BATTLESHIPS", C.TEXT_COLOR, 20)

    if S.phase == "placement" then
        api.draw_text(200, 30, "Place your ships", C.TEXT_DIM, 14)
    elseif S.phase == "battle" then
        local turn_text = S.is_my_turn() and "Your turn" or "Opponent's turn"
        local turn_color = S.is_my_turn() and C.LABEL_OWN or C.TEXT_DIM
        api.draw_text(200, 30, turn_text, turn_color, 14)
    elseif S.phase == "game_over" then
        api.draw_text(200, 30, "Game Over", C.TEXT_DIM, 14)
    end
end

return M
