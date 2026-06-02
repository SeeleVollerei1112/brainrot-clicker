-- ============================================================
-- Mall/MallController.lua
-- 内购商城编排层：绑定入口/关闭/侧边栏标签/购买按钮，
-- 通过自定义消息开关商城画布（画布已在编辑器绑定 show/hide_event）。
-- ============================================================

local MallConfig = require("Data.MallConfig")
local MallSystem = require("Mall.MallSystem")
local MallView = require("Mall.MallView")
local UINodes = require("Data.UINodes")
local UIConfig = require("Data.UIConfig")

local MallController = {}

---@param event_arguments table
---@param callback function
---@param register_trigger fun(event_arguments: table, callback: function): integer
---@param missing_log string
local function bind_button(node, event_arguments, callback, register_trigger, missing_log)
    if node then
        register_trigger(event_arguments, callback)
    else
        LuaAPI.log(missing_log, 1)
    end
end

---打开商城画布并渲染默认标签页。
---@param role Role
local function handle_open(role)
    role.send_ui_custom_event(UIConfig.APP.events.open_mall, {})
    MallView.initialize_role(role)
    MallView.render(role, MallSystem.get_display_data())
    MallView.select_tab(role, MallView.get_default_tab_key())
end

---关闭商城画布。
---@param role Role
local function handle_close(role)
    role.send_ui_custom_event(UIConfig.APP.events.close_mall, {})
end

---切换侧边栏标签页。
---@param role Role
---@param tab_key string
local function handle_select(role, tab_key)
    MallView.select_tab(role, tab_key)
end

---处理一次购买。
---@param role Role
---@param item_id integer
local function handle_buy(role, item_id)
    local result = MallSystem.purchase(role, item_id)
    if not result.success then
        LuaAPI.log("[MallController] 购买失败 item=" .. tostring(item_id) .. " reason=" .. result.reason, 0)
        return
    end
    -- 占位：真实内购成功后通常刷新货币/背包 UI，待接入游戏逻辑。
    MallView.render(role, MallSystem.get_display_data())
end

---玩家会话创建时调用：强制隐藏商城画布并做一次性设置。
---修复“开局直接弹出商城”——商城画布在地图中默认 visible，需开局主动隐藏
---（编辑器 visible=false 仅在保存后生效，故用代码兜底）。
---@param role Role
function MallController.initialize_role(role)
    if not role then
        return
    end
    role.send_ui_custom_event(UIConfig.APP.events.close_mall, {})
    MallView.initialize_role(role)
end

---绑定商城所有交互。GAME_INIT 时由 GameController 调用。
---@param register_trigger fun(event_arguments: table, callback: function): integer
function MallController.initialize(register_trigger)
    MallView.initialize()

    -- 入口按钮（世界画布的 btn_shop）：打开商城
    local open_button = UINodes[UIConfig.APP.buttons.mall_open]
    bind_button(
        open_button,
        { EVENT.EUI_NODE_TOUCH_EVENT, open_button, UIConfig.TOUCH.CLICK },
        function(event_name, actor, data)
            if data and data.role then
                handle_open(data.role)
            end
        end,
        register_trigger,
        "[MallController] 缺少入口按钮节点: " .. tostring(UIConfig.APP.buttons.mall_open)
    )

    -- 商城画布内的关闭按钮
    local close_button = UINodes[UIConfig.APP.buttons.mall_close]
    bind_button(
        close_button,
        { EVENT.EUI_NODE_TOUCH_EVENT, close_button, UIConfig.TOUCH.CLICK },
        function(event_name, actor, data)
            if data and data.role then
                handle_close(data.role)
            end
        end,
        register_trigger,
        "[MallController] 缺少关闭按钮节点: " .. tostring(UIConfig.APP.buttons.mall_close)
    )

    -- 侧边栏标签按钮 + 各商品购买按钮
    MallView.bind_tab_handler(handle_select, register_trigger)
    MallView.bind_buy_handler(handle_buy, register_trigger)

    LuaAPI.log("[MallController] 内购商城初始化完成", 0)
end

return MallController
