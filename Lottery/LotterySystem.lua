-- ============================================================
-- Lottery/LotterySystem.lua
-- Pure weighted lottery selection.
-- ============================================================

local LotteryConfig = require("Lottery.LotteryConfig")

local LotterySystem = {}

---@class LotteryDrawResult
---@field success boolean
---@field prize LotteryPrize|nil
---@field reason string|nil

---Draw one prize using the configured integer weights.
---@return LotteryDrawResult result
function LotterySystem.draw()
    local total_weight = 0

    for _, prize in ipairs(LotteryConfig.PRIZES) do
        if type(prize.weight) ~= "number" or prize.weight <= 0 or prize.weight % 1 ~= 0 then
            return {
                success = false,
                prize = nil,
                reason = "invalid_prize_weight",
            }
        end

        total_weight = total_weight + prize.weight
    end

    if total_weight <= 0 then
        return {
            success = false,
            prize = nil,
            reason = "empty_prize_pool",
        }
    end

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

    return {
        success = false,
        prize = nil,
        reason = "roll_out_of_range",
    }
end

---Resolve which card (1-based index in LotteryConfig.CARDS) shows the given prize.
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
