-- Server bootstrap for the Clicking Simulator.
-- Owns all game state mutation: clicks, purchases, pets/eggs, rebirths, autosaving,
-- and builds the map + pet-follower presentation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.PlayerData)
local MapBuilder = require(script.MapBuilder)
local PetFollowers = require(script.PetFollowers)

-- ===== Map =====

local mapRefs = MapBuilder.Build()

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
local RebirthRemote = createRemoteEvent("Rebirth")
local DataUpdatedRemote = createRemoteEvent("DataUpdated")
local HatchEggRemote = createRemoteEvent("HatchEgg")
local EquipPetRemote = createRemoteEvent("EquipPet")
local UnequipPetRemote = createRemoteEvent("UnequipPet")
local FusePetsRemote = createRemoteEvent("FusePets")
local EggResultRemote = createRemoteEvent("EggResult")

local lastClickTimes = {}

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
	leaderstats.Coins.Value = math.floor(data.Coins)
	leaderstats.Rebirths.Value = data.RebirthCount
end

local function setupLeaderstats(player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = math.floor(data.Coins)
	coins.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.RebirthCount
	rebirths.Parent = leaderstats

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
	local petMultiplier = GameConfig.GetPetMultiplierTotal(getEquippedPets(data))
	return data.ClickPower * petMultiplier * GameConfig.GetRebirthMultiplier(data.RebirthCount)
end

local function refreshFollowers(player, data)
	PetFollowers.Refresh(player, getEquippedPets(data))
end

-- ===== Player lifecycle =====

Players.PlayerAdded:Connect(function(player)
	local data = PlayerData.Load(player)
	setupLeaderstats(player, data)
	pushData(player)
	refreshFollowers(player, data)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Release(player)
	PetFollowers.Clear(player)
	lastClickTimes[player.UserId] = nil
end)

-- ===== Clicking =====

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

	local earned = getClickPower(data)
	data.Coins += earned
	data.TotalCoinsEarned += earned

	updateLeaderstats(player)
	pushData(player)
end

ClickRemote.OnServerEvent:Connect(handleClick)

-- ===== Purchases =====

PurchaseUpgradeRemote.OnServerEvent:Connect(function(player, upgradeId)
	local data = PlayerData.Get(player)
	local upgrade = findById(GameConfig.Upgrades, upgradeId)
	if not data or not upgrade then
		return
	end

	local currentLevel = data.UpgradeLevels[upgradeId] or 0
	local cost = GameConfig.GetCost(upgrade, currentLevel)
	if data.Coins < cost then
		return
	end

	data.Coins -= cost
	data.UpgradeLevels[upgradeId] = currentLevel + 1
	data.ClickPower += upgrade.ClickPowerAdd

	updateLeaderstats(player)
	pushData(player)
end)

PurchaseAutoClickerRemote.OnServerEvent:Connect(function(player, autoId)
	local data = PlayerData.Get(player)
	local auto = findById(GameConfig.AutoClickers, autoId)
	if not data or not auto then
		return
	end

	local currentLevel = data.AutoClickerLevels[autoId] or 0
	local cost = GameConfig.GetCost(auto, currentLevel)
	if data.Coins < cost then
		return
	end

	data.Coins -= cost
	data.AutoClickerLevels[autoId] = currentLevel + 1

	updateLeaderstats(player)
	pushData(player)
end)

-- ===== Pets & eggs =====

local function handleHatchEgg(player, eggId)
	local data = PlayerData.Get(player)
	local egg = findById(GameConfig.Eggs, eggId)
	if not data or not egg then
		return
	end

	if data.RebirthCount < egg.RequiredRebirths then
		return
	end

	if data.Coins < egg.Cost then
		return
	end

	data.Coins -= egg.Cost

	local rolled = GameConfig.RollPet(egg)
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

	local equipChanged = false
	if #data.EquippedPetUids < GameConfig.GetMaxEquippedPets(data.RebirthCount) then
		table.insert(data.EquippedPetUids, uid)
		equipChanged = true
	end

	updateLeaderstats(player)
	pushData(player)
	EggResultRemote:FireClient(player, newPet)
	if equipChanged then
		refreshFollowers(player, data)
	end
end

HatchEggRemote.OnServerEvent:Connect(handleHatchEgg)

EquipPetRemote.OnServerEvent:Connect(function(player, name, rarity, golden)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	if #data.EquippedPetUids >= GameConfig.GetMaxEquippedPets(data.RebirthCount) then
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
		Multiplier = fusedMultiplier * 2,
		Golden = true,
	}
	table.insert(data.Pets, goldenPet)

	if #data.EquippedPetUids < GameConfig.GetMaxEquippedPets(data.RebirthCount) then
		table.insert(data.EquippedPetUids, uid)
	end

	updateLeaderstats(player)
	pushData(player)
	refreshFollowers(player, data)
end)

-- ===== Rebirth =====

local function handleRebirth(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local requirement = GameConfig.GetRebirthRequirement(data.RebirthCount)
	if data.Coins < requirement then
		return
	end

	-- Pets are a permanent collection and carry over through rebirth.
	data.Coins = 0
	data.ClickPower = GameConfig.StartingClickPower
	data.UpgradeLevels = {}
	data.AutoClickerLevels = {}
	data.RebirthCount += 1

	updateLeaderstats(player)
	pushData(player)
end

RebirthRemote.OnServerEvent:Connect(handleRebirth)

-- ===== In-world interactions (ClickDetectors on the map) =====

local function addClickDetector(part, maxDistance)
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = maxDistance or 32
	detector.Parent = part
	return detector
end

addClickDetector(mapRefs.ClickOrb).MouseClick:Connect(handleClick)
addClickDetector(mapRefs.RebirthAltar).MouseClick:Connect(handleRebirth)

for eggId, eggPart in pairs(mapRefs.EggParts) do
	addClickDetector(eggPart).MouseClick:Connect(function(player)
		handleHatchEgg(player, eggId)
	end)
end

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
			local coinsPerSecond = 0
			for _, auto in ipairs(GameConfig.AutoClickers) do
				local level = data.AutoClickerLevels[auto.Id] or 0
				coinsPerSecond += level * auto.CoinsPerSecond
			end

			if coinsPerSecond > 0 then
				local petMultiplier = GameConfig.GetPetMultiplierTotal(getEquippedPets(data))
				local earned = coinsPerSecond * petMultiplier * GameConfig.GetRebirthMultiplier(data.RebirthCount)
				data.Coins += earned
				data.TotalCoinsEarned += earned
				updateLeaderstats(player)
				pushData(player)
			end
		end
	end
end)

-- ===== Autosave =====

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerData.Save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerData.Release(player)
	end
end)
