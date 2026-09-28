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
	{
		Id = "ClickPower5",
		Name = "Titan Strike",
		Description = "+800 coins per click",
		BaseCost = 200000,
		CostMultiplier = 1.24,
		ClickPowerAdd = 800,
	},
	{
		Id = "ClickPower6",
		Name = "Colossus Punch",
		Description = "+5,000 coins per click",
		BaseCost = 3000000,
		CostMultiplier = 1.26,
		ClickPowerAdd = 5000,
	},
	{
		Id = "ClickPower7",
		Name = "Godly Tap",
		Description = "+35,000 coins per click",
		BaseCost = 50000000,
		CostMultiplier = 1.28,
		ClickPowerAdd = 35000,
	},
}

-- ===== Click feel: combo, crits =====
-- Consecutive clicks within the combo window build a combo; higher combos multiply every click.
-- Crits roll per click. All of this is computed on the server (see handleClick).

GameConfig.Combo = {
	BaseWindow = 1.0, -- seconds allowed between clicks before the combo resets
	Tiers = { -- first tier whose MinCombo the combo count reaches (checked from the top)
		{ MinCombo = 200, Name = "OVERDRIVE", Multiplier = 3, Color = Color3.fromRGB(255, 96, 48) },
		{ MinCombo = 100, Name = "x2", Multiplier = 2, Color = Color3.fromRGB(255, 190, 40) },
		{ MinCombo = 50, Name = "x1.5", Multiplier = 1.5, Color = Color3.fromRGB(180, 110, 255) },
		{ MinCombo = 25, Name = "x1.25", Multiplier = 1.25, Color = Color3.fromRGB(80, 200, 255) },
		{ MinCombo = 0, Name = "x1", Multiplier = 1, Color = Color3.fromRGB(255, 255, 255) },
	},
}

GameConfig.Crit = {
	BaseChance = 0.05,
	BaseDamage = 2,
}

GameConfig.HoldClicksPerSecond = 5 -- holding the CLICK button; kept below fast manual clicking

-- Click boosts share UpgradeLevels with the click-power upgrades, so they reset on rebirth too.
GameConfig.ClickBoosts = {
	{
		Id = "CritChance",
		Name = "Critical Chance",
		BaseCost = 150,
		CostMultiplier = 1.35,
		MaxLevel = 25,
		PerLevel = 0.01,
	},
	{
		Id = "CritDamage",
		Name = "Critical Damage",
		BaseCost = 400,
		CostMultiplier = 1.3,
		MaxLevel = 40,
		PerLevel = 0.1,
	},
	{
		Id = "ComboWindow",
		Name = "Combo Duration",
		BaseCost = 250,
		CostMultiplier = 1.4,
		MaxLevel = 15,
		PerLevel = 0.1,
	},
}

function GameConfig.GetCritChance(levels)
	return GameConfig.Crit.BaseChance + (levels.CritChance or 0) * GameConfig.ClickBoosts[1].PerLevel
end

function GameConfig.GetCritDamage(levels)
	return GameConfig.Crit.BaseDamage + (levels.CritDamage or 0) * GameConfig.ClickBoosts[2].PerLevel
end

function GameConfig.GetComboWindow(levels)
	return GameConfig.Combo.BaseWindow + (levels.ComboWindow or 0) * GameConfig.ClickBoosts[3].PerLevel
end

function GameConfig.GetComboTier(comboCount)
	for _, tier in ipairs(GameConfig.Combo.Tiers) do
		if comboCount >= tier.MinCombo then
			return tier
		end
	end
	return GameConfig.Combo.Tiers[#GameConfig.Combo.Tiers]
end

-- "current → next" text for a click boost at `level`.
function GameConfig.DescribeBoost(item, level)
	local function value(l)
		local levels = { [item.Id] = l }
		if item.Id == "CritChance" then
			return string.format("%d%%", math.floor(GameConfig.GetCritChance(levels) * 100 + 0.5))
		elseif item.Id == "CritDamage" then
			return string.format("%.1fx", GameConfig.GetCritDamage(levels))
		end
		return string.format("%.1f sec", GameConfig.GetComboWindow(levels))
	end
	if level >= item.MaxLevel then
		return value(level) .. " (MAX)"
	end
	return value(level) .. " → " .. value(level + 1)
end

GameConfig.AutoClickers = {
	{
		Id = "Auto1",
		Name = "Clicking Bot",
		Description = "+2 coins/second",
		BaseCost = 25,
		CostMultiplier = 1.15,
		CoinsPerSecond = 2,
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

-- One-time choice of starting pet, offered to new players on their first join.
GameConfig.StarterPets = {
	{ Name = "Cat", Rarity = "Common", Multiplier = 1.1 },
	{ Name = "Dog", Rarity = "Common", Multiplier = 1.1 },
	{ Name = "Bunny", Rarity = "Common", Multiplier = 1.1 },
}

GameConfig.Rebirth = {
	BaseRequirement = 1500,
	RequirementMultiplier = 3,
	MultiplierPerRebirth = 1, -- +50% coin gain per rebirth
}

-- ===== Zones =====
-- Biome zones laid out in a line and linked by walkways. Each walkway ends in
-- a gate that stays solid for players below the zone's RequiredRebirths.
-- Zone eggs can only be hatched while standing near them (EggHatchRange).

GameConfig.Zones = {
	{ Id = "Forest", Name = "Forest", RequiredRebirths = 0 },
	{ Id = "Ice", Name = "Ice World", RequiredRebirths = 1 },
	{ Id = "Lava", Name = "Lava World", RequiredRebirths = 2 },
	{ Id = "Candy", Name = "Candy World", RequiredRebirths = 3 },
	{ Id = "Space", Name = "Space World", RequiredRebirths = 5 },
}

GameConfig.EggHatchRange = 40 -- studs; eggs outside the starting zone must be hatched in person

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
		Cost = 60,
		RequiredRebirths = 0,
		Zone = "Forest",
		Pets = {
			{ Name = "Puppy", Rarity = "Common", Weight = 50, Multiplier = 1.1 },
			{ Name = "Kitten", Rarity = "Common", Weight = 50, Multiplier = 1.15 },
			{ Name = "Fox", Rarity = "Rare", Weight = 25, Multiplier = 1.5 },
			{ Name = "Wolf", Rarity = "Rare", Weight = 20, Multiplier = 1.8 },
			{ Name = "Dragon", Rarity = "Epic", Weight = 8, Multiplier = 2.5 },
			{ Name = "Phoenix", Rarity = "Legendary", Weight = 2, Multiplier = 6 },
		},
	},
	{
		Id = "GoldenEgg",
		Name = "Golden Egg",
		Cost = 25000,
		RequiredRebirths = 1,
		Zone = "Ice",
		Pets = {
			{ Name = "Golden Retriever", Rarity = "Rare", Weight = 40, Multiplier = 2 },
			{ Name = "Griffin", Rarity = "Epic", Weight = 30, Multiplier = 3.5 },
			{ Name = "Unicorn", Rarity = "Epic", Weight = 20, Multiplier = 4 },
			{ Name = "Ancient Dragon", Rarity = "Legendary", Weight = 8, Multiplier = 10 },
			{ Name = "Celestial Phoenix", Rarity = "Mythic", Weight = 2, Multiplier = 25 },
		},
	},
	{
		Id = "LavaEgg",
		Name = "Lava Egg",
		Cost = 250000,
		RequiredRebirths = 2,
		Zone = "Lava",
		Pets = {
			{ Name = "Lava Pup", Rarity = "Rare", Weight = 40, Multiplier = 3 },
			{ Name = "Magma Golem", Rarity = "Epic", Weight = 30, Multiplier = 5 },
			{ Name = "Fire Serpent", Rarity = "Epic", Weight = 20, Multiplier = 6 },
			{ Name = "Inferno Dragon", Rarity = "Legendary", Weight = 8, Multiplier = 15 },
			{ Name = "Volcano Titan", Rarity = "Mythic", Weight = 2, Multiplier = 40 },
		},
	},
	{
		Id = "CandyEgg",
		Name = "Candy Egg",
		Cost = 3000000,
		RequiredRebirths = 3,
		Zone = "Candy",
		Pets = {
			{ Name = "Gummy Bear", Rarity = "Rare", Weight = 40, Multiplier = 5 },
			{ Name = "Lollipop Cat", Rarity = "Epic", Weight = 30, Multiplier = 9 },
			{ Name = "Cupcake Unicorn", Rarity = "Epic", Weight = 20, Multiplier = 11 },
			{ Name = "Candy Dragon", Rarity = "Legendary", Weight = 8, Multiplier = 28 },
			{ Name = "Sugar Queen", Rarity = "Mythic", Weight = 2, Multiplier = 75 },
		},
	},
	{
		Id = "SpaceEgg",
		Name = "Space Egg",
		Cost = 40000000,
		RequiredRebirths = 5,
		Zone = "Space",
		Pets = {
			{ Name = "Alien", Rarity = "Rare", Weight = 40, Multiplier = 9 },
			{ Name = "Astro Dog", Rarity = "Epic", Weight = 30, Multiplier = 16 },
			{ Name = "Nebula Fox", Rarity = "Epic", Weight = 20, Multiplier = 20 },
			{ Name = "Galaxy Dragon", Rarity = "Legendary", Weight = 8, Multiplier = 50 },
			{ Name = "Cosmic Overlord", Rarity = "Mythic", Weight = 2, Multiplier = 140 },
		},
	},
}

-- Works for both Upgrades and AutoClickers since they share BaseCost/CostMultiplier.
function GameConfig.GetCost(item, currentLevel)
	return math.floor(item.BaseCost * (item.CostMultiplier ^ currentLevel))
end

-- Total cost of buying `count` levels starting at `currentLevel`.
function GameConfig.GetBulkCost(item, currentLevel, count)
	local total = 0
	for i = 0, count - 1 do
		total += GameConfig.GetCost(item, currentLevel + i)
	end
	return total
end

-- How many levels (capped at `cap`) can be bought with `coins`, and what they cost.
function GameConfig.GetMaxAffordable(item, currentLevel, coins, cap)
	local count, total = 0, 0
	while count < cap do
		local nextCost = GameConfig.GetCost(item, currentLevel + count)
		if total + nextCost > coins then
			break
		end
		total += nextCost
		count += 1
	end
	return count, total
end

function GameConfig.GetRebirthRequirement(rebirthCount)
	return math.floor(GameConfig.Rebirth.BaseRequirement * (GameConfig.Rebirth.RequirementMultiplier ^ rebirthCount))
end

function GameConfig.GetRebirthMultiplier(rebirthCount)
	return 1 + (rebirthCount * GameConfig.Rebirth.MultiplierPerRebirth)
end

function GameConfig.GetMaxEquippedPets(rebirthCount)
	return math.min(GameConfig.MaxEquippedPets, GameConfig.BaseMaxEquippedPets + rebirthCount)
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

GameConfig.MaxPets = 200
GameConfig.MaxEquippedPets = 8
GameConfig.MaxCurrency = 1e100
GameConfig.MaxUpgradeLevel = 250
GameConfig.HatchCooldown = 0.8
GameConfig.AutosaveSeconds = 60
GameConfig.LeaderboardRefreshSeconds = 120
GameConfig.Sounds = {Click="rbxassetid://88442833509532", Purchase="rbxassetid://139719503904449", Rare="rbxassetid://1839881844"}
return GameConfig
