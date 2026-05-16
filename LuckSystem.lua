-- LuckSystem.lua
-- Location: ServerScriptService

local CardDatabase = require(game.ReplicatedStorage.Modules.CardDatabase)
local DataManager  = require(script.Parent.DataManager)

local LuckSystem = {}

-- ──────────────────────────────────────────────────────────────
-- UPGRADE LUCK LEVEL
-- Returns: true, newLevel, newMultiplier  OR  false, errorCode
-- ──────────────────────────────────────────────────────────────
function LuckSystem.UpgradeLuck(player)
	local data = DataManager.GetData(player)
	if not data then return false, "PlayerDataNotLoaded" end

	local currentLevel = data.LuckLevel or 0
	local nextLevel    = currentLevel + 1
	local nextTier     = CardDatabase.LuckTiers[nextLevel]

	if not nextTier then return false, "MaxLevelReached" end
	if data.Pucks < nextTier.Cost then return false, "InsufficientPucks" end

	data.Pucks     = data.Pucks - nextTier.Cost
	data.TotalPucksSpent = (data.TotalPucksSpent or 0) + nextTier.Cost
	data.LuckLevel = nextLevel
	DataManager.MarkDirty(player)

	return true, nextLevel, nextTier.Multiplier
end

-- ──────────────────────────────────────────────────────────────
-- ACTIVATE LUCK POTION BOOST
-- Stacks duration if a boost is already active.
-- Returns: true, expiresAt  OR  false, errorCode
-- ──────────────────────────────────────────────────────────────
function LuckSystem.ActivateBoost(player, durationSeconds, multiplier)
	local data = DataManager.GetData(player)
	if not data then return false, "PlayerDataNotLoaded" end

	local now       = os.time()
	local expiresAt

	local existing = data.ActiveLuckBoost
	if existing and existing.ExpiresAt and existing.ExpiresAt > now then
		-- Extend existing boost
		expiresAt = existing.ExpiresAt + durationSeconds
	else
		expiresAt = now + durationSeconds
	end

	data.ActiveLuckBoost = {
		ExpiresAt  = expiresAt,
		Multiplier = multiplier,
	}
	DataManager.MarkDirty(player)
	return true, expiresAt
end

-- ──────────────────────────────────────────────────────────────
-- GET BOOST INFO  (for client display)
-- Returns a table with ExpiresAt, Multiplier, Remaining, or nil
-- ──────────────────────────────────────────────────────────────
function LuckSystem.GetBoostInfo(player)
	local data = DataManager.GetData(player)
	if not data then return nil end

	local boost = data.ActiveLuckBoost
	if boost and boost.ExpiresAt and boost.ExpiresAt > os.time() then
		return {
			ExpiresAt  = boost.ExpiresAt,
			Multiplier = boost.Multiplier,
			Remaining  = boost.ExpiresAt - os.time(),
		}
	end
	return nil
end

-- ──────────────────────────────────────────────────────────────
-- PRESTIGE / REBIRTH
-- Resets Pucks and LuckLevel in exchange for a permanent luck bonus.
-- Returns: true, newPrestigeLevel, badgeName  OR  false, errorCode
-- ──────────────────────────────────────────────────────────────
function LuckSystem.Prestige(player)
	local data = DataManager.GetData(player)
	if not data then return false, "PlayerDataNotLoaded" end

	local currentPrestige = data.PrestigeLevel or 0
	local nextPrestige    = currentPrestige + 1
	local nextTier        = CardDatabase.PrestigeTiers[nextPrestige]

	if not nextTier then return false, "MaxPrestigeReached" end
	if (data.LuckLevel or 0) < 10 then return false, "MustMaxLuckFirst" end
	if data.Pucks < nextTier.CostInPucks then return false, "InsufficientPucks" end

	-- Apply prestige
	data.Pucks                  = 500  -- reset to starter pucks
	data.LuckLevel              = 0
	data.PrestigeLevel          = nextPrestige
	data.TotalPrestigeLuckBonus = (data.TotalPrestigeLuckBonus or 0) + nextTier.LuckBonus
	data.CurrentStreak          = 0
	data.PityCounters = {
		PacksSinceRare      = 0,
		PacksSinceEpic      = 0,
		PacksSinceLegendary = 0,
		PacksSinceMythic    = 0,
	}
	-- Note: inventory, gems, collection index are KEPT

	DataManager.MarkDirty(player)
	return true, nextPrestige, nextTier.Badge
end

return LuckSystem
