-- Shared configuration for the clicking simulator.
-- Used by both the server (authoritative logic) and the client (UI display).
-- Modeled after pet-collection clicker sims (e.g. Rebirth Champions Ultimate):
-- click for coins, hatch eggs for pets that multiply your earnings, fuse
-- duplicate pets into stronger Golden versions, and rebirth for a permanent
-- multiplier plus more pet-equip slots.

local GameConfig = {}

GameConfig.StartingClickPower = 1
GameConfig.ClickCooldown = 0.08 -- seconds; server-side anti-exploit throttle

GameConfig.Upgrades = {
	{
		Id = "ClickPower1",
		Name = "Better Clicks",
		Description = "+1 coin per click",
		BaseCost = 10,
		CostMultiplier = 1.15,
		ClickPowerAdd = 1,
	},
	{
		Id = "ClickPower2",
		Name = "Power Gloves",
		Description = "+5 coins per click",
		BaseCost = 100,
		CostMultiplier = 1.17,
		ClickPowerAdd = 5,
	},
	{
		Id = "ClickPower3",
		Name = "Mega Clicker",
		Description = "+25 coins per click",
		BaseCost = 1000,
		CostMultiplier = 1.2,
		ClickPowerAdd = 25,
	},
	{
		Id = "ClickPower4",
		Name = "Ultra Fist",
		Description = "+150 coins per click",
		BaseCost = 15000,
		CostMultiplier = 1.22,
		ClickPowerAdd = 150,
	},
}

GameConfig.AutoClickers = {
	{
		Id = "Auto1",
		Name = "Clicking Bot",
		Description = "+1 coin/second",
		BaseCost = 50,
		CostMultiplier = 1.15,
		CoinsPerSecond = 1,
	},
	{
		Id = "Auto2",
		Name = "Clicking Drone",
		Description = "+5 coins/second",
		BaseCost = 500,
		CostMultiplier = 1.17,
		CoinsPerSecond = 5,
	},
	{
		Id = "Auto3",
		Name = "Clicking Factory",
		Description = "+25 coins/second",
		BaseCost = 5000,
		CostMultiplier = 1.2,
		CoinsPerSecond = 25,
	},
	{
		Id = "Auto4",
		Name = "Clicking Megaplex",
		Description = "+150 coins/second",
		BaseCost = 75000,
		CostMultiplier = 1.22,
		CoinsPerSecond = 150,
	},
}

GameConfig.Rebirth = {
	BaseRequirement = 10000,
	RequirementMultiplier = 3,
	MultiplierPerRebirth = 0.5, -- +50% coin gain per rebirth
}

-- ===== Pets & eggs =====

GameConfig.BaseMaxEquippedPets = 3
GameConfig.FusionRequirement = 5 -- duplicate (non-Golden) pets needed to fuse into a Golden pet

GameConfig.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

GameConfig.RarityColors = {
	Common = Color3.fromRGB(190, 190, 200),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 80, 100),
}

GameConfig.Eggs = {
	{
		Id = "BasicEgg",
		Name = "Basic Egg",
		Cost = 100,
		RequiredRebirths = 0,
		Pets = {
			{ Name = "Puppy", Rarity = "Common", Weight = 50, Multiplier = 1.1 },
			{ Name = "Kitten", Rarity = "Common", Weight = 50, Multiplier = 1.15 },
			{ Name = "Fox", Rarity = "Rare", Weight = 25, Multiplier = 1.5 },
			{ Name = "Wolf", Rarity = "Rare", Weight = 20, Multiplier = 1.6 },
			{ Name = "Dragon", Rarity = "Epic", Weight = 8, Multiplier = 2.5 },
			{ Name = "Phoenix", Rarity = "Legendary", Weight = 2, Multiplier = 6 },
		},
	},
	{
		Id = "GoldenEgg",
		Name = "Golden Egg",
		Cost = 25000,
		RequiredRebirths = 1,
		Pets = {
			{ Name = "Golden Retriever", Rarity = "Rare", Weight = 40, Multiplier = 2 },
			{ Name = "Griffin", Rarity = "Epic", Weight = 30, Multiplier = 3.5 },
			{ Name = "Unicorn", Rarity = "Epic", Weight = 20, Multiplier = 4 },
			{ Name = "Ancient Dragon", Rarity = "Legendary", Weight = 8, Multiplier = 10 },
			{ Name = "Celestial Phoenix", Rarity = "Mythic", Weight = 2, Multiplier = 25 },
		},
	},
}

-- Works for both Upgrades and AutoClickers since they share BaseCost/CostMultiplier.
function GameConfig.GetCost(item, currentLevel)
	return math.floor(item.BaseCost * (item.CostMultiplier ^ currentLevel))
end

function GameConfig.GetRebirthRequirement(rebirthCount)
	return math.floor(GameConfig.Rebirth.BaseRequirement * (GameConfig.Rebirth.RequirementMultiplier ^ rebirthCount))
end

function GameConfig.GetRebirthMultiplier(rebirthCount)
	return 1 + (rebirthCount * GameConfig.Rebirth.MultiplierPerRebirth)
end

function GameConfig.GetMaxEquippedPets(rebirthCount)
	return GameConfig.BaseMaxEquippedPets + rebirthCount
end

-- Weighted random pet roll from an egg's pet pool.
function GameConfig.RollPet(egg)
	local totalWeight = 0
	for _, pet in ipairs(egg.Pets) do
		totalWeight += pet.Weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, pet in ipairs(egg.Pets) do
		cumulative += pet.Weight
		if roll <= cumulative then
			return pet
		end
	end

	return egg.Pets[#egg.Pets]
end

-- Multiplicative stack of every equipped pet's multiplier.
function GameConfig.GetPetMultiplierTotal(equippedPets)
	local total = 1
	for _, pet in ipairs(equippedPets) do
		total *= pet.Multiplier
	end
	return total
end

return GameConfig
