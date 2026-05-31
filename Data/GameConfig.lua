-- ============================================================
-- Data/GameConfig.lua
-- 游戏全局数值配置
-- ============================================================

---@class GameConfig
local GameConfig = {
    -- 初始属性
    INITIAL_CLICK_POWER         = 1,
    INITIAL_BRAINROT            = 0,
    INITIAL_BRAINROT_PER_SECOND = 0,
    INITIAL_COMBO_COUNT         = 0,
    INITIAL_COMBO_MULTIPLIER    = 1,
    INITIAL_TICK_COUNTER        = 0,

    -- 狂热时刻：连击阈值与倍率
    COMBO_TIERS                 = {
        { threshold = 20,  multiplier = 2 },
        { threshold = 50,  multiplier = 3 },
        { threshold = 100, multiplier = 5 },
    },
    COMBO_CLICK_GAIN            = 4,
    COMBO_DECAY_RATE            = 1,
    COMBO_MAX                   = 100,
    -- 连击的衰减和重置间隔
    COMBO_TICK_INTERVAL         = 0.1,
    -- combo 超时重置：0.1秒定时器 tick 数（15 × 0.1s = 1.5s）
    COMBO_RESET_TICKS           = 15,

    -- 被动产出
    BRAINROT_PER_SECOND_TICK_INTERVAL           = 1.0,
    BRAINROT_PER_SECOND_EASTER_BONUS_MULTIPLIER = 10,

    -- TODO:
    -- 屏幕彩蛋
    EASTER_EGG_MIN              = 15, -- 最短刷新间隔（秒）
    EASTER_EGG_MAX              = 45, -- 最长刷新间隔（秒）
    EASTER_EGG_DURATION         = 10, -- BPS×10 持续时间（秒）

    -- 数字格式阈值
    K_THRESHOLD                 = 1000,
    M_THRESHOLD                 = 1000000,
    B_THRESHOLD                 = 1000000000,
}

return GameConfig
