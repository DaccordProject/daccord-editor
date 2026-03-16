-- Game state for Battleships

local C = require("constants")

local M = {}

-- Game phase: lobby | placement | battle | game_over
M.phase = "lobby"

-- Players (by user_id)
M.player1 = ""   -- host
M.player2 = ""

-- Whose turn (1 or 2)
M.current_turn = 1

-- Winner ("" or user_id)
M.winner = ""

-- Per-player state (keyed by user_id)
M.boards = {}          -- ship placement grids (10x10)
M.shots = {}           -- shots fired at enemy + results (10x10)
M.incoming = {}        -- hits/misses received on my board (10x10)
M.ship_idx = {}        -- next ship to place (1..#SHIPS+1)
M.ship_dir = {}        -- true = horizontal
M.ship_ready = {}      -- finished placing?
M.placed_list = {}     -- list of {idx, row, col, horizontal}
M.hits_dealt = {}      -- count of hits scored on enemy
M.hits_taken = {}      -- count of hits received

-- UI state
M.mouse_x = 0
M.mouse_y = 0
M.hover_grid = ""  -- "own", "enemy", or ""
M.hover_row = -1
M.hover_col = -1
M.last_hit_row = -1
M.last_hit_col = -1
M.last_hit_result = ""

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

function M.user_id()
    return api.get_user_id()
end

function M.is_host()
    if api.get_participant_count() == 0 then return false end
    local first = api.get_participant(0)
    local first_id = ""
    local ok, uid = pcall(function() return first["user_id"] end)
    if ok and uid ~= nil and tostring(uid) ~= "" then
        first_id = tostring(uid)
    else
        local ok2, fid = pcall(function() return first["id"] end)
        if ok2 and fid ~= nil then
            first_id = tostring(fid)
        else
            first_id = tostring(first)
        end
    end
    return first_id == M.user_id()
end

function M.is_my_turn()
    local uid = M.user_id()
    local expected = M.current_turn == 1 and M.player1 or M.player2
    return uid == expected
end

function M.opponent_id()
    local uid = M.user_id()
    if uid == M.player1 then return M.player2 end
    return M.player1
end

-- Initialize per-player grids
function M.init_player(uid)
    M.boards[uid] = {}
    M.shots[uid] = {}
    M.incoming[uid] = {}
    for r = 1, C.GRID_SIZE do
        M.boards[uid][r] = {}
        M.shots[uid][r] = {}
        M.incoming[uid][r] = {}
        for c = 1, C.GRID_SIZE do
            M.boards[uid][r][c] = C.EMPTY
            M.shots[uid][r][c] = C.EMPTY
            M.incoming[uid][r][c] = C.EMPTY
        end
    end
    M.ship_idx[uid] = 1
    M.ship_dir[uid] = true
    M.ship_ready[uid] = false
    M.placed_list[uid] = {}
    M.hits_dealt[uid] = 0
    M.hits_taken[uid] = 0
end

-- Reset all per-player state
function M.init_grids()
    M.boards = {}
    M.shots = {}
    M.incoming = {}
    M.ship_idx = {}
    M.ship_dir = {}
    M.ship_ready = {}
    M.placed_list = {}
    M.hits_dealt = {}
    M.hits_taken = {}
end

-- Accessors for current user
function M.my_board()    return M.boards[M.user_id()] end
function M.my_shots()    return M.shots[M.user_id()] end
function M.my_incoming() return M.incoming[M.user_id()] end

function M.my_ship_idx()        return M.ship_idx[M.user_id()] or 1 end
function M.set_my_ship_idx(v)   M.ship_idx[M.user_id()] = v end

function M.my_ship_dir()        return M.ship_dir[M.user_id()] end
function M.set_my_ship_dir(v)   M.ship_dir[M.user_id()] = v end

function M.my_ship_ready()      return M.ship_ready[M.user_id()] or false end
function M.set_my_ship_ready(v) M.ship_ready[M.user_id()] = v end

function M.my_placed_list()     return M.placed_list[M.user_id()] end

function M.my_hits_dealt()      return M.hits_dealt[M.user_id()] or 0 end
function M.my_hits_taken()      return M.hits_taken[M.user_id()] or 0 end

-- Check if ship placement is valid
function M.can_place_ship(board, row, col, size, horizontal)
    if horizontal then
        if col + size - 1 > C.GRID_SIZE then return false end
        for c = col, col + size - 1 do
            if board[row][c] ~= C.EMPTY then return false end
        end
    else
        if row + size - 1 > C.GRID_SIZE then return false end
        for r = row, row + size - 1 do
            if board[r][col] ~= C.EMPTY then return false end
        end
    end
    return true
end

-- Place a ship on a board
function M.place_ship(board, row, col, size, horizontal)
    if horizontal then
        for c = col, col + size - 1 do
            board[row][c] = C.SHIP
        end
    else
        for r = row, row + size - 1 do
            board[r][col] = C.SHIP
        end
    end
end

-- Check if all ships on a board are sunk
function M.all_ships_sunk(ship_board, hit_board)
    for r = 1, C.GRID_SIZE do
        for c = 1, C.GRID_SIZE do
            if ship_board[r][c] == C.SHIP and hit_board[r][c] ~= C.HIT and hit_board[r][c] ~= C.SUNK then
                return false
            end
        end
    end
    return true
end

-- Serialize a board to a flat array for sending via action
function M.serialize_board(board)
    local flat = {}
    for r = 1, C.GRID_SIZE do
        for c = 1, C.GRID_SIZE do
            table.insert(flat, board[r][c])
        end
    end
    return flat
end

-- Deserialize flat array back to 10x10 grid
function M.deserialize_board(flat)
    local board = {}
    for r = 1, C.GRID_SIZE do
        board[r] = {}
        for c = 1, C.GRID_SIZE do
            local idx = (r - 1) * C.GRID_SIZE + (c - 1)
            board[r][c] = math.floor(tonumber(flat[idx]) or 0)
        end
    end
    return board
end

return M
