-- ============================================================
-- Lottery/LotteryConfig.lua
-- 转盘抽奖配置：奖励权重 + 转盘画布节点 + 动画节奏。
-- ============================================================

---@class LotteryPrize
---@field id string
---@field name string
---@field weight integer

---@class LotteryCard
---@field prize_id string  对应奖励 id（见 PRIZES）
---@field card string      卡片节点名（UINodes 键）
---@field center_pct number  边框停在该卡时，水平中心位置占画布宽度的百分比(0~100)

---@class LotteryConfig
local LotteryConfig = {
    -- 转盘画布节点（均为 Data/UINodes.lua 中的键）
    CANVAS_NAME = "转盘画布",
    BUTTON_NAME = "抽奖",
    BORDER_NAME = "选中卡片",

    TOUCH_CLICK = 1,
    TIP_DURATION = 2.0,

    ---@type LotteryPrize[]
    PRIZES = {
        { id = "common", name = "普通奖励", weight = 70 },
        { id = "rare", name = "稀有奖励", weight = 25 },
        { id = "legendary", name = "传说奖励", weight = 5 },
    },

    -- 三张卡片，按从左到右的视觉顺序排列，便于选中边框顺序循环。
    -- center_pct 为边框水平中心占画布宽度的百分比(0~100)；经跑测截图校准：
    -- 左 23 / 中 50 / 右 78，边框正好框住对应卡片。
    ---@type LotteryCard[]
    CARDS = {
        { prize_id = "common", card = "蓝色卡片", center_pct = 23.5 },
        { prize_id = "legendary", card = "彩色卡片", center_pct = 50 },
        { prize_id = "rare", card = "橙色卡片", center_pct = 77 },
    },

    -- 转动节奏（单位：帧）。先加速后减速，最终平滑停在中奖卡。
    SPIN = {
        BASE_LOOPS     = 10,   -- 至少经过的整圈数
        START_INTERVAL = 6,    -- 起步每步间隔帧（最慢）
        MIN_INTERVAL   = 3,    -- 中段每步间隔帧（最快）
        END_INTERVAL   = 16,   -- 收尾每步间隔帧（最慢）
        ACCEL_RATIO    = 0.55, -- 前 55% 行程加速，其后减速
        SETTLE_FRAMES  = 12,   -- 落定后中奖指示器额外停留帧数，再弹提示
    },
}

return LotteryConfig
