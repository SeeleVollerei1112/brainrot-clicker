-- ============================================================
-- Lottery/LotterySystem.lua
-- 纯权重抽奖逻辑。
-- ============================================================

local LotteryConfig = require("Lottery.LotteryConfig")

local LotterySystem = {}

---@class LotteryDrawResult
---@field success boolean
---@field prize LotteryPrize|nil
---@field reason string|nil

---按配置的整数权重抽取一个奖励。
---@return LotteryDrawResult result
function LotterySystem.draw()
    local total_weight = 0
    for _, prize in ipairs(LotteryConfig.PRIZES) do
        total_weight = total_weight + prize.weight
    end

    -- roll ∈ [1, total_weight]，必落在某个奖励的累计权重区间内
    local roll = GameAPI.random_int(1, total_weight)
    local cumulative_weight = 0
    for _, prize in ipairs(LotteryConfig.PRIZES) do
        cumulative_weight = cumulative_weight + prize.weight
        if roll <= cumulative_weight then
            return {
                success = true,
                prize = prize,
                reason = nil,
            }
        end
    end
end

---解析给定奖励对应的卡片（LotteryConfig.CARDS 中的 1 起始下标）。
---@param prize_id string
---@return integer|nil index
function LotterySystem.index_of_prize(prize_id)
    for index, card in ipairs(LotteryConfig.CARDS) do
        if card.prize_id == prize_id then
            return index
        end
    end
    return nil
end

return LotterySystem
