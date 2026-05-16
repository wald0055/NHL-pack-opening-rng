-- UISystem.lua  (LocalScript)
-- Location: StarterPlayerScripts
-- Complete client UI: Pack Shop, Pack Opening, Inventory, Leaderboard,
-- Quests, Profile, Puck-Index, Trade, Market, Login Calendar, Settings.
-- All scope issues fixed; functions declared before use.

print("[UISystem] Client loaded for:", game:GetService("Players").LocalPlayer.Name)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ──────────────────────────────────────────────────────────────
-- WAIT FOR REMOTES
-- ──────────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DataSync           = Remotes:WaitForChild("DataSync")
local QuestComplete      = Remotes:WaitForChild("QuestComplete")
local AchievementEarned  = Remotes:WaitForChild("AchievementEarned")
local TradeIncoming      = Remotes:WaitForChild("TradeIncoming")
local TradeBothConfirmed = Remotes:WaitForChild("TradeBothConfirmed")
local TradeCompleted     = Remotes:WaitForChild("TradeCompleted")
local TradeCancelled     = Remotes:WaitForChild("TradeCancelled")
local GlobalAnnounce     = Remotes:WaitForChild("GlobalAnnounce")
local LoginRewardReady   = Remotes:WaitForChild("LoginRewardReady")

local OpenPackFn      = Remotes:WaitForChild("OpenPack")
local SellCardFn      = Remotes:WaitForChild("SellCard")
local BulkSellFn      = Remotes:WaitForChild("BulkSell")
local LockCardFn      = Remotes:WaitForChild("LockCard")
local UpgradeLuckFn   = Remotes:WaitForChild("UpgradeLuck")
local PrestigeFn      = Remotes:WaitForChild("Prestige")
local CancelTradeEv   = Remotes:WaitForChild("CancelTrade")
local ClaimLoginFn    = Remotes:WaitForChild("ClaimLogin")
local SetShowcaseFn   = Remotes:WaitForChild("SetShowcase")
local GetLeaderboardFn= Remotes:WaitForChild("GetLeaderboard")
local GetOnlinePlayersFn = Remotes:WaitForChild("GetOnlinePlayers")

-- Phase-based trade remotes
local function safeWait(name)
	local r = Remotes:WaitForChild(name, 30)
	if not r then
		warn("[UISystem] Remote missing after 30s: " .. name .. " — is MainServer up to date?")
	end
	return r
end

local TradeRequest       = safeWait("TradeRequest")
local TradeRequestRecv   = safeWait("TradeRequestRecv")
local TradeRequestResp   = safeWait("TradeRequestResp")
local TradeSessionOpen   = safeWait("TradeSessionOpen")
local TradeOfferUpdate   = safeWait("TradeOfferUpdate")
local TradeOfferRecv     = safeWait("TradeOfferRecv")
local TradeConfirm       = safeWait("TradeConfirm")
local TradeUnconfirm     = safeWait("TradeUnconfirm")
local TradeConfirmStatus = safeWait("TradeConfirmStatus")

local CardDatabase = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CardDatabase"))

-- ──────────────────────────────────────────────────────────────
-- SHARED STATE
-- ──────────────────────────────────────────────────────────────
local LocalData    = {}
local SelectedPack = "RookiePack"
local isOpening    = false
local screens      = {}
local navButtons   = {}
local activeScreen = "Shop"

-- ──────────────────────────────────────────────────────────────
-- CARD STYLE CONFIG
-- ──────────────────────────────────────────────────────────────
local CARD_STYLES = {
	Rarity = {
		Common        = { tint=0.08, borderThick=1,   badge="⬜",  ovrSize=26, glowColor=nil },
		Rare          = { tint=0.10, borderThick=1.5, badge="🔵",  ovrSize=28, glowColor=nil },
		Epic          = { tint=0.12, borderThick=2,   badge="🟣",  ovrSize=30, glowColor=nil },
		Legendary     = { tint=0.14, borderThick=2.5, badge="🌟",  ovrSize=32, glowColor=nil },
		Mythic        = { tint=0.16, borderThick=3,   badge="💎",  ovrSize=34, glowColor=Color3.fromRGB(212,83,180) },
		Secret        = { tint=0.18, borderThick=3.5, badge="🔥",  ovrSize=36, glowColor=Color3.fromRGB(230,120,30) },
		Limited       = { tint=0.15, borderThick=3,   badge="💚",  ovrSize=33, glowColor=Color3.fromRGB(30,200,120) },
		EventExclusive= { tint=0.17, borderThick=3.5, badge="⚡",  ovrSize=35, glowColor=Color3.fromRGB(29,210,210) },
	},
	Variant = {
		Base          = Color3.fromRGB(255, 200,  50),
		Rookie        = Color3.fromRGB(100, 220, 255),
		Legend        = Color3.fromRGB(230, 120,  30),
		["All-Star"]  = Color3.fromRGB(212,  83, 180),
		Playoffs      = Color3.fromRGB(255,  80,  80),
		Default       = Color3.fromRGB(200, 200, 200),
	},
}
local function cardStyle(rarity)
	return CARD_STYLES.Rarity[rarity] or CARD_STYLES.Rarity.Common
end
local function variantColor(variant)
	return CARD_STYLES.Variant[variant] or CARD_STYLES.Variant.Default
end

-- ──────────────────────────────────────────────────────────────
-- COLOR SCHEME
-- ──────────────────────────────────────────────────────────────
local DARK_BG    = Color3.fromRGB(10,  12,  20)
local PANEL_BG   = Color3.fromRGB(18,  22,  35)
local PANEL_BG2  = Color3.fromRGB(25,  30,  48)
local ACCENT     = Color3.fromRGB(0,   153, 220)
local ACCENT2    = Color3.fromRGB(200, 16,  46)
local TEXT_WHITE = Color3.fromRGB(240, 245, 255)
local TEXT_MUTED = Color3.fromRGB(140, 150, 175)
local TEXT_DIM   = Color3.fromRGB(80,  90,  115)
local GOLD       = Color3.fromRGB(255, 200, 50)
local GREEN      = Color3.fromRGB(30,  200, 100)
local NAV_HEIGHT = 52
local TOP_HEIGHT = 46

-- ──────────────────────────────────────────────────────────────
-- UI FACTORY HELPERS
-- ──────────────────────────────────────────────────────────────
local function create(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function makeFrame(props, parent)
	props.BackgroundTransparency = props.BackgroundTransparency or 0
	props.BorderSizePixel        = props.BorderSizePixel        or 0
	return create("Frame", props, parent)
end

local function makeLabel(props, parent)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel        = props.BorderSizePixel        or 0
	props.TextWrapped            = props.TextWrapped            or false
	return create("TextLabel", props, parent)
end

local function makeButton(props, parent)
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	props.Text = props.Text or ""
	return create("TextButton", props, parent)
end

local function corner(r, parent)
	return create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(color, thickness, parent)
	return create("UIStroke", { Color = color, Thickness = thickness or 1 }, parent)
end

-- ──────────────────────────────────────────────────────────────
-- RARITY HELPER
-- ──────────────────────────────────────────────────────────────
local function rarityColor(key)
	local def = CardDatabase.Rarities[key]
	return def and def.Color or Color3.fromRGB(180,180,180)
end

local function darkTint(color, factor)
	factor = factor or 0.12
	return Color3.fromRGB(
		math.floor(color.R * factor * 255),
		math.floor(color.G * factor * 255),
		math.floor(color.B * factor * 255)
	)
end

-- ──────────────────────────────────────────────────────────────
-- SHARED CARD WIDGET
-- ──────────────────────────────────────────────────────────────
local RARITY_RANK_MAP = {
	Common=1, Rare=2, Epic=3, Legendary=4, Mythic=5,
	Secret=6, Limited=5, EventExclusive=6,
}

local function makeCardWidget(parent, card, opts)
	opts = opts or {}
	local rc       = rarityColor(card.Rarity)
	local cs       = cardStyle(card.Rarity)
	local rank     = RARITY_RANK_MAP[card.Rarity] or 1
	local isLocked = opts.isLocked or false
	local zBase    = opts.zBase or 2

	local w = makeButton({
		Size             = opts.size or UDim2.new(1,0,1,0),
		BackgroundColor3 = Color3.fromRGB(
			math.clamp(math.floor(rc.R*255*0.08 + 10), 0, 255),
			math.clamp(math.floor(rc.G*255*0.08 + 10), 0, 255),
			math.clamp(math.floor(rc.B*255*0.08 + 12), 0, 255)
		),
		ZIndex = zBase,
	}, parent)
	corner(10, w)

	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(
				math.clamp(math.floor(rc.R*255*0.18 + 8),0,255),
				math.clamp(math.floor(rc.G*255*0.14 + 8),0,255),
				math.clamp(math.floor(rc.B*255*0.14 + 10),0,255)
				)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 10, 18)),
		}),
		Rotation = 130,
	}, w)

	local borderColor = isLocked and Color3.fromRGB(255,210,50) or rc
	local borderThick = isLocked and 2.5 or (1 + rank * 0.3)
	stroke(borderColor, borderThick, w)

	local topBar = makeFrame({
		Size             = UDim2.new(1,0,0,5),
		BackgroundColor3 = rc,
		ZIndex           = zBase + 1,
	}, w)
	create("UICorner", { CornerRadius = UDim.new(0,10) }, topBar)

	local ovrSize = math.max(22, math.min(34, 18 + rank * 2))
	makeLabel({
		Size       = UDim2.new(1,0,0,ovrSize+4),
		Position   = UDim2.new(0,0,0,7),
		Text       = tostring(card.OVR),
		TextColor3 = rc,
		Font       = Enum.Font.GothamBold,
		TextSize   = ovrSize,
		ZIndex     = zBase + 1,
	}, w)

	makeLabel({
		Size       = UDim2.new(1,0,0,12),
		Position   = UDim2.new(0,0,0,ovrSize+9),
		Text       = cs.badge .. " " .. card.Rarity:sub(1,3):upper(),
		TextColor3 = rc,
		Font       = Enum.Font.GothamBold,
		TextSize   = 8,
		ZIndex     = zBase + 1,
	}, w)

	makeLabel({
		Size        = UDim2.new(1,-6,0,26),
		Position    = UDim2.new(0,3,0,ovrSize+23),
		Text        = card.PlayerName:match("(%S+)$") or card.PlayerName,
		TextColor3  = Color3.fromRGB(240,245,255),
		Font        = Enum.Font.GothamBold,
		TextSize    = 11,
		TextWrapped = true,
		ZIndex      = zBase + 1,
	}, w)

	makeLabel({
		Size       = UDim2.new(1,0,0,12),
		Position   = UDim2.new(0,0,0,ovrSize+50),
		Text       = card.Team,
		TextColor3 = Color3.fromRGB(130,145,170),
		Font       = Enum.Font.Gotham,
		TextSize   = 9,
		ZIndex     = zBase + 1,
	}, w)

	local variantStrip = makeFrame({
		Size             = UDim2.new(1,0,0,16),
		Position         = UDim2.new(0,0,1,-16),
		BackgroundColor3 = Color3.fromRGB(
			math.clamp(math.floor(rc.R*255*0.22),0,255),
			math.clamp(math.floor(rc.G*255*0.22),0,255),
			math.clamp(math.floor(rc.B*255*0.22),0,255)
		),
		ZIndex = zBase + 1,
	}, w)
	create("UICorner", { CornerRadius = UDim.new(0,10) }, variantStrip)
	makeLabel({
		Size       = UDim2.new(1,0,1,0),
		Text       = card.Variant:upper(),
		TextColor3 = variantColor(card.Variant),
		Font       = Enum.Font.GothamBold,
		TextSize   = 8,
		ZIndex     = zBase + 2,
	}, variantStrip)

	if isLocked then
		local lockBg = makeFrame({
			Size             = UDim2.new(0,18,0,18),
			Position         = UDim2.new(1,-20,0,7),
			BackgroundColor3 = Color3.fromRGB(40,32,5),
			ZIndex           = zBase + 3,
		}, w)
		corner(5, lockBg)
		stroke(Color3.fromRGB(255,210,50), 1, lockBg)
		makeLabel({
			Size       = UDim2.new(1,0,1,0),
			Text       = "🔒",
			TextColor3 = Color3.fromRGB(255,210,50),
			Font       = Enum.Font.GothamBold,
			TextSize   = 10,
			ZIndex     = zBase + 4,
		}, lockBg)
	end

	if rank >= 5 then
		local dot = makeFrame({
			Size             = UDim2.new(0,7,0,7),
			Position         = UDim2.new(0,5,0,8),
			BackgroundColor3 = rc,
			ZIndex           = zBase + 3,
		}, w)
		corner(4, dot)
	end

	return w
end

-- ──────────────────────────────────────────────────────────────
-- SOUND HELPER
-- ──────────────────────────────────────────────────────────────
local function playSound(soundId, volume, pitch)
	local s = Instance.new("Sound")
	s.SoundId       = soundId or "rbxassetid://6042053626"
	s.Volume        = volume  or 0.5
	s.PlaybackSpeed = pitch   or 1.0
	s.Parent        = SoundService
	s:Play()
	game:GetService("Debris"):AddItem(s, 5)
end

-- ──────────────────────────────────────────────────────────────
-- MAIN SCREENGUI
-- ──────────────────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "NHLPackRNG"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = PlayerGui

-- ──────────────────────────────────────────────────────────────
-- TOAST NOTIFICATION
-- ──────────────────────────────────────────────────────────────
local ToastFrame = makeFrame({
	Size             = UDim2.new(0.7, 0, 0, 48),
	Position         = UDim2.new(0.15, 0, -0.12, 0),
	BackgroundColor3 = PANEL_BG2,
	ZIndex           = 100,
}, ScreenGui)
corner(10, ToastFrame)

local ToastLabel = makeLabel({
	Size            = UDim2.new(1, -16, 1, 0),
	Position        = UDim2.new(0, 8, 0, 0),
	Text            = "",
	TextColor3      = TEXT_WHITE,
	Font            = Enum.Font.GothamBold,
	TextSize        = 13,
	TextWrapped     = true,
	ZIndex          = 101,
}, ToastFrame)

local toastActive = false
local function showToast(msg, color)
	ToastFrame.BackgroundColor3 = color or PANEL_BG2
	ToastLabel.Text = msg
	if toastActive then return end
	toastActive = true
	local inT = TweenService:Create(ToastFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back),
		{ Position = UDim2.new(0.15, 0, 0.015, 0) })
	inT:Play()
	inT.Completed:Connect(function()
		task.wait(2.5)
		TweenService:Create(ToastFrame, TweenInfo.new(0.3),
			{ Position = UDim2.new(0.15, 0, -0.12, 0) }):Play()
		toastActive = false
	end)
end

-- ──────────────────────────────────────────────────────────────
-- GLOBAL ANNOUNCE BANNER
-- ──────────────────────────────────────────────────────────────
local MainBG = makeFrame({
	Size             = UDim2.new(1,0,1,0),
	BackgroundColor3 = DARK_BG,
}, ScreenGui)

local AnnounceBanner = makeFrame({
	Size             = UDim2.new(1,0,0,34),
	Position         = UDim2.new(0,0,1,0),
	BackgroundColor3 = Color3.fromRGB(0,100,160),
	ZIndex           = 90,
}, ScreenGui)
makeLabel({
	Name       = "Lbl",
	Size       = UDim2.new(1,-16,1,0),
	Position   = UDim2.new(0,8,0,0),
	Text       = "",
	TextColor3 = TEXT_WHITE,
	Font       = Enum.Font.GothamBold,
	TextSize   = 12,
	ZIndex     = 91,
}, AnnounceBanner)

GlobalAnnounce.OnClientEvent:Connect(function(msg)
	AnnounceBanner:FindFirstChildOfClass("TextLabel").Text = msg
	local dest = UDim2.new(0,0,1,-(34 + NAV_HEIGHT))
	TweenService:Create(AnnounceBanner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = dest }):Play()
	task.wait(6)
	TweenService:Create(AnnounceBanner, TweenInfo.new(0.3), { Position = UDim2.new(0,0,1,0) }):Play()
end)

-- ──────────────────────────────────────────────────────────────
-- TOP BAR
-- ──────────────────────────────────────────────────────────────
local TopBar = makeFrame({
	Size             = UDim2.new(1,0,0,TOP_HEIGHT),
	BackgroundColor3 = PANEL_BG,
}, MainBG)
create("UIGradient", {
	Color    = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0,80,140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15,20,38)),
	}),
	Rotation = 90,
}, TopBar)

makeLabel({ Size=UDim2.new(0.45,0,1,0), Position=UDim2.new(0,10,0,0),
	Text="NHL Pack Opening RNG", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold,
	TextSize=16, TextXAlignment=Enum.TextXAlignment.Left }, TopBar)

local puckIcon = create("ImageLabel", {
	Size=UDim2.new(0,16,0,16), Position=UDim2.new(0.53,0,0.34,0),
	Image="rbxassetid://93182136116709",
	BackgroundTransparency=1,
}, TopBar)
local PucksLabel = makeLabel({ Size=UDim2.new(0.25,0,0.8,0), Position=UDim2.new(0.435,0,0.1,0),
	Text="0", TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=13 }, TopBar)

local GemsLabel  = makeLabel({ Size=UDim2.new(0.25,0,0.8,0), Position=UDim2.new(0.73,0,0.1,0),
	Text="💎 0", TextColor3=Color3.fromRGB(160,220,255), Font=Enum.Font.GothamBold, TextSize=13 }, TopBar)

-- ──────────────────────────────────────────────────────────────
-- CONTENT AREA
-- ──────────────────────────────────────────────────────────────
local ContentArea = makeFrame({
	Size             = UDim2.new(1,0,1,-(TOP_HEIGHT + NAV_HEIGHT)),
	Position         = UDim2.new(0,0,0,TOP_HEIGHT),
	BackgroundTransparency = 1,
}, MainBG)

-- ──────────────────────────────────────────────────────────────
-- NAV BAR
-- ──────────────────────────────────────────────────────────────
local NavBar = makeFrame({
	Size             = UDim2.new(1,0,0,NAV_HEIGHT),
	Position         = UDim2.new(0,0,1,-NAV_HEIGHT),
	BackgroundColor3 = PANEL_BG,
}, MainBG)
stroke(ACCENT, 1, NavBar).Transparency = 0.7

local NAV_TABS = {
	{ Name="Shop",      Icon="🏬", Screen="Shop"      },
	{ Name="Open",      Icon="📦", Screen="Open"      },
	{ Name="Inventory", Icon="🃏", Screen="Inventory" },
	{ Name="Index",     Icon="📖", Screen="Index"     },
	{ Name="Trade",     Icon="🔄", Screen="Trade"     },
	{ Name="Quests",    Icon="📋", Screen="Quests"    },
	{ Name="Rankings",  Icon="🏆", Screen="Leaderboard"},
	{ Name="Profile",   Icon="👤", Screen="Profile"   },
}

create("UIListLayout", {
	FillDirection      = Enum.FillDirection.Horizontal,
	HorizontalAlignment= Enum.HorizontalAlignment.Center,
	VerticalAlignment  = Enum.VerticalAlignment.Center,
	SortOrder          = Enum.SortOrder.LayoutOrder,
	Padding            = UDim.new(0,0),
}, NavBar)

-- ──────────────────────────────────────────────────────────────
-- SCREEN FACTORY
-- ──────────────────────────────────────────────────────────────
local function newScreen(name, useScroll)
	local f
	if useScroll ~= false then
		f = create("ScrollingFrame", {
			Name                  = name,
			Size                  = UDim2.new(1,0,1,0),
			BackgroundTransparency= 1,
			BorderSizePixel       = 0,
			Visible               = false,
			ScrollBarThickness    = 4,
			ScrollBarImageColor3  = ACCENT,
			CanvasSize            = UDim2.new(0,0,0,0),
			AutomaticCanvasSize   = Enum.AutomaticSize.Y,
		}, ContentArea)
	else
		f = makeFrame({
			Name    = name,
			Size    = UDim2.new(1,0,1,0),
			Visible = false,
			BackgroundTransparency = 1,
		}, ContentArea)
	end
	create("UIPadding", {
		PaddingLeft   = UDim.new(0,12),
		PaddingRight  = UDim.new(0,12),
		PaddingTop    = UDim.new(0,10),
		PaddingBottom = UDim.new(0,10),
	}, f)
	screens[name] = f
	return f
end

local function sectionHeader(text, parent, lo)
	local lbl = makeLabel({
		Size           = UDim2.new(1,0,0,22),
		Text           = text,
		TextColor3     = TEXT_MUTED,
		Font           = Enum.Font.GothamBold,
		TextSize       = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder    = lo or 0,
	}, parent)
	return lbl
end

-- ──────────────────────────────────────────────────────────────
-- SCREEN SWITCHER
-- ──────────────────────────────────────────────────────────────
local function switchScreen(name)
	activeScreen = name
	for n, f in pairs(screens) do f.Visible = (n == name) end
	for _, info in pairs(navButtons) do
		if info.ScreenName == name then
			info.Btn.BackgroundColor3       = Color3.fromRGB(0,80,130)
			info.Btn.BackgroundTransparency = 0
			info.Lbl.TextColor3             = TEXT_WHITE
		else
			info.Btn.BackgroundTransparency = 1
			info.Lbl.TextColor3             = TEXT_MUTED
		end
	end
	if name == "Leaderboard" then
		task.spawn(function()
			local valueData = GetLeaderboardFn:InvokeServer("Value")
			local packsData = GetLeaderboardFn:InvokeServer("Pucks")
			if refreshLeaderboard then refreshLeaderboard(valueData, packsData) end
		end)
	end
end

-- Build nav buttons
for i, tab in ipairs(NAV_TABS) do
	local btn = makeButton({
		Name                 = tab.Name,
		Size                 = UDim2.new(1/#NAV_TABS,0,1,0),
		BackgroundTransparency = 1,
		LayoutOrder          = i,
	}, NavBar)
	makeLabel({ Size=UDim2.new(1,0,0.5,0), Position=UDim2.new(0,0,0,4),
		Text=tab.Icon, TextColor3=TEXT_MUTED, Font=Enum.Font.GothamBold, TextSize=16 }, btn)
	local lbl = makeLabel({ Size=UDim2.new(1,0,0.4,0), Position=UDim2.new(0,0,0.56,0),
		Text=tab.Name, TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=9 }, btn)
	btn.MouseButton1Click:Connect(function() switchScreen(tab.Screen) end)
	navButtons[tab.Name] = { Btn=btn, Lbl=lbl, ScreenName=tab.Screen }
end

-- ══════════════════════════════════════════════════════════════
-- CARD DETAIL DIALOG
-- ══════════════════════════════════════════════════════════════
local CardDialog = makeFrame({
	Size             = UDim2.new(0.85,0,0,350),
	Position         = UDim2.new(0.075,0,0.5,-175),
	BackgroundColor3 = PANEL_BG2,
	Visible          = false,
	ZIndex           = 70,
}, ScreenGui)
corner(14, CardDialog)
stroke(ACCENT, 1.5, CardDialog)

local dialogTitle = makeLabel({ Size=UDim2.new(1,-16,0,34), Position=UDim2.new(0,8,0,8),
	Text="", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=17, ZIndex=71,
	TextXAlignment=Enum.TextXAlignment.Left }, CardDialog)

local dialogSub = makeLabel({ Size=UDim2.new(1,-16,0,22), Position=UDim2.new(0,8,0,44),
	Text="", TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=12, ZIndex=71,
	TextXAlignment=Enum.TextXAlignment.Left }, CardDialog)

local dialogRarity = makeLabel({ Size=UDim2.new(0.45,0,0,22), Position=UDim2.new(0,8,0,74),
	Text="", TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=13, ZIndex=71,
	TextXAlignment=Enum.TextXAlignment.Left }, CardDialog)

local dialogOVR = makeLabel({ Size=UDim2.new(0.45,0,0,22), Position=UDim2.new(0.52,0,0,74),
	Text="", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=13, ZIndex=71 }, CardDialog)

local dialogVariant = makeLabel({ Size=UDim2.new(1,-16,0,20), Position=UDim2.new(0,8,0,102),
	Text="", TextColor3=GOLD, Font=Enum.Font.Gotham, TextSize=12, ZIndex=71,
	TextXAlignment=Enum.TextXAlignment.Left }, CardDialog)

local dialogValue = makeLabel({ Size=UDim2.new(1,-16,0,22), Position=UDim2.new(0,8,0,128),
	Text="", TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=14, ZIndex=71,
	TextXAlignment=Enum.TextXAlignment.Left }, CardDialog)

local dialogSellBtn = makeButton({
	Size=UDim2.new(0.44,0,0,38), Position=UDim2.new(0.04,0,0,162),
	BackgroundColor3=Color3.fromRGB(180,35,35), Text="Sell",
	TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=13, ZIndex=72,
}, CardDialog)
corner(8, dialogSellBtn)

local dialogShowcaseBtn = makeButton({
	Size=UDim2.new(0.44,0,0,38), Position=UDim2.new(0.52,0,0,162),
	BackgroundColor3=Color3.fromRGB(30,80,140), Text="📌 Showcase",
	TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=12, ZIndex=72,
}, CardDialog)
corner(8, dialogShowcaseBtn)

local dialogLockBtn = makeButton({
	Size=UDim2.new(0.9,0,0,38), Position=UDim2.new(0.05,0,0,210),
	BackgroundColor3=Color3.fromRGB(40,35,10), Text="🔒 Lock Card",
	TextColor3=Color3.fromRGB(255,210,50), Font=Enum.Font.GothamBold, TextSize=13, ZIndex=72,
}, CardDialog)
corner(8, dialogLockBtn)
stroke(Color3.fromRGB(255,210,50), 1, dialogLockBtn)

local dialogCloseBtn = makeButton({
	Size=UDim2.new(0.9,0,0,36), Position=UDim2.new(0.05,0,0,258),
	BackgroundColor3=PANEL_BG, Text="Close",
	TextColor3=TEXT_MUTED, Font=Enum.Font.GothamBold, TextSize=13, ZIndex=72,
}, CardDialog)
corner(8, dialogCloseBtn)

local lockedCards = {}
local currentCard = nil

local function updateLockBtn()
	if not currentCard then return end
	local isLocked = (lockedCards and lockedCards[currentCard.CardId]) or false
	if isLocked then
		dialogLockBtn.Text             = "🔓 Unlock Card"
		dialogLockBtn.BackgroundColor3 = Color3.fromRGB(10,35,10)
		dialogLockBtn.TextColor3       = Color3.fromRGB(100,255,120)
		local s = dialogLockBtn:FindFirstChildOfClass("UIStroke")
		if s then s.Color = Color3.fromRGB(100,255,120) end
		dialogSellBtn.BackgroundColor3 = Color3.fromRGB(60,40,40)
		dialogSellBtn.AutoButtonColor  = false
	else
		dialogLockBtn.Text             = "🔒 Lock Card"
		dialogLockBtn.BackgroundColor3 = Color3.fromRGB(40,35,10)
		dialogLockBtn.TextColor3       = Color3.fromRGB(255,210,50)
		local s = dialogLockBtn:FindFirstChildOfClass("UIStroke")
		if s then s.Color = Color3.fromRGB(255,210,50) end
		dialogSellBtn.BackgroundColor3 = Color3.fromRGB(180,35,35)
		dialogSellBtn.AutoButtonColor  = true
	end
end

local function showCardDialog(card)
	currentCard            = card
	local rc               = rarityColor(card.Rarity)
	dialogTitle.Text       = card.PlayerName
	dialogTitle.TextColor3 = rc
	dialogSub.Text         = card.Team .. "  ·  " .. card.Position .. "  ·  " .. card.Era
	dialogRarity.Text      = card.Rarity
	dialogRarity.TextColor3= rc
	dialogOVR.Text         = "OVR " .. tostring(card.OVR)
	dialogVariant.Text     = "Variant: " .. card.Variant
	dialogValue.Text       = "Sell value: " .. tostring(math.floor((card.Value or 0))) .. " Pucks"
	currentCard.Locked = (lockedCards and lockedCards[currentCard.CardId]) or false
	CardDialog.Visible = true
	updateLockBtn()
end

dialogSellBtn.MouseButton1Click:Connect(function()
	if not currentCard then return end
	if currentCard.Locked or lockedCards[currentCard.CardId] then
		showToast("Unlock this card before selling.", Color3.fromRGB(255,210,50))
		return
	end
	local res = SellCardFn:InvokeServer(currentCard.CardId)
	if res and res.Success then
		showToast("Sold for " .. tostring(res.SellValue) .. " Pucks!", GOLD)
		CardDialog.Visible = false
		currentCard = nil
	else
		showToast("Could not sell: " .. tostring(res and res.Error), ACCENT2)
	end
end)

dialogLockBtn.MouseButton1Click:Connect(function()
	if not currentCard then return end
	local res = LockCardFn:InvokeServer(currentCard.CardId)
	if res and res.Success then
		lockedCards[currentCard.CardId] = res.Locked
		currentCard.Locked              = res.Locked
		updateLockBtn()
		showToast(
			res.Locked and "🔒 Card locked — safe from all selling." or "🔓 Card unlocked.",
			Color3.fromRGB(255,210,50)
		)
		refreshInventory()
	else
		showToast("Lock failed: " .. tostring(res and res.Error), ACCENT)
	end
end)

dialogShowcaseBtn.MouseButton1Click:Connect(function()
	if not currentCard then return end
	local showcase = LocalData.ShowcaseCards or {}
	local found    = false
	local newList  = {}
	for _, id in ipairs(showcase) do
		if id == currentCard.CardId then found = true
		else table.insert(newList, id) end
	end
	if not found then
		if #newList >= 5 then
			showToast("Showcase full! Remove a card first.", ACCENT2)
			return
		end
		table.insert(newList, currentCard.CardId)
	end
	local res = SetShowcaseFn:InvokeServer(newList)
	if res and res.Success then
		showToast(found and "Removed from showcase." or "Added to showcase!", GREEN)
	end
	CardDialog.Visible = false
end)

dialogCloseBtn.MouseButton1Click:Connect(function()
	CardDialog.Visible = false
end)

-- ══════════════════════════════════════════════════════════════
-- PACK ODDS POPUP
-- ══════════════════════════════════════════════════════════════
local OddsPopup = makeFrame({
	Size             = UDim2.new(0.88,0,0,380),
	Position         = UDim2.new(0.06,0,0.08,0),
	BackgroundColor3 = PANEL_BG2,
	Visible          = false,
	ZIndex           = 80,
}, ScreenGui)
corner(14, OddsPopup)
stroke(ACCENT, 1.5, OddsPopup)

local oddsTitleBar = makeFrame({
	Size             = UDim2.new(1,0,0,44),
	BackgroundColor3 = Color3.fromRGB(0,60,110),
	ZIndex           = 81,
}, OddsPopup)
corner(14, oddsTitleBar)

local oddsTitleLbl = makeLabel({
	Size       = UDim2.new(0.8,0,1,0),
	Position   = UDim2.new(0,14,0,0),
	Text       = "Pack Odds",
	TextColor3 = TEXT_WHITE,
	Font       = Enum.Font.GothamBold,
	TextSize   = 16,
	ZIndex     = 82,
	TextXAlignment = Enum.TextXAlignment.Left,
}, oddsTitleBar)

local oddsCloseBtn = makeButton({
	Size             = UDim2.new(0,36,0,36),
	Position         = UDim2.new(1,-40,0,4),
	BackgroundColor3 = Color3.fromRGB(180,35,35),
	Text             = "✕",
	TextColor3       = TEXT_WHITE,
	Font             = Enum.Font.GothamBold,
	TextSize         = 14,
	ZIndex           = 82,
}, OddsPopup)
corner(8, oddsCloseBtn)
oddsCloseBtn.MouseButton1Click:Connect(function() OddsPopup.Visible = false end)

local oddsScroll = create("ScrollingFrame", {
	Size                 = UDim2.new(1,-16,1,-60),
	Position             = UDim2.new(0,8,0,52),
	BackgroundTransparency = 1,
	BorderSizePixel      = 0,
	ScrollBarThickness   = 4,
	ScrollBarImageColor3 = ACCENT,
	CanvasSize           = UDim2.new(0,0,0,0),
	AutomaticCanvasSize  = Enum.AutomaticSize.Y,
	ZIndex               = 81,
}, OddsPopup)
create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6) }, oddsScroll)
create("UIPadding", { PaddingTop=UDim.new(0,6), PaddingBottom=UDim.new(0,6) }, oddsScroll)

local RARITY_ORDER_DISPLAY = {
	"EventExclusive", "Secret", "Limited", "Mythic", "Legendary", "Epic", "Rare", "Common"
}

local function showPackOdds(packKey)
	local pd = CardDatabase.Packs[packKey]
	if not pd then return end
	for _, c in ipairs(oddsScroll:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
	end
	oddsTitleLbl.Text = pd.DisplayName .. " — Odds"
	local total = 0
	for _, w in pairs(pd.Weights) do total = total + w end
	if total == 0 then return end
	for _, rarKey in ipairs(RARITY_ORDER_DISPLAY) do
		local weight = pd.Weights[rarKey] or 0
		if weight > 0 then
			local pct = (weight / total) * 100
			local rc  = rarityColor(rarKey)
			local cs  = cardStyle(rarKey)
			local row = makeFrame({
				Size             = UDim2.new(1,0,0,52),
				BackgroundColor3 = Color3.fromRGB(
					math.clamp(math.floor(rc.R*255*0.06+12),0,255),
					math.clamp(math.floor(rc.G*255*0.06+12),0,255),
					math.clamp(math.floor(rc.B*255*0.06+14),0,255)
				),
				ZIndex = 82,
			}, oddsScroll)
			corner(10, row)
			stroke(rc, 1, row).Transparency = 0.5
			makeFrame({ Size=UDim2.new(0,4,1,0), BackgroundColor3=rc, ZIndex=83 }, row)
			makeLabel({
				Size=UDim2.new(0.5,0,0,22), Position=UDim2.new(0,14,0,6),
				Text=cs.badge.."  "..rarKey, TextColor3=rc,
				Font=Enum.Font.GothamBold, TextSize=13, ZIndex=83,
				TextXAlignment=Enum.TextXAlignment.Left,
			}, row)
			local rarDef = CardDatabase.Rarities[rarKey]
			if rarDef then
				makeLabel({
					Size=UDim2.new(0.5,0,0,16), Position=UDim2.new(0,14,0,28),
					Text="OVR "..rarDef.OVRMin.." – "..rarDef.OVRMax,
					TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11, ZIndex=83,
					TextXAlignment=Enum.TextXAlignment.Left,
				}, row)
			end
			local pctText = pct >= 0.01 and string.format("%.2f%%", pct) or string.format("%.4f%%", pct)
			makeLabel({
				Size=UDim2.new(0.38,0,0,22), Position=UDim2.new(0.6,0,0,6),
				Text=pctText, TextColor3=TEXT_WHITE,
				Font=Enum.Font.GothamBold, TextSize=15, ZIndex=83,
				TextXAlignment=Enum.TextXAlignment.Right,
			}, row)
			local barBg = makeFrame({
				Size=UDim2.new(0.38,-4,0,6), Position=UDim2.new(0.6,0,0,32),
				BackgroundColor3=PANEL_BG, ZIndex=83,
			}, row)
			corner(3, barBg)
			corner(3, makeFrame({
				Size=UDim2.new(math.min(pct/100,1),0,1,0),
				BackgroundColor3=rc, ZIndex=84,
			}, barBg))
		end
	end
	OddsPopup.Visible = true
end

-- ══════════════════════════════════════════════════════════════
-- SCREEN: PACK SHOP
-- ══════════════════════════════════════════════════════════════
local ShopScreen = newScreen("Shop")
local function buildShopScreen()
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,12) }, ShopScreen)

	local PACK_STYLE = {
		FreePack         = { accent=Color3.fromRGB(80,200,120),  tint=Color3.fromRGB(10,40,20),   pills={"Common","Rare"},               icon="🎁" },
		RookiePack       = { accent=Color3.fromRGB(100,160,230), tint=Color3.fromRGB(12,20,45),   pills={"Common","Rare","Epic"},         icon="🏒" },
		ProPack          = { accent=Color3.fromRGB(80,140,255),  tint=Color3.fromRGB(10,18,55),   pills={"Rare","Epic","Legendary"},      icon="⭐" },
		AllStarPack      = { accent=Color3.fromRGB(160,100,255), tint=Color3.fromRGB(28,12,55),   pills={"Epic","Legendary","Mythic"},    icon="🌟" },
		StanleyCupPack   = { accent=Color3.fromRGB(255,190,30),  tint=Color3.fromRGB(45,28,5),    pills={"Legendary","Mythic","Secret"}, icon="🏆" },
		WinterClassicPack= { accent=Color3.fromRGB(80,220,220),  tint=Color3.fromRGB(5,38,45),    pills={"Epic","Legendary","Event Excl."}, icon="❄️" },
		PlayoffsPack     = { accent=Color3.fromRGB(255,80,80),   tint=Color3.fromRGB(48,8,8),     pills={"Epic","Legendary","Event Excl."}, icon="🎄" },
		ElitePack        = { accent=Color3.fromRGB(80,180,255),  tint=Color3.fromRGB(8,20,50),    pills={"Epic","Legendary","Mythic"},    icon="💠" },
		ChampionPack     = { accent=Color3.fromRGB(220,180,40),  tint=Color3.fromRGB(40,30,5),    pills={"Epic","Legendary","Mythic"},    icon="🥇" },
		LegacyPack       = { accent=Color3.fromRGB(180,80,255),  tint=Color3.fromRGB(28,8,50),    pills={"Legendary","Mythic","Secret"}, icon="👑" },
		GrandmasterPack  = { accent=Color3.fromRGB(255,160,20),  tint=Color3.fromRGB(48,25,0),    pills={"Mythic","Secret","Limited"},   icon="⚜️" },
	}

	local PILL_COLORS = {
		["Common"]      = { bg=Color3.fromRGB(55,55,65),    text=Color3.fromRGB(180,180,190) },
		["Rare"]        = { bg=Color3.fromRGB(20,55,110),   text=Color3.fromRGB(100,170,255) },
		["Epic"]        = { bg=Color3.fromRGB(50,20,100),   text=Color3.fromRGB(180,130,255) },
		["Legendary"]   = { bg=Color3.fromRGB(80,45,5),     text=Color3.fromRGB(255,190,50)  },
		["Mythic"]      = { bg=Color3.fromRGB(80,15,55),    text=Color3.fromRGB(255,100,180) },
		["Secret"]      = { bg=Color3.fromRGB(80,35,5),     text=Color3.fromRGB(255,140,50)  },
		["Event Excl."] = { bg=Color3.fromRGB(5,60,60),     text=Color3.fromRGB(80,230,220)  },
	}

	local packOrder = { "FreePack","RookiePack","ProPack","AllStarPack","StanleyCupPack","ElitePack","ChampionPack","LegacyPack","GrandmasterPack","WinterClassicPack","PlayoffsPack" }
	local shopCards = {}

	for idx, packKey in ipairs(packOrder) do
		local pd    = CardDatabase.Packs[packKey]
		local style = PACK_STYLE[packKey]
		if not pd or not style then continue end

		local card = makeButton({
			Size=UDim2.new(1,0,0,110), BackgroundColor3=style.tint, LayoutOrder=idx,
		}, ShopScreen)
		corner(14, card)
		local cardStroke = stroke(TEXT_DIM, 1, card)
		shopCards[packKey] = { frame=card, stroke=cardStroke, style=style }

		create("UIGradient", {
			Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(0.6,0.6,0.6))}),
			Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.88),NumberSequenceKeypoint.new(1,0.96)}),
			Rotation=135,
		}, card)

		local accentBar = makeFrame({ Size=UDim2.new(0,4,1,-20), Position=UDim2.new(0,0,0,10), BackgroundColor3=style.accent }, card)
		create("UICorner", { CornerRadius=UDim.new(0,4) }, accentBar)

		local iconCircle = makeFrame({ Size=UDim2.new(0,48,0,48), Position=UDim2.new(0,14,0.5,-24), BackgroundColor3=style.accent }, card)
		create("UICorner", { CornerRadius=UDim.new(1,0) }, iconCircle)
		create("UIGradient", {
			Color=ColorSequence.new(style.accent, Color3.new(math.clamp(style.accent.R*0.6,0,1),math.clamp(style.accent.G*0.6,0,1),math.clamp(style.accent.B*0.6,0,1))),
			Rotation=135,
		}, iconCircle)
		makeLabel({ Size=UDim2.new(1,0,1,0), Text=style.icon, Font=Enum.Font.GothamBold, TextSize=22, TextColor3=TEXT_WHITE }, iconCircle)

		makeLabel({ Size=UDim2.new(0.55,0,0,26), Position=UDim2.new(0,72,0,12), Text=pd.DisplayName,
			TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=15, TextXAlignment=Enum.TextXAlignment.Left }, card)
		makeLabel({ Size=UDim2.new(0.55,0,0,20), Position=UDim2.new(0,72,0,36), Text=pd.Description,
			TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left }, card)

		local pillRow = makeFrame({ Size=UDim2.new(0.56,0,0,20), Position=UDim2.new(0,72,0,62), BackgroundTransparency=1 }, card)
		create("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, VerticalAlignment=Enum.VerticalAlignment.Center, Padding=UDim.new(0,4) }, pillRow)
		for _, pillName in ipairs(style.pills) do
			local pc = PILL_COLORS[pillName] or PILL_COLORS["Common"]
			local pill = makeLabel({ Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X,
				Text=" "..pillName.." ", TextColor3=pc.text, BackgroundColor3=pc.bg, Font=Enum.Font.GothamBold, TextSize=9 }, pillRow)
			create("UICorner", { CornerRadius=UDim.new(1,0) }, pill)
			create("UIPadding", { PaddingLeft=UDim.new(0,4), PaddingRight=UDim.new(0,4) }, pill)
		end

		local costText  = pd.CostType == "Free" and "FREE" or tostring(pd.Cost).." "..pd.CostType
		local costColor = pd.CostType == "Gems" and Color3.fromRGB(120,200,255) or pd.CostType == "Free" and Color3.fromRGB(80,220,120) or GOLD
		local costBadge = makeFrame({ Size=UDim2.new(0,0,0,28), AutomaticSize=Enum.AutomaticSize.X,
			Position=UDim2.new(1,-8,0,10), AnchorPoint=Vector2.new(1,0), BackgroundColor3=Color3.fromRGB(0,0,0) }, card)
		create("UICorner", { CornerRadius=UDim.new(0,8) }, costBadge)
		create("UIPadding", { PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10) }, costBadge)
		makeLabel({ Size=UDim2.new(1,0,1,0), Text=costText, TextColor3=costColor, Font=Enum.Font.GothamBold, TextSize=13 }, costBadge)

		if pd.IsEvent then
			local evBadge = makeFrame({ Size=UDim2.new(0,0,0,20), AutomaticSize=Enum.AutomaticSize.X,
				Position=UDim2.new(1,-8,1,-28), AnchorPoint=Vector2.new(1,1), BackgroundColor3=Color3.fromRGB(5,50,35) }, card)
			create("UICorner", { CornerRadius=UDim.new(1,0) }, evBadge)
			create("UIPadding", { PaddingLeft=UDim.new(0,8), PaddingRight=UDim.new(0,8) }, evBadge)
			makeLabel({ Size=UDim2.new(1,0,1,0), Text="⚡ LIMITED EVENT", TextColor3=Color3.fromRGB(80,255,160), Font=Enum.Font.GothamBold, TextSize=9 }, evBadge)
		end

		local oddsBtn = makeButton({ Size=UDim2.new(0,80,0,22), Position=UDim2.new(0,72,1,-28),
			BackgroundColor3=Color3.fromRGB(0,40,70), Text="📊 Odds", TextColor3=ACCENT, Font=Enum.Font.GothamBold, TextSize=10 }, card)
		corner(6, oddsBtn)
		stroke(ACCENT, 1, oddsBtn).Transparency = 0.5
		oddsBtn.MouseButton1Click:Connect(function() showPackOdds(packKey) end)

		card.MouseButton1Click:Connect(function()
			SelectedPack = packKey
			for pk, sc in pairs(shopCards) do
				sc.frame.BackgroundColor3 = PACK_STYLE[pk] and PACK_STYLE[pk].tint or PANEL_BG
				if sc.stroke then sc.stroke.Color = TEXT_DIM sc.stroke.Thickness = 1 end
			end
			card.BackgroundColor3 = Color3.new(math.clamp(style.tint.R+0.06,0,1),math.clamp(style.tint.G+0.06,0,1),math.clamp(style.tint.B+0.06,0,1))
			if cardStroke then cardStroke.Color = style.accent cardStroke.Thickness = 2 end
			showToast("Selected: "..pd.DisplayName, style.tint)
		end)
	end

	local openBtn = makeButton({
		Size=UDim2.new(1,0,0,54), BackgroundColor3=ACCENT,
		Text="▶  Open Selected Pack", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=17, LayoutOrder=20,
	}, ShopScreen)
	corner(14, openBtn)
	create("UIGradient", { Color=ColorSequence.new(ACCENT, Color3.fromRGB(0,100,190)), Rotation=90 }, openBtn)
	openBtn.MouseButton1Click:Connect(function()
		switchScreen("Open")
		task.wait(0.05)
		if _G.TriggerPackOpen then _G.TriggerPackOpen() end
	end)
end

-- ══════════════════════════════════════════════════════════════
-- SCREEN: PACK OPENING
-- ══════════════════════════════════════════════════════════════
local OpenScreen = newScreen("Open")
local function buildOpenScreen()
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10) }, OpenScreen)
	sectionHeader("PACK OPENING", OpenScreen, 0)

	local oddsQuickBtn = makeButton({
		Size=UDim2.new(1,0,0,34), BackgroundColor3=Color3.fromRGB(0,40,70),
		Text="📊 View Current Pack Odds", TextColor3=ACCENT, Font=Enum.Font.GothamBold, TextSize=12, LayoutOrder=1,
	}, OpenScreen)
	corner(8, oddsQuickBtn)
	stroke(ACCENT, 1, oddsQuickBtn).Transparency = 0.5
	oddsQuickBtn.MouseButton1Click:Connect(function() showPackOdds(SelectedPack) end)

	local selLabel = makeLabel({ Size=UDim2.new(1,0,0,24), Text="Rookie Pack", TextColor3=TEXT_MUTED,
		Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=1 }, OpenScreen)

	local openBtn = makeButton({
		Size=UDim2.new(1,0,0,56), BackgroundColor3=ACCENT2,
		Text="🎁  OPEN PACK", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=18, LayoutOrder=2,
	}, OpenScreen)
	corner(12, openBtn)

	local revealArea = makeFrame({ Size=UDim2.new(1,0,0,290), BackgroundColor3=PANEL_BG, LayoutOrder=3 }, OpenScreen)
	corner(14, revealArea)

	local revealMsg = makeLabel({ Size=UDim2.new(1,0,0.25,0), Position=UDim2.new(0,0,0.08,0),
		Text="Press OPEN PACK to pull a card", TextColor3=TEXT_DIM, Font=Enum.Font.Gotham, TextSize=14 }, revealArea)

	local cardFrame = makeFrame({ Size=UDim2.new(0,160,0,220), Position=UDim2.new(0.5,-80,0.04,0),
		BackgroundColor3=Color3.fromRGB(10,12,20), Visible=false }, revealArea)
	corner(12, cardFrame)
	local cStroke = stroke(ACCENT, 2, cardFrame)

	local cGradient = create("UIGradient", {
		Color=ColorSequence.new({ ColorSequenceKeypoint.new(0,PANEL_BG2), ColorSequenceKeypoint.new(1,DARK_BG) }),
		Rotation=130,
	}, cardFrame)

	local cBar = makeFrame({ Size=UDim2.new(1,0,0,5), BackgroundColor3=ACCENT }, cardFrame)
	create("UICorner", { CornerRadius=UDim.new(0,10) }, cBar)

	local cOVR     = makeLabel({ Size=UDim2.new(1,0,0,40), Position=UDim2.new(0,0,0,7),
		Text="99", TextColor3=ACCENT, Font=Enum.Font.GothamBold, TextSize=36 }, cardFrame)
	local cRarBadge= makeLabel({ Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,0,49),
		Text="⬜ COM", TextColor3=ACCENT, Font=Enum.Font.GothamBold, TextSize=9 }, cardFrame)
	local cName    = makeLabel({ Size=UDim2.new(1,-8,0,32), Position=UDim2.new(0,4,0,65),
		Text="Player Name", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=13, TextWrapped=true }, cardFrame)
	local cTeam    = makeLabel({ Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,0,100),
		Text="TOR · C", TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11 }, cardFrame)
	local cEra     = makeLabel({ Size=UDim2.new(1,0,0,13), Position=UDim2.new(0,0,0,116),
		Text="Current Season", TextColor3=TEXT_DIM, Font=Enum.Font.Gotham, TextSize=10 }, cardFrame)
	local cVarStrip= makeFrame({ Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,1,-20), BackgroundColor3=PANEL_BG2 }, cardFrame)
	create("UICorner", { CornerRadius=UDim.new(0,10) }, cVarStrip)
	local cVar     = makeLabel({ Size=UDim2.new(1,0,1,0), Text="BASE", TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=10 }, cVarStrip)

	local streakLbl = makeLabel({ Size=UDim2.new(1,0,0,22), Text="", TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=12, LayoutOrder=4 }, OpenScreen)
	local pityLbl   = makeLabel({ Size=UDim2.new(1,0,0,18), Text="", TextColor3=TEXT_DIM, Font=Enum.Font.Gotham, TextSize=10, LayoutOrder=5 }, OpenScreen)

	local function doOpenPack()
		if isOpening then return end
		isOpening = true
		openBtn.Text = "Opening…"
		openBtn.BackgroundColor3 = Color3.fromRGB(80,80,90)
		cardFrame.Visible = false
		revealMsg.Visible = true
		revealMsg.Text    = "✨ Opening pack…"
		selLabel.Text     = (CardDatabase.Packs[SelectedPack] or { DisplayName=SelectedPack }).DisplayName

		local res = OpenPackFn:InvokeServer(SelectedPack)

		if res and res.Success then
			local card     = res.Card
			local rarKey   = res.RarityKey
			local animSpeed= res.AnimSpeed or 1.0
			local rc       = rarityColor(rarKey)
			local rank     = CardDatabase.RarityRank[rarKey] or 1

			task.wait(0.7 / animSpeed)
			revealMsg.Text = "???"
			task.wait(0.5 / animSpeed)
			revealMsg.Visible = false
			cardFrame.Visible = true

			local cs    = cardStyle(rarKey)
			local tintR = math.clamp(math.floor(rc.R*255*0.18+8),0,255)
			local tintG = math.clamp(math.floor(rc.G*255*0.14+8),0,255)
			local tintB = math.clamp(math.floor(rc.B*255*0.14+10),0,255)
			cardFrame.BackgroundColor3 = Color3.fromRGB(
				math.clamp(math.floor(rc.R*255*0.08+10),0,255),
				math.clamp(math.floor(rc.G*255*0.08+10),0,255),
				math.clamp(math.floor(rc.B*255*0.08+12),0,255)
			)
			cGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(tintR,tintG,tintB)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(8,10,18)),
			})
			cStroke.Color     = rc
			cStroke.Thickness = 1 + (RARITY_RANK_MAP[rarKey] or 1) * 0.3
			cBar.BackgroundColor3 = rc
			cOVR.Text         = tostring(card.OVR)
			cOVR.TextColor3   = rc
			cOVR.TextSize     = math.max(28, math.min(42, 24 + (RARITY_RANK_MAP[rarKey] or 1) * 2))
			cRarBadge.Text    = cs.badge.." "..rarKey:sub(1,3):upper()
			cRarBadge.TextColor3 = rc
			cName.Text        = card.PlayerName
			cTeam.Text        = card.Team.." · "..card.Position
			cEra.Text         = card.Era
			cVar.Text         = card.Variant:upper()
			cVar.TextColor3   = variantColor(card.Variant)
			cVarStrip.BackgroundColor3 = Color3.fromRGB(
				math.clamp(math.floor(rc.R*255*0.22),0,255),
				math.clamp(math.floor(rc.G*255*0.22),0,255),
				math.clamp(math.floor(rc.B*255*0.22),0,255)
			)

			cardFrame.Size     = UDim2.new(0,0,0,220)
			cardFrame.Position = UDim2.new(0.5,0,0.04,0)
			TweenService:Create(cardFrame, TweenInfo.new(0.35/animSpeed, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size=UDim2.new(0,160,0,220), Position=UDim2.new(0.5,-80,0.04,0),
			}):Play()

			playSound(CardDatabase.Rarities[rarKey].SoundId, 0.4 + rank*0.07, 0.85 + rank*0.04)

			if rank >= 5 then
				local flash = makeFrame({ Size=UDim2.new(1,0,1,0), BackgroundColor3=rc, BackgroundTransparency=0.4, ZIndex=60 }, revealArea)
				TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency=1 }):Play()
				task.delay(0.6, function() flash:Destroy() end)
			end

			local pc = LocalData.PityCounters
			if pc then
				pityLbl.Text = string.format("Pity: Rare %d/%d · Epic %d/%d · Leg %d/%d",
					pc.PacksSinceRare,      CardDatabase.PityConfig.RareGuaranteeAfter,
					pc.PacksSinceEpic,      CardDatabase.PityConfig.EpicGuaranteeAfter,
					pc.PacksSinceLegendary, CardDatabase.PityConfig.LegendaryGuaranteeAfter)
			end
			streakLbl.Text = "🔥 Streak: "..tostring(LocalData.CurrentStreak or 0).." packs"
		else
			local err  = res and res.Error or "Unknown"
			revealMsg.Visible = true
			local msgs = {
				InsufficientPucks="Not enough Pucks!", InsufficientGems="Not enough Gems!",
				InventoryFull="Inventory full! Sell some cards.", RateLimit="Slow down! Try again.",
			}
			revealMsg.Text = msgs[err] or ("Error: "..err)
			showToast(revealMsg.Text, ACCENT2)
		end

		task.wait(0.4)
		openBtn.Text             = "🎁  OPEN PACK"
		openBtn.BackgroundColor3 = ACCENT2
		isOpening                = false
	end

	openBtn.MouseButton1Click:Connect(doOpenPack)
	_G.TriggerPackOpen = doOpenPack
end

-- ══════════════════════════════════════════════════════════════
-- SCREEN: INVENTORY
-- ══════════════════════════════════════════════════════════════
local InventoryScreen = newScreen("Inventory")
local invGrid, invCountLabel

local SORT_MODES = {
	{ label="Rarity ▼", fn=function(a,b)
		local ra = CardDatabase.RarityRank[a.Rarity] or 0
		local rb = CardDatabase.RarityRank[b.Rarity] or 0
		if ra ~= rb then return ra > rb end
		return (a.OVR or 0) > (b.OVR or 0)
	end },
	{ label="OVR ▼",    fn=function(a,b) return (a.OVR or 0) > (b.OVR or 0) end },
	{ label="Value ▼",  fn=function(a,b) return (a.Value or 0) > (b.Value or 0) end },
	{ label="Name A–Z", fn=function(a,b)
		local aL = (a.PlayerName or ""):match("(%S+)$") or (a.PlayerName or "")
		local bL = (b.PlayerName or ""):match("(%S+)$") or (b.PlayerName or "")
		return aL:lower() < bL:lower()
	end },
}
local currentSortIdx    = 1
local quickSellSelected = {}
local invSortBtn, quickSellPanel

local function refreshInventory()
	if not invGrid then return end
	for _, c in ipairs(invGrid:GetChildren()) do
		if not c:IsA("UIGridLayout") then c:Destroy() end
	end
	local inv = LocalData.Inventory or {}
	if invCountLabel then
		invCountLabel.Text = "Cards: "..#inv.." / "..(LocalData.MaxInventory or 200)
	end
	for k in pairs(lockedCards) do lockedCards[k] = nil end
	for _, card in ipairs(inv) do
		if card.Locked then lockedCards[card.CardId] = true end
	end
	local sorted = {}
	for _, c in ipairs(inv) do table.insert(sorted, c) end
	table.sort(sorted, SORT_MODES[currentSortIdx].fn)
	for i, card in ipairs(sorted) do
		local isLocked = lockedCards[card.CardId]
		local w = makeCardWidget(invGrid, card, { isLocked=isLocked })
		w.LayoutOrder = i
		w.MouseButton1Click:Connect(function() showCardDialog(card) end)
	end
end

local function buildInventoryScreen()
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8) }, InventoryScreen)

	local header = makeFrame({ Size=UDim2.new(1,0,0,38), BackgroundColor3=PANEL_BG2, LayoutOrder=0 }, InventoryScreen)
	corner(10, header)
	stroke(ACCENT, 1, header).Transparency = 0.6
	create("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8), VerticalAlignment=Enum.VerticalAlignment.Center }, header)
	create("UIPadding", { PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,8), PaddingTop=UDim.new(0,0) }, header)

	local countWrap = makeFrame({ Size=UDim2.new(0.38,0,0,26), BackgroundTransparency=1 }, header)
	makeLabel({ Size=UDim2.new(0,18,1,0), Text="🃏", TextColor3=ACCENT, Font=Enum.Font.GothamBold, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left }, countWrap)
	invCountLabel = makeLabel({ Size=UDim2.new(1,-20,1,0), Position=UDim2.new(0,20,0,0), Text="Cards: 0/200",
		TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left }, countWrap)

	invSortBtn = makeButton({ Size=UDim2.new(0.3,0,0,26), BackgroundColor3=Color3.fromRGB(0,60,100),
		Text="⇅  "..SORT_MODES[1].label, TextColor3=ACCENT, Font=Enum.Font.GothamBold, TextSize=10 }, header)
	corner(8, invSortBtn)
	stroke(ACCENT, 1, invSortBtn)
	invSortBtn.MouseButton1Click:Connect(function()
		currentSortIdx = (currentSortIdx % #SORT_MODES) + 1
		invSortBtn.Text = "⇅  "..SORT_MODES[currentSortIdx].label
		refreshInventory()
	end)

	local qsToggleBtn = makeButton({ Size=UDim2.new(0.26,0,0,26), BackgroundColor3=Color3.fromRGB(140,20,20),
		Text="💰 Quick Sell", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=10 }, header)
	corner(8, qsToggleBtn)
	stroke(ACCENT2, 1, qsToggleBtn)

	quickSellPanel = makeFrame({ Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundColor3=Color3.fromRGB(22,10,10), Visible=false, LayoutOrder=1 }, InventoryScreen)
	corner(10, quickSellPanel)
	stroke(Color3.fromRGB(160,30,30), 1.5, quickSellPanel)
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6) }, quickSellPanel)
	create("UIPadding", { PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,8) }, quickSellPanel)

	makeLabel({ Size=UDim2.new(1,0,0,18), LayoutOrder=0,
		Text="SELECT RARITIES TO SELL  (locked cards are always skipped)",
		TextColor3=Color3.fromRGB(220,80,80), Font=Enum.Font.GothamBold, TextSize=10,
		TextXAlignment=Enum.TextXAlignment.Left }, quickSellPanel)

	local rarityRow = makeFrame({ Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, LayoutOrder=1 }, quickSellPanel)
	create("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,6), VerticalAlignment=Enum.VerticalAlignment.Center }, rarityRow)

	local rarityOrder = { "Common","Rare","Epic","Legendary","Mythic" }
	local checkBtns = {}
	for _, rarity in ipairs(rarityOrder) do
		local rc = rarityColor(rarity)
		local toggled = false
		local pill = makeButton({ Size=UDim2.new(0,72,0,26), BackgroundColor3=Color3.fromRGB(20,20,28),
			Text=rarity:sub(1,3):upper(), TextColor3=TEXT_DIM, Font=Enum.Font.GothamBold, TextSize=11 }, rarityRow)
		corner(6, pill)
		stroke(TEXT_DIM, 1, pill)
		local function updatePill()
			if toggled then
				pill.BackgroundColor3 = darkTint(rc, 0.85); pill.TextColor3 = rc
				local s = pill:FindFirstChildOfClass("UIStroke"); if s then s.Color = rc end
			else
				pill.BackgroundColor3 = Color3.fromRGB(20,20,28); pill.TextColor3 = TEXT_DIM
				local s = pill:FindFirstChildOfClass("UIStroke"); if s then s.Color = TEXT_DIM end
			end
		end
		pill.MouseButton1Click:Connect(function() toggled = not toggled; quickSellSelected[rarity] = toggled; updatePill() end)
		checkBtns[rarity] = { pill=pill, updatePill=updatePill }
	end

	local sellRow = makeFrame({ Size=UDim2.new(1,0,0,34), BackgroundTransparency=1, LayoutOrder=2 }, quickSellPanel)
	create("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8), VerticalAlignment=Enum.VerticalAlignment.Center }, sellRow)

	local previewLbl = makeLabel({ Size=UDim2.new(0.6,0,1,0), Text="Select rarities above",
		TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left }, sellRow)

	local function updatePreview()
		local inv = LocalData.Inventory or {}
		local count, total = 0, 0
		for _, card in ipairs(inv) do
			if quickSellSelected[card.Rarity] and not card.Locked then
				count += 1; total += math.floor((card.Value or 0))
			end
		end
		previewLbl.Text = count > 0 and (count.." cards → "..tostring(total).." Pucks") or "Select rarities above"
	end

	for _, rarity in ipairs(rarityOrder) do
		checkBtns[rarity].pill.MouseButton1Click:Connect(function() updatePreview() end)
	end

	local doSellBtn = makeButton({ Size=UDim2.new(0.38,0,0,28), BackgroundColor3=Color3.fromRGB(180,35,35),
		Text="Sell Selected", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=12 }, sellRow)
	corner(6, doSellBtn)
	doSellBtn.MouseButton1Click:Connect(function()
		local selected = {}
		for rarity, on in pairs(quickSellSelected) do if on then table.insert(selected, rarity) end end
		if #selected == 0 then showToast("Pick at least one rarity first.", Color3.fromRGB(160,30,30)); return end
		local inv = LocalData.Inventory or {}
		local count = 0
		for _, card in ipairs(inv) do if quickSellSelected[card.Rarity] and not card.Locked then count += 1 end end
		if count == 0 then showToast("No unlocked cards match the selected rarities.", TEXT_MUTED); return end
		doSellBtn.Text = "Selling..."; doSellBtn.AutoButtonColor = false
		local res = BulkSellFn:InvokeServer(selected)
		doSellBtn.Text = "Sell Selected"; doSellBtn.AutoButtonColor = true
		if res and res.Success then
			showToast("Sold "..res.Count.." cards for "..res.Total.." Pucks!", GOLD)
			for rarity in pairs(quickSellSelected) do
				quickSellSelected[rarity] = false
				if checkBtns[rarity] then checkBtns[rarity].updatePill() end
			end
			updatePreview()
		else
			showToast("Bulk sell failed: "..tostring(res and res.Error), ACCENT)
		end
	end)

	qsToggleBtn.MouseButton1Click:Connect(function()
		quickSellPanel.Visible = not quickSellPanel.Visible; updatePreview()
	end)

	local gridWrap = makeFrame({ Name="GridWrap", Size=UDim2.new(1,0,0,10), AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundTransparency=1, LayoutOrder=2 }, InventoryScreen)
	invGrid = gridWrap
	create("UIGridLayout", { CellSize=UDim2.new(0,92,0,130), CellPadding=UDim2.new(0,6,0,6),
		HorizontalAlignment=Enum.HorizontalAlignment.Center, SortOrder=Enum.SortOrder.LayoutOrder }, gridWrap)
end

-- ══════════════════════════════════════════════════════════════
-- SCREEN: PUCK-INDEX
-- ══════════════════════════════════════════════════════════════
-- Each unique player entry gets its own row showing all 8 rarity
-- slots. Collected slots show the card with correct OVR (midpoint
-- of that rarity's OVR range, or best actual OVR from inventory).
-- Uncollected slots show a dim locked placeholder.
-- ══════════════════════════════════════════════════════════════
local IndexScreen = newScreen("Index")
local indexGrid, indexPctLabel, indexBarFill

-- Ordered from lowest to highest rarity for left→right display
local INDEX_RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Limited", "EventExclusive" }

-- Midpoint OVR for each rarity (used when player has no actual card of that rarity)
local function rarityMidOVR(rarityKey)
	local def = CardDatabase.Rarities[rarityKey]
	if not def then return 70 end
	return math.floor((def.OVRMin + def.OVRMax) / 2)
end

-- Short rarity label for the index rarity strip
local RARITY_SHORT = {
	Common="COM", Rare="RAR", Epic="EPC", Legendary="LEG",
	Mythic="MYT", Secret="SEC", Limited="LIM", EventExclusive="EVT",
}

local function buildIndexScreen()
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10) }, IndexScreen)

	local headerPanel = makeFrame({ Size=UDim2.new(1,0,0,70), BackgroundColor3=PANEL_BG, LayoutOrder=0 }, IndexScreen)
	corner(12, headerPanel)
	stroke(ACCENT, 1, headerPanel).Transparency = 0.6
	create("UIGradient", { Color=ColorSequence.new({ ColorSequenceKeypoint.new(0,Color3.fromRGB(0,60,110)), ColorSequenceKeypoint.new(1,Color3.fromRGB(15,20,38)) }), Rotation=90 }, headerPanel)
	makeLabel({ Size=UDim2.new(1,0,0,22), Position=UDim2.new(0,0,0,8), Text="📖  PUCK-INDEX — COLLECTION", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=14 }, headerPanel)
	indexPctLabel = makeLabel({ Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,0,30), Text="0% Complete — 0 / 0", TextColor3=ACCENT, Font=Enum.Font.GothamBold, TextSize=11 }, headerPanel)
	local barBg = makeFrame({ Size=UDim2.new(1,-20,0,8), Position=UDim2.new(0,10,0,52), BackgroundColor3=PANEL_BG2 }, headerPanel)
	corner(4, barBg)
	indexBarFill = makeFrame({ Size=UDim2.new(0,0,1,0), BackgroundColor3=ACCENT }, barBg)
	corner(4, indexBarFill)
	for _, pct in ipairs({0.25,0.5,0.75}) do
		makeFrame({ Size=UDim2.new(0,1,1,0), Position=UDim2.new(pct,0,0,0), BackgroundColor3=Color3.fromRGB(60,70,100) }, barBg)
	end

	local groupsWrap = makeFrame({ Name="IndexGroups", Size=UDim2.new(1,0,0,10), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, LayoutOrder=1 }, IndexScreen)
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,14) }, groupsWrap)
	indexGrid = groupsWrap
end

local function refreshIndex()
	if not indexGrid then return end
	for _, c in ipairs(indexGrid:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end

	local collected = LocalData.CollectionIndex or {}
	local total     = CardDatabase.GetTotalCollectibleCards()
	local count     = LocalData.CollectionCount or 0
	local pct       = math.floor((count / math.max(total,1)) * 100)

	if indexPctLabel then indexPctLabel.Text = pct.."% Complete — "..count.." / "..total end
	if indexBarFill  then TweenService:Create(indexBarFill, TweenInfo.new(0.6,Enum.EasingStyle.Quad), { Size=UDim2.new(pct/100,0,1,0) }):Play() end

	local positionOrder  = { "C","LW","RW","D","G" }
	local positionLabel  = { C="⚔️  Centers", LW="🏒  Left Wings", RW="🥅  Right Wings", D="🛡️  Defensemen", G="🧤  Goalies" }
	local positionAccent = { C=ACCENT, LW=Color3.fromRGB(80,200,120), RW=Color3.fromRGB(212,83,180), D=GOLD, G=Color3.fromRGB(200,100,255) }

	-- Build inventory lookup: [playerName][rarityKey] → best OVR found in inventory
	local invBestOVR = {}
	for _, card in ipairs(LocalData.Inventory or {}) do
		local n = card.PlayerName
		local r = card.Rarity
		if n and r then
			if not invBestOVR[n] then invBestOVR[n] = {} end
			local cur = invBestOVR[n][r] or 0
			if (card.OVR or 0) > cur then invBestOVR[n][r] = card.OVR end
		end
	end

	-- Build unique player list per position (deduplicated by Name+Era+Team key
	-- so the same player with different eras each gets their own row)
	local byPosition = {}
	local seenKey = {}
	for _, pd in ipairs(CardDatabase.Players) do
		-- Use Name+Era+Team as the unique key so "Sidney Crosby All-Time" and
		-- "Sidney Crosby Rookie Year" are separate rows
		local key = pd.Name.."||"..pd.Era.."||"..pd.Team
		if not seenKey[key] then
			seenKey[key] = true
			-- Compute highest rarity collected for sort order
			local highestRank = 0
			for _, rk in ipairs(INDEX_RARITY_ORDER) do
				local ck = pd.Name.."_"..rk
				if collected[ck] then
					local rank = CardDatabase.RarityRank[rk] or 0
					if rank > highestRank then highestRank = rank end
				end
			end
			local pos = pd.Position or "C"
			if not byPosition[pos] then byPosition[pos] = {} end
			table.insert(byPosition[pos], { pd=pd, highestRank=highestRank, key=key })
		end
	end

	-- Card slot dimensions — 8 per row, compact
	local CARD_W  = 74   -- card width
	local CARD_H  = 104  -- card height
	local CARD_PAD = 5   -- padding between cards

	for _, pos in ipairs(positionOrder) do
		local group = byPosition[pos]
		if not group or #group == 0 then continue end

		-- Sort: players with any collected card first (highest rarity → lowest),
		-- then uncollected players alphabetically
		table.sort(group, function(a, b)
			if a.highestRank ~= b.highestRank then return a.highestRank > b.highestRank end
			return (a.pd.Name or "") < (b.pd.Name or "")
		end)

		local posColor = positionAccent[pos] or ACCENT

		-- ── Position section wrapper ──────────────────────────────
		local section = makeFrame({ Name="Section_"..pos, Size=UDim2.new(1,0,0,10),
			AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1 }, indexGrid)
		create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8) }, section)

		-- ── Section header bar ────────────────────────────────────
		local sHdr = makeFrame({ Size=UDim2.new(1,0,0,32),
			BackgroundColor3=Color3.fromRGB(
				math.clamp(math.floor(posColor.R*255*0.12),0,255),
				math.clamp(math.floor(posColor.G*255*0.12),0,255),
				math.clamp(math.floor(posColor.B*255*0.12),0,255)),
			LayoutOrder=0 }, section)
		corner(8, sHdr)
		stroke(posColor, 1, sHdr).Transparency = 0.5
		makeFrame({ Size=UDim2.new(0,4,1,0), BackgroundColor3=posColor }, sHdr)
		makeLabel({ Size=UDim2.new(0.55,0,1,0), Position=UDim2.new(0,12,0,0),
			Text=positionLabel[pos] or pos, TextColor3=posColor,
			Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left }, sHdr)

		-- Count badge: how many individual rarity slots collected vs total possible
		local slotsCollected = 0
		local slotsTotal     = #group * #INDEX_RARITY_ORDER
		for _, e in ipairs(group) do
			for _, rk in ipairs(INDEX_RARITY_ORDER) do
				local ck = e.pd.Name.."_"..rk
				if collected[ck] then slotsCollected += 1 end
			end
		end
		local countBadge = makeFrame({ Size=UDim2.new(0,80,0,22), Position=UDim2.new(1,-88,0.5,-11),
			BackgroundColor3=Color3.fromRGB(
				math.clamp(math.floor(posColor.R*255*0.2),0,255),
				math.clamp(math.floor(posColor.G*255*0.2),0,255),
				math.clamp(math.floor(posColor.B*255*0.2),0,255)) }, sHdr)
		corner(6, countBadge)
		makeLabel({ Size=UDim2.new(1,0,1,0),
			Text=slotsCollected.." / "..slotsTotal,
			TextColor3=posColor, Font=Enum.Font.GothamBold, TextSize=10 }, countBadge)

		-- ── Per-player rows ───────────────────────────────────────
		-- Each player gets a horizontal strip: name label on the left,
		-- then 8 card slots across.
		local playerList = makeFrame({ Size=UDim2.new(1,0,0,10),
			AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, LayoutOrder=1 }, section)
		create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6) }, playerList)

		for pi, entry in ipairs(group) do
			local pd = entry.pd

			-- Outer row: name label left, card strip right
			-- Height = card height + top/bottom margin
			local ROW_H = CARD_H + 10
			local playerRow = makeFrame({ Size=UDim2.new(1,0,0,ROW_H),
				BackgroundColor3=Color3.fromRGB(12,14,22), LayoutOrder=pi }, playerList)
			corner(10, playerRow)
			stroke(Color3.fromRGB(30,35,55), 1, playerRow)

			-- Left: player name + era label (fixed width 90px)
			local NAME_W = 90
			local namePanel = makeFrame({ Size=UDim2.new(0,NAME_W,1,0), Position=UDim2.new(0,0,0,0),
				BackgroundColor3=Color3.fromRGB(
					math.clamp(math.floor(posColor.R*255*0.08),0,255),
					math.clamp(math.floor(posColor.G*255*0.08),0,255),
					math.clamp(math.floor(posColor.B*255*0.08),0,255)) }, playerRow)
			corner(10, namePanel)

			-- Position pill
			local posPill = makeFrame({ Size=UDim2.new(0,22,0,14), Position=UDim2.new(0,6,0,6),
				BackgroundColor3=Color3.fromRGB(
					math.clamp(math.floor(posColor.R*255*0.3),0,255),
					math.clamp(math.floor(posColor.G*255*0.3),0,255),
					math.clamp(math.floor(posColor.B*255*0.3),0,255)) }, namePanel)
			corner(4, posPill)
			makeLabel({ Size=UDim2.new(1,0,1,0), Text=pd.Position,
				TextColor3=posColor, Font=Enum.Font.GothamBold, TextSize=8 }, posPill)

			-- Last name (large)
			makeLabel({ Size=UDim2.new(1,-8,0,32), Position=UDim2.new(0,4,0,22),
				Text=pd.Name:match("(%S+)$") or pd.Name,
				TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=11,
				TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Center }, namePanel)

			-- Team
			makeLabel({ Size=UDim2.new(1,0,0,12), Position=UDim2.new(0,0,0,56),
				Text=pd.Team, TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=9 }, namePanel)

			-- Era (small, wrapped)
			makeLabel({ Size=UDim2.new(1,-4,0,24), Position=UDim2.new(0,2,0,70),
				Text=pd.Era, TextColor3=TEXT_DIM, Font=Enum.Font.Gotham, TextSize=8,
				TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Center }, namePanel)

			-- Horizontal scrolling card strip (8 rarity slots)
			-- We use a horizontal ScrollingFrame so they don't overflow on small screens
			local stripScroll = create("ScrollingFrame", {
				Size             = UDim2.new(1,-NAME_W-6,1,-6),
				Position         = UDim2.new(0,NAME_W+6,0,3),
				BackgroundTransparency = 1,
				BorderSizePixel  = 0,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = posColor,
				CanvasSize       = UDim2.new(0, (#INDEX_RARITY_ORDER*(CARD_W+CARD_PAD)), 0, 0),
				ScrollingDirection = Enum.ScrollingDirection.X,
			}, playerRow)
			create("UIListLayout", {
				FillDirection     = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder         = Enum.SortOrder.LayoutOrder,
				Padding           = UDim.new(0, CARD_PAD),
			}, stripScroll)

			for ri, rarityKey in ipairs(INDEX_RARITY_ORDER) do
				local collectionKey = pd.Name.."_"..rarityKey
				local isCollected   = collected[collectionKey] == true

				-- Slot container (fixed size card)
				local slot = makeFrame({ Size=UDim2.new(0,CARD_W,0,CARD_H),
					BackgroundTransparency=1, LayoutOrder=ri }, stripScroll)

				if isCollected then
					-- Get best OVR for this player+rarity from inventory,
					-- fallback to midpoint of rarity OVR range
					local bestOVR = (invBestOVR[pd.Name] and invBestOVR[pd.Name][rarityKey])
						or rarityMidOVR(rarityKey)

					local fakeCard = {
						OVR        = bestOVR,
						Rarity     = rarityKey,
						PlayerName = pd.Name,
						Team       = pd.Team,
						Variant    = "Base",
					}
					local w = makeCardWidget(slot, fakeCard, { size=UDim2.new(1,0,1,0), zBase=2 })
					w.LayoutOrder = ri
				else
					-- Locked placeholder
					local rc = rarityColor(rarityKey)
					local cell = makeFrame({ Size=UDim2.new(1,0,1,0),
						BackgroundColor3=Color3.fromRGB(10,11,18), LayoutOrder=ri }, slot)
					corner(8, cell)
					-- Dim border tinted to the rarity colour so you can see what you're chasing
					local s = stroke(rc, 1, cell)
					s.Transparency = 0.75

					-- Rarity colour dot at top
					local dot = makeFrame({ Size=UDim2.new(0,8,0,8), Position=UDim2.new(0.5,-4,0,5),
						BackgroundColor3=rc }, cell)
					corner(4, dot)

					-- Lock icon
					makeLabel({ Size=UDim2.new(1,0,0,24), Position=UDim2.new(0,0,0,16),
						Text="🔒", TextColor3=Color3.fromRGB(40,46,65),
						Font=Enum.Font.GothamBold, TextSize=16 }, cell)

					-- Rarity short label
					makeLabel({ Size=UDim2.new(1,0,0,12), Position=UDim2.new(0,0,0,42),
						Text=RARITY_SHORT[rarityKey] or rarityKey:sub(1,3):upper(),
						TextColor3=rc, Font=Enum.Font.GothamBold, TextSize=8 }, cell)

					-- OVR range
					local rarDef = CardDatabase.Rarities[rarityKey]
					if rarDef then
						makeLabel({ Size=UDim2.new(1,0,0,11), Position=UDim2.new(0,0,0,56),
							Text=rarDef.OVRMin.."-"..rarDef.OVRMax,
							TextColor3=Color3.fromRGB(40,46,65), Font=Enum.Font.Gotham, TextSize=8 }, cell)
					end

					-- Bottom "???" strip
					local unknownStrip = makeFrame({ Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,1,-14),
						BackgroundColor3=Color3.fromRGB(14,15,24) }, cell)
					create("UICorner", { CornerRadius=UDim.new(0,8) }, unknownStrip)
					makeLabel({ Size=UDim2.new(1,0,1,0), Text="???",
						TextColor3=Color3.fromRGB(35,40,58), Font=Enum.Font.GothamBold, TextSize=7 }, unknownStrip)
				end
			end
		end
	end
end

-- ══════════════════════════════════════════════════════════════
-- SCREEN: TRADE  (phase-based flow)
--   1. A sends TradeRequest to server naming B
--   2. B gets TradeRequestRecv → accept/decline popup
--   3. B fires TradeRequestResp → server fires TradeSessionOpen to both
--   4. Live window opens for both; players pick cards in real time
--   5. Both fire TradeConfirm → server executes swap → TradeCompleted
-- ══════════════════════════════════════════════════════════════
local TradeScreen = newScreen("Trade")

local tradeSessionId    = nil
local tradePartnerName  = nil
local myTradeCards      = {}
local theirTradeCards   = {}
local iHaveConfirmed    = false
local theyHaveConfirmed = false

local refreshLiveMyCards
local refreshLiveTheirCards
local refreshLiveConfirmStatus
local refreshLiveInventory
local closeLiveWindow

-- ── PLAYER PICKER POPUP ───────────────────────────────────────
local PlayerPickerPopup = makeFrame({
	Size=UDim2.new(0,300,0,400), Position=UDim2.new(0.5,-150,0.5,-200),
	BackgroundColor3=Color3.fromRGB(14,16,26), Visible=false, ZIndex=200,
}, ScreenGui)
corner(14, PlayerPickerPopup)
stroke(GOLD, 2, PlayerPickerPopup)

local ppTitleBar = makeFrame({ Size=UDim2.new(1,0,0,48), BackgroundColor3=Color3.fromRGB(80,50,0), ZIndex=201 }, PlayerPickerPopup)
corner(14, ppTitleBar)
create("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(180,115,10),Color3.fromRGB(70,42,0)),Rotation=90},ppTitleBar)
makeLabel({ Size=UDim2.new(0.78,0,1,0), Position=UDim2.new(0,12,0,0), Text="SELECT A PLAYER",
	TextColor3=Color3.fromRGB(255,225,90), Font=Enum.Font.GothamBold, TextSize=15, ZIndex=202,
	TextXAlignment=Enum.TextXAlignment.Left }, ppTitleBar)

local ppCloseBtn = makeButton({ Size=UDim2.new(0,28,0,28), Position=UDim2.new(1,-32,0,10),
	BackgroundColor3=Color3.fromRGB(160,25,25), Text="✕", TextColor3=TEXT_WHITE,
	Font=Enum.Font.GothamBold, TextSize=12, ZIndex=202 }, PlayerPickerPopup)
corner(6, ppCloseBtn)
ppCloseBtn.MouseButton1Click:Connect(function() PlayerPickerPopup.Visible = false end)

local ppRefreshBtn = makeButton({ Size=UDim2.new(1,-16,0,28), Position=UDim2.new(0,8,0,56),
	BackgroundColor3=Color3.fromRGB(0,40,75), Text="🔄  Refresh Players", TextColor3=ACCENT,
	Font=Enum.Font.GothamBold, TextSize=11, ZIndex=201 }, PlayerPickerPopup)
corner(7, ppRefreshBtn)
stroke(ACCENT, 1, ppRefreshBtn).Transparency = 0.5

local ppScroll = create("ScrollingFrame", {
	Size=UDim2.new(1,-16,1,-94), Position=UDim2.new(0,8,0,92),
	BackgroundTransparency=1, BorderSizePixel=0,
	ScrollBarThickness=3, ScrollBarImageColor3=GOLD,
	CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=201,
}, PlayerPickerPopup)
create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,5) }, ppScroll)

local function refreshPlayerPicker()
	for _, c in ipairs(ppScroll:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
	local loadLbl = makeLabel({ Size=UDim2.new(1,0,0,34), Text="Loading players…",
		TextColor3=TEXT_DIM, Font=Enum.Font.Gotham, TextSize=12, ZIndex=202 }, ppScroll)
	local ok, players = pcall(function() return GetOnlinePlayersFn:InvokeServer() end)
	loadLbl:Destroy()
	if not ok or not players or #players == 0 then
		makeLabel({ Size=UDim2.new(1,0,0,34),
			Text=not ok and "⚠ Connection error" or "No other players online",
			TextColor3=TEXT_DIM, Font=Enum.Font.Gotham, TextSize=12, ZIndex=202 }, ppScroll)
		return
	end
	for i, pInfo in ipairs(players) do
		local row = makeFrame({ Size=UDim2.new(1,0,0,52), BackgroundColor3=Color3.fromRGB(18,21,32), LayoutOrder=i, ZIndex=202 }, ppScroll)
		corner(9, row); stroke(Color3.fromRGB(45,50,75), 1, row)
		local av = makeFrame({ Size=UDim2.new(0,36,0,36), Position=UDim2.new(0,8,0.5,-18), BackgroundColor3=ACCENT, ZIndex=203 }, row)
		corner(18, av)
		makeLabel({ Size=UDim2.new(1,0,1,0), Text=pInfo.Name:sub(1,1):upper(), TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=14, ZIndex=203 }, av)
		makeLabel({ Size=UDim2.new(0.52,0,0,20), Position=UDim2.new(0,52,0.5,-10), Text=pInfo.Name, TextColor3=TEXT_WHITE,
			Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=203 }, row)
		local reqBtn = makeButton({ Size=UDim2.new(0,76,0,28), Position=UDim2.new(1,-84,0.5,-14),
			BackgroundColor3=Color3.fromRGB(130,78,0), Text="REQUEST", TextColor3=TEXT_WHITE,
			Font=Enum.Font.GothamBold, TextSize=10, ZIndex=203 }, row)
		corner(6, reqBtn)
		create("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(200,135,10),Color3.fromRGB(110,58,0)),Rotation=90},reqBtn)
		reqBtn.MouseButton1Click:Connect(function()
			tradePartnerName = pInfo.Name
			PlayerPickerPopup.Visible = false
			TradeRequest:FireServer(pInfo.Name)
			showToast("Trade request sent to "..pInfo.Name.."!", GREEN)
		end)
	end
end
ppRefreshBtn.MouseButton1Click:Connect(function() task.spawn(refreshPlayerPicker) end)

-- ── INCOMING REQUEST POPUP (Player B) ────────────────────────
local RequestPopup = makeFrame({ Size=UDim2.new(0.82,0,0,190), Position=UDim2.new(0.09,0,0.28,0),
	BackgroundColor3=Color3.fromRGB(14,16,26), Visible=false, ZIndex=160 }, ScreenGui)
corner(14, RequestPopup)
stroke(ACCENT, 2, RequestPopup)
makeFrame({ Size=UDim2.new(1,0,0,48), BackgroundColor3=Color3.fromRGB(0,55,100), ZIndex=161 }, RequestPopup)
makeLabel({ Size=UDim2.new(1,-16,0,48), Position=UDim2.new(0,8,0,0), Text="🔄 Trade Request",
	TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=17, ZIndex=162 }, RequestPopup)
local reqPopupFrom = makeLabel({ Size=UDim2.new(1,-16,0,28), Position=UDim2.new(0,8,0,54),
	Text="— wants to trade with you", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=14,
	ZIndex=162, TextXAlignment=Enum.TextXAlignment.Left }, RequestPopup)
makeLabel({ Size=UDim2.new(1,-16,0,20), Position=UDim2.new(0,8,0,84),
	Text="Accept to open the live trade window and choose cards.",
	TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11, TextWrapped=true, ZIndex=162,
	TextXAlignment=Enum.TextXAlignment.Left }, RequestPopup)
local reqAcceptBtn = makeButton({ Size=UDim2.new(0.44,0,0,40), Position=UDim2.new(0.04,0,0,136),
	BackgroundColor3=GREEN, Text="✅ Accept", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=14, ZIndex=162 }, RequestPopup)
corner(9, reqAcceptBtn)
local reqDeclineBtn = makeButton({ Size=UDim2.new(0.44,0,0,40), Position=UDim2.new(0.52,0,0,136),
	BackgroundColor3=ACCENT2, Text="❌ Decline", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=14, ZIndex=162 }, RequestPopup)
corner(9, reqDeclineBtn)

local pendingRequestInitiatorId = nil

TradeRequestRecv.OnClientEvent:Connect(function(info)
	pendingRequestInitiatorId = info.InitiatorId
	reqPopupFrom.Text = info.InitiatorName.." wants to trade with you"
	RequestPopup.Visible = true
end)

reqAcceptBtn.MouseButton1Click:Connect(function()
	RequestPopup.Visible = false
	if pendingRequestInitiatorId then TradeRequestResp:FireServer(pendingRequestInitiatorId, true) end
	pendingRequestInitiatorId = nil
	showToast("Accepted! Opening trade window…", GREEN)
end)

reqDeclineBtn.MouseButton1Click:Connect(function()
	RequestPopup.Visible = false
	if pendingRequestInitiatorId then TradeRequestResp:FireServer(pendingRequestInitiatorId, false) end
	pendingRequestInitiatorId = nil
	showToast("Trade request declined.", TEXT_MUTED)
end)

-- ── LIVE TRADE WINDOW ─────────────────────────────────────────
local LiveWindow = makeFrame({ Size=UDim2.new(1,0,1,0), Position=UDim2.new(0,0,0,0),
	BackgroundColor3=Color3.fromRGB(8,10,18), Visible=false, ZIndex=150 }, ScreenGui)

local lwTitle = makeFrame({ Size=UDim2.new(1,0,0,48), BackgroundColor3=Color3.fromRGB(12,16,30), ZIndex=151 }, LiveWindow)
stroke(Color3.fromRGB(40,50,80), 1, lwTitle)
create("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(20,32,60),Color3.fromRGB(8,10,20)),Rotation=90},lwTitle)

local lwTitleLbl = makeLabel({ Size=UDim2.new(0.65,0,1,0), Position=UDim2.new(0,14,0,0),
	Text="🔄  LIVE TRADE", TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=17,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=152 }, lwTitle)
local lwStatusLbl = makeLabel({ Size=UDim2.new(0.33,0,1,0), Position=UDim2.new(0.65,0,0,0),
	Text="Select cards below", TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11,
	TextXAlignment=Enum.TextXAlignment.Right, ZIndex=152 }, lwTitle)

local HEADER_H = 48
local FOOTER_H = 54

local lwLeft = makeFrame({ Size=UDim2.new(0.52,-3,1,-(HEADER_H+FOOTER_H)), Position=UDim2.new(0,0,0,HEADER_H),
	BackgroundColor3=Color3.fromRGB(10,12,20), ZIndex=151 }, LiveWindow)
makeLabel({ Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,0),
	Text="YOUR INVENTORY — tap to offer (max 5)", TextColor3=TEXT_MUTED,
	Font=Enum.Font.GothamBold, TextSize=9, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=152 }, lwLeft)
local lwInvScroll = create("ScrollingFrame", { Size=UDim2.new(1,0,1,-22), Position=UDim2.new(0,0,0,22),
	BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=ACCENT,
	CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=152 }, lwLeft)
create("UIGridLayout", { CellSize=UDim2.new(0,80,0,112), CellPadding=UDim2.new(0,4,0,4),
	HorizontalAlignment=Enum.HorizontalAlignment.Center, SortOrder=Enum.SortOrder.LayoutOrder }, lwInvScroll)

local lwRight = makeFrame({ Size=UDim2.new(0.48,-3,1,-(HEADER_H+FOOTER_H)), Position=UDim2.new(0.52,3,0,HEADER_H),
	BackgroundTransparency=1, ZIndex=151 }, LiveWindow)

local lwYourOffer = makeFrame({ Size=UDim2.new(1,0,0.5,-4), Position=UDim2.new(0,0,0,0),
	BackgroundColor3=Color3.fromRGB(8,16,26), ZIndex=151 }, lwRight)
corner(10, lwYourOffer); stroke(ACCENT, 1.5, lwYourOffer).Transparency = 0.35
local lwYourHdr = makeFrame({ Size=UDim2.new(1,0,0,26), BackgroundColor3=Color3.fromRGB(0,38,70), ZIndex=152 }, lwYourOffer)
corner(10, lwYourHdr)
makeLabel({ Size=UDim2.new(0.55,0,1,0), Position=UDim2.new(0,8,0,0), Text="YOUR OFFER", TextColor3=ACCENT,
	Font=Enum.Font.GothamBold, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=153 }, lwYourHdr)
local lwYourValueLbl = makeLabel({ Size=UDim2.new(0.43,0,1,0), Position=UDim2.new(0.55,0,0,0), Text="0 Pucks",
	TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=10, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=153 }, lwYourHdr)
local lwYourScroll = create("ScrollingFrame", { Size=UDim2.new(1,-8,1,-30), Position=UDim2.new(0,4,0,28),
	BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=ACCENT,
	CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=152 }, lwYourOffer)
create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4) }, lwYourScroll)

local lwTheirOffer = makeFrame({ Size=UDim2.new(1,0,0.5,-4), Position=UDim2.new(0,0,0.5,4),
	BackgroundColor3=Color3.fromRGB(18,12,8), ZIndex=151 }, lwRight)
corner(10, lwTheirOffer); stroke(GOLD, 1.5, lwTheirOffer).Transparency = 0.35
local lwTheirHdr = makeFrame({ Size=UDim2.new(1,0,0,26), BackgroundColor3=Color3.fromRGB(38,26,0), ZIndex=152 }, lwTheirOffer)
corner(10, lwTheirHdr)
local lwTheirNameLbl = makeLabel({ Size=UDim2.new(0.55,0,1,0), Position=UDim2.new(0,8,0,0), Text="THEIR OFFER",
	TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=153 }, lwTheirHdr)
local lwTheirValueLbl = makeLabel({ Size=UDim2.new(0.43,0,1,0), Position=UDim2.new(0.55,0,0,0), Text="0 Pucks",
	TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=10, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=153 }, lwTheirHdr)
local lwTheirScroll = create("ScrollingFrame", { Size=UDim2.new(1,-8,1,-30), Position=UDim2.new(0,4,0,28),
	BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=GOLD,
	CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=152 }, lwTheirOffer)
create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4) }, lwTheirScroll)

local lwFooter = makeFrame({ Size=UDim2.new(1,0,0,FOOTER_H), Position=UDim2.new(0,0,1,-FOOTER_H),
	BackgroundColor3=Color3.fromRGB(10,12,20), ZIndex=151 }, LiveWindow)
stroke(Color3.fromRGB(35,40,60), 1, lwFooter)
create("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8), VerticalAlignment=Enum.VerticalAlignment.Center }, lwFooter)
create("UIPadding", { PaddingLeft=UDim.new(0,8), PaddingRight=UDim.new(0,8) }, lwFooter)

local lwAcceptBtn = makeButton({ Size=UDim2.new(0.58,0,0,38), BackgroundColor3=Color3.fromRGB(18,140,50),
	Text="✅  ACCEPT TRADE", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=14, ZIndex=152 }, lwFooter)
corner(9, lwAcceptBtn)
create("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(32,200,72),Color3.fromRGB(12,110,36)),Rotation=90},lwAcceptBtn)

local lwCancelBtn = makeButton({ Size=UDim2.new(0.40,0,0,38), BackgroundColor3=Color3.fromRGB(130,18,18),
	Text="✕  Cancel", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=13, ZIndex=152 }, lwFooter)
corner(9, lwCancelBtn)
stroke(ACCENT2, 1, lwCancelBtn).Transparency = 0.4

-- Offer row helper
local function makeOfferRow(parent, card, idx, onRemove)
	local rc  = rarityColor(card.Rarity)
	local cs  = cardStyle(card.Rarity)
	local row = makeFrame({ Size=UDim2.new(1,0,0,42),
		BackgroundColor3=Color3.fromRGB(math.clamp(math.floor(rc.R*255*0.06+10),0,255),math.clamp(math.floor(rc.G*255*0.06+10),0,255),math.clamp(math.floor(rc.B*255*0.06+12),0,255)),
		LayoutOrder=idx, ZIndex=153 }, parent)
	corner(7, row); stroke(rc, 1, row).Transparency = 0.5
	makeFrame({ Size=UDim2.new(0,3,1,0), BackgroundColor3=rc, ZIndex=154 }, row)
	makeLabel({ Size=UDim2.new(0,14,1,0), Position=UDim2.new(0,5,0,0), Text=cs.badge, TextSize=10, ZIndex=154 }, row)
	makeLabel({ Size=UDim2.new(0.5,0,0,17), Position=UDim2.new(0,21,0,4), Text=card.PlayerName, TextColor3=TEXT_WHITE,
		Font=Enum.Font.GothamBold, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=154 }, row)
	makeLabel({ Size=UDim2.new(0.5,0,0,13), Position=UDim2.new(0,21,0,22),
		Text=card.Rarity.."  OVR "..tostring(card.OVR or "?"), TextColor3=rc,
		Font=Enum.Font.Gotham, TextSize=9, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=154 }, row)
	makeLabel({ Size=UDim2.new(0.25,0,1,0), Position=UDim2.new(0.72,0,0,0),
		Text=tostring(math.floor(card.Value or 0)).."P", TextColor3=GOLD,
		Font=Enum.Font.GothamBold, TextSize=11, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=154 }, row)
	if onRemove then
		local xBtn = makeButton({ Size=UDim2.new(0,22,0,22), Position=UDim2.new(1,-26,0.5,-11),
			BackgroundColor3=Color3.fromRGB(130,18,18), Text="✕", TextColor3=TEXT_WHITE,
			Font=Enum.Font.GothamBold, TextSize=9, ZIndex=155 }, row)
		corner(4, xBtn)
		xBtn.MouseButton1Click:Connect(onRemove)
	end
end

-- Refresh functions
refreshLiveMyCards = function()
	for _, c in ipairs(lwYourScroll:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
	local total = 0
	if #myTradeCards == 0 then
		makeLabel({ Size=UDim2.new(1,0,0,34), Text="Tap cards on the left to add",
			TextColor3=TEXT_DIM, Font=Enum.Font.Gotham, TextSize=11, ZIndex=153 }, lwYourScroll)
	else
		for i, card in ipairs(myTradeCards) do
			total += math.floor(card.Value or 0)
			makeOfferRow(lwYourScroll, card, i, function()
				table.remove(myTradeCards, i)
				if iHaveConfirmed and tradeSessionId then
					iHaveConfirmed = false; TradeUnconfirm:FireServer(tradeSessionId)
				end
				local ids = {}
				for _, c2 in ipairs(myTradeCards) do table.insert(ids, c2.CardId) end
				if tradeSessionId then TradeOfferUpdate:FireServer(tradeSessionId, ids) end
				refreshLiveMyCards(); refreshLiveInventory(); refreshLiveConfirmStatus()
			end)
		end
	end
	lwYourValueLbl.Text = tostring(total).." Pucks"
end

refreshLiveTheirCards = function()
	for _, c in ipairs(lwTheirScroll:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
	local total = 0
	if #theirTradeCards == 0 then
		makeLabel({ Size=UDim2.new(1,0,0,34),
			Text=tradePartnerName and ("Waiting for "..tradePartnerName.."…") or "Waiting…",
			TextColor3=TEXT_DIM, Font=Enum.Font.Gotham, TextSize=11, ZIndex=153 }, lwTheirScroll)
	else
		for i, card in ipairs(theirTradeCards) do
			total += math.floor(card.Value or 0)
			makeOfferRow(lwTheirScroll, card, i, nil)
		end
	end
	lwTheirValueLbl.Text = tostring(total).." Pucks"
	if tradePartnerName then lwTheirNameLbl.Text = tradePartnerName:upper().."'S OFFER" end
end

refreshLiveConfirmStatus = function()
	local myTick    = iHaveConfirmed    and "✅" or "○"
	local theirTick = theyHaveConfirmed and "✅" or "○"
	local partner   = tradePartnerName or "Other"
	lwStatusLbl.Text = "You "..myTick.."  "..partner.." "..theirTick
	if iHaveConfirmed then
		lwAcceptBtn.Text             = "⏳ Waiting for "..partner.."…"
		lwAcceptBtn.BackgroundColor3 = Color3.fromRGB(40,40,55)
	else
		lwAcceptBtn.Text             = "✅  ACCEPT TRADE"
		lwAcceptBtn.BackgroundColor3 = Color3.fromRGB(18,140,50)
	end
end

refreshLiveInventory = function()
	for _, c in ipairs(lwInvScroll:GetChildren()) do if not c:IsA("UIGridLayout") then c:Destroy() end end
	local inv = LocalData.Inventory or {}
	for i, card in ipairs(inv) do
		local alreadyIn = false
		for _, mc in ipairs(myTradeCards) do if mc.CardId == card.CardId then alreadyIn = true break end end
		local w = makeCardWidget(lwInvScroll, card, {})
		w.LayoutOrder = i
		if alreadyIn then w.BackgroundTransparency = 0.55 end
		w.MouseButton1Click:Connect(function()
			for j, mc in ipairs(myTradeCards) do
				if mc.CardId == card.CardId then
					table.remove(myTradeCards, j)
					if iHaveConfirmed and tradeSessionId then iHaveConfirmed = false; TradeUnconfirm:FireServer(tradeSessionId) end
					local ids = {}
					for _, c2 in ipairs(myTradeCards) do table.insert(ids, c2.CardId) end
					if tradeSessionId then TradeOfferUpdate:FireServer(tradeSessionId, ids) end
					refreshLiveMyCards(); refreshLiveInventory(); refreshLiveConfirmStatus()
					return
				end
			end
			if #myTradeCards >= 5 then showToast("Max 5 cards per offer.", ACCENT2); return end
			if card.Locked then showToast("Unlock this card before trading.", Color3.fromRGB(255,210,50)); return end
			table.insert(myTradeCards, card)
			if iHaveConfirmed and tradeSessionId then iHaveConfirmed = false; TradeUnconfirm:FireServer(tradeSessionId) end
			local ids = {}
			for _, c2 in ipairs(myTradeCards) do table.insert(ids, c2.CardId) end
			if tradeSessionId then TradeOfferUpdate:FireServer(tradeSessionId, ids) end
			refreshLiveMyCards(); refreshLiveInventory(); refreshLiveConfirmStatus()
		end)
	end
end

local function openLiveWindow(sessionId, partnerName)
	tradeSessionId = sessionId; tradePartnerName = partnerName
	myTradeCards = {}; theirTradeCards = {}
	iHaveConfirmed = false; theyHaveConfirmed = false
	lwTitleLbl.Text = "🔄  LIVE TRADE  —  "..(partnerName or "?")
	refreshLiveInventory(); refreshLiveMyCards(); refreshLiveTheirCards(); refreshLiveConfirmStatus()
	LiveWindow.Visible = true
end

closeLiveWindow = function()
	LiveWindow.Visible = false
	tradeSessionId = nil; tradePartnerName = nil
	myTradeCards = {}; theirTradeCards = {}
	iHaveConfirmed = false; theyHaveConfirmed = false
end

lwAcceptBtn.MouseButton1Click:Connect(function()
	if not tradeSessionId then return end
	if iHaveConfirmed then
		iHaveConfirmed = false; TradeUnconfirm:FireServer(tradeSessionId); refreshLiveConfirmStatus()
	else
		iHaveConfirmed = true; TradeConfirm:FireServer(tradeSessionId); refreshLiveConfirmStatus()
	end
end)

lwCancelBtn.MouseButton1Click:Connect(function()
	if tradeSessionId then CancelTradeEv:FireServer(tradeSessionId) end
	closeLiveWindow()
	showToast("Trade cancelled.", TEXT_MUTED)
end)

-- Phase remote handlers
TradeSessionOpen.OnClientEvent:Connect(function(info)
	openLiveWindow(info.SessionId, info.PartnerName)
end)

TradeOfferRecv.OnClientEvent:Connect(function(cards)
	theirTradeCards = cards or {}
	refreshLiveTheirCards()
end)

TradeConfirmStatus.OnClientEvent:Connect(function(status)
	theyHaveConfirmed = (status.InitiatorConfirmed or false) or (status.TargetConfirmed or false)
	if status.InitiatorConfirmed and status.TargetConfirmed then
		lwStatusLbl.Text = "✅ Both accepted! Completing…"
	else
		refreshLiveConfirmStatus()
	end
end)

TradeCompleted.OnClientEvent:Connect(function()
	closeLiveWindow()
	showToast("✅ Trade complete! Cards transferred.", GREEN)
end)

TradeCancelled.OnClientEvent:Connect(function()
	closeLiveWindow()
	RequestPopup.Visible = false
	showToast("Trade was cancelled.", TEXT_MUTED)
end)

-- Legacy compat
TradeIncoming.OnClientEvent:Connect(function(info)
	pendingRequestInitiatorId = info.InitiatorId
	reqPopupFrom.Text = (info.InitiatorName or "Someone").." wants to trade with you"
	RequestPopup.Visible = true
end)

TradeBothConfirmed.OnClientEvent:Connect(function() end)

-- ── MAIN TRADE SCREEN ─────────────────────────────────────────
local function buildTradeScreen()
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,12) }, TradeScreen)
	sectionHeader("TRADE CARDS", TradeScreen, 0)

	local statusCard = makeFrame({ Size=UDim2.new(1,0,0,70), BackgroundColor3=PANEL_BG, LayoutOrder=1 }, TradeScreen)
	corner(12, statusCard); stroke(ACCENT, 1, statusCard).Transparency = 0.6
	create("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(0,50,90),Color3.fromRGB(12,16,26)),Rotation=90},statusCard)
	makeLabel({ Size=UDim2.new(1,-16,0,26), Position=UDim2.new(0,12,0,8), Text="🔄  How Trading Works",
		TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left }, statusCard)
	makeLabel({ Size=UDim2.new(1,-16,0,28), Position=UDim2.new(0,12,0,36),
		Text="Pick a player → they accept → both choose cards in real time → both confirm.",
		TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left }, statusCard)

	local openPickerBtn = makeButton({ Size=UDim2.new(1,0,0,56), BackgroundColor3=Color3.fromRGB(120,78,0),
		Text="👥  Find a Player to Trade With", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=15, LayoutOrder=2 }, TradeScreen)
	corner(12, openPickerBtn)
	create("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(195,135,12),Color3.fromRGB(100,58,0)),Rotation=90},openPickerBtn)
	openPickerBtn.MouseButton1Click:Connect(function()
		PlayerPickerPopup.Visible = true
		task.spawn(refreshPlayerPicker)
	end)

	makeLabel({ Size=UDim2.new(1,0,0,40), LayoutOrder=3,
		Text="Once the other player accepts, a live trade window opens where you both pick cards in real time.",
		TextColor3=TEXT_DIM, Font=Enum.Font.Gotham, TextSize=11, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left }, TradeScreen)

	_G.RefreshTradeInventory = function()
		if LiveWindow.Visible then refreshLiveInventory() end
	end
end

-- ══════════════════════════════════════════════════════════════
-- SCREEN: LEADERBOARD
-- ══════════════════════════════════════════════════════════════
local LeaderboardScreen = newScreen("Leaderboard")
local lbRows = { value={}, pucks={} }

local function buildLeaderboardScreen()
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8) }, LeaderboardScreen)

	local headerRow = makeFrame({ Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=0 }, LeaderboardScreen)
	create("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, VerticalAlignment=Enum.VerticalAlignment.Center,
		SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8) }, headerRow)
	local leftHeader = makeFrame({ Size=UDim2.new(0.5,-4,1,0), BackgroundTransparency=1, LayoutOrder=1 }, headerRow)
	makeLabel({ Size=UDim2.new(1,0,1,0), Text="🪙 INVENTORY VALUE", TextColor3=GOLD, Font=Enum.Font.GothamBold,
		TextSize=11, TextXAlignment=Enum.TextXAlignment.Center }, leftHeader)
	local rightHeader = makeFrame({ Size=UDim2.new(0.5,-4,1,0), BackgroundTransparency=1, LayoutOrder=2 }, headerRow)
	makeLabel({ Size=UDim2.new(1,0,1,0), Text="💰 MOST PUCKS", TextColor3=Color3.fromRGB(100,220,255),
		Font=Enum.Font.GothamBold, TextSize=11, TextXAlignment=Enum.TextXAlignment.Center }, rightHeader)

	local columnsFrame
	local function buildColumn(side, layoutOrder, scoreColor)
		local col = makeFrame({ Size=UDim2.new(0.5,-4,0,10), AutomaticSize=Enum.AutomaticSize.Y,
			BackgroundTransparency=1, LayoutOrder=layoutOrder }, columnsFrame)
		create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,5) }, col)
		for i = 1, 10 do
			local rankColor = i==1 and GOLD or i==2 and Color3.fromRGB(200,200,200) or i==3 and Color3.fromRGB(180,120,50) or TEXT_DIM
			local row = makeFrame({ Size=UDim2.new(1,0,0,50), BackgroundColor3=PANEL_BG, LayoutOrder=i }, col)
			corner(8, row)
			if i == 1 then stroke(scoreColor, 1.5, row) end
			makeLabel({ Size=UDim2.new(1,0,0,18), Position=UDim2.new(0,0,0,4), Text="#"..tostring(i),
				TextColor3=rankColor, Font=Enum.Font.GothamBold, TextSize=12 }, row)
			local nameL  = makeLabel({ Size=UDim2.new(1,-8,0,18), Position=UDim2.new(0,4,0,22), Text="—",
				TextColor3=TEXT_WHITE, Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left }, row)
			local scoreL = makeLabel({ Size=UDim2.new(1,-8,0,14), Position=UDim2.new(0,4,0,36), Text="—",
				TextColor3=scoreColor, Font=Enum.Font.GothamBold, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left }, row)
			lbRows[side][i] = { name=nameL, score=scoreL }
		end
		return col
	end

	columnsFrame = makeFrame({ Size=UDim2.new(1,0,0,10), AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundTransparency=1, LayoutOrder=1 }, LeaderboardScreen)
	create("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, VerticalAlignment=Enum.VerticalAlignment.Top,
		SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8) }, columnsFrame)
	buildColumn("value", 1, GOLD)
	buildColumn("pucks", 2, Color3.fromRGB(100,220,255))
end

function refreshLeaderboard(valueData, packsData)
	local function fill(side, data, suffix)
		for i = 1, 10 do
			local row   = lbRows[side][i]
			local entry = data and data[i]
			if row then
				row.name.Text = entry and entry.Name or "—"
				if entry then
					row.score.Text = suffix == nil and ("$"..tostring(entry.Score)) or (tostring(entry.Score)..suffix)
				else
					row.score.Text = "—"
				end
			end
		end
	end
	fill("value", valueData, nil)
	fill("pucks",  packsData,  " Pucks")
end

-- ══════════════════════════════════════════════════════════════
-- SCREEN: QUESTS
-- ══════════════════════════════════════════════════════════════
local QuestScreen = newScreen("Quests")
local questEls = {}

local function buildQuestScreen()
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8) }, QuestScreen)
	sectionHeader("DAILY QUESTS", QuestScreen, 0)
	for i = 1, 3 do
		local card = makeFrame({ Size=UDim2.new(1,0,0,74), BackgroundColor3=PANEL_BG, LayoutOrder=i }, QuestScreen)
		corner(10, card)
		local titleL = makeLabel({ Size=UDim2.new(1,-14,0,22), Position=UDim2.new(0,7,0,6), Text="Quest "..i,
			TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left }, card)
		local barBg  = makeFrame({ Size=UDim2.new(1,-14,0,8), Position=UDim2.new(0,7,0,32), BackgroundColor3=PANEL_BG2 }, card)
		corner(4, barBg)
		local barFill= makeFrame({ Size=UDim2.new(0,0,1,0), BackgroundColor3=ACCENT }, barBg)
		corner(4, barFill)
		local progL  = makeLabel({ Size=UDim2.new(0.5,-8,0,18), Position=UDim2.new(0,7,0,48), Text="0/10",
			TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left }, card)
		local rewL   = makeLabel({ Size=UDim2.new(0.5,-14,0,18), Position=UDim2.new(0.5,0,0,48), Text="300 Pucks",
			TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=11, TextXAlignment=Enum.TextXAlignment.Right }, card)
		questEls[i] = { title=titleL, bar=barFill, prog=progL, reward=rewL }
	end
	sectionHeader("WEEKLY QUESTS", QuestScreen, 5)
	for i = 1, 3 do
		local wCard = makeFrame({ Size=UDim2.new(1,0,0,74), BackgroundColor3=PANEL_BG, LayoutOrder=5+i }, QuestScreen)
		corner(10, wCard); stroke(GOLD, 1, wCard)
		local wTitle = makeLabel({ Size=UDim2.new(1,-14,0,22), Position=UDim2.new(0,7,0,6), Text="Weekly Quest "..i,
			TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left }, wCard)
		local wBarBg = makeFrame({ Size=UDim2.new(1,-14,0,8), Position=UDim2.new(0,7,0,32), BackgroundColor3=PANEL_BG2 }, wCard)
		corner(4, wBarBg)
		local wFill = makeFrame({ Size=UDim2.new(0,0,1,0), BackgroundColor3=GOLD }, wBarBg)
		corner(4, wFill)
		local wProg = makeLabel({ Size=UDim2.new(0.5,-8,0,18), Position=UDim2.new(0,7,0,48), Text="0/100",
			TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left }, wCard)
		local wRew = makeLabel({ Size=UDim2.new(0.5,0,0,18), Position=UDim2.new(0.5,0,0,48), Text="",
			TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=11, TextXAlignment=Enum.TextXAlignment.Right }, wCard)
		questEls["weekly"..i] = { title=wTitle, bar=wFill, prog=wProg, reward=wRew }
	end
end

local function refreshQuests()
	local quests = LocalData.DailyQuestsAssigned or {}
	local prog   = LocalData.DailyQuestProgress  or {}
	for i = 1, 3 do
		local el = questEls[i]; local q = quests[i]
		if el and q then
			local p = prog[q.Id] or 0; local pct = math.min(p/math.max(q.Target,1),1)
			el.title.Text = (p>=q.Target and "✅ " or "")..q.Desc
			el.title.TextColor3 = p>=q.Target and GREEN or TEXT_WHITE
			el.prog.Text = p.." / "..q.Target; el.reward.Text = tostring(q.PuckReward).." Pucks"
			TweenService:Create(el.bar, TweenInfo.new(0.4), { Size=UDim2.new(pct,0,1,0) }):Play()
		elseif el then el.title.Text="—"; el.prog.Text=""; el.reward.Text="" end
	end
	local weeklyQuests = type(LocalData.WeeklyQuestsAssigned)=="table" and LocalData.WeeklyQuestsAssigned or {}
	local wqP = LocalData.WeeklyQuestProgress or {}
	for i = 1, 3 do
		local el = questEls["weekly"..i]; local wq = weeklyQuests[i]
		if el and wq then
			local p = wqP[wq.Id] or 0; local pct = math.min(p/math.max(wq.Target,1),1)
			el.title.Text = (p>=wq.Target and "✅ " or "")..wq.Desc
			el.title.TextColor3 = p>=wq.Target and GREEN or GOLD
			el.prog.Text = p.." / "..wq.Target
			el.reward.Text = tostring(wq.PuckReward).." Pucks"..((wq.GemReward and wq.GemReward>0) and (" +"..wq.GemReward.." 💎") or "")
			TweenService:Create(el.bar, TweenInfo.new(0.4), { Size=UDim2.new(pct,0,1,0) }):Play()
		elseif el then el.title.Text="—"; el.prog.Text=""; el.reward.Text="" end
	end
end

-- ══════════════════════════════════════════════════════════════
-- SCREEN: PROFILE
-- ══════════════════════════════════════════════════════════════
local ProfileScreen = newScreen("Profile")
local profileEls = {}

local function buildProfileScreen()
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10) }, ProfileScreen)

	local header = makeFrame({ Size=UDim2.new(1,0,0,54), BackgroundTransparency=1, LayoutOrder=0 }, ProfileScreen)
	local avatarF = makeFrame({ Size=UDim2.new(0,48,0,48), Position=UDim2.new(0,0,0,3), BackgroundColor3=ACCENT }, header)
	corner(24, avatarF)
	profileEls.avatar = makeLabel({ Size=UDim2.new(1,0,1,0), Text="?", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=18 }, avatarF)
	profileEls.name   = makeLabel({ Size=UDim2.new(0.7,0,0.45,0), Position=UDim2.new(0,58,0,4), Text="Loading…",
		TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=16, TextXAlignment=Enum.TextXAlignment.Left }, header)
	profileEls.badge  = makeLabel({ Size=UDim2.new(0.7,0,0.4,0), Position=UDim2.new(0,58,0.54,0), Text="",
		TextColor3=GOLD, Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left }, header)

	local statGrid = makeFrame({ Size=UDim2.new(1,0,0,80), BackgroundTransparency=1, LayoutOrder=1 }, ProfileScreen)
	create("UIGridLayout", { CellSize=UDim2.new(0.3,0,0,70), CellPadding=UDim2.new(0.03,0,0,8), SortOrder=Enum.SortOrder.LayoutOrder }, statGrid)
	local statDefs = {
		{ Key="TotalPacksOpened",Lbl="Packs" }, { Key="TotalCardsSold",Lbl="Sold" },
		{ Key="TotalTradesDone",Lbl="Trades" }, { Key="LoginStreak",Lbl="Streak" },
		{ Key="CollectionCount",Lbl="Cards" },  { Key="PrestigeLevel",Lbl="Prestige" },
	}
	profileEls.stats = {}
	for i, sd in ipairs(statDefs) do
		local cell = makeFrame({ BackgroundColor3=PANEL_BG, LayoutOrder=i }, statGrid)
		corner(8, cell)
		local valL = makeLabel({ Size=UDim2.new(1,0,0.55,0), Position=UDim2.new(0,0,0.04,0), Text="0",
			TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=22 }, cell)
		makeLabel({ Size=UDim2.new(1,-4,0.3,0), Position=UDim2.new(0,2,0.62,0), Text=sd.Lbl,
			TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=11, TextWrapped=true }, cell)
		profileEls.stats[sd.Key] = valL
	end

	local luckSect = makeFrame({ Size=UDim2.new(1,0,0,54), BackgroundColor3=PANEL_BG, LayoutOrder=2 }, ProfileScreen)
	corner(10, luckSect)
	profileEls.luckTitle = makeLabel({ Size=UDim2.new(0.6,0,0.42,0), Position=UDim2.new(0,10,0,6), Text="Luck 0/10",
		TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left }, luckSect)
	profileEls.luckMult  = makeLabel({ Size=UDim2.new(0.35,0,0.42,0), Position=UDim2.new(0.63,0,0,6), Text="+0%",
		TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Right }, luckSect)
	local luckBarBg = makeFrame({ Size=UDim2.new(1,-20,0,10), Position=UDim2.new(0,10,0,36), BackgroundColor3=PANEL_BG2 }, luckSect)
	corner(5, luckBarBg)
	profileEls.luckBar = makeFrame({ Size=UDim2.new(0,0,1,0), BackgroundColor3=GREEN }, luckBarBg)
	corner(5, profileEls.luckBar)

	local btnRow = makeFrame({ Size=UDim2.new(1,0,0,42), BackgroundTransparency=1, LayoutOrder=3 }, ProfileScreen)
	create("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8), VerticalAlignment=Enum.VerticalAlignment.Center }, btnRow)
	local upgBtn = makeButton({ Size=UDim2.new(0.47,0,1,0), BackgroundColor3=ACCENT,
		Text="▲ Upgrade Luck", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=13 }, btnRow)
	corner(8, upgBtn)
	upgBtn.MouseButton1Click:Connect(function()
		local res = UpgradeLuckFn:InvokeServer()
		if res and res.Success then showToast("Luck → Level "..res.NewLevel.."!", GREEN)
		else showToast(res and res.Error or "Cannot upgrade", ACCENT2) end
	end)
	local prestBtn = makeButton({ Size=UDim2.new(0.47,0,1,0), BackgroundColor3=Color3.fromRGB(80,20,110),
		Text="⭐ Prestige", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=13 }, btnRow)
	corner(8, prestBtn)
	prestBtn.MouseButton1Click:Connect(function()
		local res = PrestigeFn:InvokeServer()
		if res and res.Success then showToast("Prestige "..res.NewPrestige.." — "..res.Badge.." badge!", GOLD)
		else showToast(res and res.Error or "Cannot prestige", ACCENT2) end
	end)

	sectionHeader("PRESTIGE TIERS", ProfileScreen, 3.5)
	local tierData = {
		{ level=0,badge="None",    cost="Starting",  bonus="+0%",  color=Color3.fromRGB(150,150,150) },
		{ level=1,badge="Bronze",  cost="100K Pucks", bonus="+5%",  color=Color3.fromRGB(180,120,50)  },
		{ level=2,badge="Silver",  cost="250K Pucks", bonus="+10%", color=Color3.fromRGB(180,180,180) },
		{ level=3,badge="Gold",    cost="600K Pucks", bonus="+20%", color=Color3.fromRGB(221,170,30)  },
		{ level=4,badge="Platinum",cost="1.5M Pucks", bonus="+35%", color=Color3.fromRGB(100,180,255) },
		{ level=5,badge="Diamond", cost="4M Pucks",   bonus="+55%", color=Color3.fromRGB(180,130,255) },
	}
	local tierPanel = makeFrame({ Size=UDim2.new(1,0,0,10), AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundColor3=PANEL_BG, LayoutOrder=4 }, ProfileScreen)
	corner(12, tierPanel)
	create("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,0) }, tierPanel)
	for i, t in ipairs(tierData) do
		local prestigeLevel = LocalData.PrestigeLevel or 0
		local isCurrent     = prestigeLevel == t.level
		local isCompleted   = prestigeLevel > t.level
		local row = makeFrame({ Size=UDim2.new(1,0,0,44),
			BackgroundColor3=(isCurrent or isCompleted) and PANEL_BG2 or PANEL_BG, LayoutOrder=i }, tierPanel)
		if i==1 then corner(12,row) end
		local dot = makeFrame({ Size=UDim2.new(0,28,0,28), Position=UDim2.new(0,10,0.5,-14), BackgroundColor3=t.color }, row)
		corner(14, dot)
		makeLabel({ Size=UDim2.new(1,0,1,0), Text=tostring(t.level), TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=13 }, dot)
		makeLabel({ Size=UDim2.new(0.35,0,0,18), Position=UDim2.new(0,46,0,8),
			Text=t.badge..(isCurrent and " ★" or isCompleted and " ✓" or ""),
			TextColor3=(isCurrent or isCompleted) and t.color or TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left }, row)
		makeLabel({ Size=UDim2.new(0.3,0,0,14), Position=UDim2.new(0,46,0,28), Text="Luck "..t.bonus,
			TextColor3=GREEN, Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left }, row)
		makeLabel({ Size=UDim2.new(0.32,0,1,0), Position=UDim2.new(0.66,0,0,0),
			Text=isCompleted and "Completed" or t.cost,
			TextColor3=isCompleted and GREEN or isCurrent and TEXT_DIM or GOLD,
			Font=Enum.Font.GothamBold, TextSize=12, TextXAlignment=Enum.TextXAlignment.Right }, row)
		if i < #tierData then
			makeFrame({ Size=UDim2.new(1,-16,0,1), Position=UDim2.new(0,8,1,-1), BackgroundColor3=PANEL_BG2, LayoutOrder=i }, row)
		end
	end

	sectionHeader("SHOWCASE CARDS", ProfileScreen, 4)
	local showcaseRow = makeFrame({ Size=UDim2.new(1,0,0,140), BackgroundTransparency=1, LayoutOrder=5 }, ProfileScreen)
	create("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8), VerticalAlignment=Enum.VerticalAlignment.Center }, showcaseRow)
	profileEls.showcaseRow = showcaseRow
end

local function refreshProfile()
	local data = LocalData
	local name = LocalPlayer.Name
	if profileEls.avatar then profileEls.avatar.Text = name:sub(1,1):upper() end
	if profileEls.name   then profileEls.name.Text   = name end
	local tier = (CardDatabase.PrestigeTiers[data.PrestigeLevel or 0] or { Badge="None" })
	if profileEls.badge  then profileEls.badge.Text = "Prestige "..(data.PrestigeLevel or 0).." · "..tier.Badge end

	local statVals = { TotalPacksOpened=data.TotalPacksOpened, TotalCardsSold=data.TotalCardsSold,
		TotalTradesDone=data.TotalTradesDone, LoginStreak=data.LoginStreak,
		CollectionCount=data.CollectionCount, PrestigeLevel=data.PrestigeLevel }
	for k, lbl in pairs(profileEls.stats or {}) do lbl.Text = tostring(statVals[k] or 0) end

	local lv = data.LuckLevel or 0
	local lt = CardDatabase.LuckTiers[lv] or { Multiplier=1.0 }
	if profileEls.luckTitle then profileEls.luckTitle.Text = "Luck Level "..lv.."/10" end
	if profileEls.luckMult  then profileEls.luckMult.Text  = "+"..math.floor((lt.Multiplier-1)*100).."%" end
	if profileEls.luckBar   then TweenService:Create(profileEls.luckBar, TweenInfo.new(0.5), { Size=UDim2.new(lv/10,0,1,0) }):Play() end

	if profileEls.showcaseRow then
		for _, c in ipairs(profileEls.showcaseRow:GetChildren()) do
			if not c:IsA("UIListLayout") then c:Destroy() end
		end
		local inv = data.Inventory or {}
		for _, cardId in ipairs(data.ShowcaseCards or {}) do
			for _, card in ipairs(inv) do
				if card.CardId == cardId then
					local w = makeCardWidget(profileEls.showcaseRow, card, {})
					w.Size = UDim2.new(0,92,0,130)
					break
				end
			end
		end
		local have = #(data.ShowcaseCards or {})
		for _ = have+1, 5 do
			local slot = makeFrame({ Size=UDim2.new(0,92,0,130), BackgroundColor3=PANEL_BG }, profileEls.showcaseRow)
			corner(10, slot); stroke(TEXT_DIM, 1, slot)
			makeLabel({ Size=UDim2.new(1,0,1,0), Text="+", TextColor3=TEXT_DIM, Font=Enum.Font.GothamBold, TextSize=22 }, slot)
		end
	end
end

-- ══════════════════════════════════════════════════════════════
-- LOGIN CALENDAR POPUP
-- ══════════════════════════════════════════════════════════════
local LoginPopup = makeFrame({ Size=UDim2.new(0.85,0,0,220), Position=UDim2.new(0.075,0,0.25,0),
	BackgroundColor3=PANEL_BG2, Visible=false, ZIndex=85 }, ScreenGui)
corner(14, LoginPopup); stroke(GOLD, 1.5, LoginPopup)
makeLabel({ Size=UDim2.new(1,0,0,36), Position=UDim2.new(0,0,0,6), Text="🎁 Daily Login Reward!",
	TextColor3=GOLD, Font=Enum.Font.GothamBold, TextSize=17, ZIndex=86 }, LoginPopup)
local loginRewardLbl = makeLabel({ Size=UDim2.new(1,-16,0,28), Position=UDim2.new(0,8,0,48), Text="",
	TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=15, ZIndex=86 }, LoginPopup)
local loginDayLbl    = makeLabel({ Size=UDim2.new(1,0,0,22), Position=UDim2.new(0,0,0,80), Text="",
	TextColor3=TEXT_MUTED, Font=Enum.Font.Gotham, TextSize=12, ZIndex=86 }, LoginPopup)
local loginStreakLbl  = makeLabel({ Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,106), Text="",
	TextColor3=GREEN, Font=Enum.Font.GothamBold, TextSize=12, ZIndex=86 }, LoginPopup)
local loginClaimBtn  = makeButton({ Size=UDim2.new(0.7,0,0,42), Position=UDim2.new(0.15,0,0,140),
	BackgroundColor3=ACCENT, Text="Claim Reward!", TextColor3=TEXT_WHITE, Font=Enum.Font.GothamBold, TextSize=15, ZIndex=87 }, LoginPopup)
corner(10, loginClaimBtn)

LoginRewardReady.OnClientEvent:Connect(function()
	local streak = (LocalData.LoginStreak or 0)
	local calDay = (streak % 30) + 1
	local reward = CardDatabase.LoginRewards[calDay] or { Pucks=100, Gems=0 }
	loginRewardLbl.Text = "+"..tostring(reward.Pucks).." Pucks"..(reward.Gems>0 and "  +  "..reward.Gems.." 💎" or "")
	loginDayLbl.Text    = "Day "..calDay.." of 30"
	loginStreakLbl.Text = "🔥 Login streak: "..streak.." days"
	LoginPopup.Visible  = true
end)

loginClaimBtn.MouseButton1Click:Connect(function()
	local res = ClaimLoginFn:InvokeServer()
	LoginPopup.Visible = false
	if res and res.Success then showToast("Reward claimed! +"..(res.Reward.Pucks or 0).." Pucks!", GOLD) end
end)

-- ══════════════════════════════════════════════════════════════
-- ACHIEVEMENT NOTIFICATION
-- ══════════════════════════════════════════════════════════════
AchievementEarned.OnClientEvent:Connect(function(ach)
	if ach then showToast("🏅 "..ach.Name.."! +"..(ach.PuckReward or 0).." Pucks", GOLD) end
end)

-- ══════════════════════════════════════════════════════════════
-- DATA SYNC
-- ══════════════════════════════════════════════════════════════
DataSync.OnClientEvent:Connect(function(data)
	LocalData = data
	PucksLabel.Text = tostring(data.Pucks or 0)
	GemsLabel.Text  = "💎 "..tostring(data.Gems or 0)
	refreshInventory()
	refreshProfile()
	refreshQuests()
	refreshIndex()
	if _G.RefreshTradeInventory then _G.RefreshTradeInventory() end
end)

-- ══════════════════════════════════════════════════════════════
-- BUILD ALL SCREENS & SET DEFAULT
-- ══════════════════════════════════════════════════════════════
buildShopScreen()
buildOpenScreen()
buildInventoryScreen()
buildIndexScreen()
buildTradeScreen()
buildLeaderboardScreen()
buildQuestScreen()
buildProfileScreen()

switchScreen("Shop")

print("[UISystem] NHL Pack Opening RNG — Client UI loaded.")