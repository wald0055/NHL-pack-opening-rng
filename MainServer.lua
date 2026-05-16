-- MainServer.lua
-- Location: ServerScriptService  (Script, RunContext: Server)
-- Central hub: creates all RemoteEvents/Functions, wires all systems together.

print("[MainServer] Script started, server time:", os.time())

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerScriptService= game:GetService("ServerScriptService")

-- ──────────────────────────────────────────────────────────────
-- MODULE REQUIRES
-- ──────────────────────────────────────────────────────────────
local DataManager   = require(ServerScriptService:WaitForChild("DataManager"))
local PackSystem    = require(ServerScriptService:WaitForChild("PackSystem"))
local LuckSystem    = require(ServerScriptService:WaitForChild("LuckSystem"))
local TradeSystem   = require(ServerScriptService:WaitForChild("TradeSystem"))
local EconomySystem = require(ServerScriptService:WaitForChild("EconomySystem"))
local EventSystem   = require(ServerScriptService:WaitForChild("EventSystem"))
local CardDatabase  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CardDatabase"))

-- ──────────────────────────────────────────────────────────────
-- CREATE REMOTES FOLDER
-- ──────────────────────────────────────────────────────────────
local Remotes = Instance.new("Folder")
Remotes.Name   = "Remotes"
Remotes.Parent = ReplicatedStorage

local function makeEvent(name)
	local e = Instance.new("RemoteEvent")
	e.Name   = name
	e.Parent = Remotes
	return e
end

local function makeFunction(name)
	local f = Instance.new("RemoteFunction")
	f.Name   = name
	f.Parent = Remotes
	return f
end

-- Server → Client events
local GlobalAnnounce    = makeEvent("GlobalAnnounce")
local DataSync          = makeEvent("DataSync")
local QuestComplete     = makeEvent("QuestComplete")
local AchievementEarned = makeEvent("AchievementEarned")
local TradeIncoming     = makeEvent("TradeIncoming")       -- kept for compat (unused now)
local TradeBothConfirmed= makeEvent("TradeBothConfirmed")  -- kept for compat (unused now)
local TradeCompleted    = makeEvent("TradeCompleted")
local TradeCancelled    = makeEvent("TradeCancelled")
local TradeProposed     = makeEvent("TradeProposed")

-- New phase-based trade remotes
local TradeRequest      = makeEvent("TradeRequest")         -- A → server: "I want to trade with B"
local TradeRequestRecv  = makeEvent("TradeRequestRecv")     -- server → B: "A wants to trade"
local TradeRequestResp  = makeEvent("TradeRequestResp")     -- B → server: accept/decline
local TradeSessionOpen  = makeEvent("TradeSessionOpen")     -- server → both: open live window
local TradeOfferUpdate  = makeEvent("TradeOfferUpdate")     -- player → server: my current card offer
local TradeOfferRecv    = makeEvent("TradeOfferRecv")       -- server → other player: partner's cards changed
local TradeConfirm      = makeEvent("TradeConfirm")         -- player → server: I accept this trade
local TradeUnconfirm    = makeEvent("TradeUnconfirm")       -- player → server: I unaccept (changed offer)
local TradeConfirmStatus= makeEvent("TradeConfirmStatus")   -- server → both: who has confirmed
local LoginRewardReady  = makeEvent("LoginRewardReady")

-- Client → Server calls (RemoteFunction = has return value)
local OpenPackFn        = makeFunction("OpenPack")
local SellCardFn        = makeFunction("SellCard")
local BulkSellFn = makeFunction("BulkSell")
local LockCardFn = makeFunction("LockCard")
local UpgradeLuckFn     = makeFunction("UpgradeLuck")
local PrestigeFn        = makeFunction("Prestige")
local ClaimLoginFn      = makeFunction("ClaimLogin")
local SetShowcaseFn     = makeFunction("SetShowcase")
local GetLeaderboardFn  = makeFunction("GetLeaderboard")
local GetPlayerCardsFn  = makeFunction("GetPlayerCards")
local GetOnlinePlayersFn = makeFunction("GetOnlinePlayers")

-- ──────────────────────────────────────────────────────────────
-- GET ONLINE PLAYERS  (for trade player-picker UI)
-- ──────────────────────────────────────────────────────────────
GetOnlinePlayersFn.OnServerInvoke = function(requestingPlayer)
	local result = {}
	for _, p in ipairs(Players:GetPlayers()) do
		print("[DEBUG] Checking player:", p.Name, "vs requester:", requestingPlayer.Name)
		if p.UserId ~= requestingPlayer.UserId then
			table.insert(result, {
				Name   = p.Name,
				UserId = p.UserId,
			})
		end
	end
	print("[DEBUG] Returning", #result, "players")
	return result
end

-- Client → Server (fire-and-forget)
local ProposeTradeEv    = makeEvent("ProposeTrade")   -- kept for compat
local AcceptTradeEv     = makeEvent("AcceptTrade")    -- kept for compat
local CancelTradeEv     = makeEvent("CancelTrade")

-- Wire EventSystem to the GlobalAnnounce remote
EventSystem.SetRemote(GlobalAnnounce)

-- Wire TradeSystem callback so it can fire TradeCompleted
TradeSystem.OnTradeCompleted = function(initiator, target, initCards, targCards)
	if initiator then
		TradeCompleted:FireClient(initiator)
		syncData(initiator)
		-- Check trades achievement
		local iData = DataManager.GetData(initiator)
		if iData then
			local ach = EconomySystem.CheckAchievement(initiator, "trades_10")
			if ach then AchievementEarned:FireClient(initiator, ach) end
			DataManager.UpdateLeaderboard(initiator, iData.InventoryValue or 0, iData.Pucks or 0)
		end
	end
	if target then
		TradeCompleted:FireClient(target)
		syncData(target)
		local tData = DataManager.GetData(target)
		if tData then
			local ach = EconomySystem.CheckAchievement(target, "trades_10")
			if ach then AchievementEarned:FireClient(target, ach) end
			DataManager.UpdateLeaderboard(target, tData.InventoryValue or 0, tData.Pucks or 0)
		end
	end
end

-- ──────────────────────────────────────────────────────────────
-- RATE LIMITING
-- ──────────────────────────────────────────────────────────────
local openCooldowns = {}  -- [userId] → last open clock timestamp
local OPEN_COOLDOWN = 0.5

local function checkRateLimit(player)
	local id  = player.UserId
	local now = os.clock()
	if openCooldowns[id] and (now - openCooldowns[id]) < OPEN_COOLDOWN then
		return false
	end
	openCooldowns[id] = now
	return true
end

-- ──────────────────────────────────────────────────────────────
-- GAMEPASS CACHE
-- ──────────────────────────────────────────────────────────────
local gamepassCache = {}  -- [userId] → { [passId] → bool }

local function hasGamepass(player, gamepassId)
	if gamepassId == 0 then return false end
	local uid = player.UserId
	if not gamepassCache[uid] then gamepassCache[uid] = {} end
	if gamepassCache[uid][gamepassId] == nil then
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, uid, gamepassId)
		gamepassCache[uid][gamepassId] = ok and owns or false
	end
	return gamepassCache[uid][gamepassId]
end

local function getGamepassBenefits(player)
	local benefits = {}
	local ids = CardDatabase.GamepassIds
	if hasGamepass(player, ids.AutoOpener)     then benefits.AutoOpener    = true end
	if hasGamepass(player, ids.LuckySkates)    then benefits.LuckySkates   = true end
	if hasGamepass(player, ids.VIPLockerRoom)  then benefits.VIPLockerRoom  = true end
	if hasGamepass(player, ids.VaultExpansion) then benefits.VaultExpansion = true end
	if hasGamepass(player, ids.FastBreak)      then benefits.FastBreak      = true end
	return benefits
end

-- ──────────────────────────────────────────────────────────────
-- SYNC DATA TO CLIENT  (forward-declared so TradeSystem callback can use it)
-- ──────────────────────────────────────────────────────────────
function syncData(player)
	local data = DataManager.GetData(player)
	if not data then return end
	DataSync:FireClient(player, {
		Pucks                  = data.Pucks,
		Gems                   = data.Gems,
		LuckLevel              = data.LuckLevel,
		PrestigeLevel          = data.PrestigeLevel,
		TotalPrestigeLuckBonus = data.TotalPrestigeLuckBonus,
		MaxInventory           = data.MaxInventory,
		Inventory              = data.Inventory,
		CollectionCount        = data.CollectionCount,
		CollectionIndex        = data.CollectionIndex,
		TotalPacksOpened       = data.TotalPacksOpened,
		TotalCardsSold         = data.TotalCardsSold,
		TotalTradesDone        = data.TotalTradesDone,
		RarestCardPulled       = data.RarestCardPulled,
		InventoryValue         = data.InventoryValue,
		LoginStreak            = data.LoginStreak,
		LoginCalendar          = data.LoginCalendar,
		DailyQuestsAssigned    = data.DailyQuestsAssigned,
		DailyQuestProgress     = data.DailyQuestProgress,
		WeeklyQuestsAssigned   = data.WeeklyQuestsAssigned,
		WeeklyQuestProgress    = data.WeeklyQuestProgress,
		AchievementsEarned     = data.AchievementsEarned,
		ShowcaseCards          = data.ShowcaseCards,
		ActiveLuckBoost        = data.ActiveLuckBoost,
		PityCounters           = data.PityCounters,
		TradeHistory           = data.TradeHistory,
		CurrentStreak          = data.CurrentStreak,
	})
end

-- ──────────────────────────────────────────────────────────────
-- PLAYER JOINED
-- ──────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	local data = DataManager.LoadPlayer(player)

	--Give 999999 pucks
	--if player.Name == "3nonly_ash" then data.Pucks = 999999 DataManager.MarkDirty(player) end

	task.spawn(function()
		local benefits = getGamepassBenefits(player)

		-- Apply vault expansion (once)
		if benefits.VaultExpansion and (data.MaxInventory or 200) < 700 then
			EconomySystem.ExpandInventory(player, 500)
		end

		-- VIP daily puck bonus
		if benefits.VIPLockerRoom then
			local today = math.floor(os.time() / 86400)
			if (data.LastLoginDay or 0) < today then
				EconomySystem.AddCurrency(player, CardDatabase.GamepassBenefits.VIPLockerRoom.BonusDailyPucks, 0)
			end
		end

		-- Refresh quests before first sync
		EconomySystem.RefreshQuests(player)

		-- Initial data sync
		syncData(player)

		-- Write to leaderboard stores on join so the Pucks board is populated
		-- immediately, even for players who joined before the board existed.
		DataManager.UpdateLeaderboard(player, data.InventoryValue or 0, data.Pucks or 0)

		-- Login reward available notification
		local today = math.floor(os.time() / 86400)
		if (data.LastLoginDay or 0) < today then
			LoginRewardReady:FireClient(player)
		end

		-- Welcome to active events
		EventSystem.OnPlayerJoin(player)

		-- Login streak achievements (slight delay for UI readiness)
		task.wait(5)
		if player and player.Parent then
			if (data.LoginStreak or 0) >= 7 then
				local ach = EconomySystem.CheckAchievement(player, "daily_7")
				if ach then AchievementEarned:FireClient(player, ach) end
			end
			if (data.LoginStreak or 0) >= 30 then
				local ach = EconomySystem.CheckAchievement(player, "daily_30")
				if ach then AchievementEarned:FireClient(player, ach) end
			end
			syncData(player)
		end
	end)
end)

-- ──────────────────────────────────────────────────────────────
-- PLAYER LEAVING
-- ──────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	DataManager.RemovePlayer(player)
	gamepassCache[player.UserId] = nil
	openCooldowns[player.UserId] = nil
end)

-- ──────────────────────────────────────────────────────────────
-- OPEN PACK
-- ──────────────────────────────────────────────────────────────
OpenPackFn.OnServerInvoke = function(player, packKey)
	if not checkRateLimit(player) then
		return { Success = false, Error = "RateLimit" }
	end
	if type(packKey) ~= "string" then
		return { Success = false, Error = "InvalidPackKey" }
	end

	local benefits    = getGamepassBenefits(player)
	local activeEvent = EventSystem.GetActiveEvent()

	local card, rarityKey, err = PackSystem.OpenPack(player, packKey, benefits, activeEvent)
	if err then
		return { Success = false, Error = err }
	end

	local data     = DataManager.GetData(player)
	local rankMap  = CardDatabase.RarityRank
	local rank     = rankMap[rarityKey] or 0

	-- Quest progress
	local completedQuests = {}
	local function addQ(q) for _, v in ipairs(q) do table.insert(completedQuests, v) end end
	addQ(EconomySystem.UpdateQuestProgress(player, "PacksOpened", 1))
	if rank >= 2 then addQ(EconomySystem.UpdateQuestProgress(player, "RarePulls", 1)) end
	if rank >= 3 then addQ(EconomySystem.UpdateQuestProgress(player, "EpicPulls", 1)) end
	if rank >= 4 then addQ(EconomySystem.UpdateQuestProgress(player, "LegPulls",  1)) end

	-- Achievements
	local earnedAchs = EconomySystem.CheckPackAchievements(player, data, rarityKey)

	-- Community milestone tracking
	EventSystem.OnPackOpened()

	-- Rare pull broadcast
	EventSystem.OnRarePull(player, card, rarityKey)

	-- Update ordered leaderboard
	DataManager.UpdateLeaderboard(player, data.InventoryValue or 0, data.Pucks or 0)

	-- Notify client of quest completions
	for _, q in ipairs(completedQuests) do
		QuestComplete:FireClient(player, q)
	end

	-- Notify client of achievements
	for _, a in ipairs(earnedAchs) do
		AchievementEarned:FireClient(player, a)
	end

	-- Sync updated data
	syncData(player)

	return {
		Success   = true,
		Card      = card,
		RarityKey = rarityKey,
		AnimSpeed = (benefits.FastBreak and CardDatabase.GamepassBenefits.FastBreak.AnimationSpeed or 1.0),
	}
end

-- ──────────────────────────────────────────────────────────────
-- SELL CARD
-- ──────────────────────────────────────────────────────────────
SellCardFn.OnServerInvoke = function(player, cardId)
	if type(cardId) ~= "string" then return { Success = false, Error = "InvalidCardId" } end

	local success, result = PackSystem.SellCard(player, cardId)
	if success then
		local data = DataManager.GetData(player)
		EconomySystem.UpdateQuestProgress(player, "CardsSold",   1)
		EconomySystem.UpdateQuestProgress(player, "PucksEarned", result)
		DataManager.UpdateLeaderboard(player, data.InventoryValue or 0, data.Pucks or 0)
		syncData(player)
		return { Success = true, SellValue = result }
	else
		return { Success = false, Error = result }
	end
end

BulkSellFn.OnServerInvoke = function(player, rarities)
	-- Validate input
	if type(rarities) ~= "table" or #rarities == 0 then
		return { Success=false, Error="NoRaritiesProvided" }
	end
	local allowed = {}
	for _, r in ipairs(rarities) do
		if type(r) == "string" then allowed[r] = true end
	end

	local data = DataManager.GetData(player)
	if not data then return { Success=false, Error="DataNotLoaded" } end

	local totalPucks = 0
	local count      = 0
	local remaining  = {}

	for _, card in ipairs(data.Inventory) do
		if allowed[card.Rarity] and not card.Locked then
			-- Sell it
			local sellValue = math.floor((card.Value or 0) * 1.0)
			totalPucks     = totalPucks + sellValue
			count          = count + 1
			data.TotalCardsSold   = (data.TotalCardsSold   or 0) + 1
			data.TotalPucksEarned = (data.TotalPucksEarned or 0) + sellValue
			-- Remove from showcase if present
			for si, showcardId in ipairs(data.ShowcaseCards or {}) do
				if showcardId == card.CardId then
					table.remove(data.ShowcaseCards, si)
					break
				end
			end
		else
			table.insert(remaining, card)
		end
	end

	if count == 0 then
		return { Success=false, Error="NoEligibleCards" }
	end

	data.Inventory = remaining
	data.Pucks     = data.Pucks + totalPucks

	-- Recalculate inventory value
	local total = 0
	for _, c in ipairs(data.Inventory) do total = total + (c.Value or 0) end
	data.InventoryValue = total

	-- Quest + leaderboard updates
	EconomySystem.UpdateQuestProgress(player, "CardsSold",   count)
	EconomySystem.UpdateQuestProgress(player, "PucksEarned", totalPucks)
	DataManager.UpdateLeaderboard(player, data.InventoryValue, data.Pucks or 0)
	DataManager.MarkDirty(player)
	syncData(player)

	return { Success=true, Count=count, Total=totalPucks }
end

LockCardFn.OnServerInvoke = function(player, cardId)
	if type(cardId) ~= "string" then return { Success=false, Error="InvalidCardId" } end

	local data = DataManager.GetData(player)
	if not data then return { Success=false, Error="DataNotLoaded" } end

	for _, card in ipairs(data.Inventory) do
		if card.CardId == cardId then
			card.Locked = not (card.Locked or false)
			DataManager.MarkDirty(player)
			syncData(player)
			return { Success=true, Locked=card.Locked }
		end
	end

	return { Success=false, Error="CardNotFound" }
end

-- ──────────────────────────────────────────────────────────────
-- UPGRADE LUCK
-- ──────────────────────────────────────────────────────────────
UpgradeLuckFn.OnServerInvoke = function(player)
	local success, level, mult = LuckSystem.UpgradeLuck(player)
	if success then
		local data      = DataManager.GetData(player)
		local earnedAchs= EconomySystem.CheckPackAchievements(player, data, "Common")
		for _, a in ipairs(earnedAchs) do
			AchievementEarned:FireClient(player, a)
		end
		syncData(player)
		return { Success = true, NewLevel = level, NewMultiplier = mult }
	else
		return { Success = false, Error = level }
	end
end

-- ──────────────────────────────────────────────────────────────
-- PRESTIGE
-- ──────────────────────────────────────────────────────────────
PrestigeFn.OnServerInvoke = function(player)
	local success, level, badge = LuckSystem.Prestige(player)
	if success then
		local ach = EconomySystem.CheckAchievement(player, "prestige_1")
		if ach then AchievementEarned:FireClient(player, ach) end
		syncData(player)
		return { Success = true, NewPrestige = level, Badge = badge }
	else
		return { Success = false, Error = level }
	end
end

-- ──────────────────────────────────────────────────────────────
-- TRADING  (phase-based: handshake → live negotiation → confirm)
-- ──────────────────────────────────────────────────────────────

-- Active sessions: sessionId → { InitiatorId, TargetId, InitiatorCards={}, TargetCards={}, InitiatorConfirmed, TargetConfirmed }
local tradeSessions = {}
local SESSION_TIMEOUT = 300  -- 5 min max

local function makeSessionId(a, b)
	return string.format("%d_%d_%d", a.UserId, b.UserId, os.time())
end

local function getSessionForPlayer(player)
	for id, s in pairs(tradeSessions) do
		if s.InitiatorId == player.UserId or s.TargetId == player.UserId then
			return id, s
		end
	end
	return nil, nil
end

local function resolveCards(playerId, cardIds)
	local p = Players:GetPlayerByUserId(playerId)
	if not p then return {} end
	local data = DataManager.GetData(p)
	if not data then return {} end
	local out = {}
	for _, card in ipairs(data.Inventory) do
		for _, id in ipairs(cardIds) do
			if card.CardId == id then
				table.insert(out, {
					CardId=card.CardId, PlayerName=card.PlayerName,
					Rarity=card.Rarity, OVR=card.OVR, Team=card.Team,
					Value=card.Value, Variant=card.Variant,
				})
				break
			end
		end
	end
	return out
end

-- PHASE 1: Player A requests a trade with Player B
TradeRequest.OnServerEvent:Connect(function(player, targetName)
	if type(targetName) ~= "string" then return end
	local target = Players:FindFirstChild(targetName)
	if not target or target == player then return end
	-- Don't allow if either is already in a session
	local _, existing = getSessionForPlayer(player)
	if existing then return end
	-- Fire the request notification to B
	TradeRequestRecv:FireClient(target, {
		InitiatorName = player.Name,
		InitiatorId   = player.UserId,
	})
end)

-- PHASE 1b: Player B accepts or declines
TradeRequestResp.OnServerEvent:Connect(function(player, initiatorId, accepted)
	if not accepted then
		-- Tell A they were declined
		local initiator = Players:GetPlayerByUserId(initiatorId)
		if initiator then
			TradeCancelled:FireClient(initiator)
		end
		return
	end
	local initiator = Players:GetPlayerByUserId(initiatorId)
	if not initiator then return end

	-- Create a session with no cards yet
	local sessionId = makeSessionId(initiator, player)
	tradeSessions[sessionId] = {
		InitiatorId        = initiator.UserId,
		TargetId           = player.UserId,
		InitiatorCards     = {},
		TargetCards        = {},
		InitiatorConfirmed = false,
		TargetConfirmed    = false,
		CreatedAt          = os.time(),
	}

	-- Auto-expire
	task.delay(SESSION_TIMEOUT, function()
		if tradeSessions[sessionId] then
			tradeSessions[sessionId] = nil
		end
	end)

	-- Tell both players to open the live trade window
	TradeSessionOpen:FireClient(initiator, { SessionId=sessionId, PartnerName=player.Name })
	TradeSessionOpen:FireClient(player,    { SessionId=sessionId, PartnerName=initiator.Name })
end)

-- PHASE 2: A player updates their offered cards
TradeOfferUpdate.OnServerEvent:Connect(function(player, sessionId, cardIds)
	local session = tradeSessions[sessionId]
	if not session then return end
	if type(cardIds) ~= "table" then cardIds = {} end
	-- Limit to 5
	while #cardIds > 5 do table.remove(cardIds) end

	local isInitiator = session.InitiatorId == player.UserId
	local isTarget    = session.TargetId    == player.UserId
	if not isInitiator and not isTarget then return end

	-- Resolve card objects from inventory
	local cards = resolveCards(player.UserId, cardIds)

	-- Store and reset that player's confirm (offer changed = must re-confirm)
	if isInitiator then
		session.InitiatorCards     = cards
		session.InitiatorConfirmed = false
	else
		session.TargetCards        = cards
		session.TargetConfirmed    = false
	end

	-- Relay updated cards to the other player
	local otherId = isInitiator and session.TargetId or session.InitiatorId
	local other   = Players:GetPlayerByUserId(otherId)
	if other then
		TradeOfferRecv:FireClient(other, cards)
	end

	-- Broadcast confirm status (both unchecked now since offer changed)
	local initiator = Players:GetPlayerByUserId(session.InitiatorId)
	local target    = Players:GetPlayerByUserId(session.TargetId)
	local status    = { InitiatorConfirmed=session.InitiatorConfirmed, TargetConfirmed=session.TargetConfirmed }
	if initiator then TradeConfirmStatus:FireClient(initiator, status) end
	if target    then TradeConfirmStatus:FireClient(target,    status) end
end)

-- PHASE 3: A player clicks Accept in the live window
TradeConfirm.OnServerEvent:Connect(function(player, sessionId)
	local session = tradeSessions[sessionId]
	if not session then return end
	local isInitiator = session.InitiatorId == player.UserId
	local isTarget    = session.TargetId    == player.UserId
	if not isInitiator and not isTarget then return end

	if isInitiator then session.InitiatorConfirmed = true
	else                session.TargetConfirmed    = true end

	local initiator = Players:GetPlayerByUserId(session.InitiatorId)
	local target    = Players:GetPlayerByUserId(session.TargetId)
	local status    = { InitiatorConfirmed=session.InitiatorConfirmed, TargetConfirmed=session.TargetConfirmed }
	if initiator then TradeConfirmStatus:FireClient(initiator, status) end
	if target    then TradeConfirmStatus:FireClient(target,    status) end

	-- Both confirmed — execute
	if session.InitiatorConfirmed and session.TargetConfirmed then
		tradeSessions[sessionId] = nil

		if not initiator or not target then return end
		local initiatorData = DataManager.GetData(initiator)
		local targetData    = DataManager.GetData(target)
		if not initiatorData or not targetData then return end

		-- Validate cards still exist
		local function hasCards(inv, cards)
			for _, wantCard in ipairs(cards) do
				local found = false
				for _, invCard in ipairs(inv) do
					if invCard.CardId == wantCard.CardId and not invCard.Locked then
						found = true break
					end
				end
				if not found then return false end
			end
			return true
		end

		if not hasCards(initiatorData.Inventory, session.InitiatorCards) or
			not hasCards(targetData.Inventory,    session.TargetCards) then
			if initiator then TradeCancelled:FireClient(initiator) end
			if target    then TradeCancelled:FireClient(target)    end
			return
		end

		-- Build ID sets
		local initSet, targSet = {}, {}
		for _, c in ipairs(session.InitiatorCards) do initSet[c.CardId] = true end
		for _, c in ipairs(session.TargetCards)    do targSet[c.CardId] = true end

		-- Swap inventories
		local newInitInv, newTargInv = {}, {}
		for _, c in ipairs(initiatorData.Inventory) do
			if initSet[c.CardId] then table.insert(targetData.Inventory, c)
			else table.insert(newInitInv, c) end
		end
		for _, c in ipairs(targetData.Inventory) do
			if targSet[c.CardId] then table.insert(initiatorData.Inventory, c)
			else table.insert(newTargInv, c) end
		end
		initiatorData.Inventory = newInitInv
		targetData.Inventory    = newTargInv

		-- Recalc values
		local function recalc(inv) local v=0 for _,c in ipairs(inv) do v=v+(c.Value or 0) end return v end
		initiatorData.InventoryValue = recalc(initiatorData.Inventory)
		targetData.InventoryValue    = recalc(targetData.Inventory)

		-- Stats
		initiatorData.TotalTradesDone = (initiatorData.TotalTradesDone or 0) + 1
		targetData.TotalTradesDone    = (targetData.TotalTradesDone    or 0) + 1

		DataManager.MarkDirty(initiator)
		DataManager.MarkDirty(target)

		TradeCompleted:FireClient(initiator)
		TradeCompleted:FireClient(target)
		syncData(initiator)
		syncData(target)
		DataManager.UpdateLeaderboard(initiator, initiatorData.InventoryValue, initiatorData.Pucks or 0)
		DataManager.UpdateLeaderboard(target,    targetData.InventoryValue,    targetData.Pucks    or 0)
	end
end)

-- PHASE 3b: Unconfirm (player changed offer after confirming)
TradeUnconfirm.OnServerEvent:Connect(function(player, sessionId)
	local session = tradeSessions[sessionId]
	if not session then return end
	if session.InitiatorId == player.UserId then session.InitiatorConfirmed = false
	elseif session.TargetId == player.UserId then session.TargetConfirmed = false end
	local initiator = Players:GetPlayerByUserId(session.InitiatorId)
	local target    = Players:GetPlayerByUserId(session.TargetId)
	local status    = { InitiatorConfirmed=session.InitiatorConfirmed, TargetConfirmed=session.TargetConfirmed }
	if initiator then TradeConfirmStatus:FireClient(initiator, status) end
	if target    then TradeConfirmStatus:FireClient(target,    status) end
end)

-- Cancel / leave session
CancelTradeEv.OnServerEvent:Connect(function(player, sessionId)
	local session = sessionId and tradeSessions[sessionId]
	if not session then
		-- Try finding by player
		local id, s = getSessionForPlayer(player)
		if s then
			session = s
			sessionId = id
		else return end
	end
	local initiator = Players:GetPlayerByUserId(session.InitiatorId)
	local target    = Players:GetPlayerByUserId(session.TargetId)
	tradeSessions[sessionId] = nil
	if initiator then TradeCancelled:FireClient(initiator) end
	if target    then TradeCancelled:FireClient(target)    end
end)

-- Legacy compat (old ProposeTrade/AcceptTrade no longer used but keep to avoid errors)
ProposeTradeEv.OnServerEvent:Connect(function() end)
AcceptTradeEv.OnServerEvent:Connect(function() end)

-- ──────────────────────────────────────────────────────────────
-- CLAIM LOGIN REWARD (placeholder to fix split — real handler below)
-- ──────────────────────────────────────────────────────────────
local _unusedTradingEnd = true

local function _unusedTradingEnd2() end  -- intentional blank

-- ──────────────────────────────────────────────────────────────
-- TRADING (legacy stub end)
-- ──────────────────────────────────────────────────────────────
local _compat_ProposeTradeEv_unused = true

local function _compat2() end

-- Kept for TradeSystem.OnTradeCompleted wiring (used by old TradeSystem)
-- New system handles completion inline above; this is a no-op callback
TradeSystem.OnTradeCompleted = function(initiator, target, initCards, targCards)
	-- Intentionally empty — new system fires TradeCompleted directly
end

-- ──────────────────────────────────────────────────────────────
-- [TRADING SECTION END]
-- ──────────────────────────────────────────────────────────────
local _tradingSectionDone = true

ProposeTradeEv.OnServerEvent:Connect(function(player, targetName, myCardIds, theirCardIds)
	if type(targetName) ~= "string" then return end
	local target = Players:FindFirstChild(targetName)
	if not target then return end

	local tradeId, err = TradeSystem.ProposeTrade(
		player, target,
		type(myCardIds)    == "table" and myCardIds    or {},
		type(theirCardIds) == "table" and theirCardIds or {}
	)
	if tradeId then
		-- Look up full card objects so the UI can show names/rarities
		local initiatorData = DataManager.GetData(player)
		local initiatorCards = {}
		for _, card in ipairs(initiatorData and initiatorData.Inventory or {}) do
			for _, id in ipairs(myCardIds or {}) do
				if card.CardId == id then
					table.insert(initiatorCards, {
						CardId     = card.CardId,
						PlayerName = card.PlayerName,
						Rarity     = card.Rarity,
						OVR        = card.OVR,
						Team       = card.Team,
					})
					break
				end
			end
		end

		TradeIncoming:FireClient(target, {
			TradeId       = tradeId,
			InitiatorName = player.Name,
			OfferingCards = initiatorCards,  -- full card objects
		})

		-- FIX BUG 3: Fire the tradeId back to the initiator so their client
		-- stores it in pendingTradeId. Without this, the initiator has no way
		-- to cancel the trade and their pendingTradeId stays nil/stale.
		TradeProposed:FireClient(player, tradeId)

		syncData(player)
	end
end)

AcceptTradeEv.OnServerEvent:Connect(function(player, tradeId)
	if type(tradeId) ~= "string" then return end
	local success, status = TradeSystem.AcceptTrade(player, tradeId)
	if not success then return end

	local trade = TradeSystem.GetTrade(tradeId)
	if not trade then return end
	local initiator = Players:GetPlayerByUserId(trade.InitiatorId)
	local target    = Players:GetPlayerByUserId(trade.TargetId)

	if status == "BothConfirmed" then
		-- Both players accepted — start the 10-second cancel window
		if initiator then TradeBothConfirmed:FireClient(initiator, tradeId) end
		if target    then TradeBothConfirmed:FireClient(target,    tradeId) end
	elseif status == "WaitingForOther" then
		-- Only one player has accepted — tell them their accept was registered
		-- We reuse GlobalAnnounce or just syncData; simplest is a direct FireClient
		-- on TradeBothConfirmed with a special flag isn't ideal, so we fire to just
		-- the player who accepted so they know to wait.
		-- Use the existing TradeBothConfirmed with a "waiting" payload:
		if player.UserId == trade.InitiatorId and initiator then
			TradeBothConfirmed:FireClient(initiator, tradeId, "waiting")
		elseif player.UserId == trade.TargetId and target then
			TradeBothConfirmed:FireClient(target, tradeId, "waiting")
		end
	end
end)


CancelTradeEv.OnServerEvent:Connect(function(player, tradeId)
	if type(tradeId) ~= "string" then return end
	local trade    = TradeSystem.GetTrade(tradeId)
	local initiatorId = trade and trade.InitiatorId
	local targetId    = trade and trade.TargetId
	local success  = TradeSystem.CancelTrade(player, tradeId)
	if success then
		local initiator = initiatorId and Players:GetPlayerByUserId(initiatorId)
		local target    = targetId    and Players:GetPlayerByUserId(targetId)
		if initiator then TradeCancelled:FireClient(initiator, tradeId) end
		if target    then TradeCancelled:FireClient(target,    tradeId) end
	end
end)

-- ──────────────────────────────────────────────────────────────
-- CLAIM LOGIN REWARD
-- ──────────────────────────────────────────────────────────────
ClaimLoginFn.OnServerInvoke = function(player)
	local success, reward, calDay = EconomySystem.ClaimLoginReward(player)
	if success then
		local data = DataManager.GetData(player)
		if (data.LoginStreak or 0) >= 7  then
			local ach = EconomySystem.CheckAchievement(player, "daily_7")
			if ach then AchievementEarned:FireClient(player, ach) end
		end
		if (data.LoginStreak or 0) >= 30 then
			local ach = EconomySystem.CheckAchievement(player, "daily_30")
			if ach then AchievementEarned:FireClient(player, ach) end
		end
		syncData(player)
		return { Success = true, Reward = reward, Day = calDay }
	else
		return { Success = false, Error = reward }
	end
end

-- ──────────────────────────────────────────────────────────────
-- SET SHOWCASE CARDS
-- ──────────────────────────────────────────────────────────────
SetShowcaseFn.OnServerInvoke = function(player, cardIds)
	local success, err = EconomySystem.SetShowcaseCards(player, cardIds)
	if success then
		syncData(player)
		return { Success = true }
	else
		return { Success = false, Error = err }
	end
end

-- ──────────────────────────────────────────────────────────────
-- GET LEADERBOARD
-- ──────────────────────────────────────────────────────────────
GetLeaderboardFn.OnServerInvoke = function(player, boardType)
	local top    = DataManager.GetTopPlayers(boardType or "Value", 10)
	local result = {}
	for _, entry in ipairs(top) do
		local displayName = "Player_" .. tostring(entry.UserId)
		local p = Players:GetPlayerByUserId(tonumber(entry.UserId))
		if p then displayName = p.Name end
		table.insert(result, { Name = displayName, Score = entry.Score })
	end
	return result
end

-- ──────────────────────────────────────────────────────────────
-- INSPECT OTHER PLAYER (showcase only, not full inventory)
-- ──────────────────────────────────────────────────────────────
GetPlayerCardsFn.OnServerInvoke = function(requestingPlayer, targetPlayerName)
	if type(targetPlayerName) ~= "string" then return nil end
	local target = Players:FindFirstChild(targetPlayerName)
	if not target then return nil end
	local data = DataManager.GetData(target)
	if not data then return nil end

	local showcaseCards = {}
	for _, cardId in ipairs(data.ShowcaseCards or {}) do
		for _, card in ipairs(data.Inventory) do
			if card.CardId == cardId then
				table.insert(showcaseCards, card)
				break
			end
		end
	end

	return {
		Name             = target.Name,
		TotalPacksOpened = data.TotalPacksOpened or 0,
		InventoryValue   = data.InventoryValue   or 0,
		RarestCard       = data.RarestCardPulled or "Common",
		LoginStreak      = data.LoginStreak      or 0,
		PrestigeLevel    = data.PrestigeLevel    or 0,
		ShowcaseCards    = showcaseCards,
	}
end

-- ──────────────────────────────────────────────────────────────
-- DEVELOPER PRODUCT PURCHASE HANDLER
-- ──────────────────────────────────────────────────────────────
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	for _, prod in pairs(CardDatabase.DevProducts) do
		if prod.Id ~= 0 and prod.Id == receiptInfo.ProductId then
			EconomySystem.AddCurrency(player, prod.Pucks or 0, prod.Gems or 0)
			if prod.LuckBoost then
				LuckSystem.ActivateBoost(player, prod.LuckBoost.Duration, prod.LuckBoost.Multiplier)
			end
			syncData(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	warn("[MainServer] Unrecognized ProductId: " .. tostring(receiptInfo.ProductId))
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

print("[MainServer] NHL Pack Opening RNG — Server fully initialized.")