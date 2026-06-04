-- ============================================================
-- Data/UIConfig.lua
-- UI 节点名、运行时反馈动效与通用显示配置
-- ============================================================

---@class UIConfig
local UIConfig = {
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

    COMBO_BAR = {
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
        -- 皮肤系统：达到 threshold（累计脑腐值 total_brainrot）解锁对应皮肤组。
        -- 每组同时配置：人物图片 image / 小图 image_small / 背景特效 effect_style /
        -- burst 颜色 burst。按 threshold 升序排列，index 1 为初始皮肤。
        -- 飘字颜色自动取该组 burst.rest_color（强制不透明），与背景配套。
        --
        -- 类型说明（必须填整数预设编号，非字符串）：
        --   image / image_small : ImageKey（图片编号，整数）。留空 nil 表示沿用编辑器原贴图。
        --   effect_style        : AnimationStyleKey（动效样式编号，整数）。留空 nil 则用编辑器原 char_anim_ring。
        -- TODO(策划)：填入真实图片编号、特效样式编号、阈值数值，并核对 effect_area。
        reset_image_size = false,                             -- 切换贴图时是否重置节点尺寸（false 保留编辑器尺寸）
        effect_loop = true,                                   -- 运行时特效节点是否循环播放
        effect_area = { x = 460, y = 540, w = 600, h = 600 }, -- 运行时特效节点创建位置/尺寸
        skins = {
            {
                threshold = 0,
                image = nil,        -- 初始皮肤沿用编辑器原贴图
                image_small = nil,
                effect_style = nil, -- 初始皮肤沿用编辑器原 char_anim_ring
                burst = { rest_color = 0x44FF8C00, flash_color = 0xDDFFB030, rest_transition = 0.30 },
            },
            {
                threshold = 1000,
                image = nil,        -- TODO: 图片编号
                image_small = nil,  -- TODO: 图片编号（可留 nil 沿用 image）
                effect_style = nil, -- TODO: 动效样式编号
                burst = { rest_color = 0x4400B0FF, flash_color = 0xDD60D0FF, rest_transition = 0.30 },
            },
            {
                threshold = 10000,
                image = nil,        -- TODO: 图片编号
                image_small = nil,  -- TODO: 图片编号（可留 nil 沿用 image）
                effect_style = nil, -- TODO: 动效样式编号
                burst = { rest_color = 0x44C040FF, flash_color = 0xDDD080FF, rest_transition = 0.30 },
            },
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

return UIConfig
