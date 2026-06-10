-- ============================================================
-- Lottery/LotteryConfig.lua
-- 转盘抽奖配置：奖励权重 + 转盘画布节点 + 动画节奏。
-- ============================================================

---@class LotteryPrizeReward
---@field item_id integer   奖励物件（BoothConfig.ITEMS 的 id，脑红1~5 = 101~105）
---@field level integer|nil 发放等级（缺省 1；属性按合成成长曲线折算，超出合成上限则封顶）

---@class LotteryPrize
---@field id string
---@field name string
---@field weight integer
---@field reward LotteryPrizeReward|nil 中奖发放的物件（nil = 仅提示不发放）

---@class LotteryCard
---@field prize_id string  对应奖励 id（见 PRIZES）
---@field card string      卡片节点名（UINodes 键）

---@class LotteryConfig
local LotteryConfig = {
    -- 转盘画布节点（均为 Data/UINodes.lua 中的键）
    CANVAS_NAME = "转盘画布",
    BUTTON_NAME = "抽奖",

    -- 转盘画布开关的自定义事件（画布在编辑器绑定了 show/hide_event）
    EVENTS = {
        open = "OPEN_LOTTERY_CANVAS",
        close = "CLOSE_LOTTERY_CANVAS",
    },

    -- 入口按钮（世界画布）/ 关闭按钮（转盘画布内）节点名
    BUTTONS = {
        open = "btn_lottery_spin",
        close = "关闭",
    },

    TIP_DURATION = 2.0,

    ---@type LotteryPrize[]
    PRIZES = {
        { id = "common", name = "普通奖励", weight = 70, reward = { item_id = 101, level = 1 } },
        { id = "rare", name = "稀有奖励", weight = 25, reward = { item_id = 103, level = 1 } },
        { id = "legendary", name = "传说奖励", weight = 5, reward = { item_id = 105, level = 2 } },
    },

    -- 卡片按从左到右的视觉顺序排列，选中框依此顺序循环。
    -- 每张卡在画布上须配一个选中框节点，命名约定为 "选中框_" .. card，
    -- 例如 "蓝色卡片" → "选中框_蓝色卡片"。框由编辑器与卡片对齐摆放，
    -- 运行时仅做显隐，新增卡片无需任何位置/百分比配置。
    ---@type LotteryCard[]
    CARDS = {
        { prize_id = "common", card = "蓝色卡片" },
        { prize_id = "legendary", card = "彩色卡片" },
        { prize_id = "rare", card = "橙色卡片" },
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
