-- ============================================================
-- Systems/SkinSystem.lua
-- Pure resolution of the unlocked skin tier from a brainrot value.
-- ============================================================

local SkinSystem = {}

---Return the highest skin index whose threshold is reached by the value.
---Skins must be ordered ascending by threshold; index 1 is the base tier.
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
