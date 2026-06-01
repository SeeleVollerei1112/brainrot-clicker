-- ============================================================
-- UI/CharacterView.lua
-- Bind the click target and play character-only visual feedback.
-- ============================================================

local CharacterView = {}
local UIConfig = require("Data.UIConfig")
local GameConfiguration = UIConfig.CHARACTER
local node = {}
local squeeze_generations_by_role_id = {}
local lifecycle_generation = 0

local function play_burst(role)
end
