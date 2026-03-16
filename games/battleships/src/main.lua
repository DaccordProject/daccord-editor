-- Battleships — a scripted plugin for daccord.
--
-- Two players place ships on a 10x10 grid then take turns firing at each
-- other's fleet. Sink all enemy ships to win. All game logic + rendering
-- lives here; the server relays actions to both participants.
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
    S.init_grids()
end

function _draw()
    drawing.draw_background()

    if S.phase == "lobby" then
        drawing.draw_lobby()
    elseif S.phase == "placement" then
        drawing.draw_top_bar()
        drawing.draw_placement()
    elseif S.phase == "battle" then
        drawing.draw_top_bar()
        drawing.draw_battle()
    elseif S.phase == "game_over" then
        drawing.draw_top_bar()
        drawing.draw_game_over()
    end
end

function _input(event)
    input.handle_input(event)
end

function _on_event(event_type, data)
    events.dispatch(event_type, data)
end
