-- Input handling for Battleships

local C = require("constants")
local S = require("state")
local events = require("events")

local M = {}

-- ---------------------------------------------------------------------------
-- Hit testing
-- ---------------------------------------------------------------------------

local function hit_rect(mx, my, rx, ry, rw, rh)
    return mx >= rx and mx < rx + rw and my >= ry and my < ry + rh
end

local function grid_hit_test(mx, my, grid_x, grid_y)
    if mx < grid_x or mx >= grid_x + C.GRID_PX then return -1, -1 end
    if my < grid_y or my >= grid_y + C.GRID_PX then return -1, -1 end
    local col = math.floor((mx - grid_x) / C.CELL_SIZE) + 1
    local row = math.floor((my - grid_y) / C.CELL_SIZE) + 1
    return row, col
end

-- ---------------------------------------------------------------------------
-- Click handlers
-- ---------------------------------------------------------------------------

local function handle_lobby_click(mx, my)
    local uid = S.user_id()

    -- Join button
    if hit_rect(mx, my, 240, 300, 160, 40) then
        if uid ~= S.player1 and uid ~= S.player2 then
            api.send_action(Dictionary{
                action = "join",
                user_id = uid,
            })
        end
        return
    end

    -- Start button (any joined player, needs 2 players)
    if hit_rect(mx, my, 240, 360, 160, 40) then
        if (uid == S.player1 or uid == S.player2) and S.player1 ~= "" and S.player2 ~= "" then
            api.send_action(Dictionary{
                action = "start_game",
                user_id = uid,
            })
        end
        return
    end
end

local function handle_placement_click(mx, my)
    local idx = S.my_ship_idx()
    local board = S.my_board()
    if board == nil then return end

    -- Rotate button
    if idx <= #C.SHIPS then
        local btn_y = 110 + #C.SHIPS * 22 + 24
        if hit_rect(mx, my, 390, btn_y, 130, 28) then
            S.set_my_ship_dir(not S.my_ship_dir())
            return
        end
    end

    -- Ready button
    if idx > #C.SHIPS and not S.my_ship_ready() then
        local btn_y = 110 + #C.SHIPS * 22 + 10
        if hit_rect(mx, my, 390, btn_y, 150, 36) then
            S.set_my_ship_ready(true)
            api.send_action(Dictionary{
                action = "ships_placed",
                user_id = S.user_id(),
                board = Array(S.serialize_board(board)),
            })
            return
        end
    end

    -- Place ship on own grid
    if idx > #C.SHIPS then return end

    local row, col = grid_hit_test(mx, my, C.OWN_GRID_X, C.OWN_GRID_Y)
    if row < 1 or col < 1 then return end

    local ship = C.SHIPS[idx]
    local horiz = S.my_ship_dir()
    if S.can_place_ship(board, row, col, ship.size, horiz) then
        S.place_ship(board, row, col, ship.size, horiz)
        table.insert(S.my_placed_list(), {
            idx = idx,
            row = row,
            col = col,
            horizontal = horiz,
        })
        S.set_my_ship_idx(idx + 1)
    end
end

local function handle_battle_click(mx, my)
    if not S.is_my_turn() then return end

    local row, col = grid_hit_test(mx, my, C.ENEMY_GRID_X, C.ENEMY_GRID_Y)
    if row < 1 or col < 1 then return end

    local my_shots = S.my_shots()
    if my_shots == nil then return end

    -- Can't fire at already-shot cell
    if my_shots[row] and my_shots[row][col] ~= C.EMPTY then return end

    api.send_action(Dictionary{
        action = "fire",
        user_id = S.user_id(),
        row = row,
        col = col,
    })
end

local function handle_game_over_click(mx, my)
    local uid = S.user_id()
    if hit_rect(mx, my, 250, 290, 140, 40) and (uid == S.player1 or uid == S.player2) then
        api.send_action(Dictionary{
            action = "new_game",
            user_id = uid,
        })
    end
end

-- ---------------------------------------------------------------------------
-- Main input handler
-- ---------------------------------------------------------------------------

function M.handle_input(event)
    local etype = tostring(event["type"] or "")

    if etype == "mouse_motion" then
        S.mouse_x = tonumber(event["position_x"] or 0)
        S.mouse_y = tonumber(event["position_y"] or 0)

        -- Update hover grid
        local row, col = grid_hit_test(S.mouse_x, S.mouse_y, C.OWN_GRID_X, C.OWN_GRID_Y)
        if row >= 1 and col >= 1 then
            S.hover_grid = "own"
            S.hover_row = row
            S.hover_col = col
        else
            row, col = grid_hit_test(S.mouse_x, S.mouse_y, C.ENEMY_GRID_X, C.ENEMY_GRID_Y)
            if row >= 1 and col >= 1 then
                S.hover_grid = "enemy"
                S.hover_row = row
                S.hover_col = col
            else
                S.hover_grid = ""
                S.hover_row = -1
                S.hover_col = -1
            end
        end

    elseif etype == "mouse_button" then
        local pressed = event["pressed"]
        if not pressed then return end
        local btn = math.floor(tonumber(event["button_index"] or 0))
        if btn ~= 1 then return end

        S.mouse_x = tonumber(event["position_x"] or 0)
        S.mouse_y = tonumber(event["position_y"] or 0)

        if S.phase == "lobby" then
            handle_lobby_click(S.mouse_x, S.mouse_y)
        elseif S.phase == "placement" then
            handle_placement_click(S.mouse_x, S.mouse_y)
        elseif S.phase == "battle" then
            handle_battle_click(S.mouse_x, S.mouse_y)
        elseif S.phase == "game_over" then
            handle_game_over_click(S.mouse_x, S.mouse_y)
        end

    elseif etype == "key" then
        local pressed = event["pressed"]
        if not pressed then return end
        local keycode = math.floor(tonumber(event["keycode"] or 0))

        -- R key to rotate during placement
        if S.phase == "placement" and S.my_ship_idx() <= #C.SHIPS then
            if keycode == 82 or keycode == 114 then -- 'R' or 'r'
                S.set_my_ship_dir(not S.my_ship_dir())
            end
        end
    end
end

return M
