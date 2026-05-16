-- PackSystem.lua
-- Location: ServerScriptService
-- All pack RNG is computed server-side. The client NEVER decides what was pulled.

local CardDatabase = require(game.ReplicatedStorage.Modules.CardDatabase)
local DataManager  = require(script.Parent.DataManager)

local PackSystem = {}

-- ──────────────────────────────────────────────────────────────
-- WEIGHTED RANDOM ROLL
-- Iterates rarities in deterministic order (highest → lowest)
-- ──────────────────────────────────────────────────────────────
local function weightedRoll(weights)
	local total = 0
	for _, key in ipairs(CardDatabase.RarityOrder) do
		total = total + (weights[key] or 0)
	end
	if total <= 0 then return "Common" end

	local roll = math.random(1, total)
	local cumulative = 0
	for _, key in ipairs(CardDatabase.RarityOrder) do
		cumulative = cumulative + (weights[key] or 0)
		if roll <= cumulative then
			return key
		end
	end
	return "Common"
end

-- ──────────────────────────────────────────────────────────────
-- APPLY LUCK MULTIPLIER TO WEIGHTS
-- Boosts rare+ weights proportionally; reduces Common to compensate.
-- ──────────────────────────────────────────────────────────────
local function applyLuck(weights, luckMultiplier)
	local boosted  = {}
	local totalBoost = 0
	local rareKeys = { "Rare", "Epic", "Legendary", "Mythic", "Secret", "Limited", "EventExclusive" }

	for _, key in ipairs(rareKeys) do
		local base      = weights[key] or 0
		local boostedVal= math.floor(base * luckMultiplier)
		boosted[key]    = boostedVal
		totalBoost      = totalBoost + (boostedVal - base)
	end

	-- Reduce Common weight so total stays consistent
	local baseCommon = weights["Common"] or 0
	boosted["Common"] = math.max(0, baseCommon - totalBoost)

	return boosted
end

-- ──────────────────────────────────────────────────────────────
-- PITY CHECK  (forces a rarity if player has waited too long)
-- ──────────────────────────────────────────────────────────────
local function checkPity(pityCounters)
	local p = CardDatabase.PityConfig
	if pityCounters.PacksSinceMythic    >= p.MythicGuaranteeAfter    then return "Mythic"    end
	if pityCounters.PacksSinceLegendary >= p.LegendaryGuaranteeAfter then return "Legendary" end
	if pityCounters.PacksSinceEpic      >= p.EpicGuaranteeAfter      then return "Epic"      end
	if pityCounters.PacksSinceRare      >= p.RareGuaranteeAfter      then return "Rare"      end
	return nil
end

-- ──────────────────────────────────────────────────────────────
-- UPDATE PITY COUNTERS AFTER A PULL
-- ──────────────────────────────────────────────────────────────
local function updatePity(pityCounters, pulledRarity)
	local rank = CardDatabase.RarityRank[pulledRarity] or 1

	pityCounters.PacksSinceRare      = pityCounters.PacksSinceRare      + 1
	pityCounters.PacksSinceEpic      = pityCounters.PacksSinceEpic      + 1
	pityCounters.PacksSinceLegendary = pityCounters.PacksSinceLegendary + 1
	pityCounters.PacksSinceMythic    = pityCounters.PacksSinceMythic    + 1

	if rank >= CardDatabase.RarityRank["Rare"]      then pityCounters.PacksSinceRare      = 0 end
	if rank >= CardDatabase.RarityRank["Epic"]      then pityCounters.PacksSinceEpic      = 0 end
	if rank >= CardDatabase.RarityRank["Legendary"] then pityCounters.PacksSinceLegendary = 0 end
	if rank >= CardDatabase.RarityRank["Mythic"]    then pityCounters.PacksSinceMythic    = 0 end
end

-- ──────────────────────────────────────────────────────────────
-- SELECT RANDOM VARIANT  (weighted)
-- ──────────────────────────────────────────────────────────────
local function selectVariant()
	local total = 0
	for _, w in pairs(CardDatabase.VariantWeights) do total = total + w end
	local roll  = math.random(1, total)
	local cum   = 0
	for _, variantName in ipairs(CardDatabase.Variants) do
		cum = cum + (CardDatabase.VariantWeights[variantName] or 0)
		if roll <= cum then return variantName end
	end
	return "Base"
end

-- ──────────────────────────────────────────────────────────────
-- BUILD CARD OBJECT
-- ──────────────────────────────────────────────────────────────
local function buildCard(player, rarityKey, packName)
	local rarityDef   = CardDatabase.Rarities[rarityKey]
	local playerDef   = CardDatabase.Players[math.random(1, #CardDatabase.Players)]
	local ovr         = math.random(rarityDef.OVRMin, rarityDef.OVRMax)
	local variant     = selectVariant()
	local variantMult = CardDatabase.VariantMultiplier[variant] or 1.0
	local value       = math.floor(rarityDef.BaseValue * variantMult)

	-- Unique card ID
	local cardId = string.format("%d_%d_%d", player.UserId, os.time(), math.random(100000, 999999))

	return {
		CardId     = cardId,
		PlayerName = playerDef.Name,
		Team       = playerDef.Team,
		Position   = playerDef.Position,
		Era        = playerDef.Era,
		OVR        = ovr,
		Rarity     = rarityKey,
		Variant    = variant,
		Value      = value,
		PackFrom   = packName,
		PulledAt   = os.time(),
	}
end

-- ──────────────────────────────────────────────────────────────
-- GET TOTAL LUCK MULTIPLIER FOR A PLAYER
-- ──────────────────────────────────────────────────────────────
function PackSystem.GetLuckMultiplier(data, gamepassBenefits, activeEvent)
	local mult = 1.0

	-- Base from luck level
	local tier = CardDatabase.LuckTiers[data.LuckLevel or 0]
	if tier then mult = tier.Multiplier end

	-- Prestige bonus (additive)
	mult = mult + (data.TotalPrestigeLuckBonus or 0)

	-- Active luck potion
	local boost = data.ActiveLuckBoost
	if boost and boost.ExpiresAt and boost.ExpiresAt > os.time() then
		mult = mult * boost.Multiplier
	end

	-- Gamepasses
	if gamepassBenefits then
		if gamepassBenefits.LuckySkates then
			mult = mult * CardDatabase.GamepassBenefits.LuckySkates.LuckMultiplier
		end
		if gamepassBenefits.VIPLockerRoom then
			mult = mult * CardDatabase.GamepassBenefits.VIPLockerRoom.LuckMultiplier
		end
	end

	-- Server-wide event
	if activeEvent and activeEvent.Multiplier then
		mult = mult * activeEvent.Multiplier
	end

	return mult
end

-- ──────────────────────────────────────────────────────────────
-- OPEN PACK
-- Returns: card, rarityKey, errorString (nil on success)
-- ──────────────────────────────────────────────────────────────
function PackSystem.OpenPack(player, packKey, gamepassBenefits, activeEvent)
	local data = DataManager.GetData(player)
	if not data then return nil, nil, "PlayerDataNotLoaded" end

	local packDef = CardDatabase.Packs[packKey]
	if not packDef then return nil, nil, "InvalidPack" end

	-- Inventory full
	if #data.Inventory >= (data.MaxInventory or 200) then
		return nil, nil, "InventoryFull"
	end

	-- Currency deduction
	-- Currency deduction
	if packDef.CostType == "Pucks" then
		if data.Pucks < packDef.Cost then return nil, nil, "InsufficientPucks" end
		data.Pucks = data.Pucks - packDef.Cost
		data.TotalPucksSpent = (data.TotalPucksSpent or 0) + packDef.Cost
	elseif packDef.CostType == "Gems" then
		if data.Gems < packDef.Cost then return nil, nil, "InsufficientGems" end
		data.Gems = data.Gems - packDef.Cost
	elseif packDef.CostType == "Free" then
		-- no cost, always allowed
	end

	-- Luck + rarity roll
	local luckMult       = PackSystem.GetLuckMultiplier(data, gamepassBenefits, activeEvent)
	local boostedWeights = applyLuck(packDef.Weights, luckMult)
	local forcedRarity   = checkPity(data.PityCounters)
	local rarityKey      = forcedRarity or weightedRoll(boostedWeights)

	-- Build and store card
	local card = buildCard(player, rarityKey, packDef.Name)
	table.insert(data.Inventory, card)

	-- Update pity
	updatePity(data.PityCounters, rarityKey)

	-- Stats
	data.TotalPacksOpened = (data.TotalPacksOpened or 0) + 1
	data.CurrentStreak    = (data.CurrentStreak or 0) + 1

	-- Track rarest card
	local currentRank = CardDatabase.RarityRank[data.RarestCardPulled] or 0
	local pulledRank  = CardDatabase.RarityRank[rarityKey] or 0
	if pulledRank > currentRank then
		data.RarestCardPulled = rarityKey
	end

	-- Collection index
	local colKey = card.PlayerName .. "_" .. rarityKey
	if not data.CollectionIndex[colKey] then
		data.CollectionIndex[colKey] = true
		data.CollectionCount = (data.CollectionCount or 0) + 1
	end

	-- Recalculate inventory value
	local total = 0
	for _, c in ipairs(data.Inventory) do total = total + (c.Value or 0) end
	data.InventoryValue = total

	if data.LastPackOpenedAt and (os.time() - data.LastPackOpenedAt) > 600 then
		data.CurrentStreak = 1
	end
	data.LastPackOpenedAt = os.time()

	DataManager.MarkDirty(player)
	return card, rarityKey, nil
end

-- ──────────────────────────────────────────────────────────────
-- SELL CARD  (60% value return)
-- Returns: success bool, sellValue or errorString
-- ──────────────────────────────────────────────────────────────
function PackSystem.SellCard(player, cardId)
	local data = DataManager.GetData(player)
	if not data then return false, "PlayerDataNotLoaded" end

	for i, card in ipairs(data.Inventory) do
		if card.CardId == cardId then
			if card.Locked then return false, "CardIsLocked" end
			local sellValue = math.floor((card.Value or 0) * 1.0)
			data.Pucks           = data.Pucks + sellValue
			data.TotalPucksEarned= (data.TotalPucksEarned or 0) + sellValue
			data.TotalCardsSold  = (data.TotalCardsSold  or 0) + 1
			table.remove(data.Inventory, i)

			-- Recalculate value
			local total = 0
			for _, c in ipairs(data.Inventory) do total = total + (c.Value or 0) end
			data.InventoryValue = total

			-- Remove from showcase if present
			for si, showcardId in ipairs(data.ShowcaseCards or {}) do
				if showcardId == cardId then
					table.remove(data.ShowcaseCards, si)
					break
				end
			end

			DataManager.MarkDirty(player)
			return true, sellValue
		end
	end
	return false, "CardNotFound"
end

return PackSystem
