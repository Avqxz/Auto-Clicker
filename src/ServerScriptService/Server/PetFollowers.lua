-- Spawns and animates the equipped-pet models that follow each player: each pet keeps its own spot
-- in a formation behind the player (rows of up to PER_ROW), turning with them and bobbing gently.
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

local PER_ROW = 4
local SPACING = 3.2 -- studs between pets in a row
local BEHIND = 5 -- studs behind the player for the first row
local ROW_GAP = 3.2
local HEIGHT = 2.5
local FOLLOW_SPEED = 10 -- how quickly pets glide into their spot (higher = snappier)

-- A pet's spot in the player's own space (+Z is behind the player).
local function slotOffset(index, count)
	local row = (index - 1) // PER_ROW
	local inRow = math.min(PER_ROW, count - row * PER_ROW)
	local column = (index - 1) % PER_ROW
	return Vector3.new((column - (inRow - 1) / 2) * SPACING, HEIGHT, BEHIND + row * ROW_GAP)
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
			local count = #list
			for _, entry in ipairs(list) do
				local bob = math.sin(now * 2 + entry.Index) * 0.3
				local target = facing * CFrame.new(slotOffset(entry.Index, count) + Vector3.new(0, bob, 0))
				entry.Current = if entry.Current then entry.Current:Lerp(target, alpha) else target
				entry.Model:PivotTo(entry.Current)
			end
		end
	end
end)

return PetFollowers
