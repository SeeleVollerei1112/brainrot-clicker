-- ============================================================
-- main.lua
-- Brainrot Clicker lifecycle entrypoint.
-- ============================================================

local GameController = require("Controllers.GameController")


LuaAPI.global_register_trigger_event(
    { EVENT.GAME_INIT },
    function()
        GameController.initialize()
    end
)

LuaAPI.global_register_trigger_event(
    { EVENT.GAME_END },
    function()
        GameController.shutdown()
    end
)
