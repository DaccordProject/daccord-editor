-- Event handlers for Battleships (actions relayed by server)

local C = require("constants")
local S = require("state")

local M = {}

function M.handle_join(data)
    if S.phase ~= "lobby" then return end
    local uid = tostring(data["user_id"] or "")
    if uid == "" then return end

    -- Don't re-join if already in
    if uid == S.player1 or uid == S.player2 then return end

    if S.player1 == "" then
        S.player1 = uid
    elseif S.player2 == "" then
        S.player2 = uid
    end
end

function M.handle_start_game(data)
    if S.phase ~= "lobby" then return end
    if S.player1 == "" or S.player2 == "" then return end

    S.phase = "placement"
    S.init_grids()
    S.init_player(S.player1)
    S.init_player(S.player2)
    S.current_turn = 1
    S.winner = ""
    S.last_hit_result = ""
end

function M.handle_ships_placed(data)
    if S.phase ~= "placement" then return end
    local uid = tostring(data["user_id"] or "")
    local board_data = data["board"]
    if board_data == nil then return end

    -- Store this player's board
    S.boards[uid] = S.deserialize_board(board_data)
    S.ship_ready[uid] = true

    -- Both ready? Start battle
    if S.ship_ready[S.player1] and S.ship_ready[S.player2] then
        S.phase = "battle"
        S.current_turn = 1
    end
end

function M.handle_fire(data)
    if S.phase ~= "battle" then return end
    local firer = tostring(data["user_id"] or "")
    local row = math.floor(tonumber(data["row"] or 0))
    local col = math.floor(tonumber(data["col"] or 0))
    if row < 1 or row > C.GRID_SIZE or col < 1 or col > C.GRID_SIZE then return end

    -- Validate it's the correct player's turn
    local expected = S.current_turn == 1 and S.player1 or S.player2
    if firer ~= expected then return end

    local target = firer == S.player1 and S.player2 or S.player1

    -- Can't fire at already-shot cell
    if S.shots[firer][row][col] ~= C.EMPTY then return end

    -- Check target's board for a ship
    if S.boards[target][row][col] == C.SHIP then
        S.shots[firer][row][col] = C.HIT
        S.incoming[target][row][col] = C.HIT
        S.hits_dealt[firer] = S.hits_dealt[firer] + 1
        S.hits_taken[target] = S.hits_taken[target] + 1
        S.last_hit_result = "hit"

        if S.all_ships_sunk(S.boards[target], S.shots[firer]) then
            S.last_hit_result = "sunk"
            S.winner = firer
            S.phase = "game_over"
            S.last_hit_row = row
            S.last_hit_col = col
            return
        end
    else
        S.shots[firer][row][col] = C.MISS
        S.incoming[target][row][col] = C.MISS
        S.last_hit_result = "miss"
    end

    S.last_hit_row = row
    S.last_hit_col = col

    -- Switch turns
    S.current_turn = S.current_turn == 1 and 2 or 1
end

function M.handle_new_game(data)
    S.phase = "lobby"
    S.player1 = ""
    S.player2 = ""
    S.current_turn = 1
    S.winner = ""
    S.last_hit_result = ""
    S.init_grids()
end

function M.dispatch(event_type, data)
    if event_type ~= "action" then return end

    local action = tostring(data["action"] or "")
    if action == "join" then
        M.handle_join(data)
    elseif action == "start_game" then
        M.handle_start_game(data)
    elseif action == "ships_placed" then
        M.handle_ships_placed(data)
    elseif action == "fire" then
        M.handle_fire(data)
    elseif action == "new_game" then
        M.handle_new_game(data)
    end
end

return M
