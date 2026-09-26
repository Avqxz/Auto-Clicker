-- Handles loading, caching, and saving per-player data via DataStoreService.

local DataStoreService = game:GetService("DataStoreService")

local PlayerData = {}
PlayerData.Cache = {}

-- GetDataStore throws in an unpublished place (Studio testing with no real
-- place/universe id) or when API access isn't enabled. Degrade gracefully
-- instead of letting that crash the whole server script: fall back to
-- in-memory-only data (no persistence) rather than erroring.
local storeSuccess, storeOrError = pcall(function()
	return DataStoreService:GetDataStore("ClickingSimulator_PlayerData_v1")
end)

if storeSuccess then
	PlayerData.Store = storeOrError
else
	PlayerData.Store = nil
	warn("[PlayerData] DataStore unavailable, progress will not be saved: " .. tostring(storeOrError))
end

local DEFAULT_DATA = {
	Coins = 0,
	ClickPower = 1,
	UpgradeLevels = {},
	AutoClickerLevels = {},
	RebirthCount = 0,
	TotalCoinsEarned = 0,
	Pets = {}, -- array of { Uid, Name, Rarity, Multiplier, Golden }
	EquippedPetUids = {},
	NextPetUid = 1,
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

	local data
	if PlayerData.Store then
		local success, result = pcall(function()
			return PlayerData.Store:GetAsync(key)
		end)

		if success and result then
			data = withDefaults(result)
		else
			if not success then
				warn(("[PlayerData] Failed to load data for %s: %s"):format(player.Name, tostring(result)))
			end
			data = deepCopy(DEFAULT_DATA)
		end
	else
		data = deepCopy(DEFAULT_DATA)
	end

	PlayerData.Cache[player.UserId] = data
	return data
end

function PlayerData.Get(player)
	return PlayerData.Cache[player.UserId]
end

function PlayerData.Save(player)
	if not PlayerData.Store then
		return
	end

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
