-- Spawns and animates the equipped-pet models that follow each player: each pet keeps its own spot
-- in a formation beside and a little behind the player, turning with them and bobbing gently.
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

local SIDE_GAP = 3 -- studs from the player's side to the first pet
local SPACING = 3.4 -- studs between pets on the same side
local PER_SIDE = 2 -- pets per side before starting a row further back
local BEHIND = 2 -- studs behind the player for the first row
local ROW_GAP = 3.2
local HEIGHT = 1.2
local FOLLOW_SPEED = 10 -- how quickly pets glide into their spot (higher = snappier)

-- A pet's spot in the player's own space (+X right, +Z behind). Pets alternate left and right of the
-- player and keep the middle clear, so they never block the camera looking over the player's back.
local function slotOffset(index)
	local side = if index % 2 == 1 then -1 else 1
	local pair = (index - 1) // 2 -- 0, 0, 1, 1, 2, 2, ...
	local row = pair // PER_SIDE
	local out = pair % PER_SIDE
	return Vector3.new(side * (SIDE_GAP + out * SPACING), HEIGHT, BEHIND + row * ROW_GAP)
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local alpha = 1 - math.exp(-FOLLOW_SPEED * dt)
	for player, list in pairs(playerFollowers) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			-- The player's position and facing, level (pets stay upright).
			local look = rootPart.CFrame.LookVector
			local facing = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(look.X, 0, look.Z))
			for _, entry in ipairs(list) do
				local bob = math.sin(now * 2 + entry.Index) * 0.3
				local target = facing * CFrame.new(slotOffset(entry.Index) + Vector3.new(0, bob, 0))
				entry.Current = if entry.Current then entry.Current:Lerp(target, alpha) else target
				entry.Model:PivotTo(entry.Current)
			end
		end
	end
end)

return PetFollowers
