-- DataManager.lua
-- Location: ServerScriptService
-- Handles all player data persistence via DataStore.
-- Required by MainServer and other server modules.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local DataManager = {}
DataManager.__index = DataManager

-- ──────────────────────────────────────────────────────────────
-- DATASTORES
-- ──────────────────────────────────────────────────────────────
local PlayerStore = DataStoreService:GetDataStore("NHLPackRNG_PlayerData_v2")
local WIPE_DATA_FOR_TESTING = false  -- SET TO false WHEN DONE TESTING
local ValueBoard  = DataStoreService:GetOrderedDataStore("NHLPackRNG_InventoryValue_v2")
local PucksBoard  = DataStoreService:GetOrderedDataStore("NHLPackRNG_PuckBalance_v1")

-- ──────────────────────────────────────────────────────────────
-- DEFAULT PLAYER DATA TEMPLATE
-- ──────────────────────────────────────────────────────────────
local DEFAULT_DATA = {
	-- Currency
	Pucks             = 1000,
	Gems              = 5,

	-- Progression
	LuckLevel         = 0,
	PrestigeLevel     = 0,
	TotalPrestigeLuckBonus = 0,

	-- Inventory
	Inventory         = {},
	MaxInventory      = 200,

	-- Collection index: "PlayerName_RarityKey" → true
	CollectionIndex   = {},
	CollectionCount   = 0,

	-- Lifetime stats
	TotalPacksOpened  = 0,
	TotalPucksEarned  = 0,
	TotalPucksSpent   = 0,
	TotalCardsSold    = 0,
	TotalTradesDone   = 0,
	RarestCardPulled  = "Common",
	InventoryValue    = 0,

	-- Pity counters
	PityCounters = {
		PacksSinceRare      = 0,
		PacksSinceEpic      = 0,
		PacksSinceLegendary = 0,
		PacksSinceMythic    = 0,
	},

	-- Quests
	DailyQuestProgress  = {},
	WeeklyQuestProgress = {},
	DailyQuestsAssigned = {},
	WeeklyQuestAssigned = nil,
	LastQuestResetDay   = 0,
	LastWeeklyResetDay  = 0,

	-- Login
	LastLoginDay   = 0,
	LoginStreak    = 0,
	LoginCalendar  = {},

	-- Achievements: achievementId → true
	AchievementsEarned = {},

	-- Streak (consecutive pack opens)
	CurrentStreak = 0,

	-- Showcase: up to 5 cardId strings
	ShowcaseCards = {},

	-- Active luck boost: { ExpiresAt, Multiplier } or nil
	ActiveLuckBoost = nil,

	-- Trade history: array of trade log entries
	TradeHistory = {},

	-- Metadata
	CreatedAt   = 0,
	LastSavedAt = 0,
}

-- ──────────────────────────────────────────────────────────────
-- IN-MEMORY CACHE
-- ──────────────────────────────────────────────────────────────
local cache = {}  -- [userId string] → data table
local dirty = {}  -- [userId string] → bool

-- ──────────────────────────────────────────────────────────────
-- UTILITIES
-- ──────────────────────────────────────────────────────────────
local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Merges saved data onto a fresh default copy (handles schema upgrades gracefully)
local function mergeWithDefaults(saved)
	local merged = deepCopy(DEFAULT_DATA)
	for k, v in pairs(saved) do
		if type(v) == "table" and type(merged[k]) == "table" then
			-- Shallow-merge sub-tables so new sub-keys get default values
			for k2, v2 in pairs(v) do
				merged[k][k2] = v2
			end
		else
			merged[k] = v
		end
	end
	return merged
end

-- ──────────────────────────────────────────────────────────────
-- LOAD PLAYER
-- ──────────────────────────────────────────────────────────────
function DataManager.LoadPlayer(player)
	local userId = tostring(player.UserId)
	local success, result = pcall(function()
		return PlayerStore:GetAsync(userId)
	end)

	local data
	if success and result and not WIPE_DATA_FOR_TESTING then
		data = mergeWithDefaults(result)
	else
		data = deepCopy(DEFAULT_DATA)
		data.CreatedAt = os.time()
		if not success then
			warn("[DataManager] Load failed for " .. player.Name .. ": " .. tostring(result))
		end
	end

	cache[userId] = data
	dirty[userId] = false
	return data
end

-- ──────────────────────────────────────────────────────────────
-- DATA ACCESS HELPERS
-- ──────────────────────────────────────────────────────────────
function DataManager.GetData(player)
	return cache[tostring(player.UserId)]
end

function DataManager.MarkDirty(player)
	dirty[tostring(player.UserId)] = true
end

-- ──────────────────────────────────────────────────────────────
-- SAVE PLAYER
-- ──────────────────────────────────────────────────────────────
function DataManager.SavePlayer(player)
	local userId = tostring(player.UserId)
	local data   = cache[userId]
	if not data then return end

	data.LastSavedAt = os.time()

	-- Trim trade history to last 50 entries
	while #data.TradeHistory > 50 do
		table.remove(data.TradeHistory, 1)
	end

	local success, err = pcall(function()
		PlayerStore:SetAsync(userId, data)
	end)

	if success then
		dirty[userId] = false
	else
		warn("[DataManager] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- ──────────────────────────────────────────────────────────────
-- CLEANUP ON LEAVE
-- ──────────────────────────────────────────────────────────────
function DataManager.RemovePlayer(player)
	DataManager.SavePlayer(player)
	local userId = tostring(player.UserId)
	cache[userId] = nil
	dirty[userId] = nil
end

-- ──────────────────────────────────────────────────────────────
-- AUTO-SAVE LOOP  (every 60 seconds for dirty records)
-- ──────────────────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			local userId = tostring(player.UserId)
			if dirty[userId] then
				DataManager.SavePlayer(player)
			end
		end
	end
end)

-- ──────────────────────────────────────────────────────────────
-- ORDERED-DATASTORE LEADERBOARDS
-- ──────────────────────────────────────────────────────────────
function DataManager.UpdateLeaderboard(player, inventoryValue, puckBalance)
	local uid = tostring(player.UserId)
	pcall(function() ValueBoard:SetAsync(uid, math.floor(inventoryValue)) end)
	pcall(function() PucksBoard:SetAsync(uid, math.floor(puckBalance))  end)
end

--- board = "Value" | "Packs"
function DataManager.GetTopPlayers(board, count)
	local store = (board == "Pucks") and PucksBoard or ValueBoard
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, count or 10)
	end)
	if not success then return {} end

	local entries = pages:GetCurrentPage()
	local result  = {}
	for _, entry in ipairs(entries) do
		table.insert(result, { UserId = entry.key, Score = entry.value })
	end
	return result
end

return DataManager
