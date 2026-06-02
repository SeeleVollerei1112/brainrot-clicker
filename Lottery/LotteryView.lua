-- ============================================================
-- Lottery/LotteryView.lua
-- 转盘抽奖的视觉表现：选中边框在三张卡片间循环（先加速后减速），
-- 每经过一张卡对应指示器亮起后熄灭，最终平滑停在中奖卡。
--
-- 选中边框(选中卡片)位置通过 GameAPI.set_eui_node_horizontal_auto_center
-- 驱动——这是全局节点属性，所有客户端看到同一次转动，因此用单次锁
-- 保证同一时刻只有一次转动。指示器亮灭用 Role 方法，针对触发玩家。
-- ============================================================

local UINodes = require("Data.UINodes")
local LotteryConfig = require("Lottery.LotteryConfig")

local LotteryView = {}

local tf = math.tofixed

-- 解析后的节点引用
local canvas = nil
local border = nil
local button = nil
---@type { card:ENode, center_pct:number }[]
local cards = {}

-- 失效保护 + 单次锁
local lifecycle_generation = 0
local spin_generation = 0
local is_spinning = false
-- 上次边框停靠的卡片下标（默认中间卡）
local last_index = 2

---@param name string
---@return ENode|nil
local function node(name)
    return UINodes[name]
end

---绑定转盘画布节点。GAME_INIT 时调用一次。
function LotteryView.initialize()
    lifecycle_generation = lifecycle_generation + 1
    spin_generation = 0
    is_spinning = false
    last_index = 2

    canvas = node(LotteryConfig.CANVAS_NAME)
    border = node(LotteryConfig.BORDER_NAME)
    button = node(LotteryConfig.BUTTON_NAME)

    cards = {}
    for index, card in ipairs(LotteryConfig.CARDS) do
        cards[index] = {
            card = node(card.card),
            center_pct = card.center_pct,
        }
    end

    if not border then
        LuaAPI.log("[LotteryView] 缺少选中边框节点: " .. LotteryConfig.BORDER_NAME, 1)
    end
end

---@return ENode|nil button
function LotteryView.get_button()
    return button
end

---@return boolean
function LotteryView.is_spinning()
    return is_spinning
end

-- 把选中边框移动到第 index 张卡的水平位置（按画布宽度百分比定位）。
---@param index integer
local function move_border(index)
    if not border then
        return
    end
    GameAPI.set_eui_node_horizontal_auto_center(border, true, true, tf(cards[index].center_pct))
end

-- 计算从 start_index 出发、落在 target_index 所需的总步数（含基础整圈）。
---@param start_index integer
---@param target_index integer
---@return integer total_steps
local function resolve_total_steps(start_index, target_index)
    local n = #cards
    local total = LotteryConfig.SPIN.BASE_LOOPS * n
    -- (start-1 + total) % n 应等于 target-1，否则补足差值
    local landed = (start_index - 1 + total) % n
    local want = target_index - 1
    local delta = (want - landed) % n
    return total + delta
end

-- 第 k 步（1..total）的间隔帧：先由 START 递减到 MIN，再递增到 END。
---@param k integer
---@param total integer
---@return integer frames
local function interval_at(k, total)
    local spin = LotteryConfig.SPIN
    local f = (total > 1) and (k - 1) / (total - 1) or 0
    local r = spin.ACCEL_RATIO
    local iv
    if f <= r then
        local t = (r > 0) and (f / r) or 1
        iv = spin.START_INTERVAL + (spin.MIN_INTERVAL - spin.START_INTERVAL) * t
    else
        local t = (r < 1) and ((f - r) / (1 - r)) or 1
        iv = spin.MIN_INTERVAL + (spin.END_INTERVAL - spin.MIN_INTERVAL) * t
    end
    -- 帧同步环境下小数运算结果为 Fix32，call_delay_frame 需要原生 int。
    local frames = math.tointeger(math.floor(iv + 0.5)) or 1
    if frames < 1 then
        frames = 1
    end
    return frames
end

---播放一次转动动画，保证停在 target_index，结束后回调 on_complete。
---@param role Role
---@param target_index integer
---@param on_complete fun()
function LotteryView.play_spin(role, target_index, on_complete)
    if is_spinning or not border or not role then
        return
    end
    if not target_index or not cards[target_index] then
        if on_complete then on_complete() end
        return
    end

    is_spinning = true
    spin_generation = spin_generation + 1
    local my_generation = spin_generation
    local my_lifecycle = lifecycle_generation

    local total = resolve_total_steps(last_index, target_index)
    local n = #cards

    if button then
        role.set_button_enabled(button, false)
    end

    local function is_valid()
        return my_lifecycle == lifecycle_generation and my_generation == spin_generation
    end

    local function finish(index)
        last_index = index
        is_spinning = false
        if button then
            role.set_button_enabled(button, true)
        end
        -- 边框停在中奖卡片上停留片刻，再弹出提示
        LuaAPI.call_delay_frame(math.tointeger(LotteryConfig.SPIN.SETTLE_FRAMES) or 1, function()
            if on_complete then
                on_complete()
            end
        end)
    end

    -- 第 k 步：把边框移到 index 卡。
    local function step(k, index)
        if not is_valid() then
            return
        end
        move_border(index)

        if k >= total then
            finish(index)
            return
        end

        local next_index = index % n + 1
        LuaAPI.call_delay_frame(interval_at(k, total), function()
            step(k + 1, next_index)
        end)
    end

    -- 从 last_index 出发，第一步前进到下一张卡。
    local first_index = last_index % n + 1
    step(1, first_index)
end

return LotteryView
