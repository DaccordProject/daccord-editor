-- Drawing functions for Codenames

local C = require("constants")
local S = require("state")

local M = {}

function M.draw_background()
    api.draw_rect(0, 0, C.CW, C.CH, C.BG_COLOR, true)
    if S.bg_pattern_img >= 0 then
        for ty = 0, C.CH - 1, S.BG_PATTERN_SIZE do
            for tx = 0, C.CW - 1, S.BG_PATTERN_SIZE do
                api.draw_image(S.bg_pattern_img, tx, ty)
            end
        end
    end
end

function M.draw_button(x, y, w, h, label, color)
    local bg = color
    if S.mouse_x >= x and S.mouse_x < x + w and S.mouse_y >= y and S.mouse_y < y + h then
        bg = C.BTN_HOVER
    end
    api.draw_rect(x, y, w, h, bg, true)
    local tx = x + (w - #label * 8.0) / 2.0
    local ty = y + h * 0.7
    api.draw_text(tx, ty, label, C.TEXT_COLOR, 14)
end

function M.draw_lobby()
    api.draw_text(220, 30, "CODENAMES", C.TEXT_COLOR, 28)
    api.draw_text(210, 58, "Choose your team and role", C.TEXT_DIM, 14)

    -- Red team buttons
    api.draw_text(160, 100, "RED TEAM", C.CARD_RED, 18)
    api.draw_rect(120, 120, 180, 36, "#455a64", true)
    api.draw_rect(120, 120, 180, 36, C.CARD_RED, false)
    api.draw_text(160, 144, "Spymaster", C.TEXT_COLOR, 16)
    api.draw_rect(120, 164, 180, 36, "#455a64", true)
    api.draw_rect(120, 164, 180, 36, C.CARD_RED, false)
    api.draw_text(160, 188, "Operative", C.TEXT_COLOR, 16)

    -- Blue team buttons
    api.draw_text(380, 100, "BLUE TEAM", C.CARD_BLUE, 18)
    api.draw_rect(340, 120, 180, 36, "#455a64", true)
    api.draw_rect(340, 120, 180, 36, C.CARD_BLUE, false)
    api.draw_text(380, 144, "Spymaster", C.TEXT_COLOR, 16)
    api.draw_rect(340, 164, 180, 36, "#455a64", true)
    api.draw_rect(340, 164, 180, 36, C.CARD_BLUE, false)
    api.draw_text(380, 188, "Operative", C.TEXT_COLOR, 16)

    api.draw_line(320, 90, 320, 320, C.TEXT_DIM, 1.0)

    -- Start button
    api.draw_rect(240, 350, 160, 40, C.BTN_COLOR, true)
    api.draw_text(270, 378, "START GAME", C.TEXT_COLOR, 14)
end

function M.draw_top_bar()
    api.draw_rect(0, 0, C.CW, C.TOP_BAR_H, C.TOP_BAR_COLOR, true)

    api.draw_rect(8, 6, 80, 28, C.CARD_RED, true)
    api.draw_text(16, 27, string.format("RED: %d/%d", S.score_red, S.target_red), C.TEXT_COLOR, 14)

    api.draw_rect(100, 6, 80, 28, C.CARD_BLUE, true)
    api.draw_text(108, 27, string.format("BLU: %d/%d", S.score_blue, S.target_blue), C.TEXT_COLOR, 14)

    local phase_text = ""
    if S.phase == "clue" then
        phase_text = string.format("%s's spymaster giving clue", string.upper(S.current_team))
    elseif S.phase == "guess" then
        phase_text = string.format("%s guessing (%d left)", string.upper(S.current_team), S.guesses_remaining)
    elseif S.phase == "game_over" then
        phase_text = string.format("%s WINS!", string.upper(S.winner))
    end
    api.draw_text(240, 27, phase_text, C.TEXT_COLOR, 14)

    local dot_color = S.current_team == "red" and C.CARD_RED or C.CARD_BLUE
    api.draw_circle(225, 20, 6.0, dot_color)
end

function M.draw_board()
    local is_spy = S.is_user_spymaster_of_any_team()

    for row = 0, C.GRID_ROWS - 1 do
        for col = 0, C.GRID_COLS - 1 do
            local idx = row * C.GRID_COLS + col
            local li = idx + 1
            local cx = C.GRID_X + col * (C.CARD_W + C.CARD_GAP_X)
            local cy = C.GRID_Y + row * (C.CARD_H + C.CARD_GAP_Y)
            local word = C.WORDS[S.board_word_idx[li] + 1]
            local clr = S.board_colors[li]
            local revealed = S.board_revealed[li]

            if revealed == 1 then
                local bg = C.color_int_to_hex(clr)
                api.draw_rect(cx, cy, C.CARD_W, C.CARD_H, bg, true)
                api.draw_text(cx + 6, cy + 42, word, C.TEXT_COLOR, 13)
            else
                local bg = C.CARD_UNREVEALED
                if S.hover_card == idx and S.phase == "guess" and S.is_current_operative() then
                    bg = C.CARD_HOVER
                end
                api.draw_rect(cx, cy, C.CARD_W, C.CARD_H, bg, true)
                api.draw_text(cx + 6, cy + 42, word, C.TEXT_COLOR, 13)

                if is_spy then
                    local tint = C.spy_tint_for_int(clr)
                    api.draw_rect(cx, cy, C.CARD_W, C.CARD_H, tint, true)
                end
            end

            local border_color = C.TEXT_DIM
            if S.hover_card == idx then
                border_color = C.TEXT_COLOR
            end
            api.draw_rect(cx, cy, C.CARD_W, C.CARD_H, border_color, false)
        end
    end
end

function M.draw_bottom_bar()
    api.draw_rect(0, C.BOTTOM_BAR_Y, C.CW, C.CH - C.BOTTOM_BAR_Y, C.BOTTOM_BAR_COLOR, true)

    if S.phase == "clue" then
        if S.is_spymaster() then
            api.draw_text(20, 458, "Your clue:", C.TEXT_COLOR, 14)

            local tf_bg = C.CLUE_BG
            if S.is_typing_clue then tf_bg = "#1a1a2e" end
            api.draw_rect(160, 440, 240, 30, tf_bg, true)
            api.draw_rect(160, 440, 240, 30, C.TEXT_DIM, false)

            local display_text = "type clue..."
            if #S.clue_input > 0 then display_text = S.clue_input end
            local text_col = C.TEXT_DIM
            if #S.clue_input > 0 then text_col = C.TEXT_COLOR end
            api.draw_text(168, 462, display_text, text_col, 14)

            if S.is_typing_clue then
                local cursor_x = 168 + #S.clue_input * 9.0
                api.draw_line(cursor_x, 444, cursor_x, 466, C.TEXT_COLOR, 1.0)
            end

            api.draw_rect(410, 440, 30, 30, C.CLUE_BG, true)
            api.draw_text(420, 462, "-", C.TEXT_COLOR, 16)
            api.draw_rect(445, 440, 30, 30, C.CLUE_BG, true)
            api.draw_text(454, 462, tostring(S.clue_count_input), C.TEXT_COLOR, 16)
            api.draw_rect(480, 440, 30, 30, C.CLUE_BG, true)
            api.draw_text(488, 462, "+", C.TEXT_COLOR, 16)

            local can_submit = #S.clue_input > 0 and S.clue_count_input > 0
            local btn_c = can_submit and C.BTN_COLOR or "#455a64"
            M.draw_button(520, 440, 100, 30, "GIVE CLUE", btn_c)
        else
            api.draw_text(200, 458,
                string.format("Waiting for %s's spymaster...", string.upper(S.current_team)),
                C.TEXT_DIM, 14)
        end

    elseif S.phase == "guess" then
        api.draw_text(20, 458,
            string.format("Clue: %s %d", S.clue_word, S.clue_count),
            C.TEXT_COLOR, 16)
        api.draw_text(300, 458,
            string.format("Guesses remaining: %d", S.guesses_remaining),
            C.TEXT_DIM, 14)

        if S.is_current_operative() then
            M.draw_button(250, 445, 140, 28, "END GUESSING", C.BTN_COLOR)
        end

    elseif S.phase == "game_over" then
        api.draw_text(220, 458,
            string.format("Game over! %s team wins!", string.upper(S.winner)),
            C.TEXT_COLOR, 16)
    end
end

function M.draw_game_over_overlay()
    api.draw_rect(0, 0, C.CW, C.CH, {0.0, 0.0, 0.0, 0.6}, true)

    local banner_color = S.winner == "red" and C.CARD_RED or C.CARD_BLUE
    api.draw_rect(140, 180, 360, 100, banner_color, true)
    api.draw_text(200, 230,
        string.format("%s TEAM WINS!", string.upper(S.winner)),
        C.TEXT_COLOR, 28)
    api.draw_text(220, 260,
        string.format("Red: %d | Blue: %d", S.score_red, S.score_blue),
        C.TEXT_COLOR, 16)

    if S.is_host() then
        M.draw_button(250, 370, 140, 40, "NEW GAME", C.BTN_COLOR)
    end
end

return M
