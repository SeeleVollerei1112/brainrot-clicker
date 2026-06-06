-- ============================================================
-- Data/ArchiveKeys.lua
-- 自定义存档槽登记表：name -> { id = 整数槽位, type = Enums.ArchiveType }。
-- ============================================================

return {
    -- 展台状态序列化（含收益累计游标 last_ts，见 Booth/BoothState.lua）
    BOOTH_BLOB = { id = 1001, type = Enums.ArchiveType.Str },
}
