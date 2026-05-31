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
        },
        buttons = {
            launch = "btn_launch",
            exit = "btn_exit",
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
    },

    FLOAT_TEXT = {
        channel_count = 5,
        waypoint_count = 30,
        step_frames = 1,
        base_x = 460,
        base_y = 820,
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
