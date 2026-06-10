--[[
Clicker/ClickerConfig.lua

点击主玩法配置：经济初值、HUD 节点、角色反馈、皮肤和飘字表现。
]]

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
        combo_count = 0,
        combo_multiplier = 1,
        tick_counter = 0,
    },

    PASSIVE_INCOME = {
        tick_interval = 1.0,
        easter_bonus_multiplier = 10,
    },

    EASTER_EGG = {
        spawn_interval_min = 15,
        spawn_interval_max = 45,
        duration = 10,
    },

    HUD = {
        nodes = {
            coin = "hud_coin",
            brainrot = "lbl_brainrot",
            brainrot_per_second = "lbl_bps",
        },
        legacy_nodes = {
            "btn_skin",
            "lbl_weather",
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
            pause = "CHAR_IMG_ANIM_PAUSE",
            resume = "CHAR_IMG_ANIM_RESUME",
        },
        click_animation_start_delay_frames = 1,
        use_legacy_squeeze = false,
        burst = {
            rest_color = 0x44FF8C00,
            flash_color = 0xDDFFB030,
            rest_transition = 0.30,
        },
        squeeze = {
            delay_frames = 1,
            flash_color = 0xFFAAAAAA,
            rest_color = 0xFFFFFFFF,
            rest_transition = 0.10,
        },
        --[[
        皮肤系统：达到 threshold（累计脑腐值 total_brainrot）解锁对应皮肤组。
        每组同时配置人物图片、小图、背景特效和 burst 颜色。
        ]]
        reset_image_size = false,
        effect_loop = true,
        effect_area = { x = 460, y = 540, w = 600, h = 600 },
        skins = {
            {
                threshold = 0,
                image = 1800487724,
                -- image_small = 1800487724,
                effect_style = nil,
                burst = { rest_color = 0x44FF8C00, flash_color = 0xDDFFB030, rest_transition = 0.30 },
            },
            {
                threshold = 1000,
                image = 1806795636,
                -- image_small = 1806795636,
                effect_style = nil,
                burst = { rest_color = 0x4400B0FF, flash_color = 0xDD60D0FF, rest_transition = 0.30 },
            },
            {
                threshold = 10000,
                image = 1625292968,
                -- image_small = 1625292968,
                effect_style = nil,
                burst = { rest_color = 0x44C040FF, flash_color = 0xDDD080FF, rest_transition = 0.30 },
            },
            {
                threshold = 50000,
                image = 1652210836,
                -- image_small = 1652210836,
                effect_style = nil,
                burst = { rest_color = 0x44FF3030, flash_color = 0xDDFF7070, rest_transition = 0.30 },
            },
            {
                threshold = 100000,
                image = 1811268262,
                -- image_small = 1811268262,
                effect_style = nil,
                burst = { rest_color = 0x44FF1060, flash_color = 0xDDFF60A0, rest_transition = 0.30 },
            },
            {
                threshold = 250000,
                image = 1865162322,
                -- image_small = 1865162322,
                effect_style = nil,
                burst = { rest_color = 0x44FF40A0, flash_color = 0xDDFF90C0, rest_transition = 0.30 },
            },
            {
                threshold = 500000,
                image = 1871363879,
                -- image_small = 1871363879,
                effect_style = nil,
                burst = { rest_color = 0x44FF40FF, flash_color = 0xDDFF90FF, rest_transition = 0.30 },
            },
            {
                threshold = 1000000,
                image = 1651697804,
                -- image_small = 1651697804,
                effect_style = nil,
                burst = { rest_color = 0x44A040FF, flash_color = 0xDDC080FF, rest_transition = 0.30 },
            },
            {
                threshold = 2500000,
                image = 1849956877,
                -- image_small = 1849956877,
                effect_style = nil,
                burst = { rest_color = 0x446040FF, flash_color = 0xDD9080FF, rest_transition = 0.30 },
            },
            {
                threshold = 5000000,
                image = 1668464772,
                -- image_small = 1668464772,
                effect_style = nil,
                burst = { rest_color = 0x443060FF, flash_color = 0xDD70A0FF, rest_transition = 0.30 },
            },
            {
                threshold = 10000000,
                image = 1655483461,
                -- image_small = 1655483461,
                effect_style = nil,
                burst = { rest_color = 0x440090FF, flash_color = 0xDD50C0FF, rest_transition = 0.30 },
            },
            {
                threshold = 25000000,
                image = 1840610905,
                -- image_small = 1840610905,
                effect_style = nil,
                burst = { rest_color = 0x4400D0FF, flash_color = 0xDD60E0FF, rest_transition = 0.30 },
            },
            {
                threshold = 50000000,
                image = 1721173828,
                -- image_small = 1721173828,
                effect_style = nil,
                burst = { rest_color = 0x4400D0B0, flash_color = 0xDD50E0D0, rest_transition = 0.30 },
            },
            {
                threshold = 100000000,
                image = 1830636130,
                -- image_small = 1830636130,
                effect_style = nil,
                burst = { rest_color = 0x4400D040, flash_color = 0xDD60E080, rest_transition = 0.30 },
            },
            {
                threshold = 250000000,
                image = 1711549452,
                -- image_small = 1711549452,
                effect_style = nil,
                burst = { rest_color = 0x4480E020, flash_color = 0xDDB0F060, rest_transition = 0.30 },
            },
            {
                threshold = 500000000,
                image = 1786553064,
                -- image_small = 1786553064,
                effect_style = nil,
                burst = { rest_color = 0x44FFE030, flash_color = 0xDDFFF080, rest_transition = 0.30 },
            },
            {
                threshold = 1000000000,
                image = 1614345747,
                -- image_small = 1614345747,
                effect_style = nil,
                burst = { rest_color = 0x44FFC020, flash_color = 0xDDFFD870, rest_transition = 0.30 },
            },
            {
                threshold = 2500000000,
                image = 1667836222,
                -- image_small = 1667836222,
                effect_style = nil,
                burst = { rest_color = 0x44FF8C00, flash_color = 0xDDFFB030, rest_transition = 0.30 },
            },
            {
                threshold = 5000000000,
                image = 1668247581,
                -- image_small = 1668247581,
                effect_style = nil,
                burst = { rest_color = 0x44FF6040, flash_color = 0xDDFF9070, rest_transition = 0.30 },
            },
            {
                threshold = 10000000000,
                image = 1649570931,
                -- image_small = 1649570931,
                effect_style = nil,
                burst = { rest_color = 0x44FF4020, flash_color = 0xDDFF8060, rest_transition = 0.30 },
            },
        },
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
        RESET_TICKS = 15,

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
