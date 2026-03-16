-- Game state and team helpers for Codenames

local C = require("constants")

local M = {}

-- Game state
M.phase = "lobby"  -- lobby | clue | guess | game_over
M.current_team = "red"
M.clue_word = ""
M.clue_count = 0
M.guesses_remaining = 0
M.winner = ""

-- Board as parallel arrays (1-indexed, 1..25)
M.board_word_idx = {}
M.board_colors = {}
M.board_revealed = {}

-- Teams
M.red_spymaster = ""
M.red_operatives = {}
M.blue_spymaster = ""
M.blue_operatives = {}

-- Scores
M.score_red = 0
M.score_blue = 0
M.target_red = 9
M.target_blue = 8

-- Local UI state
M.hover_card = -1
M.mouse_x = 0.0
M.mouse_y = 0.0
M.clue_input = ""
M.clue_count_input = 1
M.is_typing_clue = false

-- Background pattern (loaded from assets)
M.bg_pattern_img = -1
M.BG_PATTERN_SIZE = 16

-- ---------------------------------------------------------------------------
-- Array helpers
-- ---------------------------------------------------------------------------
function M.array_has(arr, val)
    for _, v in ipairs(arr) do
        if v == val then return true end
    end
    return false
end

function M.array_erase(arr, val)
    for i = #arr, 1, -1 do
        if arr[i] == val then
            table.remove(arr, i)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Team helpers
-- ---------------------------------------------------------------------------
function M.get_spymaster(team)
    if team == "red" then return M.red_spymaster end
    return M.blue_spymaster
end

function M.get_operatives(team)
    if team == "red" then return M.red_operatives end
    return M.blue_operatives
end

function M.user_id()
    return api.get_user_id()
end

function M.is_host()
    if api.get_participant_count() == 0 then return false end
    local first = api.get_participant(0)
    local first_id = tostring(first)
    if type(first) == "userdata" then
        local ok, uid = pcall(function() return first["user_id"] end)
        if ok and uid ~= nil and tostring(uid) ~= "" then
            first_id = tostring(uid)
        else
            local ok2, fid = pcall(function() return first["id"] end)
            if ok2 and fid ~= nil then
                first_id = tostring(fid)
            end
        end
    end
    return first_id == M.user_id()
end

function M.is_spymaster()
    return M.user_id() == M.get_spymaster(M.current_team)
end

function M.is_current_operative()
    return M.array_has(M.get_operatives(M.current_team), M.user_id())
end

function M.user_team()
    local uid = M.user_id()
    if M.red_spymaster == uid or M.array_has(M.red_operatives, uid) then return "red" end
    if M.blue_spymaster == uid or M.array_has(M.blue_operatives, uid) then return "blue" end
    return ""
end

function M.is_user_spymaster_of_any_team()
    local uid = M.user_id()
    return uid == M.red_spymaster or uid == M.blue_spymaster
end

function M.remove_user_from_teams(uid)
    if M.red_spymaster == uid then M.red_spymaster = "" end
    M.array_erase(M.red_operatives, uid)
    if M.blue_spymaster == uid then M.blue_spymaster = "" end
    M.array_erase(M.blue_operatives, uid)
end

-- ---------------------------------------------------------------------------
-- Turn management
-- ---------------------------------------------------------------------------
function M.end_turn()
    if M.current_team == "red" then
        M.current_team = "blue"
    else
        M.current_team = "red"
    end
    M.clue_word = ""
    M.clue_count = 0
    M.guesses_remaining = 0
    M.phase = "clue"
    M.is_typing_clue = false
    M.clue_input = ""
    M.clue_count_input = 1
end

return M
