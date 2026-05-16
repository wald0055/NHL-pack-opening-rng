-- EconomySystem.lua
-- Location: ServerScriptService
-- Handles quests, login rewards, achievements, currency helpers.

local CardDatabase = require(game.ReplicatedStorage.Modules.CardDatabase)
local DataManager  = require(script.Parent.DataManager)

local EconomySystem = {}

-- ──────────────────────────────────────────────────────────────
-- TIME HELPERS
-- ──────────────────────────────────────────────────────────────
local function getDayNumber()
	return math.floor(os.time() / 86400)
end

local function getWeekNumber()
	return math.floor(os.time() / (86400 * 7))
end

-- ──────────────────────────────────────────────────────────────
-- SEEDED SHUFFLE  (for deterministic quest assignment per player)
-- ──────────────────────────────────────────────────────────────
local function seededShuffle(pool, seed)
	-- Create a local RNG from seed without affecting global math.random
	local rng  = Random.new(seed)
	local copy = {}
	for _, v in ipairs(pool) do table.insert(copy, v) end
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- ──────────────────────────────────────────────────────────────
-- REFRESH QUESTS  (called on login and daily boundary cross)
-- ──────────────────────────────────────────────────────────────
function EconomySystem.RefreshQuests(player)
	local data = DataManager.GetData(player)
	if not data then return end

	local today    = getDayNumber()
	local thisWeek = getWeekNumber()
	local changed  = false

	-- Daily quests (3 per day, seeded by day × userId for consistency)
	if (data.LastQuestResetDay or 0) < today then
		local shuffled = seededShuffle(CardDatabase.DailyQuestPool, today * player.UserId)
		data.DailyQuestsAssigned = {}
		data.DailyQuestProgress  = {}
		for i = 1, math.min(3, #shuffled) do
			table.insert(data.DailyQuestsAssigned, shuffled[i])
			data.DailyQuestProgress[shuffled[i].Id] = 0
		end
		data.LastQuestResetDay = today
		changed = true
	end

	print("[DEBUG] WeeklyQuestPool size:", #(CardDatabase.WeeklyQuestPool or {}))

	-- Weekly quests (3 per week)
	if (data.LastWeeklyResetDay or 0) < thisWeek then
		local shuffled = seededShuffle(CardDatabase.WeeklyQuestPool, thisWeek * player.UserId + 7)
		data.WeeklyQuestsAssigned = {}
		data.WeeklyQuestProgress  = {}
		for i = 1, math.min(3, #shuffled) do
			table.insert(data.WeeklyQuestsAssigned, shuffled[i])
			data.WeeklyQuestProgress[shuffled[i].Id] = 0
		end
		data.LastWeeklyResetDay = thisWeek
		changed = true
	end

	if changed then DataManager.MarkDirty(player) end
end

-- ──────────────────────────────────────────────────────────────
-- UPDATE QUEST PROGRESS
-- stat: "PacksOpened" | "RarePulls" | "EpicPulls" | "LegPulls"
--       "CardsSold" | "PucksEarned" | "TradesDone"
-- Returns: array of completed quest records { Type, Quest }
-- ──────────────────────────────────────────────────────────────
function EconomySystem.UpdateQuestProgress(player, stat, amount)
	local data = DataManager.GetData(player)
	if not data then return {} end

	local completed = {}

	-- Daily quests
	for _, q in ipairs(data.DailyQuestsAssigned or {}) do
		if q.Stat == stat then
			local prog = data.DailyQuestProgress[q.Id] or 0
			if prog < q.Target then
				data.DailyQuestProgress[q.Id] = math.min(prog + amount, q.Target)
				if data.DailyQuestProgress[q.Id] >= q.Target then
					data.Pucks = data.Pucks + (q.PuckReward or 0)
					data.Gems  = data.Gems  + (q.GemReward  or 0)
					data.TotalPucksEarned = (data.TotalPucksEarned or 0) + (q.PuckReward or 0)
					table.insert(completed, { Type = "Daily", Quest = q })
				end
			end
		end
	end

	-- Weekly quests
	for _, wq in ipairs(data.WeeklyQuestsAssigned or {}) do
		if wq.Stat == stat then
			local prog = (data.WeeklyQuestProgress or {})[wq.Id] or 0
			if prog < wq.Target then
				if not data.WeeklyQuestProgress then data.WeeklyQuestProgress = {} end
				data.WeeklyQuestProgress[wq.Id] = math.min(prog + amount, wq.Target)
				if data.WeeklyQuestProgress[wq.Id] >= wq.Target then
					data.Pucks = data.Pucks + (wq.PuckReward or 0)
					data.Gems  = data.Gems  + (wq.GemReward  or 0)
					data.TotalPucksEarned = (data.TotalPucksEarned or 0) + (wq.PuckReward or 0)
					table.insert(completed, { Type = "Weekly", Quest = wq })
				end
			end
		end
	end 

	if #completed > 0 then DataManager.MarkDirty(player) end
	return completed
end

-- ──────────────────────────────────────────────────────────────
-- DAILY LOGIN REWARD
-- Returns: true, rewardTable, calendarDay  OR  false, errorCode
-- ──────────────────────────────────────────────────────────────
function EconomySystem.ClaimLoginReward(player)
	local data = DataManager.GetData(player)
	if not data then return false, "PlayerDataNotLoaded" end

	local today = getDayNumber()
	if (data.LastLoginDay or 0) == today then
		return false, "AlreadyClaimed"
	end

	-- Update streak
	if (data.LastLoginDay or 0) == today - 1 then
		data.LoginStreak = (data.LoginStreak or 0) + 1
	else
		data.LoginStreak = 1
	end
	data.LastLoginDay = today

	-- 30-day calendar position
	local calDay = ((data.LoginStreak - 1) % 30) + 1
	local reward = CardDatabase.LoginRewards[calDay] or { Pucks = 100, Gems = 0 }

	data.Pucks            = data.Pucks + (reward.Pucks or 0)
	data.Gems             = data.Gems  + (reward.Gems  or 0)
	data.TotalPucksEarned = (data.TotalPucksEarned or 0) + (reward.Pucks or 0)

	if not data.LoginCalendar then data.LoginCalendar = {} end
	data.LoginCalendar[tostring(calDay)] = true

	DataManager.MarkDirty(player)
	return true, reward, calDay
end

-- ──────────────────────────────────────────────────────────────
-- CHECK SINGLE ACHIEVEMENT
-- Returns: achievementDef if newly earned, nil if already earned or not found
-- ──────────────────────────────────────────────────────────────
function EconomySystem.CheckAchievement(player, achievementId)
	local data = DataManager.GetData(player)
	if not data then return nil end
	if not data.AchievementsEarned then data.AchievementsEarned = {} end
	if data.AchievementsEarned[achievementId] then return nil end  -- already earned

	local achDef = nil
	for _, a in ipairs(CardDatabase.Achievements) do
		if a.Id == achievementId then achDef = a break end
	end
	if not achDef then return nil end

	data.AchievementsEarned[achievementId] = true
	data.Pucks            = data.Pucks + (achDef.PuckReward or 0)
	data.Gems             = data.Gems  + (achDef.GemReward  or 0)
	data.TotalPucksEarned = (data.TotalPucksEarned or 0) + (achDef.PuckReward or 0)

	DataManager.MarkDirty(player)
	return achDef
end

-- ──────────────────────────────────────────────────────────────
-- BATCH ACHIEVEMENT CHECK  (called after pack opens, luck upgrades, etc.)
-- Returns: array of earned achievement defs
-- ──────────────────────────────────────────────────────────────
function EconomySystem.CheckPackAchievements(player, data, rarityKey)
	local earned = {}
	local function check(id)
		local r = EconomySystem.CheckAchievement(player, id)
		if r then table.insert(earned, r) end
	end

	-- Pack count
	local packs = data.TotalPacksOpened or 0
	if packs >= 1    then check("first_pack")  end
	if packs >= 10   then check("packs_10")    end
	if packs >= 100  then check("packs_100")   end
	if packs >= 1000 then check("packs_1000")  end

	-- Rarity
	local r = CardDatabase.RarityRank[rarityKey] or 0
	if r >= 2 then check("first_rare")      end
	if r >= 3 then check("first_epic")      end
	if r >= 4 then check("first_legendary") end
	if r >= 5 then check("first_mythic")    end
	if r >= 6 then check("first_secret")    end

	-- Luck
	local lv = data.LuckLevel or 0
	if lv >= 5  then check("luck_5")  end
	if lv >= 10 then check("luck_10") end

	-- Collection
	local total = CardDatabase.GetTotalCollectibleCards()
	local pct   = ((data.CollectionCount or 0) / math.max(total, 1)) * 100
	if pct >= 25  then check("collection_25")  end
	if pct >= 50  then check("collection_50")  end
	if pct >= 100 then check("collection_100") end

	-- Trades
	local trades = data.TotalTradesDone or 0
	if trades >= 10 then check("trades_10") end

	return earned
end

-- ──────────────────────────────────────────────────────────────
-- ADD CURRENCY DIRECTLY  (dev products, admin, etc.)
-- ──────────────────────────────────────────────────────────────
function EconomySystem.AddCurrency(player, pucks, gems)
	local data = DataManager.GetData(player)
	if not data then return false end
	data.Pucks            = data.Pucks + (pucks or 0)
	data.Gems             = data.Gems  + (gems  or 0)
	data.TotalPucksEarned = (data.TotalPucksEarned or 0) + (pucks or 0)
	DataManager.MarkDirty(player)
	return true
end

-- ──────────────────────────────────────────────────────────────
-- EXPAND INVENTORY
-- ──────────────────────────────────────────────────────────────
function EconomySystem.ExpandInventory(player, slots)
	local data = DataManager.GetData(player)
	if not data then return false end
	data.MaxInventory = (data.MaxInventory or 200) + (slots or 0)
	DataManager.MarkDirty(player)
	return true
end

-- ──────────────────────────────────────────────────────────────
-- SET SHOWCASE CARDS  (up to 5)
-- ──────────────────────────────────────────────────────────────
function EconomySystem.SetShowcaseCards(player, cardIds)
	if type(cardIds) ~= "table" then return false, "InvalidInput" end
	if #cardIds > 5 then return false, "TooManyCards" end

	local data = DataManager.GetData(player)
	if not data then return false, "PlayerDataNotLoaded" end

	-- Validate player owns every card
	for _, id in ipairs(cardIds) do
		local found = false
		for _, c in ipairs(data.Inventory) do
			if c.CardId == id then found = true break end
		end
		if not found then return false, "CardNotFound:" .. tostring(id) end
	end

	data.ShowcaseCards = cardIds
	DataManager.MarkDirty(player)
	return true
end

return EconomySystem
