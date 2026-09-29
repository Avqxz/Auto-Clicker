-- Spawns and animates the equipped-pet models that follow each player, on an even ring around them.
-- Most pets run along the ground (feet on the floor under their spot, hopping while the player moves,
-- sitting still when they stop); flying pets (GameConfig.PetFlies) float and bob at shoulder height.
-- Standing still, every pet faces the player; on the move, they face the way the player is going.
-- These are real server-owned Workspace instances, so every client sees them.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetModelFactory = require(ReplicatedStorage.Modules.PetModelFactory)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

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
		local _, size = model:GetBoundingBox()
		table.insert(list, { Model = model, Index = i, HalfHeight = size.Y / 2, Flies = GameConfig.PetFlies(pet.Name) })
	end
	playerFollowers[player] = list
end

function PetFollowers.Clear(player)
	clearFollowers(player)
end

local MIN_RADIUS = 4.5 -- studs from the player to the ring of pets
local SPACING = 3.2 -- studs between neighbouring pets around the ring (it grows with more pets)
local FLY_HEIGHT = 3 -- studs above the ground for flying pets
local HOP_HEIGHT = 0.7 -- how high running pets hop
local HOP_SPEED = 11 -- hops per second (radians); each pet is a little out of step
local MOVING_SPEED = 2 -- studs/second the player must move before pets run instead of sit
local FOLLOW_SPEED = 10 -- how quickly pets glide into their spot (higher = snappier)

-- The floor under a point: the world's geometry only (Map.Zones), not players, pets, or the invisible
-- clickable boxes around eggs and stations.
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include
local function groundBelow(position)
	local zones = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Zones")
	if not zones then return nil end
	groundRay.FilterDescendantsInstances = { zones }
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), groundRay)
	return hit and hit.Position.Y
end

-- A pet's spot on an even ring around the player, in the player's own space (-Z is forward). The ring
-- turns with the player but doesn't spin. Angles are offset by half a step so no pet sits dead
-- ahead: one pet is right behind, two are either side, four sit on the diagonals.
local function slotOffset(index, count, minRadius)
	local step = 2 * math.pi / count
	local angle = step / 2 + (index - 1) * step -- measured from straight ahead
	local radius = math.max(minRadius, SPACING * count / (2 * math.pi))
	return Vector3.new(math.sin(angle) * radius, 0, -math.cos(angle) * radius)
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local alpha = 1 - math.exp(-FOLLOW_SPEED * dt)
	for player, list in pairs(playerFollowers) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if rootPart and humanoid then
			-- The player's position and facing, level (pets stay upright).
			local look = rootPart.CFrame.LookVector
			local facing = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(look.X, 0, look.Z))
			local velocity = rootPart.AssemblyLinearVelocity
			local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING_SPEED
			-- Where the player's feet are, for pets that find no floor under them (bridge edges, jumps).
			local feetY = rootPart.Position.Y - rootPart.Size.Y / 2 - humanoid.HipHeight
			local count = #list
			-- Big pets (Secrets) widen the ring so they don't overlap the player.
			local ringRadius = MIN_RADIUS
			for _, entry in ipairs(list) do
				ringRadius = math.max(ringRadius, entry.HalfHeight + 3)
			end
			for _, entry in ipairs(list) do
				local spot = (facing * CFrame.new(slotOffset(entry.Index, count, ringRadius))).Position
				local floor = groundBelow(spot) or feetY
				local y
				if entry.Flies then
					-- Big pets (Secrets) float a bit higher so they clear the ground.
					y = math.max(floor, feetY) + math.max(FLY_HEIGHT, entry.HalfHeight + 1.2) + math.sin(now * 2 + entry.Index) * 0.3
				else
					local hop = if moving then math.abs(math.sin(now * HOP_SPEED + entry.Index * 1.3)) * HOP_HEIGHT else 0
					y = floor + entry.HalfHeight + hop
				end
				spot = Vector3.new(spot.X, y, spot.Z)
				-- Idle: look at the player. Moving: look where the player is heading.
				local lookAt = if moving then spot + Vector3.new(look.X, 0, look.Z)
					else Vector3.new(rootPart.Position.X, y, rootPart.Position.Z)
				local target = CFrame.lookAt(spot, lookAt)
				entry.Current = if entry.Current then entry.Current:Lerp(target, alpha) else target
				entry.Model:PivotTo(entry.Current)
			end
		end
	end
end)

return PetFollowers
