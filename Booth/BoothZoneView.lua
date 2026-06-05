-- ============================================================
-- Booth/BoothZoneView.lua
-- 展台区「锁定/解锁」场景表现层：
--   · 未解锁展区：隐藏该区所有展台模型(set_model_visible(false))，公告板红字「未解锁」。
--   · 已解锁展区：显示展台模型，公告板展示「每秒总收益 / 总收益」(数值逻辑留空待接)。
--
-- 展台模型 / 公告板都是场景里编辑器摆好的单位，按命名 (BoothConfig.booth_stand_name /
-- zone_board_name) 用 LuaAPI.query_unit 反查并缓存；缺失则安全跳过并打日志。
-- 公告板是带 billboard 文本的 Obstacle：set_billboard_text / set_billboard_text_color。
--
-- 注意：set_model_visible / set_billboard_text 是单位级（非按玩家）生效，符合本作
-- 单人进度玩法；收益为占位 0（见 compute_zone_income，TODO 后续按 placements 求和）。
-- ============================================================

local BoothConfig = require("Data.BoothConfig")
local BoothController = require("Booth.BoothController")
local BoothState = require("Systems.BoothState")

local BoothZoneView = {}

-- 文本颜色（0xAARRGGBB）
local COLOR_LOCKED = 0xFFFF3030   -- 未解锁：红
local COLOR_UNLOCKED = 0xFFFFFFFF -- 已解锁：白

-- 单位缓存：stands_cache[zone_id] = { Unit, ... }；board_cache[zone_id] = Obstacle
local stands_cache = {}
local board_cache = {}
-- 记录某名字是否已查过（避免每次刷新都对缺失单位刷日志）
local resolved_zone = {}

---解析并缓存某展台区的展台模型 + 公告板单位（仅首次查询）。
---@param zone_id integer
local function resolve_zone_units(zone_id)
    if resolved_zone[zone_id] then
        return
    end
    resolved_zone[zone_id] = true

    local stands = {}
    local zone = BoothConfig.find_zone(zone_id)
    if zone then
        for booth_index = 0, zone.booth_count - 1 do
            local name = BoothConfig.booth_stand_name(zone_id, booth_index)
            local unit = name and LuaAPI.query_unit(name)
            if unit then
                stands[#stands + 1] = unit
            else
                LuaAPI.log("[BoothZoneView] 找不到展台模型: " .. tostring(name), 1)
            end
        end
    end
    stands_cache[zone_id] = stands

    local board_name = BoothConfig.zone_board_name(zone_id)
    local board = board_name and LuaAPI.query_unit(board_name)
    if not board then
        LuaAPI.log("[BoothZoneView] 找不到公告板: " .. tostring(board_name), 1)
    end
    board_cache[zone_id] = board
end

---GAME_INIT 时清空单位缓存（重新试玩会重置场景单位句柄）。
function BoothZoneView.initialize()
    stands_cache = {}
    board_cache = {}
    resolved_zone = {}
end

---计算某展台区的收益（占位）。TODO(玩法)：按 state.placements[zone_id] 各实例
---的 income_per_second 求和得「每秒总收益」，并累计「总收益」。当前留空返回 0。
---@param role Role
---@param zone_id integer
---@return integer income_per_second, integer income_total
function BoothZoneView.compute_zone_income(role, zone_id)
    return 0, 0
end

---按解锁状态刷新某展台区的展台模型显隐 + 公告板文本。
---@param role Role
---@param zone_id integer
function BoothZoneView.refresh_zone(role, zone_id)
    if not role then
        return
    end
    local state = BoothController.get_state(role)
    if not state then
        return
    end
    local unlocked = BoothState.is_zone_unlocked(state, zone_id)

    resolve_zone_units(zone_id)

    -- 展台模型显隐
    local stands = stands_cache[zone_id] or {}
    for _, unit in ipairs(stands) do
        pcall(function() unit.set_model_visible(unlocked) end)
        pcall(function() unit.set_physics_active(unlocked) end)
    end

    -- 公告板文本
    local board = board_cache[zone_id]
    if board then
        if unlocked then
            local per_second, total = BoothZoneView.compute_zone_income(role, zone_id)
            local text = "每秒总收益: " .. tostring(per_second) .. "\n总收益: " .. tostring(total)
            pcall(function() board.set_billboard_text(text) end)
            pcall(function() board.set_billboard_text_color(COLOR_UNLOCKED) end)
        else
            pcall(function() board.set_billboard_text("未解锁") end)
            pcall(function() board.set_billboard_text_color(COLOR_LOCKED) end)
        end
    end
end

---刷新所有展台区（会话开始 / 解锁状态变更后调用）。
---@param role Role
function BoothZoneView.refresh_all(role)
    for _, zone in ipairs(BoothConfig.ZONES) do
        BoothZoneView.refresh_zone(role, zone.id)
    end
end

return BoothZoneView
