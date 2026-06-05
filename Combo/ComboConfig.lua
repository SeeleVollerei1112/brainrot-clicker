--[[
Combo/ComboConfig.lua

连击配置：连击增长、衰减、倍率档位和连击条反馈参数。
]]

---@class ComboConfig
local ComboConfig = {
    TIERS = {
        { threshold = 20,  multiplier = 2 },
        { threshold = 50,  multiplier = 3 },
        { threshold = 100, multiplier = 5 },
    },
    CLICK_GAIN = 4,
    DECAY_RATE = 1,
    MAX = 100,
    TICK_INTERVAL = 0.1,
    RESET_TICKS = 15,

    BAR = {
        nodes = {
            bar = "combo_bar",
            label = "combo_label",
        },
        settle_size = 64,
        pop_start_size = 40,
        pop_peak_size = 110,
        pop_grow_duration = 0.10,
        pop_settle_duration = 0.12,
        pop_start_delay_frames = 1,
        pop_settle_delay_frames = 15,
        shadow_sweep = { 0, 5, 10, 13, 10, 5, 0 },
        shadow_sweep_frames = 5,
        shadow_reset_x = 0,
        shadow_reset_y = -4,
        tier_colors = {
            [1] = 0xFFFFD700,
            [2] = 0xFFFF8C00,
            [3] = 0xFFFF3300,
        },
        tier_texts = {
            [1] = "×2",
            [2] = "×3",
            [3] = "×5",
        },
        progress_transition = 0.10,
    },
}

return ComboConfig
