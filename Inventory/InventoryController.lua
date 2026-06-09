-- ============================================================
-- Inventory/InventoryController.lua
-- 背包侧边栏编排层：GAME_INIT 绑定 装备栏/储物栏 标签按钮点击；
-- 玩家会话创建时做一次性设置（关闭文字触摸 + 默认选中）。
-- ============================================================

local InventoryView = require("Inventory.InventoryView")
local ItemSynthesisSystem = require("Inventory.ItemSynthesisSystem")

local InventoryController = {}

---切换背包侧边栏标签页。
---@param role Role
---@param tab_key string
local function handle_select(role, tab_key)
    InventoryView.select_tab(role, tab_key)
end

---玩家会话创建时调用：关闭标签文字触摸并应用默认选中。
---@param session PlayerSession
function InventoryController.setup_session(session)
    local role = session and session.role
    if not role then
        return
    end
    ItemSynthesisSystem.restore_role_inventory(role)
    InventoryView.initialize_role(role)
end

---@param session PlayerSession
function InventoryController.cleanup_session(session)
    local role = session and session.role
    if role then
        ItemSynthesisSystem.save_role_inventory(role)
    end
end

---@param role Role
function InventoryController.initialize_role(role)
    InventoryController.setup_session({ role = role })
end

---绑定背包侧边栏所有交互。GAME_INIT 时由 GameApp 调用。
---@param application Application
function InventoryController.initialize(application)
    local register_trigger = application.register_trigger
    ItemSynthesisSystem.initialize()
    InventoryView.initialize()
    InventoryView.bind_tab_handler(handle_select, register_trigger)
    LuaAPI.log("[InventoryController] 背包侧边栏初始化完成", 0)
end

return InventoryController
