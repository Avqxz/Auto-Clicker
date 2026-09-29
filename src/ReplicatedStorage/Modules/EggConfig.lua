-- Eggs and hatching settings. Everything about hatching is data-driven from here:
--
-- Adding an egg: add an entry to EggConfig.Eggs, then give a pedestal in the world the egg's Id
-- (MapBuilder does this for the art package's egg stands; any other part works too: set its
-- attribute EggId = "<Id>" and tag it "EggPedestal"). Pets need no other setup; a pet with an art
-- model or icon gets one through GameConfig.PetArt.
--
-- Egg fields:
--   Id, Name                 unique id and display name
--   Cost, Currency           price per egg; Currency is a key of EggConfig.Currencies
--   RequiredRebirths         Ascensions needed to hatch it
--   Zone                     the island it stands on
--   Model                    name of the egg model in the world (used for the egg UI and hatch animation)
--   HatchAnywhere            hatch from the Eggs menu without walking to the pedestal (Auto Hatch always
--                            needs the player at the pedestal)
--   Aura                     glow and particles around the pedestal egg
--   Pets                     { Name, Rarity, Multiplier, and Weight or Chance }. Weights are relative;
--                            Chance is a percentage. Either way they are normalized, so they don't
--                            need to add up to 100.
local EggConfig = {}

EggConfig.Currencies = {
	Coins = { Name = "Coins", Icon = "💰" },
	Gems = { Name = "Gems", Icon = "💎" },
	Tokens = { Name = "Tokens", Icon = "🎟️" },
}

EggConfig.Eggs = {
	{
		Id = "StarterEgg",
		Name = "Starter Egg",
		Cost = 60,
		Currency = "Coins",
		RequiredRebirths = 0,
		Zone = "Lobby",
		Model = "EggBody_Lobby",
		HatchAnywhere = true,
		Pets = {
			{ Name = "Puppy", Rarity = "Common", Weight = 40, Multiplier = 1.1 },
			{ Name = "Bunny", Rarity = "Common", Weight = 32, Multiplier = 1.1 },
			{ Name = "Fox", Rarity = "Unique", Weight = 20, Multiplier = 1.25 },
			{ Name = "Bee", Rarity = "Rare", Weight = 6, Multiplier = 2 },
			{ Name = "Leaf Dragon", Rarity = "Epic", Weight = 1.7, Multiplier = 3.5 },
			{ Name = "Crowned Stag", Rarity = "Legendary", Weight = 0.3, Multiplier = 8 },
		},
	},
	{
		Id = "GrasslandsEgg",
		Name = "Grasslands Egg",
		Cost = 15000,
		Currency = "Coins",
		RequiredRebirths = 1,
		Zone = "Grasslands",
		Model = "EggBody_Grasslands",
		Aura = true,
		Pets = {
			{ Name = "Bee", Rarity = "Rare", Weight = 45, Multiplier = 2 },
			{ Name = "Leaf Dragon", Rarity = "Epic", Weight = 35, Multiplier = 3.5 },
			{ Name = "Crowned Stag", Rarity = "Legendary", Weight = 17, Multiplier = 8 },
			{ Name = "World Tree Guardian", Rarity = "Secret", Weight = 3, Multiplier = 25 },
		},
	},
	{
		Id = "DesertEgg",
		Name = "Desert Egg",
		Cost = 80000,
		Currency = "Coins",
		RequiredRebirths = 2,
		Zone = "Desert",
		Model = "EggBody_Desert",
		Aura = true,
		Pets = {
			{ Name = "Camel", Rarity = "Common", Weight = 30, Multiplier = 2.5 },
			{ Name = "Cobra", Rarity = "Unique", Weight = 28, Multiplier = 2.75 },
			{ Name = "Scorpion", Rarity = "Rare", Weight = 18, Multiplier = 3.75 },
			{ Name = "Fennec", Rarity = "Rare", Weight = 14, Multiplier = 4.5 },
			{ Name = "Scarab", Rarity = "Epic", Weight = 7, Multiplier = 7.5 },
			{ Name = "Sphinx", Rarity = "Legendary", Weight = 2.5, Multiplier = 17.5 },
			{ Name = "Sandclock Colossus", Rarity = "Secret", Weight = 0.5, Multiplier = 45 },
		},
	},
	{
		Id = "IceEgg",
		Name = "Ice Egg",
		Cost = 300000,
		Currency = "Coins",
		RequiredRebirths = 3,
		Zone = "Ice",
		Model = "EggBody_Ice",
		Aura = true,
		Pets = {
			{ Name = "Penguin", Rarity = "Common", Weight = 30, Multiplier = 4 },
			{ Name = "Polar Cub", Rarity = "Unique", Weight = 28, Multiplier = 4.4 },
			{ Name = "Snow Bunny", Rarity = "Rare", Weight = 18, Multiplier = 6 },
			{ Name = "Ice Wolf", Rarity = "Rare", Weight = 14, Multiplier = 7.2 },
			{ Name = "Frost Dragon", Rarity = "Epic", Weight = 7, Multiplier = 12 },
			{ Name = "Aurora Owl", Rarity = "Legendary", Weight = 2.5, Multiplier = 28 },
			{ Name = "Frozen TV", Rarity = "Secret", Weight = 0.5, Multiplier = 72 },
		},
	},
	{
		Id = "EnchantedEgg",
		Name = "Enchanted Egg",
		Cost = 1200000,
		Currency = "Coins",
		RequiredRebirths = 4,
		Zone = "Enchanted",
		Model = "EggBody_Enchanted",
		Aura = true,
		Pets = {
			{ Name = "Fairy Cat", Rarity = "Common", Weight = 30, Multiplier = 6.5 },
			{ Name = "Mushroom", Rarity = "Unique", Weight = 28, Multiplier = 7.15 },
			{ Name = "Crystal Bunny", Rarity = "Rare", Weight = 18, Multiplier = 9.75 },
			{ Name = "Spirit Fox", Rarity = "Rare", Weight = 14, Multiplier = 11.7 },
			{ Name = "Mystic Dragon", Rarity = "Epic", Weight = 7, Multiplier = 19.5 },
			{ Name = "Crystal Deer", Rarity = "Legendary", Weight = 2.5, Multiplier = 45.5 },
			{ Name = "Moon Mask", Rarity = "Secret", Weight = 0.5, Multiplier = 117 },
		},
	},
	{
		Id = "VolcanoEgg",
		Name = "Volcano Egg",
		Cost = 5000000,
		Currency = "Coins",
		RequiredRebirths = 5,
		Zone = "Volcano",
		Model = "EggBody_Volcano",
		Aura = true,
		Pets = {
			{ Name = "Lava Pup", Rarity = "Common", Weight = 30, Multiplier = 10 },
			{ Name = "Fire Bat", Rarity = "Unique", Weight = 28, Multiplier = 11 },
			{ Name = "Ember Lizard", Rarity = "Rare", Weight = 18, Multiplier = 15 },
			{ Name = "Demon", Rarity = "Rare", Weight = 14, Multiplier = 18 },
			{ Name = "Magma Golem", Rarity = "Epic", Weight = 7, Multiplier = 30 },
			{ Name = "Phoenix", Rarity = "Legendary", Weight = 2.5, Multiplier = 70 },
			{ Name = "Infernal Chest", Rarity = "Secret", Weight = 0.5, Multiplier = 180 },
		},
	},
	{
		Id = "CandyEgg",
		Name = "Candy Egg",
		Cost = 20000000,
		Currency = "Coins",
		RequiredRebirths = 6,
		Zone = "Candy",
		Model = "EggBody_Candy",
		Aura = true,
		Pets = {
			{ Name = "Cupcake", Rarity = "Common", Weight = 30, Multiplier = 16 },
			{ Name = "Marshmallow", Rarity = "Unique", Weight = 28, Multiplier = 17.6 },
			{ Name = "Gummy Bear", Rarity = "Rare", Weight = 18, Multiplier = 24 },
			{ Name = "Donut", Rarity = "Rare", Weight = 14, Multiplier = 28.8 },
			{ Name = "Candy Dog", Rarity = "Epic", Weight = 7, Multiplier = 48 },
			{ Name = "Cake Dragon", Rarity = "Legendary", Weight = 2.5, Multiplier = 112 },
			{ Name = "Chocolate Chicken", Rarity = "Secret", Weight = 0.5, Multiplier = 288 },
		},
	},
	{
		Id = "CelestialEgg",
		Name = "Celestial Egg",
		Cost = 150000000,
		Currency = "Coins",
		RequiredRebirths = 8,
		Zone = "Celestial",
		Model = "EggBody_Celestial",
		Aura = true,
		Pets = {
			{ Name = "Star Pup", Rarity = "Common", Weight = 30, Multiplier = 26 },
			{ Name = "Cosmic Cat", Rarity = "Unique", Weight = 28, Multiplier = 28.6 },
			{ Name = "Star Sprite", Rarity = "Rare", Weight = 18, Multiplier = 39 },
			{ Name = "Angel", Rarity = "Rare", Weight = 14, Multiplier = 46.8 },
			{ Name = "Void Ray", Rarity = "Epic", Weight = 7, Multiplier = 78 },
			{ Name = "Celestial Dragon", Rarity = "Legendary", Weight = 2.5, Multiplier = 182 },
			{ Name = "Orbit Guardian", Rarity = "Secret", Weight = 0.5, Multiplier = 468 },
		},
	},
}

-- Hatch options. An unlock is { Pass = "<GamePasses key>" } and/or { Rebirths = n }; owning the pass
-- OR having the Ascensions unlocks it. An empty table means always unlocked.
EggConfig.TripleHatchUnlock = { Pass = "TripleHatch" }
EggConfig.AutoHatchUnlock = { Pass = "AutoHatch", Rebirths = 1 }

EggConfig.HatchCooldown = 0.8 -- seconds between hatches (halved by Fast Hatch)
EggConfig.ProximityRange = 16 -- studs from a pedestal at which its egg UI opens
EggConfig.ServerRange = 40 -- studs the server allows (lenient: the player may be moving)
EggConfig.AutoHatchDelay = 0.25 -- seconds between the end of one auto hatch and the next request
EggConfig.SkipMinDelay = 0.45 -- the hatch animation can be skipped/sped up after this many seconds
EggConfig.AnnounceMinRarity = "Legendary" -- server-wide announcements for this tier and rarer
EggConfig.AnnounceShiny = true -- also announce every Shiny hatch

-- Keyboard shortcuts (Enum.KeyCode names). Shown on the buttons for keyboard players.
EggConfig.Keys = { Hatch1 = "E", Hatch3 = "R", Auto = "T", Skip = "Space" }

-- Luck. Total luck multiplies each pet's weight by luck ^ (its rarity's LuckPower, see PetConfig),
-- then the chances are renormalized, so rare pets gain the most and nothing goes negative.
--   total = (1 + skill + pet abilities) x pass x boosts x server event, capped at MaxLuck
EggConfig.Luck = {
	SkillPerLevel = 0.1, -- Egg Luck skill
	Pass = "Lucky",
	PassMultiplier = 1.5,
	BoostKey = "Luck", -- data.Boosts key of the 2x Luck boost (Token Shop and dev product)
	BoostMultiplier = 2,
	ServerAttribute = "ServerLuck", -- ReplicatedStorage attribute set by the server for events
	MaxLuck = 25,
}

-- Shiny: a rare sparkling variant of any pet, rolled after the pet. Chance rises with luck ^ LuckPower.
EggConfig.Shiny = {
	BaseChance = 1 / 250,
	LuckPower = 0.5,
	MaxChance = 0.05,
	Multiplier = 1.5, -- Shiny pets are this much stronger
}

-- Hatch sounds (GameConfig.Sounds keys) and ids.
EggConfig.Sounds = {
	Hover = { Id = "rbxassetid://88442833509532", Volume = 0.08, Pitch = 1.4 },
	Click = { Id = "rbxassetid://88442833509532", Volume = 0.2 },
	Purchase = { Id = "rbxassetid://139719503904449", Volume = 0.35 },
	Shake = { Id = "rbxassetid://88442833509532", Volume = 0.3, Pitch = 0.6 },
	Crack = { Id = "rbxassetid://9113959343", Volume = 0.5 },
	Reveal = { Id = "rbxassetid://140323850218372", Volume = 0.45 },
	RevealLegendary = { Id = "rbxassetid://1839881844", Volume = 0.45 },
	RevealSecret = { Id = "rbxassetid://1845411858", Volume = 0.5 },
	Error = { Id = "rbxassetid://88442833509532", Volume = 0.3, Pitch = 0.5 },
}

EggConfig.ById = {}
for _, egg in ipairs(EggConfig.Eggs) do
	egg.Currency = egg.Currency or "Coins"
	EggConfig.ById[egg.Id] = egg
end

return EggConfig
