-- ============================================================
-- Lottery/LotteryConfig.lua
-- Basic lottery configuration for logic verification.
-- ============================================================

---@class LotteryPrize
---@field id string
---@field name string
---@field weight integer

---@class LotteryConfig
local LotteryConfig = {
    BUTTON_NODE_NAME = "btn_lottery_spin",
    TOUCH_CLICK = 1,
    TIP_DURATION = 2.0,

    ---@type LotteryPrize[]
    PRIZES = {
        {
            id = "common",
            name = "普通奖励",
            weight = 70,
        },
        {
            id = "rare",
            name = "稀有奖励",
            weight = 25,
        },
        {
            id = "legendary",
            name = "传说奖励",
            weight = 5,
        },
    },
}

return LotteryConfig
