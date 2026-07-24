-- Handles loading, caching, and saving per-player data via DataStoreService.

local DataStoreService = game:GetService("DataStoreService")

local PlayerData = {}
PlayerData.Store = DataStoreService:GetDataStore("ClickingSimulator_PlayerData_v1")
PlayerData.Cache = {}

local DEFAULT_DATA = {
	Coins = 0,
	ClickPower = 1,
	UpgradeLevels = {},
	AutoClickerLevels = {},
	RebirthCount = 0,
	TotalCoinsEarned = 0,
}

local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return copy
end

local function withDefaults(data)
	for key, defaultValue in pairs(DEFAULT_DATA) do
		if data[key] == nil then
			data[key] = if type(defaultValue) == "table" then deepCopy(defaultValue) else defaultValue
		end
	end
	return data
end

function PlayerData.Load(player)
	local key = "Player_" .. player.UserId

	local success, result = pcall(function()
		return PlayerData.Store:GetAsync(key)
	end)

	local data
	if success and result then
		data = withDefaults(result)
	else
		if not success then
			warn(("[PlayerData] Failed to load data for %s: %s"):format(player.Name, tostring(result)))
		end
		data = deepCopy(DEFAULT_DATA)
	end

	PlayerData.Cache[player.UserId] = data
	return data
end

function PlayerData.Get(player)
	return PlayerData.Cache[player.UserId]
end

function PlayerData.Save(player)
	local data = PlayerData.Cache[player.UserId]
	if not data then
		return
	end

	local key = "Player_" .. player.UserId
	local success, err = pcall(function()
		PlayerData.Store:SetAsync(key, data)
	end)

	if not success then
		warn(("[PlayerData] Failed to save data for %s: %s"):format(player.Name, tostring(err)))
	end
end

function PlayerData.Release(player)
	PlayerData.Save(player)
	PlayerData.Cache[player.UserId] = nil
end

return PlayerData
