-- Server side of egg hatching. The client only asks to hatch (RequestHatch: egg id, 1 or 3, manual or
-- auto); this service checks everything, takes the currency, rolls the pets (PetRollService), stores
-- them, and returns what was hatched so the client can animate it.
--
-- Checks, in order: request shape, one request at a time + cooldown (anti-spam), egg exists, Ascensions,
-- distance to the egg's pedestal, Triple/Auto unlock, currency for every egg, inventory space.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.GameConfig)
local EggConfig = require(Modules.EggConfig)
local PetConfig = require(Modules.PetConfig)
local HatchMath = require(Modules.HatchMath)
local PetRollService = require(script.Parent.PetRollService)

local EggHatchingService = {}

local PEDESTAL_TAG = "EggPedestal"
local MAX_REQUESTS_PER_SECOND = 6 -- anything faster is spam, even with Fast Hatch

-- Pet name -> rarity from the egg tables (the source of truth when tiers are renamed).
local rarityByName = {}
for _, egg in ipairs(EggConfig.Eggs) do
	for _, pet in ipairs(egg.Pets) do
		rarityByName[pet.Name] = pet.Rarity
	end
end

local function unlocked(data, unlock)
	if not unlock or (unlock.Pass == nil and unlock.Rebirths == nil) then
		return true
	end
	return (unlock.Pass ~= nil and GameConfig.HasPass(data, unlock.Pass))
		or (unlock.Rebirths ~= nil and data.RebirthCount >= unlock.Rebirths)
end
EggHatchingService.IsUnlocked = unlocked

-- Pedestal part for an egg id (tagged EggPedestal with an EggId attribute).
local function findPedestal(eggId)
	for _, part in ipairs(CollectionService:GetTagged(PEDESTAL_TAG)) do
		if part:GetAttribute("EggId") == eggId and part:IsDescendantOf(workspace) then
			return part
		end
	end
	return nil
end

-- deps: { PlayerData, pushData(player), updateLeaderstats(player), refreshFollowers(player, data),
--         getEquippedPets(data), Quests, announce(message, rarity), remotes (Folder) }
function EggHatchingService.Start(deps)
	local requestHatch = Instance.new("RemoteFunction")
	requestHatch.Name = "RequestHatch"
	requestHatch.Parent = deps.remotes
	local setAutoDelete = Instance.new("RemoteEvent")
	setAutoDelete.Name = "SetAutoDelete"
	setAutoDelete.Parent = deps.remotes

	local busy = {} -- [userId] = true while a hatch is being processed
	local lastHatch = {} -- [userId] = os.clock() of the last accepted hatch
	local requestLog = {} -- [userId] = { count, windowStart } for spam limiting

	local function fail(reason, message)
		return { Ok = false, Reason = reason, Message = message }
	end

	local function spamming(userId)
		local now = os.clock()
		local log = requestLog[userId]
		if not log or now - log[2] >= 1 then
			requestLog[userId] = { 1, now }
			return false
		end
		log[1] += 1
		return log[1] > MAX_REQUESTS_PER_SECOND
	end

	local function hatch(player, eggId, count, isAuto)
		local data = deps.PlayerData.Get(player)
		if not data then
			return fail("NoData", "Still loading, try again in a moment")
		end
		local egg = EggConfig.ById[eggId]
		if not egg then
			return fail("BadEgg", "That egg doesn't exist")
		end
		if data.RebirthCount < egg.RequiredRebirths then
			return fail("Locked", "Ascend " .. egg.RequiredRebirths .. " time" .. (if egg.RequiredRebirths == 1 then "" else "s") .. " to hatch the " .. egg.Name)
		end

		-- Near the pedestal (the Starter Egg can also be hatched from the Eggs menu, but not on auto).
		if isAuto or not egg.HatchAnywhere then
			local pedestal = findPedestal(egg.Id)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not pedestal or not root or (root.Position - pedestal.Position).Magnitude > EggConfig.ServerRange then
				return fail("TooFar", "Walk to the " .. egg.Name .. " to hatch it")
			end
		end

		if count == 3 and not unlocked(data, EggConfig.TripleHatchUnlock) then
			return fail("NeedTriple", "Triple Hatch is locked")
		end
		if isAuto and not unlocked(data, EggConfig.AutoHatchUnlock) then
			return fail("NeedAuto", "Auto Hatch is locked")
		end

		local currency = EggConfig.Currencies[egg.Currency] and egg.Currency or "Coins"
		local totalCost = egg.Cost * count
		if (data[currency] or 0) < totalCost then
			return fail("Currency", "Not enough " .. EggConfig.Currencies[currency].Name .. "!")
		end
		if #data.Pets + count > GameConfig.MaxPets then
			return fail("InventoryFull", "Pet Inventory Full!")
		end

		-- Everything checks out: pay, roll, store.
		data[currency] -= totalCost
		data.EggsHatched = (data.EggsHatched or 0) + count
		data.Discovered = data.Discovered or {}
		data.Settings = data.Settings or {}
		data.Settings.AutoDelete = data.Settings.AutoDelete or {}
		deps.Quests.Track(data, "Hatch", count)

		local luck = HatchMath.GetLuck(data, GameConfig.GetSkillLevel(data.Skills, "EggLuck"),
			GameConfig.GetPetAbilityStats(deps.getEquippedPets(data)).EggLuck)
		local maxEquipped = GameConfig.GetMaxEquippedPets(data.RebirthCount, data.Skills, data.Passes)
		local results, equipChanged = {}, false
		for _ = 1, count do
			local entry, shiny = PetRollService.Roll(egg, luck)
			local isNew = not data.Discovered[entry.Name]
			data.Discovered[entry.Name] = true
			-- Auto-delete never takes a Shiny, a first discovery, or a tier that isn't allowed.
			local deleted = data.Settings.AutoDelete[entry.Rarity] == true and PetConfig.CanAutoDelete(entry.Rarity)
				and not shiny and not isNew
			local pet = PetRollService.MakePet(data.NextPetUid, entry, shiny)
			if not deleted then
				data.NextPetUid += 1
				table.insert(data.Pets, pet)
				if #data.EquippedPetUids < maxEquipped then
					table.insert(data.EquippedPetUids, pet.Uid)
					equipChanged = true
				end
			end
			if PetConfig.AtLeast(entry.Rarity, "Legendary") then
				deps.Quests.Track(data, "HatchLegendary", 1)
			end
			if PetConfig.AtLeast(entry.Rarity, EggConfig.AnnounceMinRarity) or (shiny and EggConfig.AnnounceShiny) then
				deps.announce(string.format("%s hatched a %s%s %s!", player.DisplayName, if shiny then "SHINY " else "",
					string.upper(entry.Rarity), entry.Name), entry.Rarity)
			end
			table.insert(results, {
				Name = pet.Name,
				Rarity = pet.Rarity,
				Multiplier = pet.Multiplier,
				Shiny = shiny,
				New = isNew,
				Deleted = deleted,
			})
		end

		deps.updateLeaderstats(player)
		deps.pushData(player)
		if equipChanged then
			deps.refreshFollowers(player, data)
		end
		return { Ok = true, EggId = egg.Id, Pets = results, Luck = luck }
	end

	requestHatch.OnServerInvoke = function(player, eggId, count, isAuto)
		-- Shape checks first: never trust anything from the client.
		if type(eggId) ~= "string" or #eggId > 64 or (count ~= 1 and count ~= 3) or type(isAuto) ~= "boolean" then
			return fail("BadRequest", "")
		end
		local userId = player.UserId
		if spamming(userId) then
			return fail("Busy", "")
		end
		if busy[userId] then
			return fail("Busy", "")
		end
		local cooldown = EggConfig.HatchCooldown * (if player:GetAttribute("Pass_FastHatch") then 0.5 else 1)
		if lastHatch[userId] and os.clock() - lastHatch[userId] < cooldown then
			return fail("Cooldown", "")
		end
		busy[userId] = true
		local ok, result = pcall(hatch, player, eggId, count, isAuto)
		busy[userId] = nil
		if not ok then
			warn("[EggHatching] " .. tostring(result))
			return fail("Error", "Something went wrong, try again")
		end
		if result.Ok then
			lastHatch[userId] = os.clock()
		end
		return result
	end

	setAutoDelete.OnServerEvent:Connect(function(player, rarity, enabled)
		local data = deps.PlayerData.Get(player)
		if not data or type(rarity) ~= "string" or type(enabled) ~= "boolean" or not PetConfig.CanAutoDelete(rarity) then
			return
		end
		data.Settings = data.Settings or {}
		data.Settings.AutoDelete = data.Settings.AutoDelete or {}
		data.Settings.AutoDelete[rarity] = enabled or nil
		deps.pushData(player)
	end)

	local api = {}

	-- Bring a loaded save up to date: pets get the current tier of their species (e.g. Mythic -> Secret)
	-- and the Shiny/Level/Locked fields, and every pet already owned counts as discovered.
	function api.PrepareData(data)
		data.Discovered = data.Discovered or {}
		data.Settings = data.Settings or {}
		data.Settings.AutoDelete = data.Settings.AutoDelete or {}
		for _, pet in ipairs(data.Pets) do
			pet.Rarity = rarityByName[pet.Name] or pet.Rarity
			pet.Shiny = pet.Shiny == true
			pet.Level = pet.Level or 1
			pet.Locked = pet.Locked == true
			data.Discovered[pet.Name] = true
		end
	end

	function api.Discover(data, petName)
		data.Discovered = data.Discovered or {}
		data.Discovered[petName] = true
	end

	function api.PlayerRemoving(player)
		busy[player.UserId] = nil
		lastHatch[player.UserId] = nil
		requestLog[player.UserId] = nil
	end

	api.PedestalTag = PEDESTAL_TAG
	return api
end

return EggHatchingService
