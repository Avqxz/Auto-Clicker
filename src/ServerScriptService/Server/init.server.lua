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
local RebirthRemote = createRemoteEvent("Rebirth")
local DataUpdatedRemote = createRemoteEvent("DataUpdated")
local HatchEggRemote = createRemoteEvent("HatchEgg")
local EquipPetRemote = createRemoteEvent("EquipPet")
local UnequipPetRemote = createRemoteEvent("UnequipPet")
local FusePetsRemote = createRemoteEvent("FusePets")
local EggResultRemote = createRemoteEvent("EggResult")
local ZoneLockedRemote = createRemoteEvent("ZoneLocked")

local FeedbackRemote=createRemoteEvent("Feedback")
local AnnouncementRemote=createRemoteEvent("Announcement")
local RedeemCodeRemote=createRemoteEvent("RedeemCode")
local RequestDataRemote=createRemoteEvent("RequestData")
local PromoCodes=require(script.PromoCodes)
local lastClickTimes = {}
local limits={}
local function allow(player,key,seconds)
 local id=player.UserId limits[id]=limits[id] or {}
 local now=os.clock() if now-(limits[id][key] or -math.huge)<seconds then return false end
 limits[id][key]=now return true
end
local function earn(data,amount)
 data.Coins=math.min(GameConfig.MaxCurrency,data.Coins+amount)
 data.TotalCoinsEarned=math.min(GameConfig.MaxCurrency,data.TotalCoinsEarned+amount)
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
	leaderstats.Coins.Value = math.floor(data.Coins)
	leaderstats.Rebirths.Value = data.RebirthCount
end

local function setupLeaderstats(player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("NumberValue")
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
 if not data then return end
 if not player.Parent then PlayerData.Release(player) return end
	setupLeaderstats(player, data)
	pushData(player)
	refreshFollowers(player, data)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Release(player)
	PetFollowers.Clear(player)
	lastClickTimes[player.UserId] = nil
 limits[player.UserId]=nil
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
	earn(data,earned)

	updateLeaderstats(player)
	pushData(player)
end

ClickRemote.OnServerEvent:Connect(handleClick)

-- ===== Purchases =====

PurchaseUpgradeRemote.OnServerEvent:Connect(function(player, upgradeId)
 if type(upgradeId)~="string" or not allow(player,"purchase",0.12) then return end
	local data = PlayerData.Get(player)
	local upgrade = findById(GameConfig.Upgrades, upgradeId)
	if not data or not upgrade then
		return
	end

	local currentLevel = data.UpgradeLevels[upgradeId] or 0
	if currentLevel>=GameConfig.MaxUpgradeLevel then return end
 local cost = GameConfig.GetCost(upgrade, currentLevel)
	if data.Coins < cost then
		return
	end

	data.Coins -= cost
	data.UpgradeLevels[upgradeId] = currentLevel + 1
	data.ClickPower += upgrade.ClickPowerAdd
 FeedbackRemote:FireClient(player,"Purchase","Upgrade purchased!")

	updateLeaderstats(player)
	pushData(player)
end)

PurchaseAutoClickerRemote.OnServerEvent:Connect(function(player, autoId)
 if type(autoId)~="string" or not allow(player,"purchase",0.12) then return end
	local data = PlayerData.Get(player)
	local auto = findById(GameConfig.AutoClickers, autoId)
	if not data or not auto then
		return
	end

	local currentLevel = data.AutoClickerLevels[autoId] or 0
	if currentLevel>=GameConfig.MaxUpgradeLevel then return end
 local cost = GameConfig.GetCost(auto, currentLevel)
	if data.Coins < cost then
		return
	end

	data.Coins -= cost
	data.AutoClickerLevels[autoId] = currentLevel + 1
 FeedbackRemote:FireClient(player,"Purchase","Auto-clicker purchased!")

	updateLeaderstats(player)
	pushData(player)
end)

-- ===== Pets & eggs =====

local function handleHatchEgg(player, eggId)
 if type(eggId)~="string" or not allow(player,"hatch",GameConfig.HatchCooldown) then return end
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

	if #data.Pets>=GameConfig.MaxPets then FeedbackRemote:FireClient(player,"Info","Pet storage full. Fuse duplicates to make room.") return end
 data.Coins -= egg.Cost
 data.EggsHatched=(data.EggsHatched or 0)+1

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
 if newPet.Rarity=="Mythic" or newPet.Rarity=="Legendary" then
  AnnouncementRemote:FireAllClients(player.Name.." hatched "..newPet.Rarity.." "..newPet.Name.."!",newPet.Rarity)
 end
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
 if not allow(player,"rebirth",0.5) then return end
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
 FeedbackRemote:FireClient(player,"Rebirth","REBIRTH! Permanent multiplier x"..GameConfig.GetRebirthMultiplier(data.RebirthCount))

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

-- ===== Frost World portal (rebirth-gated teleport) =====
-- The portal is non-solid. Touching it teleports qualifying players to its
-- "Destination" attribute; everyone else gets a toast and is pushed back.

local zoneLockedCooldown = {}

mapRefs.FrostPortal.Touched:Connect(function(hit)
	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local data = PlayerData.Get(player)
	if not data then
		return
	end

	if data.RebirthCount >= GameConfig.FrostZoneRequiredRebirths then
        local root=character:FindFirstChild("HumanoidRootPart")
        if root and allow(player,"gate",1) then
         root.CFrame=CFrame.new(mapRefs.FrostPortal:GetAttribute("Destination"))
        end
		return
	end

	if zoneLockedCooldown[player.UserId] then
		return
	end
	zoneLockedCooldown[player.UserId] = true
	task.delay(0.5, function()
		zoneLockedCooldown[player.UserId] = nil
	end)

	ZoneLockedRemote:FireClient(player, GameConfig.FrostZoneRequiredRebirths)

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local delta = rootPart.Position - mapRefs.FrostPortal.Position
		delta = Vector3.new(delta.X, 0, delta.Z)
		local pushDirection = if delta.Magnitude > 0 then delta.Unit else Vector3.new(0, 0, 1)
		rootPart.CFrame = rootPart.CFrame + pushDirection * 6
	end
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
			local coinsPerSecond = 0
			for _, auto in ipairs(GameConfig.AutoClickers) do
				local level = data.AutoClickerLevels[auto.Id] or 0
				coinsPerSecond += level * auto.CoinsPerSecond
			end

			if coinsPerSecond > 0 then
				local petMultiplier = GameConfig.GetPetMultiplierTotal(getEquippedPets(data))
				local earned = coinsPerSecond * petMultiplier * GameConfig.GetRebirthMultiplier(data.RebirthCount)
				earn(data,earned)
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
 data.RedeemedCodes[code]=true earn(data,reward.Coins)
 updateLeaderstats(player) pushData(player)
 FeedbackRemote:FireClient(player,"Purchase","Code redeemed! +"..reward.Coins.." Coins")
 task.spawn(function() PlayerData.Save(player) end)
end)
