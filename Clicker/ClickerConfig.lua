--[[
Clicker/ClickerConfig.lua

点击主玩法配置：经济初值、HUD 节点、角色反馈、皮肤和飘字表现。
]]

--[[
皮肤系统：达到 threshold（累计脑腐值 total_brainrot）解锁对应皮肤组。
紧凑数据行：{ 解锁门槛, 形象图, 爆点底色, 爆点闪色 }
]]
local SKIN_ROWS = {
    { 0,           1800487724, 0x44FF8C00, 0xDDFFB030 },
    { 1000,        1806795636, 0x4400B0FF, 0xDD60D0FF },
    { 10000,       1625292968, 0x44C040FF, 0xDDD080FF },
    { 50000,       1652210836, 0x44FF3030, 0xDDFF7070 },
    { 100000,      1811268262, 0x44FF1060, 0xDDFF60A0 },
    { 250000,      1865162322, 0x44FF40A0, 0xDDFF90C0 },
    { 500000,      1871363879, 0x44FF40FF, 0xDDFF90FF },
    { 1000000,     1651697804, 0x44A040FF, 0xDDC080FF },
    { 2500000,     1849956877, 0x446040FF, 0xDD9080FF },
    { 5000000,     1668464772, 0x443060FF, 0xDD70A0FF },
    { 10000000,    1655483461, 0x440090FF, 0xDD50C0FF },
    { 25000000,    1840610905, 0x4400D0FF, 0xDD60E0FF },
    { 50000000,    1721173828, 0x4400D0B0, 0xDD50E0D0 },
    { 100000000,   1830636130, 0x4400D040, 0xDD60E080 },
    { 250000000,   1711549452, 0x4480E020, 0xDDB0F060 },
    { 500000000,   1786553064, 0x44FFE030, 0xDDFFF080 },
    { 1000000000,  1614345747, 0x44FFC020, 0xDDFFD870 },
    { 2500000000,  1667836222, 0x44FF8C00, 0xDDFFB030 },
    { 5000000000,  1668247581, 0x44FF6040, 0xDDFF9070 },
    { 10000000000, 1649570931, 0x44FF4020, 0xDDFF8060 },
}

-- 按数据行展开为完整皮肤配置；每组同时配置人物图片和 burst 颜色。
local skins = {}
for index, row in ipairs(SKIN_ROWS) do
    skins[index] = {
        threshold = row[1],
        image = row[2],
        burst = { rest_color = row[3], flash_color = row[4], rest_transition = 0.30 },
    }
end

---@class ClickerConfig
local ClickerConfig = {
    -- 点击画布开关的自定义事件（画布在编辑器绑定了 show/hide_event）
    EVENTS = {
        open_click_canvas = "OPEN_CLICK_CANVAS",
        close_click_canvas = "CLOSE_CLICK_CANVAS",
    },

    -- 入口/退出按钮节点名：launch 在世界画布，exit 在点击画布
    BUTTONS = {
        launch = "btn_launch",
        exit = "btn_exit",
    },

    -- 入口/退出按钮文案
    BUTTON_TEXT = {
        launch = "开始点击",
        exit = "",
    },

    INITIAL = {
        click_power = 1,
        brainrot = 0,
        brainrot_per_second = 0,
    },

    PASSIVE_INCOME = {
        tick_interval = 1.0,
    },

    HUD = {
        nodes = {
            brainrot = "lbl_brainrot",
            brainrot_per_second = "lbl_bps",
        },
        brainrot_per_second_prefix = "每秒: +",
    },

    CHARACTER = {
        nodes = {
            full_background = "full_bg",
            right_background = "right_bg",
            burst = "char_burst",
            animation_ring = "char_anim_ring",
            character_image = "char_img",
            character_image_small = "char_img_small",
            click_button = "char_click_btn",
        },
        animation_events = {
            reset = "CHAR_IMG_ANIM_RESET",
            start = "CHAR_IMG_ANIM_START",
        },
        click_animation_start_delay_frames = 1,
        burst = {
            rest_color = 0x44FF8C00,
            flash_color = 0xDDFFB030,
            rest_transition = 0.30,
        },
        reset_image_size = false,
        effect_loop = true,
        effect_area = { x = 460, y = 540, w = 600, h = 600 },
        skins = skins,
    },

    -- 连击配置（并入自原 Combo/ComboConfig.lua）：连击增长/衰减/倍率档位 + 连击条反馈参数。
    COMBO = {
        TIERS = {
            { threshold = 20,  multiplier = 2 },
            { threshold = 50,  multiplier = 3 },
            { threshold = 100, multiplier = 5 },
        },
        CLICK_GAIN = 4,
        DECAY_RATE = 1,
        MAX = 100,
        TICK_INTERVAL = 0.1,

        BAR = {
            nodes = {
                bar = "combo_bar",
                label = "combo_label",
            },
            settle_size = 64,
            pop_start_size = 40,
            pop_peak_size = 110,
            pop_grow_duration = 0.10,
            pop_settle_duration = 0.12,
            pop_start_delay_frames = 1,
            pop_settle_delay_frames = 15,
            shadow_sweep = { 0, 5, 10, 13, 10, 5, 0 },
            shadow_sweep_frames = 5,
            shadow_reset_x = 0,
            shadow_reset_y = -4,
            tier_colors = {
                [1] = 0xFFFFD700,
                [2] = 0xFFFF8C00,
                [3] = 0xFFFF3300,
            },
            tier_texts = {
                [1] = "×2",
                [2] = "×3",
                [3] = "×5",
            },
            progress_transition = 0.10,
        },
    },

    FLOAT_TEXT = {
        channel_count = 5,
        frame_steps = 30,
        step_frames = 1,
        base_x = 460,
        base_y = 620,
        rise_dist = 520,
        size_bottom = 100,
        size_top = 34,
        fade_start = 0.30,
        channel_gap = 30,
        width = 240,
        height = 80,
        label_style = 10001,
        color = 0xFFFFD700,
        outline_color = 0xFF000000,
        outline_width = 2,
        name_prefix = "ft_",
    },
}

return ClickerConfig
