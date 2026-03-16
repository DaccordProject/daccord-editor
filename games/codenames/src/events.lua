-- Event handlers for Codenames (actions relayed by server)

local C = require("constants")
local S = require("state")

local M = {}

function M.handle_join_team(data)
    if S.phase ~= "lobby" then return end
    local uid = tostring(data["user_id"] or "")
    local team = tostring(data["team"] or "")
    local role = tostring(data["role"] or "")
    if team ~= "red" and team ~= "blue" then return end
    if role ~= "spymaster" and role ~= "operative" then return end

    S.remove_user_from_teams(uid)

    if role == "spymaster" then
        if team == "red" then
            S.red_spymaster = uid
        else
            S.blue_spymaster = uid
        end
    else
        if team == "red" then
            if not S.array_has(S.red_operatives, uid) then
                table.insert(S.red_operatives, uid)
            end
        else
            if not S.array_has(S.blue_operatives, uid) then
                table.insert(S.blue_operatives, uid)
            end
        end
    end
end

function M.handle_start_game(data)
    if S.phase ~= "lobby" then return end

    local widx = data["word_idx"]
    local clrs = data["colors"]
    if widx == nil or clrs == nil then return end
    if #widx ~= C.CARD_COUNT or #clrs ~= C.CARD_COUNT then return end

    S.board_word_idx = {}
    S.board_colors = {}
    S.board_revealed = {}
    S.target_red = 0
    S.target_blue = 0

    for i = 0, C.CARD_COUNT - 1 do
        local wi = math.floor(tonumber(widx[i]))
        local clr = math.floor(tonumber(clrs[i]))
        table.insert(S.board_word_idx, wi)
        table.insert(S.board_colors, clr)
        table.insert(S.board_revealed, 0)
        if clr == C.CLR_RED then
            S.target_red = S.target_red + 1
        elseif clr == C.CLR_BLUE then
            S.target_blue = S.target_blue + 1
        end
    end

    S.score_red = 0
    S.score_blue = 0
    S.current_team = "red"
    S.clue_word = ""
    S.clue_count = 0
    S.guesses_remaining = 0
    S.winner = ""
    S.phase = "clue"
    S.is_typing_clue = false
    S.clue_input = ""
    S.clue_count_input = 1
end

function M.handle_give_clue(data)
    if S.phase ~= "clue" then return end
    local uid = tostring(data["user_id"] or "")
    local sm = S.get_spymaster(S.current_team)
    if uid ~= sm then return end

    S.clue_word = tostring(data["word"] or "")
    S.clue_count = math.floor(tonumber(data["count"] or 0))
    S.guesses_remaining = S.clue_count + 1
    S.phase = "guess"
    S.is_typing_clue = false
end

function M.handle_guess_card(data)
    if S.phase ~= "guess" then return end
    local uid = tostring(data["user_id"] or "")
    local ops = S.get_operatives(S.current_team)
    if not S.array_has(ops, uid) then return end

    local idx = math.floor(tonumber(data["index"] or -1))
    local li = idx + 1
    if li < 1 or li > C.CARD_COUNT then return end
    if S.board_revealed[li] == 1 then return end

    S.board_revealed[li] = 1
    local card_color = S.board_colors[li]

    if card_color == C.CLR_RED then
        S.score_red = S.score_red + 1
    elseif card_color == C.CLR_BLUE then
        S.score_blue = S.score_blue + 1
    end

    -- Check win conditions
    if card_color == C.CLR_ASSASSIN then
        S.winner = S.current_team == "red" and "blue" or "red"
        S.phase = "game_over"
        return
    end

    if S.score_red >= S.target_red then
        S.winner = "red"
        S.phase = "game_over"
        return
    end
    if S.score_blue >= S.target_blue then
        S.winner = "blue"
        S.phase = "game_over"
        return
    end

    -- Wrong color or neutral — end turn
    local current_clr = S.current_team == "red" and C.CLR_RED or C.CLR_BLUE
    if card_color ~= current_clr then
        S.end_turn()
        return
    end

    -- Correct guess
    S.guesses_remaining = S.guesses_remaining - 1
    if S.guesses_remaining <= 0 then
        S.end_turn()
    end
end

function M.handle_end_guessing(data)
    if S.phase ~= "guess" then return end
    local uid = tostring(data["user_id"] or "")
    local ops = S.get_operatives(S.current_team)
    if not S.array_has(ops, uid) then return end
    S.end_turn()
end

function M.handle_new_game(data)
    S.phase = "lobby"
    S.board_word_idx = {}
    S.board_colors = {}
    S.board_revealed = {}
    S.red_spymaster = ""
    S.red_operatives = {}
    S.blue_spymaster = ""
    S.blue_operatives = {}
    S.current_team = "red"
    S.clue_word = ""
    S.clue_count = 0
    S.guesses_remaining = 0
    S.score_red = 0
    S.score_blue = 0
    S.target_red = 9
    S.target_blue = 8
    S.winner = ""
    S.is_typing_clue = false
    S.clue_input = ""
end

-- Board generation (host only)
local function shuffle(arr)
    for i = #arr, 2, -1 do
        local j = math.random(1, i)
        arr[i], arr[j] = arr[j], arr[i]
    end
end

function M.generate_board_action()
    local indices = {}
    for i = 0, #C.WORDS - 1 do
        table.insert(indices, i)
    end
    shuffle(indices)

    local word_idx = {}
    for i = 1, C.CARD_COUNT do
        table.insert(word_idx, indices[i])
    end

    -- Assign colors: 9 red, 8 blue, 7 neutral, 1 assassin
    local colors = {}
    for _ = 1, 9 do table.insert(colors, C.CLR_RED) end
    for _ = 1, 8 do table.insert(colors, C.CLR_BLUE) end
    for _ = 1, 7 do table.insert(colors, C.CLR_NEUTRAL) end
    table.insert(colors, C.CLR_ASSASSIN)
    shuffle(colors)

    api.send_action(Dictionary{
        action = "start_game",
        word_idx = Array(word_idx),
        colors = Array(colors),
        user_id = S.user_id(),
    })
end

function M.dispatch(event_type, data)
    if event_type ~= "action" then return end

    local action = tostring(data["action"] or "")
    if action == "join_team" then
        M.handle_join_team(data)
    elseif action == "start_game" then
        M.handle_start_game(data)
    elseif action == "give_clue" then
        M.handle_give_clue(data)
    elseif action == "guess_card" then
        M.handle_guess_card(data)
    elseif action == "end_guessing" then
        M.handle_end_guessing(data)
    elseif action == "new_game" then
        M.handle_new_game(data)
    end
end

return M
