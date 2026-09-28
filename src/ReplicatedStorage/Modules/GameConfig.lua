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

-- `skills` (the player's skill-tree levels) is optional everywhere below.
-- `gear` is GameConfig.GetGearStats(data); both it and `skills` are optional.
function GameConfig.GetCritChance(levels, skills, gear)
	return GameConfig.Crit.BaseChance + (levels.CritChance or 0) * GameConfig.ClickBoosts[1].PerLevel
		+ GameConfig.GetSkillLevel(skills, "CritMastery") * 0.01
		+ (gear and gear.CritChance or 0)
end

function GameConfig.GetCritDamage(levels, skills, gear)
	return GameConfig.Crit.BaseDamage + (levels.CritDamage or 0) * GameConfig.ClickBoosts[2].PerLevel
		+ GameConfig.GetSkillLevel(skills, "MegaCrits") * 0.25
		+ (gear and gear.CritDamage or 0)
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

-- The tier's multiplier with the Combo Boost skill, which grows only the bonus part (x2 -> x2.2 at level 1).
function GameConfig.GetComboMultiplier(comboCount, skills)
	local bonus = GameConfig.GetComboTier(comboCount).Multiplier - 1
	return 1 + bonus * (1 + 0.2 * GameConfig.GetSkillLevel(skills, "ComboBoost"))
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

-- Players see this as "Ascension"; the save keeps the original RebirthCount field.
GameConfig.Rebirth = {
	BaseRequirement = 1500,
	RequirementMultiplier = 3,
	MultiplierPerRebirth = 1, -- +100% coin gain per Ascension
	BaseGems = 10, -- Gems for ascending at exactly the requirement on the first Ascension
}

-- ===== Skill tree (bought with Gems, never reset) =====
-- Each node's effect is applied where that stat is computed (click power, crits, combo, auto
-- income, offline earnings, egg luck, equip slots, fusion). Requires = another node at level >= 1.

GameConfig.Skills = {
	{ Id = "ClickMastery", Branch = "Power", Name = "Click Mastery", MaxLevel = 10, BaseCost = 5, CostGrowth = 1.5,
		Effect = function(l) return "+" .. (l * 10) .. "% click power" end },
	{ Id = "CritMastery", Branch = "Power", Name = "Crit Mastery", MaxLevel = 5, BaseCost = 10, CostGrowth = 1.6, Requires = "ClickMastery",
		Effect = function(l) return "+" .. l .. "% crit chance" end },
	{ Id = "MegaCrits", Branch = "Power", Name = "Mega Crits", MaxLevel = 5, BaseCost = 15, CostGrowth = 1.6, Requires = "CritMastery",
		Effect = function(l) return "+" .. string.format("%.2f", l * 0.25) .. "x crit damage" end },
	{ Id = "ComboBoost", Branch = "Power", Name = "Combo Boost", MaxLevel = 5, BaseCost = 10, CostGrowth = 1.6, Requires = "ClickMastery",
		Effect = function(l) return "+" .. (l * 20) .. "% combo bonus" end },
	{ Id = "AutoPower", Branch = "Automation", Name = "Auto Power", MaxLevel = 10, BaseCost = 5, CostGrowth = 1.5,
		Effect = function(l) return "+" .. (l * 20) .. "% auto-clicker income" end },
	{ Id = "OfflineEarnings", Branch = "Automation", Name = "Offline Earnings", MaxLevel = 5, BaseCost = 12, CostGrowth = 1.7, Requires = "AutoPower",
		Effect = function(l) return (l * 10) .. "% of auto income while offline (8h max)" end },
	{ Id = "HeadStart", Branch = "Automation", Name = "Head Start", MaxLevel = 5, BaseCost = 8, CostGrowth = 1.7, Requires = "AutoPower",
		Effect = function(l) return "Start each Ascension with " .. (500 * l * l) .. " coins" end },
	{ Id = "EggLuck", Branch = "Luck", Name = "Egg Luck", MaxLevel = 10, BaseCost = 5, CostGrowth = 1.5,
		Effect = function(l) return "+" .. (l * 10) .. "% odds for non-Common pets" end },
	{ Id = "PetSlots", Branch = "Luck", Name = "Pet Slots", MaxLevel = 2, BaseCost = 25, CostGrowth = 2.5, Requires = "EggLuck",
		Effect = function(l) return "+" .. l .. " pet equip slot" .. (l == 1 and "" or "s") end },
	{ Id = "GoldenTouch", Branch = "Luck", Name = "Golden Touch", MaxLevel = 4, BaseCost = 12, CostGrowth = 1.7, Requires = "EggLuck",
		Effect = function(l) return "Golden fusions give x" .. string.format("%.2f", 2 + 0.25 * l) end },
}
GameConfig.SkillBranches = { "Power", "Automation", "Luck" }
GameConfig.OfflineCapSeconds = 8 * 60 * 60

function GameConfig.GetSkill(id)
	for _, node in ipairs(GameConfig.Skills) do
		if node.Id == id then
			return node
		end
	end
	return nil
end

function GameConfig.GetSkillLevel(skills, id)
	return skills and skills[id] or 0
end

function GameConfig.GetSkillCost(node, level)
	return math.floor(node.BaseCost * node.CostGrowth ^ level)
end

-- Gems for ascending now: more if you overshoot the requirement, and more each Ascension.
function GameConfig.GetAscensionGems(coins, rebirthCount)
	local ratio = math.max(1, coins / GameConfig.GetRebirthRequirement(rebirthCount))
	return math.floor(GameConfig.Rebirth.BaseGems * math.sqrt(ratio) * (1 + 0.5 * rebirthCount))
end

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

-- ===== Retention: daily rewards, quests, offline earnings =====
-- Days/weeks are UTC (os.time); weeks start Monday. Daily quests are the same for everyone on a
-- given day (picked from the pool with the day as the seed); weekly quests likewise per week.

GameConfig.OfflineBaseRate = 0.05 -- share of auto income earned while offline, before the skill

-- Day 7 is the top of the streak; claiming after it starts over at day 1. Missing a day resets.
-- Coins rewards are a share of the player's current Ascension requirement, so they stay useful.
GameConfig.DailyRewards = {
	{ Gems = 5 },
	{ CoinsPct = 0.25 },
	{ Gems = 10 },
	{ CoinsPct = 0.5 },
	{ Gems = 15 },
	{ CoinsPct = 1 },
	{ Gems = 40 },
}

GameConfig.QuestsPerPeriod = 3
GameConfig.QuestPool = {
	-- Kind is what the server tracks: Click, Hatch, HatchLegendary (Legendary or better), BossWin,
	-- Ascend, Upgrade (levels bought), Combo (highest combo reached, not a running total).
	Daily = {
		{ Id = "d_click", Kind = "Click", Target = 3000, Text = "Click 3,000 times", Gems = 6 },
		{ Id = "d_hatch", Kind = "Hatch", Target = 10, Text = "Hatch 10 eggs", Gems = 6 },
		{ Id = "d_boss", Kind = "BossWin", Target = 2, Text = "Defeat 2 bosses", Gems = 8 },
		{ Id = "d_combo", Kind = "Combo", Target = 100, Text = "Reach a 100x combo", Gems = 5 },
		{ Id = "d_upgrade", Kind = "Upgrade", Target = 25, Text = "Buy 25 upgrade levels", Gems = 5 },
		{ Id = "d_ascend", Kind = "Ascend", Target = 1, Text = "Ascend once", Gems = 8 },
	},
	Weekly = {
		{ Id = "w_click", Kind = "Click", Target = 25000, Text = "Click 25,000 times", Gems = 35 },
		{ Id = "w_ascend", Kind = "Ascend", Target = 5, Text = "Ascend 5 times", Gems = 50 },
		{ Id = "w_boss", Kind = "BossWin", Target = 15, Text = "Defeat 15 bosses", Gems = 45 },
		{ Id = "w_legendary", Kind = "HatchLegendary", Target = 3, Text = "Hatch 3 Legendary+ pets", Gems = 50 },
		{ Id = "w_hatch", Kind = "Hatch", Target = 100, Text = "Hatch 100 eggs", Gems = 35 },
	},
}

function GameConfig.GetDayIndex(t)
	return math.floor((t or os.time()) / 86400)
end

function GameConfig.GetWeekIndex(t)
	return math.floor(((t or os.time()) - 4 * 86400) / 604800) -- Unix time 0 was a Thursday; shift to Monday
end

function GameConfig.GetQuestDef(group, id)
	for _, quest in ipairs(GameConfig.QuestPool[group]) do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

-- The period's quest ids, picked from the pool with the period index as the seed.
function GameConfig.PickQuests(group, periodIndex)
	local pool = table.clone(GameConfig.QuestPool[group])
	local rng = Random.new(periodIndex * 7919 + (if group == "Weekly" then 1 else 0))
	local picked = {}
	for _ = 1, math.min(GameConfig.QuestsPerPeriod, #pool) do
		local quest = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(picked, quest.Id)
	end
	return picked
end

-- The streak day (1-7) the next claim would be, and whether it can be claimed today.
function GameConfig.GetDailyRewardState(daily, now)
	local today = GameConfig.GetDayIndex(now)
	local last = daily and daily.LastClaimDay or -1
	local streak = daily and daily.Streak or 0
	if last == today then
		return streak, false
	end
	local nextDay = if last == today - 1 then streak % #GameConfig.DailyRewards + 1 else 1
	return nextDay, true
end

-- ===== Bosses & equipment =====
-- Each zone has a boss at its far end. Fights are personal and timed: while a player is fighting,
-- their clicks deal damage (same power/combo/crit math) instead of earning coins. Winning pays
-- coins + Gems and drops one of the boss's four gear pieces.

GameConfig.BossFightSeconds = 60
GameConfig.BossWinCooldown = 90
GameConfig.BossLossCooldown = 10
GameConfig.BossRange = 70 -- studs; clicks only hit the boss while this close
GameConfig.MaxGearItems = 40

GameConfig.Bosses = {
	{ Zone = "Forest", Id = "Mossback", Name = "MOSSBACK", Health = 3000, RewardCoins = 1200, RewardGems = 2, Rarity = "Common" },
	{ Zone = "Ice", Id = "FrostGolem", Name = "FROST GOLEM", Health = 40000, RewardCoins = 15000, RewardGems = 4, Rarity = "Rare" },
	{ Zone = "Lava", Id = "MagmaKing", Name = "MAGMA KING", Health = 600000, RewardCoins = 200000, RewardGems = 8, Rarity = "Epic" },
	{ Zone = "Candy", Id = "GummyTyrant", Name = "GUMMY TYRANT", Health = 10000000, RewardCoins = 3000000, RewardGems = 15, Rarity = "Legendary" },
	{ Zone = "Space", Id = "VoidTitan", Name = "VOID TITAN", Health = 250000000, RewardCoins = 60000000, RewardGems = 30, Rarity = "Mythic" },
}

GameConfig.GearSlots = { "Gloves", "Aura", "Core", "Artifact" }

-- Stats: ClickPower (+x click power), CritChance, CritDamage, AutoPower (+x auto income),
-- Burst = { Every, Multiplier, Name }: every Nth click is multiplied.
GameConfig.Gear = {
	{ Id = "LeafGloves", Boss = "Mossback", Slot = "Gloves", Name = "Leaf Gloves", Stats = { ClickPower = 0.15 } },
	{ Id = "SproutAura", Boss = "Mossback", Slot = "Aura", Name = "Sprout Aura", Stats = { CritChance = 0.02 } },
	{ Id = "AcornCore", Boss = "Mossback", Slot = "Core", Name = "Acorn Core", Stats = { AutoPower = 0.2 } },
	{ Id = "MossyCharm", Boss = "Mossback", Slot = "Artifact", Name = "Mossy Charm", Stats = { CritDamage = 0.2 } },

	{ Id = "FrostGloves", Boss = "FrostGolem", Slot = "Gloves", Name = "Frost Gloves", Stats = { ClickPower = 0.35, CritChance = 0.01 } },
	{ Id = "BlizzardAura", Boss = "FrostGolem", Slot = "Aura", Name = "Blizzard Aura", Stats = { CritChance = 0.04 } },
	{ Id = "GlacierCore", Boss = "FrostGolem", Slot = "Core", Name = "Glacier Core", Stats = { AutoPower = 0.5 } },
	{ Id = "SnowflakeRelic", Boss = "FrostGolem", Slot = "Artifact", Name = "Snowflake Relic", Stats = { CritDamage = 0.4 } },

	{ Id = "MagmaGloves", Boss = "MagmaKing", Slot = "Gloves", Name = "Magma Gloves", Stats = { ClickPower = 0.7 } },
	{ Id = "InfernoAura", Boss = "MagmaKing", Slot = "Aura", Name = "Inferno Aura", Stats = { CritChance = 0.06, CritDamage = 0.2 } },
	{ Id = "VolcanicCore", Boss = "MagmaKing", Slot = "Core", Name = "Volcanic Core", Stats = { AutoPower = 1 } },
	{ Id = "EmberIdol", Boss = "MagmaKing", Slot = "Artifact", Name = "Ember Idol",
		Stats = { CritDamage = 0.3, Burst = { Every = 100, Multiplier = 5, Name = "EMBER BURST" } } },

	{ Id = "SugarGloves", Boss = "GummyTyrant", Slot = "Gloves", Name = "Sugar Gloves", Stats = { ClickPower = 1.2, CritChance = 0.02 } },
	{ Id = "SprinkleAura", Boss = "GummyTyrant", Slot = "Aura", Name = "Sprinkle Aura", Stats = { CritChance = 0.08 } },
	{ Id = "GumdropCore", Boss = "GummyTyrant", Slot = "Core", Name = "Gumdrop Core", Stats = { AutoPower = 1.8 } },
	{ Id = "LollipopTotem", Boss = "GummyTyrant", Slot = "Artifact", Name = "Lollipop Totem", Stats = { CritDamage = 1 } },

	{ Id = "QuantumGloves", Boss = "VoidTitan", Slot = "Gloves", Name = "Quantum Gloves",
		Stats = { ClickPower = 2, CritChance = 0.08, Burst = { Every = 100, Multiplier = 10, Name = "QUANTUM BURST" } } },
	{ Id = "NebulaAura", Boss = "VoidTitan", Slot = "Aura", Name = "Nebula Aura", Stats = { CritChance = 0.12, CritDamage = 0.5 } },
	{ Id = "StarCore", Boss = "VoidTitan", Slot = "Core", Name = "Star Core", Stats = { AutoPower = 3 } },
	{ Id = "VoidArtifact", Boss = "VoidTitan", Slot = "Artifact", Name = "Void Artifact", Stats = { CritDamage = 1.5 } },
}

function GameConfig.GetBoss(id)
	for _, boss in ipairs(GameConfig.Bosses) do
		if boss.Id == id then
			return boss
		end
	end
	return nil
end

function GameConfig.GetGear(id)
	for _, item in ipairs(GameConfig.Gear) do
		if item.Id == id then
			return item
		end
	end
	return nil
end

-- Rarity of a gear piece = its boss's rarity.
function GameConfig.GetGearRarity(item)
	local boss = GameConfig.GetBoss(item.Boss)
	return boss and boss.Rarity or "Common"
end

-- Summed stats of the equipped gear (data.Gear = { Items = { {Uid, Id} }, Equipped = { [slot] = uid } }).
function GameConfig.GetGearStats(data)
	local total = { ClickPower = 0, CritChance = 0, CritDamage = 0, AutoPower = 0, Bursts = {} }
	local gear = data and data.Gear
	if not gear then
		return total
	end
	for _, uid in pairs(gear.Equipped or {}) do
		for _, owned in ipairs(gear.Items or {}) do
			if owned.Uid == uid then
				local item = GameConfig.GetGear(owned.Id)
				if item then
					for stat, value in pairs(item.Stats) do
						if stat == "Burst" then
							table.insert(total.Bursts, value)
						else
							total[stat] += value
						end
					end
				end
			end
		end
	end
	return total
end

-- One-line stat summary for UI, e.g. "+35% click • +1% crit".
function GameConfig.DescribeGear(item)
	local parts = {}
	local st = item.Stats
	if st.ClickPower then table.insert(parts, "+" .. math.floor(st.ClickPower * 100 + 0.5) .. "% click") end
	if st.CritChance then table.insert(parts, "+" .. math.floor(st.CritChance * 100 + 0.5) .. "% crit") end
	if st.CritDamage then table.insert(parts, "+" .. string.format("%.1f", st.CritDamage) .. "x crit dmg") end
	if st.AutoPower then table.insert(parts, "+" .. math.floor(st.AutoPower * 100 + 0.5) .. "% auto") end
	if st.Burst then table.insert(parts, st.Burst.Name .. ": every " .. st.Burst.Every .. " clicks x" .. st.Burst.Multiplier) end
	return table.concat(parts, " • ")
end

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

function GameConfig.GetMaxEquippedPets(rebirthCount, skills)
	return math.min(GameConfig.MaxEquippedPets, GameConfig.BaseMaxEquippedPets + rebirthCount)
		+ GameConfig.GetSkillLevel(skills, "PetSlots")
end

-- Weighted random pet roll from an egg's pet pool. Egg Luck scales up every non-Common weight.
function GameConfig.RollPet(egg, skills)
	local luck = 1 + 0.1 * GameConfig.GetSkillLevel(skills, "EggLuck")
	local function weight(pet)
		return if pet.Rarity == "Common" then pet.Weight else pet.Weight * luck
	end
	local totalWeight = 0
	for _, pet in ipairs(egg.Pets) do
		totalWeight += weight(pet)
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, pet in ipairs(egg.Pets) do
		cumulative += weight(pet)
		if roll <= cumulative then
			return pet
		end
	end

	return egg.Pets[#egg.Pets]
end

-- Coins per click before combo/crit: base x pets x Ascension x Click Mastery x gear.
function GameConfig.GetClickPower(data, equippedPets)
	return data.ClickPower * GameConfig.GetPetMultiplierTotal(equippedPets)
		* GameConfig.GetRebirthMultiplier(data.RebirthCount)
		* (1 + 0.1 * GameConfig.GetSkillLevel(data.Skills, "ClickMastery"))
		* (1 + GameConfig.GetGearStats(data).ClickPower)
end

-- Coins per second from auto-clickers: base x pets x Ascension x Auto Power.
function GameConfig.GetAutoIncome(data, equippedPets)
	local perSecond = 0
	for _, auto in ipairs(GameConfig.AutoClickers) do
		perSecond += (data.AutoClickerLevels[auto.Id] or 0) * auto.CoinsPerSecond
	end
	return perSecond * GameConfig.GetPetMultiplierTotal(equippedPets)
		* GameConfig.GetRebirthMultiplier(data.RebirthCount)
		* (1 + 0.2 * GameConfig.GetSkillLevel(data.Skills, "AutoPower"))
		* (1 + GameConfig.GetGearStats(data).AutoPower)
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
