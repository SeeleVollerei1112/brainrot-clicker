-- ============================================================
-- main.lua
-- Brainrot Clicker lifecycle entrypoint.
-- ============================================================

local GameApp = require("App.GameApp")


LuaAPI.global_register_trigger_event(
    { EVENT.GAME_INIT },
    function()
        GameApp.initialize()
    end
)

LuaAPI.global_register_trigger_event(
    { EVENT.GAME_END },
    function()
        GameApp.shutdown()
    end
)
