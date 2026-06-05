--[[
Clicker/SkinSystem.lua

皮肤档位计算：根据累计脑腐值解析当前可用的最高皮肤。
]]

local SkinSystem = {}

---返回已达到门槛的最高皮肤索引。
---skins 需要按 threshold 升序排列；索引 1 是基础皮肤。
---@param skins table[] ordered skin tiers, each with a numeric `threshold`
---@param value number lifetime brainrot
---@return integer tier_index
function SkinSystem.resolve_tier_index(skins, value)
    local tier_index = 1
    if not skins then
        return tier_index
    end

    for index = 1, #skins do
        local skin = skins[index]
        if skin and value >= (skin.threshold or 0) then
            tier_index = index
        else
            break
        end
    end

    return tier_index
end

return SkinSystem
