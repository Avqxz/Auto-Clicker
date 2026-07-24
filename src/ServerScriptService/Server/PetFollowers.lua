-- Spawns and animates the equipped-pet models that visibly orbit each player,
-- matching the "pets follow you" presentation of pet-collection clicker sims.
-- These are real server-owned Workspace instances, so every client sees them.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetModelFactory = require(ReplicatedStorage.Modules.PetModelFactory)

local PetFollowers = {}

local followersFolder = Instance.new("Folder")
followersFolder.Name = "PetFollowers"
followersFolder.Parent = workspace

local playerFollowers = {} -- [player] = { { Model = Model, Index = number }, ... }

local function clearFollowers(player)
	local list = playerFollowers[player]
	if list then
		for _, entry in ipairs(list) do
			entry.Model:Destroy()
		end
	end
	playerFollowers[player] = nil
end

-- equippedPets: array of { Name, Rarity, Multiplier, Golden }
function PetFollowers.Refresh(player, equippedPets)
	clearFollowers(player)

	local list = {}
	for i, pet in ipairs(equippedPets) do
		local model = PetModelFactory.Create(pet)
		model.Parent = followersFolder
		table.insert(list, { Model = model, Index = i })
	end
	playerFollowers[player] = list
end

function PetFollowers.Clear(player)
	clearFollowers(player)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, list in pairs(playerFollowers) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local count = #list
			for _, entry in ipairs(list) do
				local angle = now * 1.5 + (entry.Index - 1) * (2 * math.pi / math.max(count, 1))
				local radius = 5.5
				local bob = math.sin(now * 2 + entry.Index) * 0.3
				local offset = Vector3.new(math.cos(angle) * radius, 2.5 + bob, math.sin(angle) * radius)
				entry.Model:PivotTo(CFrame.new(rootPart.Position + offset))
			end
		end
	end
end)

return PetFollowers
