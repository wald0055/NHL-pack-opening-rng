-- EventSystem.lua
-- Location: ServerScriptService
-- Manages global announcements, server-wide luck events, community milestones,
-- and weekend double-luck scheduling.

local Players      = game:GetService("Players")
local CardDatabase = require(game.ReplicatedStorage.Modules.CardDatabase)

local EventSystem  = {}

-- ──────────────────────────────────────────────────────────────
-- REMOTE REFERENCE  (set by MainServer after remotes are created)
-- ──────────────────────────────────────────────────────────────
local GlobalAnnounceRemote = nil

function EventSystem.SetRemote(remote)
	GlobalAnnounceRemote = remote
end

-- ──────────────────────────────────────────────────────────────
-- GLOBAL CHAT ANNOUNCEMENT
-- ──────────────────────────────────────────────────────────────
function EventSystem.Announce(message)
	if GlobalAnnounceRemote then
		GlobalAnnounceRemote:FireAllClients(message)
	end
end

function EventSystem.AnnounceToPlayer(player, message)
	if GlobalAnnounceRemote and player and player.Parent then
		GlobalAnnounceRemote:FireClient(player, message)
	end
end

-- ──────────────────────────────────────────────────────────────
-- ACTIVE SERVER EVENT STATE
-- ──────────────────────────────────────────────────────────────
local activeEvent = nil  -- { Name, Multiplier, ExpiresAt } or nil

function EventSystem.GetActiveEvent()
	if activeEvent and activeEvent.ExpiresAt > os.time() then
		return activeEvent
	end
	activeEvent = nil
	return nil
end

-- ──────────────────────────────────────────────────────────────
-- ACTIVATE A SERVER-WIDE LUCK EVENT
-- ──────────────────────────────────────────────────────────────
function EventSystem.ActivateServerEvent(name, multiplier, durationSeconds)
	activeEvent = {
		Name       = name,
		Multiplier = multiplier,
		ExpiresAt  = os.time() + durationSeconds,
	}
	EventSystem.Announce(string.format(
		"⚡ Server event: %s (%.1fx luck) — %d minutes remaining!",
		name, multiplier, math.floor(durationSeconds / 60)
		))
	task.delay(durationSeconds, function()
		if activeEvent and activeEvent.Name == name then
			activeEvent = nil
			EventSystem.Announce("The " .. name .. " luck event has ended.")
		end
	end)
end

-- ──────────────────────────────────────────────────────────────
-- MYTHIC+ PULL GLOBAL BROADCAST
-- ──────────────────────────────────────────────────────────────
local BROADCAST_RARITIES = {
	Legendary      = true,
	Mythic         = true,
	Secret         = true,
	Limited        = true,
	EventExclusive = true,
}

function EventSystem.OnRarePull(player, card, rarityKey)
	if not BROADCAST_RARITIES[rarityKey] then return end
	local rarityDef = CardDatabase.Rarities[rarityKey]
	local prefix = rarityKey == "Legendary" and "🌟"
		or rarityKey == "Mythic" and "💎"
		or rarityKey == "Secret" and "🔥"
		or "⚡"
	local msg = string.format(
		"%s %s just pulled a %s %s %s!",
		prefix, player.Name, rarityDef.Name, card.PlayerName, prefix
	)
	EventSystem.Announce(msg)
end

-- ──────────────────────────────────────────────────────────────
-- COMMUNITY MILESTONE TRACKING  (total server packs)
-- ──────────────────────────────────────────────────────────────
local totalServerPacks    = 0
local announcedMilestones = {}

local MILESTONES = {
	[100000]  = { msg = "🎉 100k packs opened! Everyone gets +10% luck for 30 min!", mult = 1.10, dur = 1800 },
	[500000]  = { msg = "🎉 500k packs! +20% luck for 30 minutes!",                  mult = 1.20, dur = 1800 },
	[1000000] = { msg = "🏆 1 MILLION packs! MEGA +50% luck for 1 hour!",            mult = 1.50, dur = 3600 },
}

function EventSystem.OnPackOpened()
	totalServerPacks = totalServerPacks + 1
	for threshold, data in pairs(MILESTONES) do
		if totalServerPacks >= threshold and not announcedMilestones[threshold] then
			announcedMilestones[threshold] = true
			EventSystem.Announce(data.msg)
			EventSystem.ActivateServerEvent("Community Milestone", data.mult, data.dur)
		end
	end
end

-- ──────────────────────────────────────────────────────────────
-- PLAYER JOIN  (welcome back + active event notice)
-- ──────────────────────────────────────────────────────────────
function EventSystem.OnPlayerJoin(player)
	task.delay(3, function()
		if not (player and player.Parent) then return end
		local event = EventSystem.GetActiveEvent()
		if event then
			local remaining = math.max(0, event.ExpiresAt - os.time())
			EventSystem.AnnounceToPlayer(player, string.format(
				"⚡ Active event: %s (%.1fx luck) — %d min remaining!",
				event.Name, event.Multiplier, math.floor(remaining / 60)
				))
		end
	end)
end

-- ──────────────────────────────────────────────────────────────
-- WEEKEND DOUBLE LUCK  (auto-activates Fri–Sun UTC)
-- ──────────────────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(300)  -- check every 5 minutes
		local weekday  = tonumber(os.date("%w"))   -- 0=Sun, 5=Fri, 6=Sat
		local isWeekend = (weekday == 0 or weekday == 5 or weekday == 6)
		if isWeekend and not EventSystem.GetActiveEvent() then
			EventSystem.ActivateServerEvent("Weekend Double Luck", 2.0, 300)
		end
	end
end)

return EventSystem
