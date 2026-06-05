--[[
Booth/BoothZoneView.lua

展台区场景表现层。
锁定展区隐藏展台模型并关闭物理；解锁展区显示展台模型并恢复碰撞。
公告板展示当前展区状态。展台和公告板都是编辑器中已摆放的场景单位，
运行时按 BoothConfig 的命名规则通过 LuaAPI.query_unit 查询并缓存。
]]

local BoothConfig = require("Booth.BoothConfig")
local BoothController = require("Booth.BoothController")
local BoothState = require("Booth.BoothState")

local BoothZoneView = {}

local COLOR_LOCKED = 0xFFFF3030
local COLOR_UNLOCKED = 0xFFFFFFFF

---@type table<integer, Unit[]>
local stands_cache = {}

---@type table<integer, Unit>
local board_cache = {}

---@type table<integer, boolean>
local resolved_zone = {}

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
            local unit = LuaAPI.query_unit(name)
            if unit then
                stands[#stands + 1] = unit
            else
                LuaAPI.log("[BoothZoneView] 找不到展台模型: " .. tostring(name), 1)
            end
        end
    end
    stands_cache[zone_id] = stands

    local board_name = BoothConfig.zone_board_name(zone_id)
    local board = LuaAPI.query_unit(board_name)
    if not board then
        LuaAPI.log("[BoothZoneView] 找不到公告板: " .. tostring(board_name), 1)
    end
    board_cache[zone_id] = board
end

---@param unit Unit
local function unlock_stand(unit)
    unit.set_model_visible(true)
    unit.set_physics_active(true)
    unit.set_model_physic_visible(true)

    LuaAPI.call_delay_frame(1, function()
        unit.set_model_visible(true)
        unit.set_physics_active(true)
        unit.set_model_physic_visible(true)
    end)
end

---@param unit Unit
local function lock_stand(unit)
    unit.set_physics_active(false)
    unit.set_model_physic_visible(false)
    unit.set_model_visible(false)
end

function BoothZoneView.initialize()
    stands_cache = {}
    board_cache = {}
    resolved_zone = {}
end

---@param role Role
---@param zone_id integer
---@return integer income_per_second, integer income_total
function BoothZoneView.compute_zone_income(role, zone_id)
    return 0, 0
end

---@param role Role
---@param zone_id integer
function BoothZoneView.refresh_zone(role, zone_id)
    local state = BoothController.get_state(role)
    local unlocked = BoothState.is_zone_unlocked(state, zone_id)

    resolve_zone_units(zone_id)

    for _, stand in ipairs(stands_cache[zone_id]) do
        if unlocked then
            unlock_stand(stand)
        else
            lock_stand(stand)
        end
    end

    local board = board_cache[zone_id]
    if not board then
        return
    end

    if unlocked then
        local per_second, total = BoothZoneView.compute_zone_income(role, zone_id)
        board.set_billboard_text("每秒总收益: " .. tostring(per_second) .. "\n总收益: " .. tostring(total))
        board.set_billboard_text_color(COLOR_UNLOCKED)
    else
        board.set_billboard_text("未解锁")
        board.set_billboard_text_color(COLOR_LOCKED)
    end
end

---@param role Role
function BoothZoneView.refresh_all(role)
    for _, zone in ipairs(BoothConfig.ZONES) do
        BoothZoneView.refresh_zone(role, zone.id)
    end
end

return BoothZoneView
