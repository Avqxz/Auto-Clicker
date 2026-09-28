-- Server bootstrap for the Clicking Simulator.
-- Owns all game state mutation: clicks, purchases, pets/eggs, Ascension + skills, autosaving,
-- and builds the map + pet-follower presentation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.PlayerData)
local Quests = require(script.Quests)
local Monetization = require(script.Monetization)
local MapBuilder = require(script.MapBuilder)
local PetFollowers = require(script.PetFollowers)

-- ===== Map =====

local mapRefs = MapBuilder.Build()
require(script.GlobalBoards).Start(PlayerData)

-- ===== Remotes =====

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local function createRemoteEvent(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local ClickRemote = createRemoteEvent("Click")
local PurchaseUpgradeRemote = createRemoteEvent("PurchaseUpgrade")
local PurchaseAutoClickerRemote = createRemoteEvent("PurchaseAutoClicker")
local AscendRemote = createRemoteEvent("Ascend")
local UnlockSkillRemote = createRemoteEvent("UnlockSkill")
local OpenPanelRemote = createRemoteEvent("OpenPanel")
local DataUpdatedRemote = createRemoteEvent("DataUpdated")
local HatchEggRemote = createRemoteEvent("HatchEgg")
local EquipPetRemote = createRemoteEvent("EquipPet")
local UnequipPetRemote = createRemoteEvent("UnequipPet")
local FusePetsRemote = createRemoteEvent("FusePets")
local EggResultRemote = createRemoteEvent("EggResult")
local EggLockedRemote = createRemoteEvent("EggLocked")
local ZoneLockedRemote = createRemoteEvent("ZoneLocked")
local ClickResultRemote = createRemoteEvent("ClickResult")
local BossStateRemote = createRemoteEvent("BossState")
local EquipGearRemote = createRemoteEvent("EquipGear")
local UnequipGearRemote = createRemoteEvent("UnequipGear")
local SalvageGearRemote = createRemoteEvent("SalvageGear")
local UpgradeGearRemote = createRemoteEvent("UpgradeGear")
local SellPowerRemote = createRemoteEvent("SellPower")
local BuyBoostRemote = createRemoteEvent("BuyBoost")
local ClaimQuestRemote = createRemoteEvent("ClaimQuest")
local ClaimDailyRemote = createRemoteEvent("ClaimDaily")
local OfflineEarningsRemote = createRemoteEvent("OfflineEarnings")
local PickStarterPetRemote = createRemoteEvent("PickStarterPet")

local FeedbackRemote=createRemoteEvent("Feedback")
local AnnouncementRemote=createRemoteEvent("Announcement")
local RedeemCodeRemote=createRemoteEvent("RedeemCode")
local RequestDataRemote=createRemoteEvent("RequestData")
local PromoCodes=require(script.PromoCodes)
local lastClickTimes = {}
local comboStates = {} -- [userId] = { Count, Last }
local burstCounters = {} -- [userId] = clicks counted toward gear bursts
local bossFights = {} -- [userId] = { Boss, Health, Ends }
local bossCooldowns = {} -- [userId] = { [bossId] = os.clock() when it can be fought again }
local limits={}
local function allow(player,key,seconds)
 local id=player.UserId limits[id]=limits[id] or {}
 local now=os.clock() if now-(limits[id][key] or -math.huge)<seconds then return false end
 limits[id][key]=now return true
end
-- Power: the click currency (clicks, auto-clickers, offline). Coins: the egg currency.
local function earnPower(data,amount)
 data.Power=math.min(GameConfig.MaxCurrency,data.Power+amount)
 data.TotalPowerEarned=math.min(GameConfig.MaxCurrency,data.TotalPowerEarned+amount)
end
local function earnCoins(data,amount)
 data.Coins=math.min(GameConfig.MaxCurrency,data.Coins+amount)
end

-- ===== Helpers =====

local function pushData(player)
	local data = PlayerData.Get(player)
	if data then
		DataUpdatedRemote:FireClient(player, data)
	end
end

local function updateLeaderstats(player)
	local data = PlayerData.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not data or not leaderstats then
		return
	end
	leaderstats.Power.Value = math.floor(data.Power)
	leaderstats.Ascensions.Value = data.RebirthCount
end

local function setupLeaderstats(player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local power = Instance.new("NumberValue")
	power.Name = "Power"
	power.Value = math.floor(data.Power)
	power.Parent = leaderstats

	local ascensions = Instance.new("IntValue")
	ascensions.Name = "Ascensions" -- stored as RebirthCount in the save
	ascensions.Value = data.RebirthCount
	ascensions.Parent = leaderstats

	leaderstats.Parent = player
end

local function findById(list, id)
	for _, entry in ipairs(list) do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

local function getEquippedPets(data)
	local equippedSet = {}
	for _, uid in ipairs(data.EquippedPetUids) do
		equippedSet[uid] = true
	end
	local equipped = {}
	for _, pet in ipairs(data.Pets) do
		if equippedSet[pet.Uid] then
			table.insert(equipped, pet)
		end
	end
	return equipped
end

local function getClickPower(data)
	return GameConfig.GetClickPower(data, getEquippedPets(data))
end

local function refreshFollowers(player, data)
	PetFollowers.Refresh(player, getEquippedPets(data))
end

-- ===== Player lifecycle =====

local monetization = Monetization.Start({
	PlayerData = PlayerData,
	pushData = pushData,
	feedback = function(player, kind, text) FeedbackRemote:FireClient(player, kind, text) end,
	bossCooldowns = bossCooldowns,
})

Players.PlayerAdded:Connect(function(player)
	local data = PlayerData.Load(player)
 if not data then return end
 if not player.Parent then PlayerData.Release(player) return end
	setupLeaderstats(player, data)

	Quests.Refresh(data)
	monetization.RefreshPasses(player, data)

	-- Offline earnings: a base share of auto income for the time since the last save (capped),
	-- raised by the Offline Earnings skill.
	local offlineRate = GameConfig.OfflineBaseRate + 0.1 * GameConfig.GetSkillLevel(data.Skills, "OfflineEarnings")
	if data.LastOnline then
		local seconds = math.clamp(os.time() - data.LastOnline, 0, GameConfig.OfflineCapSeconds)
		local offline = math.floor(GameConfig.GetAutoIncome(data, getEquippedPets(data)) * seconds * offlineRate)
		if offline > 0 then
			earnPower(data, offline)
			updateLeaderstats(player)
			task.delay(3, function() -- after the client UI is up
				OfflineEarningsRemote:FireClient(player, offline, seconds, offlineRate)
			end)
		end
	end

	pushData(player)
	refreshFollowers(player, data)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Release(player)
	PetFollowers.Clear(player)
	lastClickTimes[player.UserId] = nil
	comboStates[player.UserId] = nil
	burstCounters[player.UserId] = nil
	bossFights[player.UserId] = nil
	bossCooldowns[player.UserId] = nil
 limits[player.UserId]=nil
end)

-- ===== Boss fights =====
-- Personal, timed fights started from a boss's Fight prompt. Clicks damage the boss (see handleClick).

local function endBossFight(player, fight, won)
	bossFights[player.UserId] = nil
	bossCooldowns[player.UserId] = bossCooldowns[player.UserId] or {}
	bossCooldowns[player.UserId][fight.Boss.Id] = os.clock() + (if won then GameConfig.BossWinCooldown else GameConfig.BossLossCooldown)
end

local function winBossFight(player, data, fight)
	local boss = fight.Boss
	endBossFight(player, fight, true)
	local coins = boss.RewardCoins * GameConfig.GetRebirthMultiplier(data.RebirthCount)
		* (1 + GameConfig.GetPetAbilityStats(getEquippedPets(data)).CoinBonus)
		* (if GameConfig.HasPass(data, "VIP") then 1 + GameConfig.VIPBonus else 1)
	earnCoins(data, coins)
	local gems = boss.RewardGems
	data.Gems = (data.Gems or 0) + gems
	local essence = boss.RewardEssence or 0
	data.Essence = (data.Essence or 0) + essence

	-- Drop one of the boss's gear pieces (Gems instead if the gear bag is full).
	local drops = {}
	for _, item in ipairs(GameConfig.Gear) do
		if item.Boss == boss.Id then
			table.insert(drops, item)
		end
	end
	local dropId
	local gear = data.Gear
	if #drops > 0 and #gear.Items < GameConfig.MaxGearItems then
		local item = drops[math.random(#drops)]
		dropId = item.Id
		local uid = gear.NextUid
		gear.NextUid += 1
		table.insert(gear.Items, { Uid = uid, Id = item.Id, Level = 0 })
		if not gear.Equipped[item.Slot] then
			gear.Equipped[item.Slot] = uid -- fill an empty slot automatically
		end
	else
		data.Gems += gems
		gems *= 2
	end

	Quests.Track(data, "BossWin", 1)
	BossStateRemote:FireClient(player, "win", { Coins = coins, Gems = gems, Essence = essence, Gear = dropId })
	updateLeaderstats(player)
	pushData(player)
end

local function startBossFight(player, boss)
	local data = PlayerData.Get(player)
	if not data or bossFights[player.UserId] then
		return
	end
	local zone = findById(GameConfig.Zones, boss.Zone)
	if zone and data.RebirthCount < zone.RequiredRebirths then
		return
	end
	local readyAt = bossCooldowns[player.UserId] and bossCooldowns[player.UserId][boss.Id]
	if readyAt and os.clock() < readyAt then
		FeedbackRemote:FireClient(player, "Info", boss.Name .. " is recovering — back in " .. math.ceil(readyAt - os.clock()) .. "s")
		return
	end
	bossFights[player.UserId] = { Boss = boss, Health = boss.Health, Ends = os.clock() + GameConfig.BossFightSeconds }
	BossStateRemote:FireClient(player, "start", { Id = boss.Id, Name = boss.Name, Health = boss.Health, Seconds = GameConfig.BossFightSeconds })
end

for bossId, ref in pairs(mapRefs.Bosses) do
	local boss = GameConfig.GetBoss(bossId)
	ref.Prompt.Triggered:Connect(function(player)
		startBossFight(player, boss)
	end)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for userId, fight in pairs(bossFights) do
		if now > fight.Ends then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				endBossFight(player, fight, false)
				BossStateRemote:FireClient(player, "lose")
			else
				bossFights[userId] = nil
			end
		end
	end
end)

-- ===== Gear =====

local function findGear(data, uid)
	for i, owned in ipairs(data.Gear.Items) do
		if owned.Uid == uid then
			return owned, i
		end
	end
	return nil
end

EquipGearRemote.OnServerEvent:Connect(function(player, uid)
	if type(uid) ~= "number" or not allow(player, "gear", 0.1) then return end
	local data = PlayerData.Get(player)
	local owned = data and findGear(data, uid)
	local item = owned and GameConfig.GetGear(owned.Id)
	if item then
		data.Gear.Equipped[item.Slot] = uid
		pushData(player)
	end
end)

UnequipGearRemote.OnServerEvent:Connect(function(player, slot)
	if type(slot) ~= "string" or not allow(player, "gear", 0.1) then return end
	local data = PlayerData.Get(player)
	if data and data.Gear.Equipped[slot] then
		data.Gear.Equipped[slot] = nil
		pushData(player)
	end
end)

-- Salvaging destroys a piece for Essence (base value + half of what was spent upgrading it).
SalvageGearRemote.OnServerEvent:Connect(function(player, uid)
	if type(uid) ~= "number" or not allow(player, "gear", 0.1) then return end
	local data = PlayerData.Get(player)
	local owned, index = data and findGear(data, uid)
	local item = owned and GameConfig.GetGear(owned.Id)
	if item then
		for slot, equippedUid in pairs(data.Gear.Equipped) do
			if equippedUid == uid then
				data.Gear.Equipped[slot] = nil
			end
		end
		table.remove(data.Gear.Items, index)
		local essence = GameConfig.GetGearSalvageValue(item, owned.Level)
		data.Essence = (data.Essence or 0) + essence
		FeedbackRemote:FireClient(player, "Purchase", "Salvaged " .. item.Name .. " for +" .. essence .. " Essence")
		pushData(player)
	end
end)

UpgradeGearRemote.OnServerEvent:Connect(function(player, uid)
	if type(uid) ~= "number" or not allow(player, "gear", 0.15) then return end
	local data = PlayerData.Get(player)
	local owned = data and findGear(data, uid)
	local item = owned and GameConfig.GetGear(owned.Id)
	if not item or (owned.Level or 0) >= GameConfig.GearMaxLevel then
		return
	end
	local cost = GameConfig.GetGearUpgradeCost(item, owned.Level)
	if (data.Essence or 0) < cost then
		return
	end
	data.Essence -= cost
	owned.Level = (owned.Level or 0) + 1
	FeedbackRemote:FireClient(player, "Purchase", item.Name .. " upgraded to +" .. owned.Level)
	pushData(player)
end)

-- ===== Selling Power & Token Shop =====

SellPowerRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "sell", 0.5) then return end
	local data = PlayerData.Get(player)
	if not data or data.Power < 1 then
		return
	end
	local sold = math.floor(data.Power)
	local coins = math.floor(sold * GameConfig.GetSellRate(data.RebirthCount)
		* (1 + GameConfig.GetPetAbilityStats(getEquippedPets(data)).CoinBonus)
		* (if GameConfig.HasPass(data, "VIP") then 1 + GameConfig.VIPBonus else 1))
	data.Power -= sold
	earnCoins(data, coins)
	FeedbackRemote:FireClient(player, "Purchase", "Sold " .. sold .. " Power for " .. coins .. " Coins")
	updateLeaderstats(player)
	pushData(player)
end)

-- Buying a boost starts it, or extends a running one (up to BoostMaxMinutes left).
BuyBoostRemote.OnServerEvent:Connect(function(player, itemId)
	if type(itemId) ~= "string" or not allow(player, "boost", 0.3) then return end
	local data = PlayerData.Get(player)
	local item = data and findById(GameConfig.TokenShop, itemId)
	if not item or (data.Tokens or 0) < item.Cost then
		return
	end
	local now = os.time()
	local current = math.max(now, data.Boosts[item.Boost] or 0)
	if current + item.Minutes * 60 > now + GameConfig.BoostMaxMinutes * 60 then
		FeedbackRemote:FireClient(player, "Info", item.Name .. " is already stacked to the max")
		return
	end
	data.Tokens -= item.Cost
	data.Boosts[item.Boost] = current + item.Minutes * 60
	FeedbackRemote:FireClient(player, "Purchase", item.Name .. " active for " .. math.ceil((data.Boosts[item.Boost] - now) / 60) .. " min")
	pushData(player)
end)

-- ===== Quests & daily reward =====

ClaimQuestRemote.OnServerEvent:Connect(function(player, group, index)
	if (group ~= "Daily" and group ~= "Weekly") or type(index) ~= "number" or not allow(player, "quest", 0.2) then return end
	local data = PlayerData.Get(player)
	local def = data and Quests.Claim(data, group, index)
	if def then
		FeedbackRemote:FireClient(player, "Purchase", "Quest complete: " .. def.Text .. "  +" .. def.Gems .. " 💎"
			.. (if def.Tokens then "  +" .. def.Tokens .. " Tokens" else ""))
		pushData(player)
	end
end)

ClaimDailyRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "daily", 1) then return end
	local data = PlayerData.Get(player)
	local reward = data and Quests.ClaimDaily(data)
	if reward then
		if reward.Coins > 0 then
			earnCoins(data, reward.Coins)
		end
		if GameConfig.HasPass(data, "VIP") then -- VIP daily chest
			data.Gems += GameConfig.VIPDailyGems
			reward.Gems += GameConfig.VIPDailyGems
		end
		local parts = {}
		if reward.Gems > 0 then table.insert(parts, "+" .. reward.Gems .. " 💎") end
		if reward.Tokens > 0 then table.insert(parts, "+" .. reward.Tokens .. " Tokens") end
		if reward.Coins > 0 then table.insert(parts, "+" .. reward.Coins .. " Coins") end
		FeedbackRemote:FireClient(player, "Ascend", "Day " .. reward.Day .. " reward: " .. table.concat(parts, "  "))
		updateLeaderstats(player)
		pushData(player)
	end
end)

-- ===== Clicking =====
-- Each click extends the player's combo (if it lands within the combo window), picks up the
-- combo tier's multiplier, and rolls for a crit. The client only displays the result.

local function handleClick(player)
	local now = os.clock()
	local last = lastClickTimes[player.UserId]
	if last and now - last < GameConfig.ClickCooldown then
		return
	end
	lastClickTimes[player.UserId] = now

	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local levels = data.UpgradeLevels
	local bonus = GameConfig.GetBonusStats(data, getEquippedPets(data)) -- gear + pet abilities
	local combo = comboStates[player.UserId]
	if not combo or now - combo.Last > GameConfig.GetComboWindow(levels, bonus) then
		combo = { Count = 0 }
		comboStates[player.UserId] = combo
	end
	combo.Count += 1
	combo.Last = now

	-- Named effects that fired on this click (shown on the floating number).
	local procName
	-- Surge abilities: a chance to fill the combo straight to OVERDRIVE.
	local overdrive = GameConfig.Combo.Tiers[1].MinCombo
	for _, surge in ipairs(bonus.Surges) do
		if combo.Count < overdrive and math.random() < surge.Chance then
			combo.Count = overdrive
			procName = surge.Name
		end
	end
	Quests.Track(data, "Click", 1)
	Quests.Track(data, "Combo", combo.Count)

	local skills = data.Skills
	local crit = math.random() < GameConfig.GetCritChance(levels, skills, bonus)
	local earned = getClickPower(data) * GameConfig.GetComboMultiplier(combo.Count, skills, bonus)
		* (if crit then GameConfig.GetCritDamage(levels, skills, bonus) else 1)

	-- Bursts (gear + pets): every Nth click is multiplied. Procs (pets): a chance to multiply.
	local clicks = (burstCounters[player.UserId] or 0) + 1
	burstCounters[player.UserId] = clicks
	for _, burst in ipairs(bonus.Bursts) do
		if clicks % burst.Every == 0 then
			earned *= burst.Multiplier
			procName = burst.Name
		end
	end
	for _, proc in ipairs(bonus.Procs) do
		if math.random() < proc.Chance then
			earned *= proc.Multiplier
			procName = proc.Name
		end
	end

	-- In a boss fight (and close enough), the click hits the boss instead of earning Power.
	local fight = bossFights[player.UserId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local bossPos = fight and mapRefs.Bosses[fight.Boss.Id] and mapRefs.Bosses[fight.Boss.Id].Position
	if fight and root and bossPos and (root.Position - bossPos).Magnitude <= GameConfig.BossRange then
		fight.Health = math.max(0, fight.Health - earned)
		ClickResultRemote:FireClient(player, earned, crit, combo.Count, "boss", procName)
		BossStateRemote:FireClient(player, "hp", fight.Health)
		if fight.Health <= 0 then
			winBossFight(player, data, fight)
		end
		return
	end

	earnPower(data,earned)
	ClickResultRemote:FireClient(player, earned, crit, combo.Count, nil, procName)
	updateLeaderstats(player)
	pushData(player)
end

ClickRemote.OnServerEvent:Connect(handleClick)

-- ===== Purchases =====

-- `amount` is 1, 10 or "max"; buys as many of those levels as the player can afford.
local function buyLevels(player, list, levelsKey, id, amount, onLevel)
	if type(id) ~= "string" or not allow(player, "purchase", 0.12) then return end
	if amount ~= 1 and amount ~= 10 and amount ~= "max" then return end
	local data = PlayerData.Get(player)
	local item = data and findById(list, id)
	if not item then
		return
	end

	local levels = data[levelsKey]
	local currentLevel = levels[id] or 0
	local cap = math.max(0, (item.MaxLevel or GameConfig.MaxUpgradeLevel) - currentLevel)
	local wanted = if amount == "max" then cap else math.min(amount, cap)
	local count, cost = GameConfig.GetMaxAffordable(item, currentLevel, data.Power, wanted)
	if count == 0 or (amount ~= "max" and count < wanted) then
		return -- x1/x10 buy all-or-nothing; MAX buys whatever fits
	end

	data.Power -= cost
	levels[id] = currentLevel + count
	Quests.Track(data, "Upgrade", count)
	if onLevel then onLevel(data, item, count) end
	FeedbackRemote:FireClient(player, "Purchase", item.Name .. (if count > 1 then " x" .. count else "") .. " purchased!")

	updateLeaderstats(player)
	pushData(player)
end

local upgradeCatalog = {}
for _, item in ipairs(GameConfig.Upgrades) do table.insert(upgradeCatalog, item) end
for _, item in ipairs(GameConfig.ClickBoosts) do table.insert(upgradeCatalog, item) end

PurchaseUpgradeRemote.OnServerEvent:Connect(function(player, upgradeId, amount)
	buyLevels(player, upgradeCatalog, "UpgradeLevels", upgradeId, amount or 1, function(data, item, count)
		if item.ClickPowerAdd then
			data.ClickPower += item.ClickPowerAdd * count
		end
	end)
end)

PurchaseAutoClickerRemote.OnServerEvent:Connect(function(player, autoId, amount)
	buyLevels(player, GameConfig.AutoClickers, "AutoClickerLevels", autoId, amount or 1)
end)

-- ===== Pets & eggs =====

-- skipCooldown: the 2nd/3rd egg of a Triple Hatch.
local function handleHatchEgg(player, eggId, skipCooldown)
	local cooldown = GameConfig.HatchCooldown * (if player:GetAttribute("Pass_FastHatch") then 0.5 else 1)
	if type(eggId)~="string" or (not skipCooldown and not allow(player,"hatch",cooldown)) then return end
	local data = PlayerData.Get(player)
	local egg = findById(GameConfig.Eggs, eggId)
	if not data or not egg then
		return
	end

	if data.RebirthCount < egg.RequiredRebirths then
		EggLockedRemote:FireClient(player, egg.Name, egg.RequiredRebirths)
		return
	end

	-- Eggs outside the starting zone must be hatched in person, behind that zone's rebirth gate.
	if egg.Zone ~= GameConfig.Zones[1].Id then
		local eggPart = mapRefs.EggParts[egg.Id]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not eggPart or not root or (root.Position - eggPart.Position).Magnitude > GameConfig.EggHatchRange then
			local zone = findById(GameConfig.Zones, egg.Zone)
			FeedbackRemote:FireClient(player, "Info", "Go to " .. (zone and zone.Name or egg.Zone) .. " to hatch the " .. egg.Name .. "!")
			return
		end
	end

	if data.Coins < egg.Cost then
		return
	end

	if #data.Pets>=GameConfig.MaxPets then FeedbackRemote:FireClient(player,"Info","Pet storage full. Fuse duplicates to make room.") return end
 data.Coins -= egg.Cost
 data.EggsHatched=(data.EggsHatched or 0)+1
	Quests.Track(data, "Hatch", 1)

	local rolled = GameConfig.RollPet(egg, data.Skills,
		GameConfig.GetBoostMultiplier(data, "Luck") * (1 + GameConfig.GetPetAbilityStats(getEquippedPets(data)).EggLuck)
			* (if GameConfig.HasPass(data, "Lucky") then 1.5 else 1))
	local uid = data.NextPetUid
	data.NextPetUid += 1

	local newPet = {
		Uid = uid,
		Name = rolled.Name,
		Rarity = rolled.Rarity,
		Multiplier = rolled.Multiplier,
		Golden = false,
	}
	table.insert(data.Pets, newPet)
	if newPet.Rarity == "Legendary" or newPet.Rarity == "Mythic" then
		Quests.Track(data, "HatchLegendary", 1)
	end

	local equipChanged = false
	if #data.EquippedPetUids < GameConfig.GetMaxEquippedPets(data.RebirthCount, data.Skills, data.Passes) then
		table.insert(data.EquippedPetUids, uid)
		equipChanged = true
	end

	updateLeaderstats(player)
	pushData(player)
	EggResultRemote:FireClient(player, newPet)
 if newPet.Rarity=="Mythic" or newPet.Rarity=="Legendary" then
  AnnouncementRemote:FireAllClients(player.Name.." hatched "..newPet.Rarity.." "..newPet.Name.."!",newPet.Rarity)
 end
	if equipChanged then
		refreshFollowers(player, data)
	end
end

HatchEggRemote.OnServerEvent:Connect(function(player, eggId, count)
	-- Triple Hatch pass: three eggs per press (each still checks cost, storage and range).
	if count == 3 and player:GetAttribute("Pass_TripleHatch") then
		local data = PlayerData.Get(player)
		local before = data and #data.Pets
		handleHatchEgg(player, eggId)
		if data and #data.Pets > before then
			handleHatchEgg(player, eggId, true)
			handleHatchEgg(player, eggId, true)
		end
		return
	end
	handleHatchEgg(player, eggId)
end)

PickStarterPetRemote.OnServerEvent:Connect(function(player, petName)
	local data = PlayerData.Get(player)
	if not data or data.HasPickedStarterPet then
		return
	end

	local chosen
	for _, starter in ipairs(GameConfig.StarterPets) do
		if starter.Name == petName then
			chosen = starter
			break
		end
	end
	if not chosen then
		return
	end

	local uid = data.NextPetUid
	data.NextPetUid += 1

	local newPet = {
		Uid = uid,
		Name = chosen.Name,
		Rarity = chosen.Rarity,
		Multiplier = chosen.Multiplier,
		Golden = false,
	}
	table.insert(data.Pets, newPet)
	table.insert(data.EquippedPetUids, uid)
	data.HasPickedStarterPet = true

	pushData(player)
	refreshFollowers(player, data)
end)

EquipPetRemote.OnServerEvent:Connect(function(player, name, rarity, golden)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	if #data.EquippedPetUids >= GameConfig.GetMaxEquippedPets(data.RebirthCount, data.Skills, data.Passes) then
		return
	end

	local equippedSet = {}
	for _, uid in ipairs(data.EquippedPetUids) do
		equippedSet[uid] = true
	end

	for _, pet in ipairs(data.Pets) do
		if pet.Name == name and pet.Rarity == rarity and pet.Golden == golden and not equippedSet[pet.Uid] then
			table.insert(data.EquippedPetUids, pet.Uid)
			pushData(player)
			refreshFollowers(player, data)
			return
		end
	end
end)

UnequipPetRemote.OnServerEvent:Connect(function(player, name, rarity, golden)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local petsByUid = {}
	for _, pet in ipairs(data.Pets) do
		petsByUid[pet.Uid] = pet
	end

	for i, uid in ipairs(data.EquippedPetUids) do
		local pet = petsByUid[uid]
		if pet and pet.Name == name and pet.Rarity == rarity and pet.Golden == golden then
			table.remove(data.EquippedPetUids, i)
			pushData(player)
			refreshFollowers(player, data)
			return
		end
	end
end)

FusePetsRemote.OnServerEvent:Connect(function(player, name, rarity)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local matches = {}
	for _, pet in ipairs(data.Pets) do
		if pet.Name == name and pet.Rarity == rarity and not pet.Golden then
			table.insert(matches, pet)
		end
	end

	if #matches < GameConfig.FusionRequirement then
		return
	end

	local fuseUidSet = {}
	for i = 1, GameConfig.FusionRequirement do
		fuseUidSet[matches[i].Uid] = true
	end
	local fusedMultiplier = matches[1].Multiplier

	local remainingPets = {}
	for _, pet in ipairs(data.Pets) do
		if not fuseUidSet[pet.Uid] then
			table.insert(remainingPets, pet)
		end
	end
	data.Pets = remainingPets

	local remainingEquipped = {}
	for _, uid in ipairs(data.EquippedPetUids) do
		if not fuseUidSet[uid] then
			table.insert(remainingEquipped, uid)
		end
	end
	data.EquippedPetUids = remainingEquipped

	local uid = data.NextPetUid
	data.NextPetUid += 1

	local goldenPet = {
		Uid = uid,
		Name = name,
		Rarity = rarity,
		Multiplier = fusedMultiplier * (2 + 0.25 * GameConfig.GetSkillLevel(data.Skills, "GoldenTouch")),
		Golden = true,
	}
	table.insert(data.Pets, goldenPet)

	if #data.EquippedPetUids < GameConfig.GetMaxEquippedPets(data.RebirthCount, data.Skills, data.Passes) then
		table.insert(data.EquippedPetUids, uid)
	end

	updateLeaderstats(player)
	pushData(player)
	refreshFollowers(player, data)
end)

-- ===== Ascension (saved as RebirthCount) & skill tree =====

local function handleAscend(player)
	if not allow(player, "ascend", 0.5) then return end
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local requirement = GameConfig.GetRebirthRequirement(data.RebirthCount)
	if data.Power < requirement then
		return
	end

	-- Resets Power, Coins, click power, upgrades and auto-clickers. Pets, Gems, Tokens, Essence,
	-- gear and skills are permanent.
	local gems = GameConfig.GetAscensionGems(data.Power, data.RebirthCount)
	data.Gems = (data.Gems or 0) + gems
	local headStart = GameConfig.GetSkillLevel(data.Skills, "HeadStart")
	data.Power = 500 * headStart * headStart
	data.Coins = 0
	data.ClickPower = GameConfig.StartingClickPower
	data.UpgradeLevels = {}
	data.AutoClickerLevels = {}
	data.RebirthCount += 1
	Quests.Track(data, "Ascend", 1)
	FeedbackRemote:FireClient(player, "Ascend", "ASCENDED! +" .. gems .. " Gems • Power x" .. GameConfig.GetRebirthMultiplier(data.RebirthCount))

	updateLeaderstats(player)
	pushData(player)
end

AscendRemote.OnServerEvent:Connect(handleAscend)

UnlockSkillRemote.OnServerEvent:Connect(function(player, skillId)
	if type(skillId) ~= "string" or not allow(player, "skill", 0.15) then return end
	local data = PlayerData.Get(player)
	local node = GameConfig.GetSkill(skillId)
	if not data or not node then
		return
	end
	data.Skills = data.Skills or {}
	local level = data.Skills[skillId] or 0
	if level >= node.MaxLevel then
		return
	end
	if node.Requires and (data.Skills[node.Requires] or 0) < 1 then
		return
	end
	local cost = GameConfig.GetSkillCost(node, level)
	if (data.Gems or 0) < cost then
		return
	end

	data.Gems -= cost
	data.Skills[skillId] = level + 1
	FeedbackRemote:FireClient(player, "Purchase", node.Name .. " → level " .. (level + 1))
	pushData(player)
	if skillId == "PetSlots" then
		refreshFollowers(player, data)
	end
end)

-- ===== In-world interactions (ClickDetectors on the map) =====

local function addClickDetector(part, maxDistance)
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = maxDistance or 32
	detector.Parent = part
	return detector
end

addClickDetector(mapRefs.ClickOrb).MouseClick:Connect(handleClick)
-- Pack stations (treasure chest -> Daily Rewards, enchanting table -> Token Shop) open their panel.
for kind, prompt in pairs(mapRefs.Stations or {}) do
	prompt.Triggered:Connect(function(player)
		OpenPanelRemote:FireClient(player, kind)
	end)
end

addClickDetector(mapRefs.RebirthAltar).MouseClick:Connect(function(player)
	OpenPanelRemote:FireClient(player, "Ascend") -- confirm in the Ascend panel rather than ascending on one click
end)

for eggId, eggPart in pairs(mapRefs.EggParts) do
	addClickDetector(eggPart).MouseClick:Connect(function(player)
		handleHatchEgg(player, eggId)
	end)
end

-- ===== Zone gates =====
-- Gates are solid on the server and opened per player on the client (Client/ZoneGates.lua), so a
-- player below the requirement just bumps into it; tell them what they need.

local gateToastCooldown = {}
for _, gate in ipairs(mapRefs.Gates) do
	gate.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local data = player and PlayerData.Get(player)
		if not data or data.RebirthCount >= gate:GetAttribute("RequiredRebirths") then
			return
		end
		if gateToastCooldown[player.UserId] and os.clock() - gateToastCooldown[player.UserId] < 2 then
			return
		end
		gateToastCooldown[player.UserId] = os.clock()
		ZoneLockedRemote:FireClient(player, gate:GetAttribute("ZoneName"), gate:GetAttribute("RequiredRebirths"))
	end)
end
Players.PlayerRemoving:Connect(function(player)
	gateToastCooldown[player.UserId] = nil
end)

-- ===== Passive income (auto-clickers) =====

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 1 then
		return
	end
	accumulator = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.Get(player)
		if data then
			local earned = GameConfig.GetAutoIncome(data, getEquippedPets(data))
			if earned > 0 then
				earnPower(data,earned)
				updateLeaderstats(player)
				pushData(player)
			end
		end
	end
end)

-- ===== Autosave =====

task.spawn(function()
	while true do
		task.wait(GameConfig.AutosaveSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerData.Save(player)
		end
	end
end)

game:BindToClose(function()
 local pending=0
 for _,player in ipairs(Players:GetPlayers()) do
  pending+=1 task.spawn(function() PlayerData.Release(player) pending-=1 end)
 end
 local deadline=os.clock()+25
 while pending>0 and os.clock()<deadline do task.wait(0.1) end
end)

RequestDataRemote.OnServerEvent:Connect(function(player)
 if allow(player,"sync",1) then pushData(player) end
end)
RedeemCodeRemote.OnServerEvent:Connect(function(player,raw)
 if not allow(player,"code",1) then return end
 if type(raw)~="string" or #raw>40 then return end
 local code=string.upper(string.match(raw,"^%s*(.-)%s*$"))
 local data=PlayerData.Get(player) if not data then return end
 local reward=PromoCodes[code]
 if not reward or (reward.ExpiresAt and os.time()>reward.ExpiresAt) then FeedbackRemote:FireClient(player,"Info","That code is invalid or expired.") return end
 data.RedeemedCodes=data.RedeemedCodes or {}
 if data.RedeemedCodes[code] then FeedbackRemote:FireClient(player,"Info","You already redeemed this code.") return end
 -- No yielding between the duplicate check, marking the code and granting its reward.
 data.RedeemedCodes[code]=true earnCoins(data,reward.Coins)
 updateLeaderstats(player) pushData(player)
 FeedbackRemote:FireClient(player,"Purchase","Code redeemed! +"..reward.Coins.." Coins")
 task.spawn(function() PlayerData.Save(player) end)
end)
