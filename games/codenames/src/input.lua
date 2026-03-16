-- Input handling and hit testing for Codenames

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

local function hit_test_card(mx, my)
    for row = 0, C.GRID_ROWS - 1 do
        for col = 0, C.GRID_COLS - 1 do
            local cx = C.GRID_X + col * (C.CARD_W + C.CARD_GAP_X)
            local cy = C.GRID_Y + row * (C.CARD_H + C.CARD_GAP_Y)
            if mx >= cx and mx < cx + C.CARD_W and my >= cy and my < cy + C.CARD_H then
                return row * C.GRID_COLS + col
            end
        end
    end
    return -1
end

-- ---------------------------------------------------------------------------
-- Click handlers
-- ---------------------------------------------------------------------------
local function send_join(team, role)
    api.send_action(Dictionary{
        action = "join_team",
        team = team,
        role = role,
        user_id = S.user_id(),
    })
end

local function can_start()
    local red_count = #S.red_operatives
    if S.red_spymaster ~= "" then red_count = red_count + 1 end
    local blue_count = #S.blue_operatives
    if S.blue_spymaster ~= "" then blue_count = blue_count + 1 end
    return red_count >= 1 and blue_count >= 1
end

local function handle_lobby_click(mx, my)
    if hit_rect(mx, my, 120, 120, 180, 36) then
        send_join("red", "spymaster")
    elseif hit_rect(mx, my, 120, 164, 180, 36) then
        send_join("red", "operative")
    elseif hit_rect(mx, my, 340, 120, 180, 36) then
        send_join("blue", "spymaster")
    elseif hit_rect(mx, my, 340, 164, 180, 36) then
        send_join("blue", "operative")
    elseif hit_rect(mx, my, 240, 350, 160, 40) and S.is_host() then
        if can_start() then
            events.generate_board_action()
        end
    end
end

local function handle_clue_key(keycode, unicode)
    -- Enter
    if keycode == 4194304 then
        if #S.clue_input > 0 and S.clue_count_input > 0 then
            api.send_action(Dictionary{
                action = "give_clue",
                word = string.upper(S.clue_input),
                count = S.clue_count_input,
                user_id = S.user_id(),
            })
            S.is_typing_clue = false
        end
        return
    end

    -- Backspace
    if keycode == 4194308 then
        if #S.clue_input > 0 then
            S.clue_input = string.sub(S.clue_input, 1, #S.clue_input - 1)
        end
        return
    end

    -- Escape
    if keycode == 4194305 then
        S.is_typing_clue = false
        return
    end

    -- Printable character
    if unicode >= 32 and unicode < 127 and #S.clue_input < 20 then
        local ch = string.char(unicode)
        if string.upper(ch) >= "A" and string.upper(ch) <= "Z" then
            S.clue_input = S.clue_input .. ch
        end
    end
end

local function handle_clue_click(mx, my)
    if not S.is_spymaster() then return end

    if hit_rect(mx, my, 160, 440, 240, 30) then
        S.is_typing_clue = true
        return
    end

    if hit_rect(mx, my, 410, 440, 30, 30) then
        if S.clue_count_input > 0 then
            S.clue_count_input = S.clue_count_input - 1
        end
        return
    end

    if hit_rect(mx, my, 480, 440, 30, 30) then
        if S.clue_count_input < 9 then
            S.clue_count_input = S.clue_count_input + 1
        end
        return
    end

    if hit_rect(mx, my, 520, 440, 100, 30) then
        if #S.clue_input > 0 and S.clue_count_input > 0 then
            api.send_action(Dictionary{
                action = "give_clue",
                word = string.upper(S.clue_input),
                count = S.clue_count_input,
                user_id = S.user_id(),
            })
        end
        return
    end

    S.is_typing_clue = false
end

local function handle_guess_click(mx, my)
    if not S.is_current_operative() then return end

    if hit_rect(mx, my, 250, 445, 140, 28) then
        api.send_action(Dictionary{
            action = "end_guessing",
            user_id = S.user_id(),
        })
        return
    end

    local idx = hit_test_card(mx, my)
    if idx >= 0 and S.board_revealed[idx + 1] == 0 then
        api.send_action(Dictionary{
            action = "guess_card",
            index = idx,
            user_id = S.user_id(),
        })
    end
end

local function handle_game_over_click(mx, my)
    if hit_rect(mx, my, 250, 370, 140, 40) and S.is_host() then
        api.send_action(Dictionary{
            action = "new_game",
            user_id = S.user_id(),
        })
    end
end

-- ---------------------------------------------------------------------------
-- Main input handler
-- ---------------------------------------------------------------------------
function M.handle_input(event)
    local etype = tostring(event["type"] or "")
    if etype == "mouse_button" then
        print("[LuaInput] MOUSE_BUTTON pressed=" .. tostring(event["pressed"]) .. " btn=" .. tostring(event["button_index"]) .. " x=" .. tostring(event["position_x"]) .. " y=" .. tostring(event["position_y"]))
    end

    if etype == "mouse_motion" then
        S.mouse_x = tonumber(event["position_x"] or 0)
        S.mouse_y = tonumber(event["position_y"] or 0)
        S.hover_card = hit_test_card(S.mouse_x, S.mouse_y)

    elseif etype == "mouse_button" then
        local pressed = event["pressed"]
        local btn_raw = event["button_index"]
        print("[LuaInput] pressed=" .. tostring(pressed) .. " type=" .. type(pressed) .. " btn_raw=" .. tostring(btn_raw) .. " type=" .. type(btn_raw))
        if not pressed then return end
        local btn = math.floor(tonumber(event["button_index"] or 0))
        if btn ~= 1 then return end

        S.mouse_x = tonumber(event["position_x"] or 0)
        S.mouse_y = tonumber(event["position_y"] or 0)
        print("[LuaInput] click at " .. S.mouse_x .. "," .. S.mouse_y .. " phase=" .. S.phase)

        if S.phase == "lobby" then
            handle_lobby_click(S.mouse_x, S.mouse_y)
        elseif S.phase == "clue" then
            handle_clue_click(S.mouse_x, S.mouse_y)
        elseif S.phase == "guess" then
            handle_guess_click(S.mouse_x, S.mouse_y)
        elseif S.phase == "game_over" then
            handle_game_over_click(S.mouse_x, S.mouse_y)
        end

    elseif etype == "key" then
        local pressed = event["pressed"]
        if not pressed then return end
        local keycode = math.floor(tonumber(event["keycode"] or 0))
        local unicode = math.floor(tonumber(event["unicode"] or 0))

        if S.is_typing_clue then
            handle_clue_key(keycode, unicode)
        end
    end
end

return M
