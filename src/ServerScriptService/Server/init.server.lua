-- Server bootstrap for the Clicking Simulator.
-- Owns all game state mutation: clicks, purchases, rebirths, and autosaving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.PlayerData)

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

-- ===== Player lifecycle =====

Players.PlayerAdded:Connect(function(player)
	local data = PlayerData.Load(player)
	setupLeaderstats(player, data)
	pushData(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Release(player)
	lastClickTimes[player.UserId] = nil
end)

-- ===== Clicking =====

ClickRemote.OnServerEvent:Connect(function(player)
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

	local earned = data.ClickPower * GameConfig.GetRebirthMultiplier(data.RebirthCount)
	data.Coins += earned
	data.TotalCoinsEarned += earned

	updateLeaderstats(player)
	pushData(player)
end)

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

-- ===== Rebirth =====

RebirthRemote.OnServerEvent:Connect(function(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local requirement = GameConfig.GetRebirthRequirement(data.RebirthCount)
	if data.Coins < requirement then
		return
	end

	data.Coins = 0
	data.ClickPower = GameConfig.StartingClickPower
	data.UpgradeLevels = {}
	data.AutoClickerLevels = {}
	data.RebirthCount += 1

	updateLeaderstats(player)
	pushData(player)
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
				local earned = coinsPerSecond * GameConfig.GetRebirthMultiplier(data.RebirthCount)
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
