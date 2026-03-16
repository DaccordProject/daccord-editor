-- Codenames — a scripted plugin for daccord.
--
-- All game logic + rendering lives here. The server relays actions to all
-- session participants. Every client applies actions deterministically so
-- their states stay in sync. The host generates the initial board and
-- broadcasts it via the "start_game" action.
--
-- Bridge API (global `api` table from ScriptedRuntime):
--   api.draw_rect, api.draw_text, api.draw_line, api.draw_circle,
--   api.send_action, api.get_participants, api.get_role, api.get_user_id,
--   api.canvas_width, api.canvas_height

local S = require("state")
local events = require("events")
local drawing = require("drawing")
local input = require("input")

-- ---------------------------------------------------------------------------
-- Lifecycle functions (called by ScriptedRuntime)
-- ---------------------------------------------------------------------------

function _ready()
    math.randomseed(tonumber(tostring({}):match("0x(%x+)")) or 12345)

    local ok, img = pcall(function()
        local data = api.read_asset("assets/bg_pattern.png")
        return api.load_image(data)
    end)
    if ok and img and img >= 0 then
        S.bg_pattern_img = img
    end
end

function _draw()
    drawing.draw_background()

    if S.phase == "lobby" then
        drawing.draw_lobby()
    elseif S.phase == "clue" or S.phase == "guess" then
        drawing.draw_top_bar()
        drawing.draw_board()
        drawing.draw_bottom_bar()
    elseif S.phase == "game_over" then
        drawing.draw_top_bar()
        drawing.draw_board()
        drawing.draw_bottom_bar()
        drawing.draw_game_over_overlay()
    end
end

function _input(event)
    input.handle_input(event)
end

function _on_event(event_type, data)
    events.dispatch(event_type, data)
end
