--[[
App/AppConfig.lua

应用级配置：画布名称、UI 自定义事件、按钮节点名与触摸常量。
]]

---@class AppConfig
local AppConfig = {
    TOUCH = {
        CLICK = 1,
        PRESS = 2,
        RELEASE = 3,
    },

    APP = {
        canvases = {
            world = "世界画布",
            click = "点击画布",
        },
        events = {
            open_click_canvas = "OPEN_CLICK_CANVAS",
            close_click_canvas = "CLOSE_CLICK_CANVAS",
            open_lottery = "OPEN_LOTTERY_CANVAS",
            close_lottery = "CLOSE_LOTTERY_CANVAS",
            open_mall = "OPEN_MALL_CANVAS",
            close_mall = "CLOSE_MALL_CANVAS",
        },
        buttons = {
            launch = "btn_launch",
            exit = "btn_exit",
            lottery_open = "btn_lottery_spin",
            lottery_close = "关闭",
            mall_open = "btn_shop",
            mall_close = "mall_btn_close",
        },
        text = {
            launch = "开始点击",
            exit = "",
        },
    },
}

return AppConfig
