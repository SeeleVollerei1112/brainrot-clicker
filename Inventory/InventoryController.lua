-- ============================================================
-- Inventory/InventoryController.lua
-- 背包侧边栏编排层：GAME_INIT 绑定 装备栏/储物栏 标签按钮点击；
-- 玩家会话创建时做一次性设置（关闭文字触摸 + 默认选中）。
-- ============================================================

local InventoryView = require("Inventory.InventoryView")
local ItemSynthesisSystem = require("Inventory.ItemSynthesisSystem")
local SessionStateRegistry = require("App.SessionStateRegistry")

local InventoryController = {}

-- 背包无内存状态片（状态在角色装备槽，引擎侧），只声明恢复/保存钩子。
-- 与 Booth 共用存档槽位，串行 save（read-merge-write）不破坏合并语义。
SessionStateRegistry.declare("inventory", {
    restore = function(session)
        ItemSynthesisSystem.restore_role_inventory(session.role)
    end,
    save = function(session)
        ItemSynthesisSystem.save_role_inventory(session.role)
    end,
})

---玩家会话创建时调用：关闭标签文字触摸并应用默认选中。
---@param session PlayerSession
function InventoryController.setup_session(session)
    -- 系统背包面板位于引擎 UI 顶层，会覆盖自定义画布；这里改用自定义背包侧边栏。
    session.role.show_bag_panel(false)
    InventoryView.initialize_role(session.role)
end

---绑定背包侧边栏所有交互。GAME_INIT 时由 GameApp 调用。
---@param application Application
function InventoryController.initialize(application)
    local register_trigger = application.register_trigger
    InventoryView.initialize()
    InventoryView.bind_tab_handler(InventoryView.select_tab, register_trigger)
    LuaAPI.log("[InventoryController] 背包侧边栏初始化完成", 0)
end

return InventoryController
