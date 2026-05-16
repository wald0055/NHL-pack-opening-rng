local Players     = game:GetService("Players")
local DataManager = require(script.Parent.DataManager)

local TradeSystem = {}

local pendingTrades = {}
local TRADE_TIMEOUT = 120
local CANCEL_WINDOW = 10

local function generateTradeId()
	return string.format("%d_%d", os.time(), math.random(100000, 999999))
end

local function findCards(inventory, cardIds)
	if #cardIds == 0 then return {}, nil end
	local found    = {}
	local foundSet = {}
	for _, card in ipairs(inventory) do
		if table.find(cardIds, card.CardId) then
			table.insert(found, card)
			foundSet[card.CardId] = true
		end
	end
	for _, id in ipairs(cardIds) do
		if not foundSet[id] then return nil, "CardNotFound:" .. id end
	end
	return found, nil
end

function TradeSystem.ProposeTrade(initiator, target, initiatorCardIds, targetCardIds)
	if initiator == target then return nil, "CannotTradeSelf" end
	if #initiatorCardIds == 0 and #targetCardIds == 0 then return nil, "EmptyTrade" end
	if #initiatorCardIds > 5 or #targetCardIds > 5 then return nil, "TooManyCards" end

	local initiatorData = DataManager.GetData(initiator)
	local targetData    = DataManager.GetData(target)
	if not initiatorData or not targetData then return nil, "PlayerDataNotLoaded" end

	-- Validate cards exist and are not locked
	if #initiatorCardIds > 0 then
		local cards, err = findCards(initiatorData.Inventory, initiatorCardIds)
		if err then return nil, "Initiator_" .. err end
		for _, card in ipairs(cards) do
			if card.Locked then return nil, "Initiator_CardLocked:" .. card.CardId end
		end
	end

	if #targetCardIds > 0 then
		local cards, err = findCards(targetData.Inventory, targetCardIds)
		if err then return nil, "Target_" .. err end
		for _, card in ipairs(cards) do
			if card.Locked then return nil, "Target_CardLocked:" .. card.CardId end
		end
	end

	local tradeId = generateTradeId()
	pendingTrades[tradeId] = {
		TradeId           = tradeId,
		InitiatorId       = initiator.UserId,
		TargetId          = target.UserId,
		InitiatorCardIds  = initiatorCardIds,
		TargetCardIds     = targetCardIds,
		InitiatorAccepted = false,
		TargetAccepted    = false,
		CreatedAt         = os.time(),
		ConfirmedAt       = nil,
		Completed         = false,
	}

	task.delay(TRADE_TIMEOUT, function()
		local liveTrade = pendingTrades[tradeId]
		if liveTrade and not liveTrade.Completed then
			pendingTrades[tradeId] = nil
		end
	end)

	return tradeId, nil
end

function TradeSystem.AcceptTrade(player, tradeId)
	local trade = pendingTrades[tradeId]
	if not trade       then return false, "TradeNotFound"    end
	if trade.Completed then return false, "TradeAlreadyDone" end

	if player.UserId == trade.InitiatorId then
		if trade.InitiatorAccepted then return false, "AlreadyAccepted" end
		trade.InitiatorAccepted = true
	elseif player.UserId == trade.TargetId then
		if trade.TargetAccepted then return false, "AlreadyAccepted" end
		trade.TargetAccepted = true
	else
		return false, "NotInTrade"
	end

	if trade.InitiatorAccepted and trade.TargetAccepted then
		trade.ConfirmedAt = os.time()
		task.delay(CANCEL_WINDOW, function()
			local liveTrade = pendingTrades[tradeId]
			if liveTrade and not liveTrade.Completed then
				TradeSystem.ExecuteTrade(tradeId)
			end
		end)
		return true, "BothConfirmed"
	end

	return true, "WaitingForOther"
end

function TradeSystem.CancelTrade(player, tradeId)
	local trade = pendingTrades[tradeId]
	if not trade       then return false, "TradeNotFound"    end
	if trade.Completed then return false, "TradeAlreadyDone" end
	if player.UserId ~= trade.InitiatorId and player.UserId ~= trade.TargetId then
		return false, "NotInTrade"
	end
	pendingTrades[tradeId] = nil
	return true
end

function TradeSystem.ExecuteTrade(tradeId)
	local trade = pendingTrades[tradeId]
	if not trade or trade.Completed then return false, "InvalidTrade" end

	-- Mark completed immediately to prevent double-execution
	trade.Completed = true

	local initiator = Players:GetPlayerByUserId(trade.InitiatorId)
	local target    = Players:GetPlayerByUserId(trade.TargetId)

	if not initiator or not target then
		pendingTrades[tradeId] = nil
		return false, "PlayerLeft"
	end

	local initiatorData = DataManager.GetData(initiator)
	local targetData    = DataManager.GetData(target)
	if not initiatorData or not targetData then
		pendingTrades[tradeId] = nil
		return false, "DataUnavailable"
	end

	-- Snapshot cards to move BEFORE modifying inventories
	local initiatorCards = {}
	local targetCards    = {}

	if #trade.InitiatorCardIds > 0 then
		local cards, err = findCards(initiatorData.Inventory, trade.InitiatorCardIds)
		if err then
			pendingTrades[tradeId] = nil
			return false, "InitiatorCardsMissing"
		end
		initiatorCards = cards
	end

	if #trade.TargetCardIds > 0 then
		local cards, err = findCards(targetData.Inventory, trade.TargetCardIds)
		if err then
			pendingTrades[tradeId] = nil
			return false, "TargetCardsMissing"
		end
		targetCards = cards
	end

	-- Build sets for fast lookup
	local initiatorCardSet = {}
	for _, card in ipairs(initiatorCards) do initiatorCardSet[card.CardId] = true end
	local targetCardSet = {}
	for _, card in ipairs(targetCards) do targetCardSet[card.CardId] = true end

	-- Remove initiator's cards from initiator inventory
	local newInitiatorInv = {}
	for _, card in ipairs(initiatorData.Inventory) do
		if not initiatorCardSet[card.CardId] then
			table.insert(newInitiatorInv, card)
		end
	end
	initiatorData.Inventory = newInitiatorInv

	-- Remove target's cards from target inventory
	local newTargetInv = {}
	for _, card in ipairs(targetData.Inventory) do
		if not targetCardSet[card.CardId] then
			table.insert(newTargetInv, card)
		end
	end
	targetData.Inventory = newTargetInv

	-- Give initiator's cards to target
	for _, card in ipairs(initiatorCards) do
		table.insert(targetData.Inventory, card)
	end

	-- Give target's cards to initiator
	for _, card in ipairs(targetCards) do
		table.insert(initiatorData.Inventory, card)
	end

	-- Update showcase: remove traded cards from showcase lists
	local function cleanShowcase(data, tradedSet)
		local newShowcase = {}
		for _, id in ipairs(data.ShowcaseCards or {}) do
			if not tradedSet[id] then
				table.insert(newShowcase, id)
			end
		end
		data.ShowcaseCards = newShowcase
	end
	cleanShowcase(initiatorData, initiatorCardSet)
	cleanShowcase(targetData, targetCardSet)

	-- Recalculate inventory values
	local function recalc(inv)
		local v = 0
		for _, c in ipairs(inv) do v = v + (c.Value or 0) end
		return v
	end
	initiatorData.InventoryValue = recalc(initiatorData.Inventory)
	targetData.InventoryValue    = recalc(targetData.Inventory)

	-- Update stats
	initiatorData.TotalTradesDone = (initiatorData.TotalTradesDone or 0) + 1
	targetData.TotalTradesDone    = (targetData.TotalTradesDone    or 0) + 1

	-- Log trade history
	local now = os.time()
	table.insert(initiatorData.TradeHistory, {
		TradeId         = tradeId,
		CompletedAt     = now,
		PartnerName     = target.Name,
		GaveCardIds     = trade.InitiatorCardIds,
		ReceivedCardIds = trade.TargetCardIds,
	})
	table.insert(targetData.TradeHistory, {
		TradeId         = tradeId,
		CompletedAt     = now,
		PartnerName     = initiator.Name,
		GaveCardIds     = trade.TargetCardIds,
		ReceivedCardIds = trade.InitiatorCardIds,
	})

	-- Trim trade history
	while #initiatorData.TradeHistory > 50 do table.remove(initiatorData.TradeHistory, 1) end
	while #targetData.TradeHistory    > 50 do table.remove(targetData.TradeHistory, 1)    end

	DataManager.MarkDirty(initiator)
	DataManager.MarkDirty(target)

	-- Remove from pending
	pendingTrades[tradeId] = nil

	-- Fire callback AFTER all data mutations are complete
	if TradeSystem.OnTradeCompleted then
		TradeSystem.OnTradeCompleted(initiator, target, initiatorCards, targetCards)
	end

	return true, initiatorCards, targetCards
end

function TradeSystem.GetTrade(tradeId)
	return pendingTrades[tradeId]
end

function TradeSystem.GetPendingTradesForPlayer(player)
	local result = {}
	for _, trade in pairs(pendingTrades) do
		if trade.InitiatorId == player.UserId or trade.TargetId == player.UserId then
			table.insert(result, trade)
		end
	end
	return result
end

return TradeSystem
