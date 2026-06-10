--[[
App/AppConfig.lua

应用级配置：触摸常量与画布名称。
功能专属的自定义事件 / 按钮 / 文案已归位到各功能的 Config
（ClickerConfig / LotteryConfig / MallConfig）。
]]

---@class AppConfig
local AppConfig = {
    TOUCH = {
        CLICK = 1,
    },

    APP = {
        canvases = {
            world = "世界画布",
            click = "点击画布",
        },
    },
}

return AppConfig
