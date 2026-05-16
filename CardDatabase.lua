-- CardDatabase.lua
-- Location: ReplicatedStorage/Modules/CardDatabase
-- All card definitions, rarity config, pack definitions, and static game data.
-- This module is shared between server and client (required from both sides).

local CardDatabase = {}

-- ──────────────────────────────────────────────────────────────
-- RARITY DEFINITIONS
-- ──────────────────────────────────────────────────────────────
CardDatabase.Rarities = {
	Common = {
		Name          = "Common",
		Color         = Color3.fromRGB(180, 180, 180),
		ParticleCount = 0,
		SoundId       = "rbxassetid://6042053626",
		GlowIntensity = 0,
		OVRMin        = 60,
		OVRMax        = 68,
		BaseValue     = 50,
	},
	Rare = {
		Name          = "Rare",
		Color         = Color3.fromRGB(55, 138, 221),
		ParticleCount = 10,
		SoundId       = "rbxassetid://6042053626",
		GlowIntensity = 0.3,
		OVRMin        = 69,
		OVRMax        = 77,
		BaseValue     = 200,
	},
	Epic = {
		Name          = "Epic",
		Color         = Color3.fromRGB(127, 119, 221),
		ParticleCount = 30,
		SoundId       = "rbxassetid://126941244422484",
		GlowIntensity = 0.6,
		OVRMin        = 78,
		OVRMax        = 85,
		BaseValue     = 800,
	},
	Legendary = {
		Name          = "Legendary",
		Color         = Color3.fromRGB(221, 170, 30),
		ParticleCount = 60,
		SoundId       = "rbxassetid://126941244422484",
		GlowIntensity = 1.0,
		OVRMin        = 86,
		OVRMax        = 92,
		BaseValue     = 5000,
	},
	Mythic = {
		Name          = "Mythic",
		Color         = Color3.fromRGB(212, 83, 180),
		ParticleCount = 120,
		SoundId       = "rbxassetid://126941244422484",
		GlowIntensity = 1.5,
		OVRMin        = 93,
		OVRMax        = 97,
		BaseValue     = 25000,
	},
	Secret = {
		Name          = "Secret",
		Color         = Color3.fromRGB(230, 120, 30),
		ParticleCount = 200,
		SoundId       = "rbxassetid://126941244422484",
		GlowIntensity = 2.0,
		OVRMin        = 98,
		OVRMax        = 99,
		BaseValue     = 150000,
	},
	Limited = {
		Name          = "Limited",
		Color         = Color3.fromRGB(30, 200, 120),
		ParticleCount = 80,
		SoundId       = "rbxassetid://126941244422484",
		GlowIntensity = 1.2,
		OVRMin        = 90,
		OVRMax        = 96,
		BaseValue     = 75000,
	},
	EventExclusive = {
		Name          = "Event Exclusive",
		Color         = Color3.fromRGB(29, 210, 210),
		ParticleCount = 150,
		SoundId       = "rbxassetid://126941244422484",
		GlowIntensity = 1.8,
		OVRMin        = 94,
		OVRMax        = 99,
		BaseValue     = 50000,
	},
}

-- Deterministic rarity order for weighted rolls (highest → lowest priority)
CardDatabase.RarityOrder = {
	"EventExclusive", "Secret", "Limited", "Mythic",
	"Legendary", "Epic", "Rare", "Common"
}

-- Rarity rank (used for comparisons everywhere)
CardDatabase.RarityRank = {
	Common        = 1,
	Rare          = 2,
	Epic          = 3,
	Legendary     = 4,
	Mythic        = 5,
	Secret        = 6,
	Limited       = 7,
	EventExclusive= 8,
}

-- ──────────────────────────────────────────────────────────────
-- CARD VARIANTS
-- ──────────────────────────────────────────────────────────────
CardDatabase.Variants = {
	"Base", "Shiny", "Holographic", "Rainbow", "Animated", "Signed"
}

CardDatabase.VariantMultiplier = {
	Base        = 1.0,
	Shiny       = 1.5,
	Holographic = 2.5,
	Rainbow     = 4.0,
	Animated    = 6.0,
	Signed      = 10.0,
}

-- Variant pull weights (out of 1000)
CardDatabase.VariantWeights = {
	Base        = 600,
	Shiny       = 200,
	Holographic = 100,
	Rainbow     = 60,
	Animated    = 30,
	Signed      = 10,
}

-- ──────────────────────────────────────────────────────────────
-- NHL PLAYER ROSTER  (verified against 2025-26 NHL Opening Day rosters)
-- ──────────────────────────────────────────────────────────────
CardDatabase.Players = {
	-- Centers
	{ Name = "Connor McDavid",     Team = "EDM", Position = "C",  Era = "Current Season" },
	{ Name = "Leon Draisaitl",     Team = "EDM", Position = "C",  Era = "Current Season" },
	{ Name = "Nathan MacKinnon",   Team = "COL", Position = "C",  Era = "Current Season" },
	{ Name = "Auston Matthews",    Team = "TOR", Position = "C",  Era = "Current Season" },
	{ Name = "Sidney Crosby",      Team = "PIT", Position = "C",  Era = "All-Time" },
	{ Name = "Sidney Crosby",      Team = "PIT", Position = "C",  Era = "Rookie Year" },
	{ Name = "Elias Pettersson",   Team = "VAN", Position = "C",  Era = "Current Season" },
	{ Name = "Anze Kopitar",       Team = "LAK", Position = "C",  Era = "All-Time" },
	{ Name = "Ryan O'Reilly",      Team = "NSH", Position = "C",  Era = "Current Season" },  -- NSH confirmed on opening day roster
	{ Name = "Bo Horvat",          Team = "NYI", Position = "C",  Era = "Current Season" },
	{ Name = "Brayden Point",      Team = "TBL", Position = "C",  Era = "Current Season" },
	{ Name = "Dylan Larkin",       Team = "DET", Position = "C",  Era = "Current Season" },
	{ Name = "Aleksander Barkov",  Team = "FLA", Position = "C",  Era = "Current Season" },
	{ Name = "Sam Reinhart",       Team = "FLA", Position = "C",  Era = "Current Season" },
	{ Name = "Mark Scheifele",     Team = "WPG", Position = "C",  Era = "Current Season" },
	{ Name = "Joe Pavelski",       Team = "DAL", Position = "C",  Era = "All-Time" },
	{ Name = "Jack Hughes",        Team = "NJD", Position = "C",  Era = "Current Season" },
	{ Name = "Tim Stutzle",        Team = "OTT", Position = "C",  Era = "Current Season" },
	{ Name = "Tage Thompson",      Team = "BUF", Position = "C",  Era = "Current Season" },
	{ Name = "Trevor Zegras",      Team = "PHI", Position = "C",  Era = "Current Season" },  -- traded ANA→PHI
	{ Name = "Mason McTavish",     Team = "ANA", Position = "C",  Era = "Rookie Year" },
	{ Name = "Macklin Celebrini",  Team = "SJS", Position = "C",  Era = "Rookie Year" },
	{ Name = "Wyatt Johnston",     Team = "DAL", Position = "C",  Era = "Current Season" },
	{ Name = "Logan Stankoven",    Team = "CAR", Position = "C",  Era = "Current Season" },  -- traded DAL→CAR
	{ Name = "Cole Perfetti",      Team = "WPG", Position = "C",  Era = "Current Season" },
	{ Name = "Shane Wright",       Team = "SEA", Position = "C",  Era = "Current Season" },
	{ Name = "Matty Beniers",      Team = "SEA", Position = "C",  Era = "Current Season" },
	{ Name = "Ryan McLeod",        Team = "EDM", Position = "C",  Era = "Current Season" },
	{ Name = "Noah Cates",         Team = "PHI", Position = "C",  Era = "Current Season" },
	{ Name = "Dawson Mercer",      Team = "NJD", Position = "C",  Era = "Current Season" },
	{ Name = "Dylan Cozens",       Team = "OTT", Position = "C",  Era = "Current Season" },  -- traded BUF→OTT
	{ Name = "Quinton Byfield",    Team = "LAK", Position = "C",  Era = "Current Season" },
	{ Name = "Barrett Hayton",     Team = "UTA", Position = "C",  Era = "Current Season" },  -- ARI relocated to UTA
	{ Name = "Cody Glass",         Team = "NJD", Position = "C",  Era = "Current Season" },  -- re-signed NJD
	{ Name = "Nick Suzuki",        Team = "MTL", Position = "C",  Era = "Current Season" },
	{ Name = "Kirby Dach",         Team = "MTL", Position = "C",  Era = "Current Season" },  -- confirmed MTL on opening day
	{ Name = "Nico Hischier",      Team = "NJD", Position = "C",  Era = "Current Season" },
	{ Name = "Lars Eller",         Team = "OTT", Position = "C",  Era = "Current Season" },  -- confirmed OTT on opening day
	{ Name = "Connor Bedard",      Team = "CHI", Position = "C",  Era = "Rookie Year" },
	{ Name = "Elias Lindholm",     Team = "BOS", Position = "C",  Era = "Current Season" },
	{ Name = "Casey Mittelstadt",  Team = "BOS", Position = "C",  Era = "Current Season" },  -- confirmed BOS on opening day
	{ Name = "Roope Hintz",        Team = "DAL", Position = "C",  Era = "Current Season" },
	{ Name = "Tyler Seguin",       Team = "DAL", Position = "C",  Era = "Current Season" },
	{ Name = "Matt Duchene",       Team = "DAL", Position = "C",  Era = "Current Season" },  -- confirmed DAL on opening day
	{ Name = "Nazem Kadri",        Team = "CGY", Position = "C",  Era = "Current Season" },
	{ Name = "J.T. Compher",       Team = "DET", Position = "C",  Era = "Current Season" },
	{ Name = "Martin Necas",       Team = "COL", Position = "C",  Era = "Current Season" },
	{ Name = "Cutter Gauthier",    Team = "ANA", Position = "C",  Era = "Rookie Year" },
	{ Name = "Frank Nazar",        Team = "CHI", Position = "C",  Era = "Rookie Year" },
	{ Name = "Mikael Backlund",    Team = "CGY", Position = "C",  Era = "Current Season" },
	{ Name = "Pavel Zacha",        Team = "BOS", Position = "C",  Era = "Current Season" },
	{ Name = "Brock Nelson",       Team = "COL", Position = "C",  Era = "Current Season" },  -- traded NYI→COL, re-signed COL
	{ Name = "Mikko Rantanen",     Team = "DAL", Position = "RW", Era = "Current Season" },  -- confirmed DAL on opening day
	{ Name = "Mavrik Bourque",     Team = "DAL", Position = "C",  Era = "Current Season" },  -- confirmed DAL, plays C/F not D
	{ Name = "Ross Colton",        Team = "COL", Position = "C",  Era = "Current Season" },  -- confirmed COL, plays C not LW
	{ Name = "Marco Kasper",       Team = "DET", Position = "C",  Era = "Rookie Year" },     -- confirmed DET, plays C not LW
	{ Name = "Leo Carlsson",       Team = "ANA", Position = "C",  Era = "Rookie Year" },     -- confirmed ANA, plays C not LW
	{ Name = "Mikael Granlund",    Team = "ANA", Position = "C",  Era = "Current Season" },  -- signed ANA as UFA; plays C not RW
	{ Name = "Claude Giroux",      Team = "OTT", Position = "C",  Era = "All-Time" },        -- confirmed OTT; plays C not RW

	-- Left Wings / Right Wings
	{ Name = "David Pastrnak",     Team = "BOS", Position = "RW", Era = "Current Season" },
	{ Name = "Nikita Kucherov",    Team = "TBL", Position = "RW", Era = "Current Season" },
	{ Name = "Alex Ovechkin",      Team = "WSH", Position = "LW", Era = "All-Time" },
	{ Name = "Alex Ovechkin",      Team = "WSH", Position = "LW", Era = "Rookie Year" },
	{ Name = "Brad Marchand",      Team = "FLA", Position = "LW", Era = "Current Season" },  -- traded BOS→FLA
	{ Name = "Artemi Panarin",     Team = "NYR", Position = "LW", Era = "Current Season" },  -- confirmed NYR on opening day (traded to LAK Feb 4 mid-season)
	{ Name = "Kyle Connor",        Team = "WPG", Position = "LW", Era = "Current Season" },
	{ Name = "Kirill Kaprizov",    Team = "MIN", Position = "LW", Era = "Current Season" },
	{ Name = "Matthew Tkachuk",    Team = "FLA", Position = "LW", Era = "Current Season" },
	{ Name = "Brady Tkachuk",      Team = "OTT", Position = "LW", Era = "Current Season" },
	{ Name = "Jonathan Huberdeau", Team = "CGY", Position = "LW", Era = "Current Season" },  -- confirmed CGY (injured)
	{ Name = "Mika Zibanejad",     Team = "NYR", Position = "C",  Era = "Current Season" },
	{ Name = "Patrick Kane",       Team = "DET", Position = "RW", Era = "Current Season" },  -- confirmed DET re-signed; current card
	{ Name = "Patrick Kane",       Team = "CHI", Position = "RW", Era = "All-Time" },        -- All-Time CHI card
	{ Name = "Mitch Marner",       Team = "VGK", Position = "RW", Era = "Current Season" },  -- signed TOR then traded to VGK
	{ Name = "Mark Stone",         Team = "VGK", Position = "RW", Era = "Current Season" },
	{ Name = "William Nylander",   Team = "TOR", Position = "RW", Era = "Current Season" },
	{ Name = "Cole Caufield",      Team = "MTL", Position = "RW", Era = "Current Season" },
	{ Name = "Yegor Sharangovich", Team = "CGY", Position = "LW", Era = "Current Season" },
	{ Name = "Fabian Lysell",      Team = "BOS", Position = "RW", Era = "Rookie Year" },
	{ Name = "Matvei Michkov",     Team = "PHI", Position = "RW", Era = "Rookie Year" },
	{ Name = "Brock Faber",        Team = "MIN", Position = "D",  Era = "Current Season" },  -- confirmed MIN, plays D not LW
	{ Name = "William Carrier",    Team = "CAR", Position = "LW", Era = "Current Season" },  -- confirmed CAR on opening day
	{ Name = "Rickard Rakell",     Team = "PIT", Position = "LW", Era = "Current Season" },
	{ Name = "Jason Robertson",    Team = "DAL", Position = "RW", Era = "Current Season" },
	{ Name = "Filip Forsberg",     Team = "NSH", Position = "LW", Era = "Current Season" },
	{ Name = "Alex DeBrincat",     Team = "DET", Position = "LW", Era = "Current Season" },  -- confirmed DET; plays LW not RW
	{ Name = "Timo Meier",         Team = "NJD", Position = "LW", Era = "Current Season" },
	{ Name = "Zach Hyman",         Team = "EDM", Position = "LW", Era = "Current Season" },  -- confirmed EDM (injured on opening day)
	{ Name = "Jake Guentzel",      Team = "TBL", Position = "LW", Era = "Current Season" },
	{ Name = "Pavel Dorofeyev",    Team = "VGK", Position = "LW", Era = "Current Season" },
	{ Name = "Andrei Svechnikov",  Team = "CAR", Position = "RW", Era = "Current Season" },
	{ Name = "Dylan Guenther",     Team = "UTA", Position = "RW", Era = "Current Season" },  -- confirmed UTA on opening day
	{ Name = "Kaiden Guhle",       Team = "MTL", Position = "D",  Era = "Current Season" },  -- confirmed MTL, plays D not LW
	{ Name = "Juraj Slafkovsky",   Team = "MTL", Position = "LW", Era = "Rookie Year" },
	{ Name = "Ivan Miroshnichenko",Team = "WSH", Position = "LW", Era = "Rookie Year" },
	{ Name = "Conor Garland",      Team = "VAN", Position = "RW", Era = "Current Season" },
	{ Name = "Nino Niederreiter",  Team = "WPG", Position = "LW", Era = "Current Season" },
	{ Name = "Alex Killorn",       Team = "ANA", Position = "LW", Era = "Current Season" },  -- confirmed ANA on opening day
	{ Name = "Teuvo Teravainen",   Team = "CHI", Position = "LW", Era = "Current Season" },  -- confirmed CHI; plays LW not RW
	{ Name = "Lucas Raymond",      Team = "DET", Position = "RW", Era = "Current Season" },
	{ Name = "Elmer Soderblom",    Team = "DET", Position = "LW", Era = "Current Season" },
	{ Name = "Artturi Lehkonen",   Team = "COL", Position = "LW", Era = "Current Season" },
	{ Name = "Valeri Nichushkin",  Team = "COL", Position = "RW", Era = "Current Season" },
	{ Name = "Victor Olofsson",    Team = "COL", Position = "LW", Era = "Current Season" },  -- confirmed COL on opening day
	{ Name = "Beckett Sennecke",   Team = "ANA", Position = "RW", Era = "Rookie Year" },
	{ Name = "Jiri Kulich",        Team = "BUF", Position = "LW", Era = "Rookie Year" },
	{ Name = "Zach Benson",        Team = "BUF", Position = "LW", Era = "Rookie Year" },
	{ Name = "Alex Tuch",          Team = "BUF", Position = "LW", Era = "Current Season" },
	{ Name = "Jack Quinn",         Team = "BUF", Position = "RW", Era = "Current Season" },
	{ Name = "Matt Coronato",      Team = "CGY", Position = "RW", Era = "Current Season" },
	{ Name = "Joel Farabee",       Team = "CGY", Position = "LW", Era = "Current Season" },  -- confirmed CGY on opening day
	{ Name = "Lukas Reichel",      Team = "CHI", Position = "LW", Era = "Current Season" },
	{ Name = "Tyler Bertuzzi",     Team = "CHI", Position = "LW", Era = "Current Season" },  -- confirmed CHI on opening day
	{ Name = "Ilya Mikheyev",      Team = "CHI", Position = "LW", Era = "Current Season" },  -- confirmed CHI; plays LW not RW
	{ Name = "Gabriel Landeskog",  Team = "COL", Position = "LW", Era = "All-Time" },
	{ Name = "Axel Sandin-Pellikka",Team = "DET", Position = "RW", Era = "Rookie Year" },
	{ Name = "Troy Terry",         Team = "ANA", Position = "RW", Era = "Current Season" },
	{ Name = "Chris Kreider",      Team = "ANA", Position = "LW", Era = "Current Season" },  -- traded NYR→ANA
	{ Name = "Noah Dobson",        Team = "MTL", Position = "D",  Era = "Current Season" },  -- traded NYI→MTL

	-- Defensemen
	{ Name = "Cale Makar",         Team = "COL", Position = "D",  Era = "Current Season" },
	{ Name = "Adam Fox",           Team = "NYR", Position = "D",  Era = "Current Season" },
	{ Name = "Victor Hedman",      Team = "TBL", Position = "D",  Era = "All-Time" },
	{ Name = "Erik Karlsson",      Team = "PIT", Position = "D",  Era = "Current Season" },  -- confirmed PIT on opening day
	{ Name = "Rasmus Dahlin",      Team = "BUF", Position = "D",  Era = "Current Season" },
	{ Name = "Quinn Hughes",       Team = "VAN", Position = "D",  Era = "Current Season" },
	{ Name = "Shea Weber",         Team = "MTL", Position = "D",  Era = "All-Time" },
	{ Name = "Drew Doughty",       Team = "LAK", Position = "D",  Era = "All-Time" },
	{ Name = "Devon Toews",        Team = "COL", Position = "D",  Era = "Current Season" },
	{ Name = "Roman Josi",         Team = "NSH", Position = "D",  Era = "Current Season" },
	{ Name = "Morgan Rielly",      Team = "TOR", Position = "D",  Era = "Current Season" },
	{ Name = "Dougie Hamilton",    Team = "NJD", Position = "D",  Era = "Current Season" },
	{ Name = "Miro Heiskanen",     Team = "DAL", Position = "D",  Era = "Current Season" },
	{ Name = "Moritz Seider",      Team = "DET", Position = "D",  Era = "Rookie Year" },
	{ Name = "Evan Bouchard",      Team = "EDM", Position = "D",  Era = "Current Season" },
	{ Name = "Nicklas Lidstrom",   Team = "DET", Position = "D",  Era = "All-Time" },
	{ Name = "Bobby Orr",          Team = "BOS", Position = "D",  Era = "All-Time" },
	{ Name = "Jake Sanderson",     Team = "OTT", Position = "D",  Era = "Current Season" },
	{ Name = "Luke Hughes",        Team = "NJD", Position = "D",  Era = "Rookie Year" },
	{ Name = "Mikhail Sergachev",  Team = "UTA", Position = "D",  Era = "Current Season" },  -- confirmed UTA on opening day
	{ Name = "Josh Morrissey",     Team = "WPG", Position = "D",  Era = "Current Season" },
	{ Name = "Darnell Nurse",      Team = "EDM", Position = "D",  Era = "Current Season" },
	{ Name = "Travis Sanheim",     Team = "PHI", Position = "D",  Era = "Current Season" },
	{ Name = "Brent Burns",        Team = "COL", Position = "D",  Era = "Current Season" },  -- confirmed COL on opening day (was CAR)
	{ Name = "Bowen Byram",        Team = "BUF", Position = "D",  Era = "Current Season" },  -- re-signed BUF confirmed
	{ Name = "Owen Power",         Team = "BUF", Position = "D",  Era = "Rookie Year" },
	{ Name = "Simon Nemec",        Team = "NJD", Position = "D",  Era = "Rookie Year" },
	{ Name = "David Jiricek",      Team = "MIN", Position = "D",  Era = "Rookie Year" },     -- confirmed MIN on opening day (was CBJ)
	{ Name = "Cam York",           Team = "PHI", Position = "D",  Era = "Current Season" },
	{ Name = "Nils Lundkvist",     Team = "DAL", Position = "D",  Era = "Current Season" },  -- confirmed DAL on opening day
	{ Name = "Zach Werenski",      Team = "CBJ", Position = "D",  Era = "Current Season" },
	{ Name = "Thomas Harley",      Team = "DAL", Position = "D",  Era = "Current Season" },
	{ Name = "Olen Zellweger",     Team = "ANA", Position = "D",  Era = "Rookie Year" },
	{ Name = "Charlie McAvoy",     Team = "BOS", Position = "D",  Era = "Current Season" },
	{ Name = "Hampus Lindholm",    Team = "BOS", Position = "D",  Era = "Current Season" },
	{ Name = "Mason Lohrei",       Team = "BOS", Position = "D",  Era = "Current Season" },
	{ Name = "Mattias Samuelsson", Team = "BUF", Position = "D",  Era = "Current Season" },
	{ Name = "Zayne Parekh",       Team = "CGY", Position = "D",  Era = "Rookie Year" },
	{ Name = "Rasmus Andersson",   Team = "CGY", Position = "D",  Era = "Current Season" },
	{ Name = "Mackenzie Weegar",   Team = "CGY", Position = "D",  Era = "Current Season" },
	{ Name = "Connor Murphy",      Team = "CHI", Position = "D",  Era = "Current Season" },
	{ Name = "Samuel Girard",      Team = "COL", Position = "D",  Era = "Current Season" },
	{ Name = "Josh Manson",        Team = "COL", Position = "D",  Era = "Current Season" },
	{ Name = "Esa Lindell",        Team = "DAL", Position = "D",  Era = "Current Season" },
	{ Name = "Simon Edvinsson",    Team = "DET", Position = "D",  Era = "Rookie Year" },
	{ Name = "Albert Johansson",   Team = "DET", Position = "D",  Era = "Current Season" },
	{ Name = "Pavel Mintyukov",    Team = "ANA", Position = "D",  Era = "Rookie Year" },
	{ Name = "Jackson LaCombe",    Team = "ANA", Position = "D",  Era = "Current Season" },
	{ Name = "Jacob Trouba",       Team = "ANA", Position = "D",  Era = "Current Season" },  -- confirmed ANA on opening day
	{ Name = "Henri Jokiharju",    Team = "BOS", Position = "D",  Era = "Current Season" },  -- confirmed BOS on opening day
	{ Name = "Sam Rinzel",         Team = "CHI", Position = "D",  Era = "Rookie Year" },
	{ Name = "Artyom Levshunov",   Team = "CHI", Position = "D",  Era = "Rookie Year" },

	-- Goalies
	{ Name = "Andrei Vasilevskiy", Team = "TBL", Position = "G",  Era = "Current Season" },
	{ Name = "Igor Shesterkin",    Team = "NYR", Position = "G",  Era = "Current Season" },
	{ Name = "Juuse Saros",        Team = "NSH", Position = "G",  Era = "Current Season" },
	{ Name = "Ilya Sorokin",       Team = "NYI", Position = "G",  Era = "Current Season" },
	{ Name = "Jacob Markstrom",    Team = "NJD", Position = "G",  Era = "Current Season" },  -- confirmed NJD on opening day
	{ Name = "Thatcher Demko",     Team = "VAN", Position = "G",  Era = "Current Season" },
	{ Name = "Marc-Andre Fleury",  Team = "MIN", Position = "G",  Era = "All-Time" },
	{ Name = "Martin Brodeur",     Team = "NJD", Position = "G",  Era = "All-Time" },
	{ Name = "Patrick Roy",        Team = "COL", Position = "G",  Era = "All-Time" },
	{ Name = "Sergei Bobrovsky",   Team = "FLA", Position = "G",  Era = "Current Season" },
	{ Name = "Frederik Andersen",  Team = "CAR", Position = "G",  Era = "Current Season" },
	{ Name = "Jeremy Swayman",     Team = "BOS", Position = "G",  Era = "Current Season" },
	{ Name = "Connor Hellebuyck",  Team = "WPG", Position = "G",  Era = "Current Season" },
	{ Name = "Jake Oettinger",     Team = "DAL", Position = "G",  Era = "Current Season" },
	{ Name = "Stuart Skinner",     Team = "EDM", Position = "G",  Era = "Current Season" },
	{ Name = "Linus Ullmark",      Team = "OTT", Position = "G",  Era = "Current Season" },  -- confirmed OTT on opening day
	{ Name = "Cayden Primeau",     Team = "TOR", Position = "G",  Era = "Current Season" },  -- confirmed TOR on opening day (was MTL)
	{ Name = "Tristan Jarry",      Team = "PIT", Position = "G",  Era = "Current Season" },
	{ Name = "Ville Husso",        Team = "ANA", Position = "G",  Era = "Current Season" },  -- confirmed ANA on opening day (was DET)
	{ Name = "Vitek Vanecek",      Team = "UTA", Position = "G",  Era = "Current Season" },  -- confirmed UTA on opening day
	{ Name = "Akira Schmid",       Team = "VGK", Position = "G",  Era = "Current Season" },  -- confirmed VGK on opening day
	{ Name = "Spencer Knight",     Team = "CHI", Position = "G",  Era = "Current Season" },  -- confirmed CHI on opening day (was FLA)
	{ Name = "Yaroslav Askarov",   Team = "NSH", Position = "G",  Era = "Rookie Year" },
	{ Name = "Devon Levi",         Team = "BUF", Position = "G",  Era = "Rookie Year" },     -- note: UPL listed as injured on opening day; Levi/Georgiev are backups
	{ Name = "Joel Hofer",         Team = "STL", Position = "G",  Era = "Current Season" },
	{ Name = "Lukas Dostal",       Team = "ANA", Position = "G",  Era = "Current Season" },  -- confirmed ANA on opening day
	{ Name = "Dustin Wolf",        Team = "CGY", Position = "G",  Era = "Rookie Year" },
	{ Name = "Samuel Ersson",      Team = "PHI", Position = "G",  Era = "Current Season" },
	{ Name = "Alexandar Georgiev", Team = "BUF", Position = "G",  Era = "Current Season" },  -- confirmed BUF on opening day
	{ Name = "Joonas Korpisalo",   Team = "BOS", Position = "G",  Era = "Current Season" },  -- confirmed BOS on opening day
	{ Name = "Arvid Soderblom",    Team = "CHI", Position = "G",  Era = "Current Season" },
	{ Name = "Scott Wedgewood",    Team = "COL", Position = "G",  Era = "Current Season" },  -- confirmed COL on opening day
	{ Name = "Casey DeSmith",      Team = "DAL", Position = "G",  Era = "Current Season" },  -- confirmed DAL on opening day
	{ Name = "John Gibson",        Team = "DET", Position = "G",  Era = "Current Season" },  -- traded ANA→DET confirmed
	{ Name = "Cam Talbot",         Team = "DET", Position = "G",  Era = "Current Season" },  -- confirmed DET on opening day
	{ Name = "Petr Mrazek",        Team = "ANA", Position = "G",  Era = "Current Season" },  -- traded DET→ANA confirmed on opening day
	{ Name = "Colten Ellis",       Team = "BUF", Position = "G",  Era = "Current Season" },  -- confirmed BUF on opening day

	-- All-Time Legends
	{ Name = "Wayne Gretzky",      Team = "EDM", Position = "C",  Era = "All-Time" },
	{ Name = "Mario Lemieux",      Team = "PIT", Position = "C",  Era = "All-Time" },
	{ Name = "Gordie Howe",        Team = "DET", Position = "RW", Era = "All-Time" },
	{ Name = "Maurice Richard",    Team = "MTL", Position = "RW", Era = "All-Time" },
	{ Name = "Mark Messier",       Team = "EDM", Position = "C",  Era = "All-Time" },
	{ Name = "Jaromir Jagr",       Team = "PIT", Position = "RW", Era = "All-Time" },
	{ Name = "Phil Esposito",      Team = "BOS", Position = "C",  Era = "All-Time" },
	{ Name = "Guy Lafleur",        Team = "MTL", Position = "RW", Era = "All-Time" },
	{ Name = "Mike Modano",        Team = "DAL", Position = "C",  Era = "All-Time" },
	{ Name = "Steve Yzerman",      Team = "DET", Position = "C",  Era = "All-Time" },
	{ Name = "Joe Sakic",          Team = "COL", Position = "C",  Era = "All-Time" },
	{ Name = "Teemu Selanne",      Team = "ANA", Position = "RW", Era = "All-Time" },
	{ Name = "Brett Hull",         Team = "STL", Position = "RW", Era = "All-Time" },
}

-- ──────────────────────────────────────────────────────────────
-- PACK DEFINITIONS
-- ──────────────────────────────────────────────────────────────
CardDatabase.Packs = {
	RookiePack = {
		Name        = "Rookie Pack",
		DisplayName = "🏒 Rookie Pack",
		Cost        = 300,
		CostType    = "Pucks",
		Tier        = 1,
		Description = "Perfect for new collectors. Mostly Common and Rare pulls.",
		Weights = {
			Common         = 7500,
			Rare           = 2200,
			Epic           = 270,
			Legendary      = 28,
			Mythic         = 2,
			Secret         = 0,
			Limited        = 0,
			EventExclusive = 0,
		},
	},
	ProPack = {
		Name        = "Pro Pack",
		DisplayName = "⭐ Pro Pack",
		Cost        = 800,
		CostType    = "Pucks",
		Tier        = 2,
		Description = "Better odds across the board. Common through Epic.",
		Weights = {
			Common         = 5800,
			Rare           = 3000,
			Epic           = 650,
			Legendary      = 120,
			Mythic         = 28,
			Secret         = 2,
			Limited        = 0,
			EventExclusive = 0,
		},
	},
	AllStarPack = {
		Name        = "All-Star Pack",
		DisplayName = "🌟 All-Star Pack",
		Cost        = 2200,
		CostType    = "Pucks",
		Tier        = 3,
		Description = "Premium pack with elevated Epic and Legendary chances.",
		Weights = {
			Common         = 0,
			Rare           = 5500,
			Epic           = 3000,
			Legendary      = 1300,
			Mythic         = 175,
			Secret         = 23,
			Limited        = 2,
			EventExclusive = 0,
		},
	},
	StanleyCupPack = {
		Name        = "Stanley Cup Pack",
		DisplayName = "🏆 Stanley Cup Pack",
		Cost        = 5000,
		CostType    = "Pucks",
		Tier        = 4,
		Description = "Elite pack. Legendary and Mythic guaranteed possible.",
		Weights = {
			Common         = 0,
			Rare           = 0,
			Epic           = 5200,
			Legendary      = 3400,
			Mythic         = 1200,
			Secret         = 250,
			Limited        = 24,
			EventExclusive = 1,
		},
	},
	WinterClassicPack = {
		Name        = "Winter Classic Pack",
		DisplayName = "❄️ Winter Classic Pack",
		Cost        = 15,
		CostType    = "Gems",
		Tier        = 5,
		Description = "Limited event pack. Exclusive Event cards inside!",
		IsEvent     = true,
		EventName   = "WinterClassic",
		Weights = {
			Common         = 0,
			Rare           = 4000,
			Epic           = 3200,
			Legendary      = 1800,
			Mythic         = 700,
			Secret         = 200,
			Limited        = 80,
			EventExclusive = 20,
		},
	},
	PlayoffsPack = {
		Name        = "Playoffs Pack",
		DisplayName = "🎄 Playoffs Pack",
		Cost        = 20,
		CostType    = "Gems",
		Tier        = 5,
		Description = "Playoff season exclusives. Chase the Cup cards!",
		IsEvent     = true,
		EventName   = "Playoffs",
		Weights = {
			Common         = 0,
			Rare           = 3500,
			Epic           = 3500,
			Legendary      = 2000,
			Mythic         = 750,
			Secret         = 200,
			Limited        = 0,
			EventExclusive = 50,
		},
	},
	FreePack = {
		Name        = "Free Pack",
		DisplayName = "🎁 Free Pack",
		Cost        = 0,
		CostType    = "Free",
		Tier        = 1,
		Description = "A free pack for everyone! Open as many as you want.",
		Weights = {
			Common         = 8500,
			Rare           = 1400,
			Epic           = 95,
			Legendary      = 1,
			Mythic         = 0,
			Secret         = 0,
			Limited        = 0,
			EventExclusive = 0,
		},
	},
	ElitePack = {
		Name        = "Elite Pack",
		DisplayName = "💠 Elite Pack",
		Cost        = 10000,
		CostType    = "Pucks",
		Tier        = 5,
		Description = "High-tier pack. Rare minimum, strong Legendary odds.",
		Weights = {
			Common         = 0,
			Rare           = 3000,
			Epic           = 4000,
			Legendary      = 2200,
			Mythic         = 700,
			Secret         = 95,
			Limited        = 5,
			EventExclusive = 0,
		},
	},
	ChampionPack = {
		Name        = "Champion Pack",
		DisplayName = "🥇 Champion Pack",
		Cost        = 15000,
		CostType    = "Pucks",
		Tier        = 6,
		Description = "Champion-tier pulls. Guaranteed Epic or better.",
		Weights = {
			Common         = 0,
			Rare           = 0,
			Epic           = 4500,
			Legendary      = 3500,
			Mythic         = 1600,
			Secret         = 370,
			Limited        = 28,
			EventExclusive = 2,
		},
	},
	LegacyPack = {
		Name        = "Legacy Pack",
		DisplayName = "👑 Legacy Pack",
		Cost        = 30000,
		CostType    = "Pucks",
		Tier        = 7,
		Description = "Pull the legends. Mythic and Secret odds heavily boosted.",
		Weights = {
			Common         = 0,
			Rare           = 0,
			Epic           = 1500,
			Legendary      = 4000,
			Mythic         = 3200,
			Secret         = 1100,
			Limited        = 185,
			EventExclusive = 15,
		},
	},
	GrandmasterPack = {
		Name        = "Grandmaster Pack",
		DisplayName = "⚜️ Grandmaster Pack",
		Cost        = 50000,
		CostType    = "Pucks",
		Tier        = 8,
		Description = "The rarest of em all. Secret and Limited await.",
		Weights = {
			Common         = 0,
			Rare           = 0,
			Epic           = 0,
			Legendary      = 2000,
			Mythic         = 4500,
			Secret         = 2800,
			Limited        = 650,
			EventExclusive = 50,
		},
	},
}

-- ──────────────────────────────────────────────────────────────
-- LUCK UPGRADE TIERS  (index = luck level)
-- ──────────────────────────────────────────────────────────────
CardDatabase.LuckTiers = {
	[0]  = { Multiplier = 1.00, Cost = 0 },
	[1]  = { Multiplier = 1.05, Cost = 500 },
	[2]  = { Multiplier = 1.10, Cost = 1200 },
	[3]  = { Multiplier = 1.18, Cost = 2500 },
	[4]  = { Multiplier = 1.28, Cost = 5000 },
	[5]  = { Multiplier = 1.40, Cost = 10000 },
	[6]  = { Multiplier = 1.55, Cost = 20000 },
	[7]  = { Multiplier = 1.75, Cost = 40000 },
	[8]  = { Multiplier = 2.00, Cost = 80000 },
	[9]  = { Multiplier = 2.30, Cost = 150000 },
	[10] = { Multiplier = 2.75, Cost = 300000 },
}

-- ──────────────────────────────────────────────────────────────
-- PRESTIGE / REBIRTH TIERS
-- ──────────────────────────────────────────────────────────────
CardDatabase.PrestigeTiers = {
	[0] = { Badge = "None",     LuckBonus = 0.00, CostInPucks = 0 },
	[1] = { Badge = "Bronze",   LuckBonus = 0.05, CostInPucks = 100000 },
	[2] = { Badge = "Silver",   LuckBonus = 0.10, CostInPucks = 250000 },
	[3] = { Badge = "Gold",     LuckBonus = 0.20, CostInPucks = 600000 },
	[4] = { Badge = "Platinum", LuckBonus = 0.35, CostInPucks = 1500000 },
	[5] = { Badge = "Diamond",  LuckBonus = 0.55, CostInPucks = 4000000 },
}

-- ──────────────────────────────────────────────────────────────
-- ACHIEVEMENT DEFINITIONS
-- ──────────────────────────────────────────────────────────────
CardDatabase.Achievements = {
	{ Id = "first_pack",      Name = "Ice Breaker",     Desc = "Open your first pack.",             PuckReward = 100,    GemReward = 0 },
	{ Id = "packs_10",        Name = "On A Roll",        Desc = "Open 10 packs.",                    PuckReward = 250,    GemReward = 0 },
	{ Id = "packs_100",       Name = "Pack Rat",         Desc = "Open 100 packs.",                   PuckReward = 1000,   GemReward = 2 },
	{ Id = "packs_1000",      Name = "Grinder",          Desc = "Open 1,000 packs.",                 PuckReward = 5000,   GemReward = 10 },
	{ Id = "first_rare",      Name = "Blue Ice",         Desc = "Pull your first Rare card.",        PuckReward = 150,    GemReward = 0 },
	{ Id = "first_epic",      Name = "Purple Rain",      Desc = "Pull your first Epic card.",        PuckReward = 500,    GemReward = 1 },
	{ Id = "first_legendary", Name = "Golden Moment",    Desc = "Pull your first Legendary card.",   PuckReward = 2000,   GemReward = 3 },
	{ Id = "first_mythic",    Name = "Mythic Status",    Desc = "Pull your first Mythic card.",      PuckReward = 10000,  GemReward = 10 },
	{ Id = "first_secret",    Name = "Secret Handshake", Desc = "Pull a Secret card.",               PuckReward = 50000,  GemReward = 25 },
	{ Id = "luck_5",          Name = "Lucky Skates",     Desc = "Reach Luck Level 5.",               PuckReward = 3000,   GemReward = 5 },
	{ Id = "luck_10",         Name = "Four Leaf Clover", Desc = "Max out Luck Level.",               PuckReward = 10000,  GemReward = 15 },
	{ Id = "prestige_1",      Name = "Rebirth",          Desc = "Complete your first Prestige.",     PuckReward = 0,      GemReward = 20 },
	{ Id = "collection_25",   Name = "Quarter Full",     Desc = "Complete 25% of the Puck-Index.",   PuckReward = 5000,   GemReward = 5 },
	{ Id = "collection_50",   Name = "Halfway There",    Desc = "Complete 50% of the Puck-Index.",   PuckReward = 15000,  GemReward = 15 },
	{ Id = "collection_100",  Name = "Full Collection",  Desc = "Complete 100% of the Puck-Index.",  PuckReward = 100000, GemReward = 100 },
	{ Id = "trades_10",       Name = "Market Mover",     Desc = "Complete 10 trades.",               PuckReward = 1000,   GemReward = 2 },
	{ Id = "daily_7",         Name = "Week Warrior",     Desc = "Log in 7 days in a row.",           PuckReward = 500,    GemReward = 3 },
	{ Id = "daily_30",        Name = "Iron Man",         Desc = "Log in 30 days in a row.",          PuckReward = 5000,   GemReward = 15 },
}

-- ──────────────────────────────────────────────────────────────
-- DAILY QUEST POOL
-- ──────────────────────────────────────────────────────────────
CardDatabase.DailyQuestPool = {
	{ Id = "open_packs_5",   Desc = "Open 5 packs",           Target = 5,   Stat = "PacksOpened", PuckReward = 300,  GemReward = 0 },
	{ Id = "open_packs_10",  Desc = "Open 10 packs",          Target = 10,  Stat = "PacksOpened", PuckReward = 600,  GemReward = 0 },
	{ Id = "open_packs_20",  Desc = "Open 20 packs",          Target = 20,  Stat = "PacksOpened", PuckReward = 1200, GemReward = 1 },
	{ Id = "pull_rare",      Desc = "Pull a Rare or higher",  Target = 1,   Stat = "RarePulls",   PuckReward = 200,  GemReward = 0 },
	{ Id = "pull_epic",      Desc = "Pull an Epic or higher", Target = 1,   Stat = "EpicPulls",   PuckReward = 500,  GemReward = 1 },
	{ Id = "sell_cards_5",   Desc = "Sell 5 cards",           Target = 5,   Stat = "CardsSold",   PuckReward = 400,  GemReward = 0 },
	{ Id = "sell_cards_10",  Desc = "Sell 10 cards",          Target = 10,  Stat = "CardsSold",   PuckReward = 800,  GemReward = 0 },
	{ Id = "earn_pucks_500", Desc = "Earn 500 Pucks",         Target = 500, Stat = "PucksEarned", PuckReward = 250,  GemReward = 0 },
}

-- ──────────────────────────────────────────────────────────────
-- WEEKLY QUEST POOL
-- ──────────────────────────────────────────────────────────────
CardDatabase.WeeklyQuestPool = {
	-- Pack opening
	{ Id = "weekly_packs_50",   Desc = "Open 50 packs this week",    Target = 50,  Stat = "PacksOpened", PuckReward = 5000,  GemReward = 2,  GuaranteedRarity = nil },
	{ Id = "weekly_packs_100",  Desc = "Open 100 packs this week",   Target = 100, Stat = "PacksOpened", PuckReward = 10000, GemReward = 5,  GuaranteedRarity = "Epic" },
	{ Id = "weekly_packs_250",  Desc = "Open 250 packs this week",   Target = 250, Stat = "PacksOpened", PuckReward = 25000, GemReward = 10, GuaranteedRarity = "Legendary" },

	-- Rarity pulls
	{ Id = "weekly_rare_10",    Desc = "Pull 10 Rare or higher",     Target = 10,  Stat = "RarePulls",   PuckReward = 3000,  GemReward = 1,  GuaranteedRarity = nil },
	{ Id = "weekly_epic_5",     Desc = "Pull 5 Epic or higher",      Target = 5,   Stat = "EpicPulls",   PuckReward = 6000,  GemReward = 3,  GuaranteedRarity = nil },
	{ Id = "weekly_legendary",  Desc = "Pull 3 Legendary or higher", Target = 3,   Stat = "LegPulls",    PuckReward = 8000,  GemReward = 5,  GuaranteedRarity = nil },
	{ Id = "weekly_legendary_5",Desc = "Pull 5 Legendary or higher", Target = 5,   Stat = "LegPulls",    PuckReward = 15000, GemReward = 8,  GuaranteedRarity = nil },

	-- Trading
	{ Id = "weekly_trades_3",   Desc = "Complete 3 trades",          Target = 3,   Stat = "TradesDone",  PuckReward = 3000,  GemReward = 1,  GuaranteedRarity = nil },
	{ Id = "weekly_trades_5",   Desc = "Complete 5 trades",          Target = 5,   Stat = "TradesDone",  PuckReward = 6000,  GemReward = 3,  GuaranteedRarity = nil },
	{ Id = "weekly_trades_10",  Desc = "Complete 10 trades",         Target = 10,  Stat = "TradesDone",  PuckReward = 12000, GemReward = 5,  GuaranteedRarity = nil },

	-- Selling
	{ Id = "weekly_sell_10",    Desc = "Sell 10 cards",              Target = 10,  Stat = "CardsSold",   PuckReward = 2000,  GemReward = 1,  GuaranteedRarity = nil },
	{ Id = "weekly_sell_20",    Desc = "Sell 20 cards",              Target = 20,  Stat = "CardsSold",   PuckReward = 4000,  GemReward = 2,  GuaranteedRarity = nil },
	{ Id = "weekly_sell_50",    Desc = "Sell 50 cards",              Target = 50,  Stat = "CardsSold",   PuckReward = 9000,  GemReward = 3,  GuaranteedRarity = nil },

	-- Earning pucks
	{ Id = "weekly_earn_5000",  Desc = "Earn 5,000 Pucks",           Target = 5000,  Stat = "PucksEarned", PuckReward = 2000,  GemReward = 1, GuaranteedRarity = nil },
	{ Id = "weekly_earn_20000", Desc = "Earn 20,000 Pucks",          Target = 20000, Stat = "PucksEarned", PuckReward = 7000,  GemReward = 3, GuaranteedRarity = nil },
}

-- ──────────────────────────────────────────────────────────────
-- DAILY LOGIN REWARDS (30-day rolling calendar)
-- ──────────────────────────────────────────────────────────────
CardDatabase.LoginRewards = {
	[1]  = { Pucks = 100,  Gems = 0,  GuaranteedRarity = nil },
	[2]  = { Pucks = 150,  Gems = 0,  GuaranteedRarity = nil },
	[3]  = { Pucks = 200,  Gems = 1,  GuaranteedRarity = nil },
	[4]  = { Pucks = 200,  Gems = 0,  GuaranteedRarity = nil },
	[5]  = { Pucks = 300,  Gems = 1,  GuaranteedRarity = nil },
	[6]  = { Pucks = 300,  Gems = 0,  GuaranteedRarity = nil },
	[7]  = { Pucks = 500,  Gems = 2,  GuaranteedRarity = "Rare" },
	[8]  = { Pucks = 200,  Gems = 0,  GuaranteedRarity = nil },
	[9]  = { Pucks = 250,  Gems = 1,  GuaranteedRarity = nil },
	[10] = { Pucks = 300,  Gems = 2,  GuaranteedRarity = nil },
	[11] = { Pucks = 300,  Gems = 0,  GuaranteedRarity = nil },
	[12] = { Pucks = 400,  Gems = 1,  GuaranteedRarity = nil },
	[13] = { Pucks = 400,  Gems = 0,  GuaranteedRarity = nil },
	[14] = { Pucks = 800,  Gems = 3,  GuaranteedRarity = "Rare" },
	[15] = { Pucks = 300,  Gems = 1,  GuaranteedRarity = nil },
	[16] = { Pucks = 350,  Gems = 0,  GuaranteedRarity = nil },
	[17] = { Pucks = 400,  Gems = 2,  GuaranteedRarity = nil },
	[18] = { Pucks = 400,  Gems = 0,  GuaranteedRarity = nil },
	[19] = { Pucks = 500,  Gems = 2,  GuaranteedRarity = nil },
	[20] = { Pucks = 500,  Gems = 0,  GuaranteedRarity = nil },
	[21] = { Pucks = 1000, Gems = 5,  GuaranteedRarity = "Rare" },
	[22] = { Pucks = 400,  Gems = 1,  GuaranteedRarity = nil },
	[23] = { Pucks = 450,  Gems = 2,  GuaranteedRarity = nil },
	[24] = { Pucks = 500,  Gems = 2,  GuaranteedRarity = nil },
	[25] = { Pucks = 500,  Gems = 3,  GuaranteedRarity = nil },
	[26] = { Pucks = 600,  Gems = 3,  GuaranteedRarity = nil },
	[27] = { Pucks = 600,  Gems = 3,  GuaranteedRarity = nil },
	[28] = { Pucks = 700,  Gems = 5,  GuaranteedRarity = nil },
	[29] = { Pucks = 800,  Gems = 5,  GuaranteedRarity = nil },
	[30] = { Pucks = 2000, Gems = 10, GuaranteedRarity = "Epic" },
}

-- ──────────────────────────────────────────────────────────────
-- GAMEPASS IDs  (replace with real IDs after creation)
-- ──────────────────────────────────────────────────────────────
CardDatabase.GamepassIds = {
	AutoOpener    = 0,
	LuckySkates   = 0,
	VIPLockerRoom = 0,
	VaultExpansion= 0,
	FastBreak     = 0,
}

CardDatabase.GamepassBenefits = {
	AutoOpener    = { AutoOpen = true },
	LuckySkates   = { LuckMultiplier = 1.5 },
	VIPLockerRoom = { LuckMultiplier = 2.0, BonusDailyPucks = 500, VIPTag = true },
	VaultExpansion= { ExtraSlots = 500 },
	FastBreak     = { AnimationSpeed = 2.0 },
}

-- ──────────────────────────────────────────────────────────────
-- DEVELOPER PRODUCT IDs  (replace with real IDs after creation)
-- ──────────────────────────────────────────────────────────────
CardDatabase.DevProducts = {
	Pucks1000  = { Id = 3591026662, Pucks = 1000,  Gems = 0 },
	Pucks5000  = { Id = 3591026785, Pucks = 5000,  Gems = 0 },
	Pucks25000 = { Id = 3591027009, Pucks = 25000, Gems = 0 },
	Gems50     = { Id = 3591028431, Pucks = 0,     Gems = 50 },
	Gems200    = { Id = 3591028613, Pucks = 0,     Gems = 200 },
	LuckPotion = { Id = 0, Pucks = 0,     Gems = 0,  LuckBoost = { Duration = 1800, Multiplier = 1.5 } },
}

-- ──────────────────────────────────────────────────────────────
-- PITY SYSTEM CONFIG
-- ──────────────────────────────────────────────────────────────
CardDatabase.PityConfig = {
	RareGuaranteeAfter      = 5,
	EpicGuaranteeAfter      = 20,
	LegendaryGuaranteeAfter = 50,
	MythicGuaranteeAfter    = 100,
}

-- ──────────────────────────────────────────────────────────────
-- UTILITY: total collectible card count (for collection %)
-- ──────────────────────────────────────────────────────────────
function CardDatabase.GetTotalCollectibleCards()
	-- Each player can appear as each rarity (8) — this is the theoretical max
	return #CardDatabase.Players * 8
end

return CardDatabase