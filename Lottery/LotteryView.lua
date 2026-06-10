-- ============================================================
-- Lottery/LotteryView.lua
-- 转盘抽奖的视觉表现：每张卡片自带一个选中框，转动时在各卡的框之间
-- 逐一显隐（先加速后减速），最终停在中奖卡——其框保持点亮。
--
-- 选中框显隐通过 Role.set_node_visible 驱动，这是 per-Role 属性，因此每个
-- 玩家各自独立转动、只看到自己的高亮，互不干扰。所有玩家共享同一套框
-- 节点（显隐互不影响），转动状态按 role_id 分桶维护。
--
-- 框节点命名约定：每张卡 card 对应 "选中框_" .. card（前缀硬编码于此），
-- 由编辑器与卡片对齐摆放。新增卡片无需任何位置配置。
-- ============================================================

local UINodes = require("Data.UINodes")
local LotteryConfig = require("Lottery.LotteryConfig")

local LotteryView = {}

-- 选中框节点命名前缀：框名 = FRAME_PREFIX .. 卡片名
local FRAME_PREFIX = "选中框_"

-- 解析后的共享节点引用（显隐是 per-Role 的，节点本身全局共享）
local button = nil
---@type { frame:ENode|nil }[]
local cards = {}

-- 全局生命周期代：GAME_INIT / shutdown 时自增，使在途延迟回调失效
local lifecycle_generation = 0

-- per-Role 转动状态
---@type table<RoleID, boolean>
local is_spinning_by_role = {}
---@type table<RoleID, integer>  每次转动自增，用于使旧转动的延迟回调失效
local spin_generation_by_role = {}
---@type table<RoleID, integer>  上次停靠的卡片下标（决定下次转动起点）
local last_index_by_role = {}
---@type table<RoleID, integer>  当前对该玩家点亮的框下标
local shown_index_by_role = {}

local get_role_id = require("Util.RoleUtil").get_role_id

---绑定转盘画布与各卡片的选中框节点。GAME_INIT 时调用一次。
function LotteryView.initialize()
    lifecycle_generation = lifecycle_generation + 1
    is_spinning_by_role = {}
    spin_generation_by_role = {}
    last_index_by_role = {}
    shown_index_by_role = {}

    button = UINodes[LotteryConfig.BUTTON_NAME]

    cards = {}
    for index, card in ipairs(LotteryConfig.CARDS) do
        local frame_name = FRAME_PREFIX .. card.card
        local frame = UINodes[frame_name]
        cards[index] = { frame = frame }
        if not frame then
            LuaAPI.log("[LotteryView] 缺少选中框节点: " .. frame_name, 1)
        end
    end
end

---对该玩家隐藏全部选中框。
---@param role Role
local function hide_all_frames(role)
    for _, entry in ipairs(cards) do
        if entry.frame then
            role.set_node_visible(entry.frame, false)
        end
    end
end

---为玩家初始化：隐藏其所有选中框并重置该玩家的转动状态。
---@param role Role
function LotteryView.initialize_role(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    hide_all_frames(role)

    is_spinning_by_role[role_id] = false
    spin_generation_by_role[role_id] = 0
    last_index_by_role[role_id] = 1
    shown_index_by_role[role_id] = nil
end

---玩家离开时：隐藏其框并丢弃其转动状态。
---@param role Role
function LotteryView.cleanup_role(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    hide_all_frames(role)

    is_spinning_by_role[role_id] = nil
    spin_generation_by_role[role_id] = nil
    last_index_by_role[role_id] = nil
    shown_index_by_role[role_id] = nil
end

---@return ENode|nil button
function LotteryView.get_button()
    return button
end

---该玩家当前是否正在转动。
---@param role Role
---@return boolean
function LotteryView.is_spinning(role)
    local role_id = get_role_id(role)
    if not role_id then
        return false
    end
    return is_spinning_by_role[role_id] == true
end

-- 仅对该玩家点亮第 index 张卡的框：熄灭上一个，再点亮当前。
---@param role Role
---@param role_id RoleID
---@param index integer
local function show_frame_only(role, role_id, index)
    local previous = shown_index_by_role[role_id]
    if previous and previous ~= index then
        local prev_entry = cards[previous]
        if prev_entry and prev_entry.frame then
            role.set_node_visible(prev_entry.frame, false)
        end
    end

    local entry = cards[index]
    if entry and entry.frame then
        role.set_node_visible(entry.frame, true)
    end

    shown_index_by_role[role_id] = index
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

---为玩家播放一次转动动画，保证停在 target_index，结束后回调 on_complete。
---@param role Role
---@param target_index integer
---@param on_complete fun()
function LotteryView.play_spin(role, target_index, on_complete)
    local role_id = get_role_id(role)
    if not role_id then
        if on_complete then on_complete() end
        return
    end
    if is_spinning_by_role[role_id] then
        return
    end
    if not target_index or not cards[target_index] then
        if on_complete then on_complete() end
        return
    end

    is_spinning_by_role[role_id] = true
    spin_generation_by_role[role_id] = (spin_generation_by_role[role_id] or 0) + 1
    local my_generation = spin_generation_by_role[role_id]
    local my_lifecycle = lifecycle_generation

    local last_index = last_index_by_role[role_id] or 1
    local n = #cards
    local total = resolve_total_steps(last_index, target_index)

    if button then
        role.set_button_enabled(button, false)
    end

    local function is_valid()
        return my_lifecycle == lifecycle_generation
            and my_generation == spin_generation_by_role[role_id]
    end

    local function finish(index)
        last_index_by_role[role_id] = index
        is_spinning_by_role[role_id] = false
        if button then
            role.set_button_enabled(button, true)
        end
        -- 中奖卡的框保持点亮，停留片刻后再弹出提示。
        LuaAPI.call_delay_frame(math.tointeger(LotteryConfig.SPIN.SETTLE_FRAMES) or 1, function()
            if on_complete then
                on_complete()
            end
        end)
    end

    -- 第 k 步：点亮 index 卡的框。
    local function step(k, index)
        if not is_valid() then
            return
        end
        show_frame_only(role, role_id, index)

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
