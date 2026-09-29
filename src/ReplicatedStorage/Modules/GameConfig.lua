-- Shared configuration for the clicking simulator.
-- Used by both the server (authoritative logic) and the client (UI display).
-- Modeled after pet-collection clicker sims (e.g. Rebirth Champions Ultimate):
-- click for Power, hatch eggs (bought with Coins) for pets that multiply your earnings, fuse
-- duplicate pets into stronger Golden versions, and rebirth for a permanent
-- multiplier plus more pet-equip slots.

local EggConfig = require(script.Parent.EggConfig)
local PetConfig = require(script.Parent.PetConfig)

local GameConfig = {}

GameConfig.StartingClickPower = 1
GameConfig.ClickCooldown = 0.08 -- seconds; server-side anti-exploit throttle

GameConfig.Upgrades = {
	{
		Id = "ClickPower1",
		Name = "Better Clicks",
		Description = "+1 Power per click",
		BaseCost = 10,
		CostMultiplier = 1.15,
		ClickPowerAdd = 1,
	},
	{
		Id = "ClickPower2",
		Name = "Power Gloves",
		Description = "+5 Power per click",
		BaseCost = 100,
		CostMultiplier = 1.17,
		ClickPowerAdd = 5,
	},
	{
		Id = "ClickPower3",
		Name = "Mega Clicker",
		Description = "+25 Power per click",
		BaseCost = 1000,
		CostMultiplier = 1.2,
		ClickPowerAdd = 25,
	},
	{
		Id = "ClickPower4",
		Name = "Ultra Fist",
		Description = "+150 Power per click",
		BaseCost = 15000,
		CostMultiplier = 1.22,
		ClickPowerAdd = 150,
	},
	{
		Id = "ClickPower5",
		Name = "Titan Strike",
		Description = "+800 Power per click",
		BaseCost = 200000,
		CostMultiplier = 1.24,
		ClickPowerAdd = 800,
	},
	{
		Id = "ClickPower6",
		Name = "Colossus Punch",
		Description = "+5,000 Power per click",
		BaseCost = 3000000,
		CostMultiplier = 1.26,
		ClickPowerAdd = 5000,
	},
	{
		Id = "ClickPower7",
		Name = "Godly Tap",
		Description = "+35,000 Power per click",
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
-- `bonus` is GameConfig.GetBonusStats(data, equippedPets) (gear + pet abilities); it and `skills`
-- are optional.
function GameConfig.GetCritChance(levels, skills, bonus)
	return GameConfig.Crit.BaseChance + (levels.CritChance or 0) * GameConfig.ClickBoosts[1].PerLevel
		+ GameConfig.GetSkillLevel(skills, "CritMastery") * 0.01
		+ (bonus and bonus.CritChance or 0)
end

function GameConfig.GetCritDamage(levels, skills, bonus)
	return GameConfig.Crit.BaseDamage + (levels.CritDamage or 0) * GameConfig.ClickBoosts[2].PerLevel
		+ GameConfig.GetSkillLevel(skills, "MegaCrits") * 0.25
		+ (bonus and bonus.CritDamage or 0)
end

function GameConfig.GetComboWindow(levels, bonus)
	return GameConfig.Combo.BaseWindow + (levels.ComboWindow or 0) * GameConfig.ClickBoosts[3].PerLevel
		+ (bonus and bonus.ComboWindow or 0)
end

function GameConfig.GetComboTier(comboCount)
	for _, tier in ipairs(GameConfig.Combo.Tiers) do
		if comboCount >= tier.MinCombo then
			return tier
		end
	end
	return GameConfig.Combo.Tiers[#GameConfig.Combo.Tiers]
end

-- The tier's multiplier with Combo Boost (skill) and combo-bonus abilities, which grow only the bonus
-- part (x2 -> x2.2 with Combo Boost 1).
function GameConfig.GetComboMultiplier(comboCount, skills, bonus)
	local extra = GameConfig.GetComboTier(comboCount).Multiplier - 1
	return 1 + extra * (1 + 0.2 * GameConfig.GetSkillLevel(skills, "ComboBoost") + (bonus and bonus.ComboBonus or 0))
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
		Description = "+2 Power/second",
		BaseCost = 25,
		CostMultiplier = 1.15,
		PowerPerSecond = 2,
	},
	{
		Id = "Auto2",
		Name = "Clicking Drone",
		Description = "+5 Power/second",
		BaseCost = 500,
		CostMultiplier = 1.17,
		PowerPerSecond = 5,
	},
	{
		Id = "Auto3",
		Name = "Clicking Factory",
		Description = "+25 Power/second",
		BaseCost = 5000,
		CostMultiplier = 1.2,
		PowerPerSecond = 25,
	},
	{
		Id = "Auto4",
		Name = "Clicking Megaplex",
		Description = "+150 Power/second",
		BaseCost = 75000,
		CostMultiplier = 1.22,
		PowerPerSecond = 150,
	},
}

-- One-time choice of starting pet, offered to new players on their first join.
GameConfig.StarterPets = {
	{ Name = "Puppy", Rarity = "Common", Multiplier = 1.1 },
	{ Name = "Bunny", Rarity = "Common", Multiplier = 1.1 },
	{ Name = "Fox", Rarity = "Common", Multiplier = 1.1 },
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
		Effect = function(l) return "Start each Ascension with " .. (500 * l * l) .. " Power" end },
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
function GameConfig.GetAscensionGems(power, rebirthCount)
	local ratio = math.max(1, power / GameConfig.GetRebirthRequirement(rebirthCount))
	return math.floor(GameConfig.Rebirth.BaseGems * math.sqrt(ratio) * (1 + 0.5 * rebirthCount))
end

-- ===== Zones =====
-- The art package's islands: a lobby and seven biomes joined by bridges. Each bridge has a gate that
-- stays solid for players below the next zone's RequiredRebirths.
-- Zone eggs can only be hatched while standing near them (EggHatchRange).

GameConfig.Zones = {
	{ Id = "Lobby", Name = "Lobby", RequiredRebirths = 0 },
	{ Id = "Grasslands", Name = "Grasslands", RequiredRebirths = 1 },
	{ Id = "Desert", Name = "Desert", RequiredRebirths = 2 },
	{ Id = "Ice", Name = "Ice Peaks", RequiredRebirths = 3 },
	{ Id = "Enchanted", Name = "Enchanted Forest", RequiredRebirths = 4 },
	{ Id = "Volcano", Name = "Volcano", RequiredRebirths = 5 },
	{ Id = "Candy", Name = "Candy Land", RequiredRebirths = 6 },
	{ Id = "Celestial", Name = "Celestial Heaven", RequiredRebirths = 8 },
}

GameConfig.EggHatchRange = 40 -- studs; eggs outside the starting zone must be hatched in person

-- ===== Retention: daily rewards, quests, offline earnings =====
-- Days/weeks are UTC (os.time); weeks start Monday. Daily quests are the same for everyone on a
-- given day (picked from the pool with the day as the seed); weekly quests likewise per week.

GameConfig.OfflineBaseRate = 0.05 -- share of auto income earned while offline, before the skill

-- Day 7 is the top of the streak; claiming after it starts over at day 1. Missing a day resets.
-- Coins rewards are a share of the player's current Ascension requirement, so they stay useful.
-- Day 7 also pays Tokens.
GameConfig.DailyRewards = {
	{ Gems = 5 },
	{ CoinsPct = 0.25 },
	{ Gems = 10 },
	{ CoinsPct = 0.5 },
	{ Gems = 15 },
	{ CoinsPct = 1 },
	{ Gems = 40, Tokens = 10 },
}

GameConfig.QuestsPerPeriod = 3
GameConfig.QuestPool = {
	-- Kind is what the server tracks: Click, Hatch, HatchLegendary (Legendary or better), BossWin,
	-- Ascend, Upgrade (levels bought), Combo (highest combo reached, not a running total).
	Daily = {
		{ Id = "d_click", Kind = "Click", Target = 3000, Text = "Click 3,000 times", Gems = 6, Tokens = 1 },
		{ Id = "d_hatch", Kind = "Hatch", Target = 10, Text = "Hatch 10 eggs", Gems = 6, Tokens = 1 },
		{ Id = "d_boss", Kind = "BossWin", Target = 2, Text = "Defeat 2 bosses", Gems = 8, Tokens = 1 },
		{ Id = "d_combo", Kind = "Combo", Target = 100, Text = "Reach a 100x combo", Gems = 5, Tokens = 1 },
		{ Id = "d_upgrade", Kind = "Upgrade", Target = 25, Text = "Buy 25 upgrade levels", Gems = 5, Tokens = 1 },
		{ Id = "d_ascend", Kind = "Ascend", Target = 1, Text = "Ascend once", Gems = 8, Tokens = 1 },
	},
	Weekly = {
		{ Id = "w_click", Kind = "Click", Target = 25000, Text = "Click 25,000 times", Gems = 35, Tokens = 5 },
		{ Id = "w_ascend", Kind = "Ascend", Target = 5, Text = "Ascend 5 times", Gems = 50, Tokens = 5 },
		{ Id = "w_boss", Kind = "BossWin", Target = 15, Text = "Defeat 15 bosses", Gems = 45, Tokens = 5 },
		{ Id = "w_legendary", Kind = "HatchLegendary", Target = 3, Text = "Hatch 3 Legendary+ pets", Gems = 50, Tokens = 5 },
		{ Id = "w_hatch", Kind = "Hatch", Target = 100, Text = "Hatch 100 eggs", Gems = 35, Tokens = 5 },
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

-- ===== Currencies: Power, Coins, Gems, Tokens, Essence =====
-- Power: from clicking/auto-clickers; buys upgrades and auto-clickers; needed to Ascend (resets).
-- Coins: from bosses, quests, daily rewards and selling Power; buys eggs (resets on Ascension).
-- Gems: from Ascending, bosses and quests; buys skills (kept).
-- Tokens: from quests and the day-7 streak; buys timed boosts in the Token Shop (kept).
-- Essence: from bosses and salvaging gear; upgrades gear (kept).

-- Coins per Power when selling; improves with each Ascension.
function GameConfig.GetSellRate(rebirthCount)
	return 1 + 0.1 * rebirthCount
end

GameConfig.TokenShop = {
	{ Id = "PowerBoost", Boost = "Power", Name = "2x Power", Description = "Double Power from clicks and auto-clickers", Minutes = 15, Cost = 10 },
	{ Id = "LuckBoost", Boost = "Luck", Name = "2x Luck", Description = "Double odds for non-Common pets", Minutes = 15, Cost = 10 },
}
GameConfig.BoostMaxMinutes = 60 -- buying again extends a running boost, up to this much time left

-- 2 while the boost is running (data.Boosts[kind] = os.time it ends), else 1.
function GameConfig.GetBoostMultiplier(data, kind, now)
	local ends = data and data.Boosts and data.Boosts[kind]
	return if ends and ends > (now or os.time()) then 2 else 1
end

-- Gear upgrading with Essence: each level adds 20% to every stat (bursts unchanged).
GameConfig.GearMaxLevel = 5
GameConfig.GearUpgradeCost = { Common = 5, Rare = 10, Epic = 20, Legendary = 40, Mythic = 80 } -- x (level + 1)
GameConfig.GearSalvageValue = { Common = 3, Rare = 6, Epic = 12, Legendary = 25, Mythic = 50 }

function GameConfig.GetGearLevelScale(level)
	return 1 + 0.2 * (level or 0)
end

function GameConfig.GetGearUpgradeCost(item, level)
	return GameConfig.GearUpgradeCost[GameConfig.GetGearRarity(item)] * ((level or 0) + 1)
end

-- Essence back from salvaging: the base value plus half of what was spent upgrading it.
function GameConfig.GetGearSalvageValue(item, level)
	local spent = 0
	for l = 0, (level or 0) - 1 do
		spent += GameConfig.GetGearUpgradeCost(item, l)
	end
	return GameConfig.GearSalvageValue[GameConfig.GetGearRarity(item)] + math.floor(spent / 2)
end

-- ===== Monetization =====
-- Paste the IDs from the Creator Dashboard (Monetization > Passes / Developer Products). An Id of 0
-- means "not set up": the item is hidden from players (Studio shows it as "ID not set").
-- Everything here is convenience or speed; nothing is required to progress.

GameConfig.GamePasses = {
	{ Key = "AutoClick", Id = 0, Name = "Auto Click", Description = "Adds an AUTO toggle that clicks for you" },
	{ Key = "TripleHatch", Id = 0, Name = "Triple Hatch", Description = "Hatch 3 eggs at once" },
	{ Key = "AutoHatch", Id = 0, Name = "Auto Hatch", Description = "Hatch eggs automatically (free after your first Ascension)" },
	{ Key = "PetSlots", Id = 0, Name = "+3 Pet Equip", Description = "Equip 3 more pets" },
	{ Key = "Lucky", Id = 0, Name = "Lucky", Description = "x1.5 odds for non-Common pets, forever" },
	{ Key = "FastHatch", Id = 0, Name = "Fast Hatch", Description = "Hatch twice as fast" },
	{ Key = "VIP", Id = 0, Name = "VIP", Description = "+10% Power, +10% Coins, VIP chat tag, +5 Gems per daily reward, VIP aura" },
}

GameConfig.DevProducts = {
	{ Key = "PowerBoost15", Id = 0, Name = "2x Power (15 min)", Boost = "Power", Minutes = 15 },
	{ Key = "LuckBoost15", Id = 0, Name = "2x Luck (15 min)", Boost = "Luck", Minutes = 15 },
	{ Key = "BossRetry", Id = 0, Name = "Instant Boss Retry", Description = "Clears every boss cooldown" },
	{ Key = "TokenPack", Id = 0, Name = "Token Pack", Description = "+25 Tokens", Tokens = 25 },
}

GameConfig.AutoClickPerSecond = 5
GameConfig.PaidBoostMaxMinutes = 180 -- paid boosts can stack further than Token Shop ones
GameConfig.VIPBonus = 0.1 -- +10% Power and Coins
GameConfig.VIPDailyGems = 5

-- data.Passes is refreshed from Roblox on every join ({ [Key] = true }).
function GameConfig.HasPass(data, key)
	return data ~= nil and data.Passes ~= nil and data.Passes[key] == true
end

-- ===== Bosses & equipment =====
-- Each zone has a boss at its far end. Fights are personal and timed: while a player is fighting,
-- their clicks deal damage (same power/combo/crit math) instead of earning Power. Winning pays
-- Coins, Gems and Essence and drops one of the boss's four gear pieces.

GameConfig.BossFightSeconds = 60
GameConfig.BossWinCooldown = 90
GameConfig.BossLossCooldown = 10
GameConfig.BossRange = 70 -- studs; clicks only hit the boss while this close
GameConfig.MaxGearItems = 40

-- Model = the pet whose model is scaled up for the boss. Ids of the original five bosses are kept so
-- gear already in saves still belongs to a boss.
GameConfig.Bosses = {
	{ Zone = "Grasslands", Id = "Mossback", Name = "STAG KING", Model = "Crowned Stag", Health = 3000, RewardCoins = 1200, RewardGems = 2, RewardEssence = 1, Rarity = "Common" },
	{ Zone = "Desert", Id = "Sphinx", Name = "GREAT SPHINX", Model = "Sphinx", Health = 20000, RewardCoins = 8000, RewardGems = 3, RewardEssence = 2, Rarity = "Common" },
	{ Zone = "Ice", Id = "FrostGolem", Name = "AURORA OWL", Model = "Aurora Owl", Health = 80000, RewardCoins = 30000, RewardGems = 4, RewardEssence = 3, Rarity = "Rare" },
	{ Zone = "Enchanted", Id = "CrystalDeer", Name = "CRYSTAL DEER", Model = "Crystal Deer", Health = 400000, RewardCoins = 150000, RewardGems = 6, RewardEssence = 5, Rarity = "Rare" },
	{ Zone = "Volcano", Id = "MagmaKing", Name = "PHOENIX LORD", Model = "Phoenix", Health = 1500000, RewardCoins = 600000, RewardGems = 8, RewardEssence = 6, Rarity = "Epic" },
	{ Zone = "Candy", Id = "GummyTyrant", Name = "CAKE DRAGON", Model = "Cake Dragon", Health = 10000000, RewardCoins = 3000000, RewardGems = 15, RewardEssence = 12, Rarity = "Legendary" },
	{ Zone = "Celestial", Id = "VoidTitan", Name = "CELESTIAL DRAGON", Model = "Celestial Dragon", Health = 250000000, RewardCoins = 60000000, RewardGems = 30, RewardEssence = 25, Rarity = "Mythic" },
}

GameConfig.GearSlots = { "Gloves", "Aura", "Core", "Artifact" }

-- Stats: ClickPower (+x click power), CritChance, CritDamage, AutoPower (+x auto income),
-- Burst = { Every, Multiplier, Name }: every Nth click is multiplied.
GameConfig.Gear = {
	{ Id = "LeafGloves", Boss = "Mossback", Slot = "Gloves", Name = "Leaf Gloves", Stats = { ClickPower = 0.15 } },
	{ Id = "SproutAura", Boss = "Mossback", Slot = "Aura", Name = "Sprout Aura", Stats = { CritChance = 0.02 } },
	{ Id = "AcornCore", Boss = "Mossback", Slot = "Core", Name = "Acorn Core", Stats = { AutoPower = 0.2 } },
	{ Id = "MossyCharm", Boss = "Mossback", Slot = "Artifact", Name = "Mossy Charm", Stats = { CritDamage = 0.2 } },

	{ Id = "SandGloves", Boss = "Sphinx", Slot = "Gloves", Name = "Sand Gloves", Stats = { ClickPower = 0.25 } },
	{ Id = "MirageAura", Boss = "Sphinx", Slot = "Aura", Name = "Mirage Aura", Stats = { CritChance = 0.03 } },
	{ Id = "ScarabCore", Boss = "Sphinx", Slot = "Core", Name = "Scarab Core", Stats = { AutoPower = 0.35 } },
	{ Id = "SunAmulet", Boss = "Sphinx", Slot = "Artifact", Name = "Sun Amulet", Stats = { CritDamage = 0.3 } },

	{ Id = "FrostGloves", Boss = "FrostGolem", Slot = "Gloves", Name = "Frost Gloves", Stats = { ClickPower = 0.35, CritChance = 0.01 } },
	{ Id = "BlizzardAura", Boss = "FrostGolem", Slot = "Aura", Name = "Blizzard Aura", Stats = { CritChance = 0.04 } },
	{ Id = "GlacierCore", Boss = "FrostGolem", Slot = "Core", Name = "Glacier Core", Stats = { AutoPower = 0.5 } },
	{ Id = "SnowflakeRelic", Boss = "FrostGolem", Slot = "Artifact", Name = "Snowflake Relic", Stats = { CritDamage = 0.4 } },

	{ Id = "CrystalGloves", Boss = "CrystalDeer", Slot = "Gloves", Name = "Crystal Gloves", Stats = { ClickPower = 0.5, CritChance = 0.01 } },
	{ Id = "FairyAura", Boss = "CrystalDeer", Slot = "Aura", Name = "Fairy Aura", Stats = { CritChance = 0.05 } },
	{ Id = "MoonstoneCore", Boss = "CrystalDeer", Slot = "Core", Name = "Moonstone Core", Stats = { AutoPower = 0.75 } },
	{ Id = "MysticCharm", Boss = "CrystalDeer", Slot = "Artifact", Name = "Mystic Charm", Stats = { CritDamage = 0.5 } },

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
					local scale = GameConfig.GetGearLevelScale(owned.Level)
					for stat, value in pairs(item.Stats) do
						if stat == "Burst" then
							table.insert(total.Bursts, value)
						else
							total[stat] += value * scale
						end
					end
				end
			end
		end
	end
	return total
end

-- One-line stat summary for UI at a given upgrade level, e.g. "+35% click • +1% crit".
function GameConfig.DescribeGear(item, level)
	local parts = {}
	local st = item.Stats
	local k = GameConfig.GetGearLevelScale(level)
	if st.ClickPower then table.insert(parts, "+" .. math.floor(st.ClickPower * k * 100 + 0.5) .. "% click") end
	if st.CritChance then table.insert(parts, "+" .. string.format("%g", math.floor(st.CritChance * k * 1000 + 0.5) / 10) .. "% crit") end
	if st.CritDamage then table.insert(parts, "+" .. string.format("%.2f", st.CritDamage * k) .. "x crit dmg") end
	if st.AutoPower then table.insert(parts, "+" .. math.floor(st.AutoPower * k * 100 + 0.5) .. "% auto") end
	if st.Burst then table.insert(parts, st.Burst.Name .. ": every " .. st.Burst.Every .. " clicks x" .. st.Burst.Multiplier) end
	return table.concat(parts, " • ")
end

-- ===== Pets & eggs =====

GameConfig.BaseMaxEquippedPets = 3
GameConfig.FusionRequirement = 5 -- duplicate (non-Golden) pets needed to fuse into a Golden pet

GameConfig.RarityOrder = {}
GameConfig.RarityColors = {}
for _, tier in ipairs(PetConfig.Rarities) do
	table.insert(GameConfig.RarityOrder, tier.Id)
	GameConfig.RarityColors[tier.Id] = tier.Color
end

-- Eggs, hatch odds and hatch settings live in EggConfig; rarity tiers in PetConfig.
GameConfig.Eggs = EggConfig.Eggs

-- Pet name -> its model in ReplicatedStorage.ArtPets (from the art package), its biome, and its rendered
-- icon (uploaded image, shown on pet cards). PetModelFactory falls back to a cube pet in the biome's
-- colors if the model isn't imported.
GameConfig.PetArt = {
	["Puppy"] = { Model = "Pet_Grasslands_Puppy", Biome = "Grasslands", Icon = "rbxassetid://103846961680644" },
	["Bunny"] = { Model = "Pet_Grasslands_Bunny", Biome = "Grasslands", Icon = "rbxassetid://128121022364568" },
	["Bee"] = { Model = "Pet_Grasslands_Bee", Biome = "Grasslands", Icon = "rbxassetid://111756269027018" },
	["Fox"] = { Model = "Pet_Grasslands_Fox", Biome = "Grasslands", Icon = "rbxassetid://73661426520357" },
	["Leaf Dragon"] = { Model = "Pet_Grasslands_LeafDragon", Biome = "Grasslands", Icon = "rbxassetid://82112157321350" },
	["Crowned Stag"] = { Model = "Pet_Grasslands_CrownedStag", Biome = "Grasslands", Icon = "rbxassetid://76024431754536" },
	["World Tree Guardian"] = { Model = "Pet_Grasslands_WorldTreeGuardian", Biome = "Grasslands", Icon = "rbxassetid://109837610531088" },
	["Camel"] = { Model = "Pet_Desert_Camel", Biome = "Desert", Icon = "rbxassetid://109947294993165" },
	["Cobra"] = { Model = "Pet_Desert_Cobra", Biome = "Desert", Icon = "rbxassetid://78323012044742" },
	["Scorpion"] = { Model = "Pet_Desert_Scorpion", Biome = "Desert", Icon = "rbxassetid://107957695943317" },
	["Fennec"] = { Model = "Pet_Desert_Fennec", Biome = "Desert", Icon = "rbxassetid://121584564209762" },
	["Scarab"] = { Model = "Pet_Desert_Scarab", Biome = "Desert", Icon = "rbxassetid://85912978382430" },
	["Sphinx"] = { Model = "Pet_Desert_Sphinx", Biome = "Desert", Icon = "rbxassetid://118098140986504" },
	["Sandclock Colossus"] = { Model = "Pet_Desert_SandclockColossus", Biome = "Desert", Icon = "rbxassetid://113643259682568" },
	["Penguin"] = { Model = "Pet_Ice_Penguin", Biome = "Ice", Icon = "rbxassetid://129203863609859" },
	["Polar Cub"] = { Model = "Pet_Ice_PolarCub", Biome = "Ice", Icon = "rbxassetid://125625734909186" },
	["Snow Bunny"] = { Model = "Pet_Ice_SnowBunny", Biome = "Ice", Icon = "rbxassetid://71235331544698" },
	["Ice Wolf"] = { Model = "Pet_Ice_IceWolf", Biome = "Ice", Icon = "rbxassetid://102556498341035" },
	["Frost Dragon"] = { Model = "Pet_Ice_FrostDragon", Biome = "Ice", Icon = "rbxassetid://120130519760005" },
	["Aurora Owl"] = { Model = "Pet_Ice_AuroraOwl", Biome = "Ice", Icon = "rbxassetid://137994648550726" },
	["Frozen TV"] = { Model = "Pet_Ice_FrozenTV", Biome = "Ice", Icon = "rbxassetid://103008526204124" },
	["Fairy Cat"] = { Model = "Pet_Enchanted_FairyCat", Biome = "Enchanted", Icon = "rbxassetid://92742548003992" },
	["Mushroom"] = { Model = "Pet_Enchanted_Mushroom", Biome = "Enchanted", Icon = "rbxassetid://75140815978770" },
	["Crystal Bunny"] = { Model = "Pet_Enchanted_CrystalBunny", Biome = "Enchanted", Icon = "rbxassetid://97852022602307" },
	["Spirit Fox"] = { Model = "Pet_Enchanted_SpiritFox", Biome = "Enchanted", Icon = "rbxassetid://124426584648756" },
	["Mystic Dragon"] = { Model = "Pet_Enchanted_MysticDragon", Biome = "Enchanted", Icon = "rbxassetid://85083156829718" },
	["Crystal Deer"] = { Model = "Pet_Enchanted_CrystalDeer", Biome = "Enchanted", Icon = "rbxassetid://127253958103300" },
	["Moon Mask"] = { Model = "Pet_Enchanted_MoonMask", Biome = "Enchanted", Icon = "rbxassetid://75358607880420" },
	["Lava Pup"] = { Model = "Pet_Volcano_LavaPup", Biome = "Volcano", Icon = "rbxassetid://137163502198168" },
	["Fire Bat"] = { Model = "Pet_Volcano_FireBat", Biome = "Volcano", Icon = "rbxassetid://72687460603377" },
	["Ember Lizard"] = { Model = "Pet_Volcano_EmberLizard", Biome = "Volcano", Icon = "rbxassetid://83889621185914" },
	["Demon"] = { Model = "Pet_Volcano_Demon", Biome = "Volcano", Icon = "rbxassetid://135096734646167" },
	["Magma Golem"] = { Model = "Pet_Volcano_MagmaGolem", Biome = "Volcano", Icon = "rbxassetid://110957780944833" },
	["Phoenix"] = { Model = "Pet_Volcano_Phoenix", Biome = "Volcano", Icon = "rbxassetid://109420304265773" },
	["Infernal Chest"] = { Model = "Pet_Volcano_InfernalChest", Biome = "Volcano", Icon = "rbxassetid://140074705941404" },
	["Cupcake"] = { Model = "Pet_Candy_Cupcake", Biome = "Candy", Icon = "rbxassetid://89903970427330" },
	["Marshmallow"] = { Model = "Pet_Candy_Marshmallow", Biome = "Candy", Icon = "rbxassetid://116649793572646" },
	["Gummy Bear"] = { Model = "Pet_Candy_GummyBear", Biome = "Candy", Icon = "rbxassetid://95406905832230" },
	["Donut"] = { Model = "Pet_Candy_Donut", Biome = "Candy", Icon = "rbxassetid://82065435440752" },
	["Candy Dog"] = { Model = "Pet_Candy_CandyDog", Biome = "Candy", Icon = "rbxassetid://131151440542933" },
	["Cake Dragon"] = { Model = "Pet_Candy_CakeDragon", Biome = "Candy", Icon = "rbxassetid://104200478371145" },
	["Chocolate Chicken"] = { Model = "Pet_Candy_ChocolateChicken", Biome = "Candy", Icon = "rbxassetid://88412596442918" },
	["Star Pup"] = { Model = "Pet_Celestial_StarPup", Biome = "Celestial", Icon = "rbxassetid://89874853310986" },
	["Cosmic Cat"] = { Model = "Pet_Celestial_CosmicCat", Biome = "Celestial", Icon = "rbxassetid://126819945035405" },
	["Star Sprite"] = { Model = "Pet_Celestial_StarSprite", Biome = "Celestial", Icon = "rbxassetid://71639698217612" },
	["Angel"] = { Model = "Pet_Celestial_Angel", Biome = "Celestial", Icon = "rbxassetid://83750155487243" },
	["Void Ray"] = { Model = "Pet_Celestial_VoidRay", Biome = "Celestial", Icon = "rbxassetid://128180175040278" },
	["Celestial Dragon"] = { Model = "Pet_Celestial_CelestialDragon", Biome = "Celestial", Icon = "rbxassetid://120000969015780" },
	["Orbit Guardian"] = { Model = "Pet_Celestial_OrbitGuardian", Biome = "Celestial", Icon = "rbxassetid://106834778953477" },
}

-- ===== Pet abilities =====
-- Epic+ pets have an ability that works while equipped (on top of their multiplier). Kinds:
--   Burst = { Every, Multiplier }: every Nth click is multiplied (shares the counter with gear bursts)
--   Proc = { Chance, Multiplier }: each click has a chance to be multiplied
--   Surge = { Chance }: each click has a chance to fill the combo straight to OVERDRIVE
--   passives: CritChance, CritDamage, AutoPower, EggLuck, ComboWindow (sec), ComboBonus, CoinBonus
-- Golden pets get 1.5x the passive values (bursts/procs/surges are unchanged).

GameConfig.GoldenAbilityScale = 1.5
GameConfig.PetAbilities = {
	Dragon = { Name = "Overcharge", Burst = { Every = 50, Multiplier = 3 } },
	Phoenix = { Name = "Flame Burst", Burst = { Every = 25, Multiplier = 10 } },
	Griffin = { Name = "Keen Eye", CritChance = 0.03 },
	Unicorn = { Name = "Lucky Horn", EggLuck = 0.15 },
	["Ancient Dragon"] = { Name = "Overcharge", Burst = { Every = 30, Multiplier = 10 } },
	["Celestial Phoenix"] = { Name = "Void Surge", Surge = { Chance = 0.05 } },
	["Magma Golem"] = { Name = "Molten Core", AutoPower = 0.25 },
	["Fire Serpent"] = { Name = "Scorch", CritDamage = 0.5 },
	["Inferno Dragon"] = { Name = "Inferno", Burst = { Every = 25, Multiplier = 8 } },
	["Volcano Titan"] = { Name = "Eruption", Proc = { Chance = 0.03, Multiplier = 20 } },
	["Lollipop Cat"] = { Name = "Sugar Rush", ComboWindow = 0.3 },
	["Cupcake Unicorn"] = { Name = "Sweet Luck", EggLuck = 0.25 },
	["Candy Dragon"] = { Name = "Candy Crush", Burst = { Every = 20, Multiplier = 8 } },
	["Sugar Queen"] = { Name = "Royal Treasury", CoinBonus = 0.5 },
	["Astro Dog"] = { Name = "Orbit", AutoPower = 0.4 },
	["Nebula Fox"] = { Name = "Void Surge", Surge = { Chance = 0.05 } },
	["Galaxy Dragon"] = { Name = "Supernova", Burst = { Every = 30, Multiplier = 15 } },
	["Cosmic Overlord"] = { Name = "Singularity", ComboBonus = 0.5, Burst = { Every = 100, Multiplier = 25 } },

	-- Art-package pets (Epic, Legendary and Secret/Mythic of each biome). Phoenix and Magma Golem
	-- above also cover the Volcano pets of the same names.
	["Leaf Dragon"] = { Name = "Photosynthesis", AutoPower = 0.15 },
	["Crowned Stag"] = { Name = "Royal Charge", Burst = { Every = 40, Multiplier = 5 } },
	["World Tree Guardian"] = { Name = "Ancient Roots", CoinBonus = 0.3, AutoPower = 0.3 },
	Scarab = { Name = "Golden Shell", CoinBonus = 0.2 },
	Sphinx = { Name = "Riddle", Proc = { Chance = 0.03, Multiplier = 8 } },
	["Sandclock Colossus"] = { Name = "Time Warp", ComboWindow = 0.5, Burst = { Every = 60, Multiplier = 10 } },
	["Frost Dragon"] = { Name = "Frostbite", CritChance = 0.03 },
	["Aurora Owl"] = { Name = "Aurora", EggLuck = 0.2 },
	["Frozen TV"] = { Name = "Static Surge", Surge = { Chance = 0.06 } },
	["Mystic Dragon"] = { Name = "Arcane Focus", CritDamage = 0.4 },
	["Crystal Deer"] = { Name = "Prism", Burst = { Every = 30, Multiplier = 8 } },
	["Moon Mask"] = { Name = "Lunar Veil", EggLuck = 0.35, CritChance = 0.04 },
	["Infernal Chest"] = { Name = "Treasure Hoard", CoinBonus = 0.6, Proc = { Chance = 0.02, Multiplier = 25 } },
	["Candy Dog"] = { Name = "Sugar Rush", ComboWindow = 0.3 },
	["Cake Dragon"] = { Name = "Layer Cake", Burst = { Every = 20, Multiplier = 10 } },
	["Chocolate Chicken"] = { Name = "Golden Eggs", EggLuck = 0.4, CoinBonus = 0.4 },
	["Void Ray"] = { Name = "Void Surge", Surge = { Chance = 0.05 } },
	["Celestial Dragon"] = { Name = "Supernova", Burst = { Every = 25, Multiplier = 20 } },
	["Orbit Guardian"] = { Name = "Singularity", ComboBonus = 0.6, Burst = { Every = 100, Multiplier = 30 } },
}

local PASSIVES = { "CritChance", "CritDamage", "AutoPower", "EggLuck", "ComboWindow", "ComboBonus", "CoinBonus" }

-- "Overcharge: every 30 clicks, next click x10" (nil if the pet has no ability).
function GameConfig.DescribePetAbility(petName, golden)
	local a = GameConfig.PetAbilities[petName]
	if not a then
		return nil
	end
	local k = if golden then GameConfig.GoldenAbilityScale else 1
	local parts = {}
	if a.Burst then table.insert(parts, "every " .. a.Burst.Every .. " clicks, next click x" .. a.Burst.Multiplier) end
	if a.Proc then table.insert(parts, math.floor(a.Proc.Chance * 100 + 0.5) .. "% chance a click deals x" .. a.Proc.Multiplier) end
	if a.Surge then table.insert(parts, math.floor(a.Surge.Chance * 100 + 0.5) .. "% chance to fill the combo to OVERDRIVE") end
	if a.CritChance then table.insert(parts, "+" .. string.format("%g", a.CritChance * k * 100) .. "% crit chance") end
	if a.CritDamage then table.insert(parts, "+" .. string.format("%g", a.CritDamage * k) .. "x crit damage") end
	if a.AutoPower then table.insert(parts, "+" .. math.floor(a.AutoPower * k * 100 + 0.5) .. "% auto income") end
	if a.EggLuck then table.insert(parts, "+" .. math.floor(a.EggLuck * k * 100 + 0.5) .. "% egg luck") end
	if a.ComboWindow then table.insert(parts, "+" .. string.format("%g", a.ComboWindow * k) .. "s combo window") end
	if a.ComboBonus then table.insert(parts, "+" .. math.floor(a.ComboBonus * k * 100 + 0.5) .. "% combo bonus") end
	if a.CoinBonus then table.insert(parts, "+" .. math.floor(a.CoinBonus * k * 100 + 0.5) .. "% Coins from selling & bosses") end
	return a.Name .. ": " .. table.concat(parts, ", ")
end

-- Summed abilities of the equipped pets.
function GameConfig.GetPetAbilityStats(equippedPets)
	local total = { Bursts = {}, Procs = {}, Surges = {} }
	for _, stat in ipairs(PASSIVES) do total[stat] = 0 end
	for _, pet in ipairs(equippedPets or {}) do
		local a = GameConfig.PetAbilities[pet.Name]
		if a then
			local k = if pet.Golden then GameConfig.GoldenAbilityScale else 1
			for _, stat in ipairs(PASSIVES) do
				if a[stat] then total[stat] += a[stat] * k end
			end
			local name = string.upper(a.Name)
			if a.Burst then table.insert(total.Bursts, { Every = a.Burst.Every, Multiplier = a.Burst.Multiplier, Name = name }) end
			if a.Proc then table.insert(total.Procs, { Chance = a.Proc.Chance, Multiplier = a.Proc.Multiplier, Name = name }) end
			if a.Surge then table.insert(total.Surges, { Chance = a.Surge.Chance, Name = name }) end
		end
	end
	return total
end

-- Gear + pet-ability bonuses in one table; this is what the stat formulas take as `bonus`.
function GameConfig.GetBonusStats(data, equippedPets)
	local gear = GameConfig.GetGearStats(data)
	local pets = GameConfig.GetPetAbilityStats(equippedPets)
	local bonus = { Bursts = {}, Procs = pets.Procs, Surges = pets.Surges, ClickPower = gear.ClickPower }
	for _, stat in ipairs(PASSIVES) do
		bonus[stat] = (gear[stat] or 0) + pets[stat]
	end
	for _, b in ipairs(gear.Bursts) do table.insert(bonus.Bursts, b) end
	for _, b in ipairs(pets.Bursts) do table.insert(bonus.Bursts, b) end
	return bonus
end

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

-- How many levels (capped at `cap`) can be bought with `budget`, and what they cost.
function GameConfig.GetMaxAffordable(item, currentLevel, budget, cap)
	local count, total = 0, 0
	while count < cap do
		local nextCost = GameConfig.GetCost(item, currentLevel + count)
		if total + nextCost > budget then
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

function GameConfig.GetMaxEquippedPets(rebirthCount, skills, passes)
	return math.min(GameConfig.MaxEquippedPets, GameConfig.BaseMaxEquippedPets + rebirthCount)
		+ GameConfig.GetSkillLevel(skills, "PetSlots")
		+ (if passes and passes.PetSlots then 3 else 0)
end

-- Power per click before combo/crit: base x pets x Ascension x Click Mastery x gear x 2x Power boost.
function GameConfig.GetClickPower(data, equippedPets)
	return data.ClickPower * GameConfig.GetPetMultiplierTotal(equippedPets)
		* GameConfig.GetRebirthMultiplier(data.RebirthCount)
		* (1 + 0.1 * GameConfig.GetSkillLevel(data.Skills, "ClickMastery"))
		* (1 + GameConfig.GetGearStats(data).ClickPower)
		* GameConfig.GetBoostMultiplier(data, "Power")
		* (if GameConfig.HasPass(data, "VIP") then 1 + GameConfig.VIPBonus else 1)
end

-- Power per second from auto-clickers: base x pets x Ascension x Auto Power x gear x pet abilities
-- x 2x Power boost.
function GameConfig.GetAutoIncome(data, equippedPets)
	local perSecond = 0
	for _, auto in ipairs(GameConfig.AutoClickers) do
		perSecond += (data.AutoClickerLevels[auto.Id] or 0) * auto.PowerPerSecond
	end
	return perSecond * GameConfig.GetPetMultiplierTotal(equippedPets)
		* GameConfig.GetRebirthMultiplier(data.RebirthCount)
		* (1 + 0.2 * GameConfig.GetSkillLevel(data.Skills, "AutoPower"))
		* (1 + GameConfig.GetGearStats(data).AutoPower)
		* (1 + GameConfig.GetPetAbilityStats(equippedPets).AutoPower)
		* GameConfig.GetBoostMultiplier(data, "Power")
		* (if GameConfig.HasPass(data, "VIP") then 1 + GameConfig.VIPBonus else 1)
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
GameConfig.HatchCooldown = EggConfig.HatchCooldown
GameConfig.AutosaveSeconds = 60
GameConfig.LeaderboardRefreshSeconds = 120
GameConfig.Sounds = {Click="rbxassetid://88442833509532", Purchase="rbxassetid://139719503904449", Rare="rbxassetid://1839881844"}

-- Background music: joyful, calm tracks from Roblox's licensed APM music library (usable in any
-- experience). Played client-side in a shuffled loop with cross-fades; players can mute it with the
-- music button.
GameConfig.Music = {
	Volume = 0.3,
	FadeSeconds = 2,
	Tracks = {
		{ Id = 1842663547, Name = "Feeling Glad" }, -- light, happy mandolin folk
		{ Id = 1839843882, Name = "A Welcome Smile" }, -- carefree acoustic guitar
		{ Id = 1836356540, Name = "Ukelele Maiden" }, -- easygoing ukulele
		{ Id = 1841004403, Name = "Feels Easy" },
		{ Id = 1842285702, Name = "On the Go" }, -- light-hearted easy listening
	},
}
return GameConfig
