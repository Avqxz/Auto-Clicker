-- Procedurally builds the game's map on server start: a Farm zone (ground,
-- spawn, click plaza, rebirth altar, Basic Egg hatchery) connected by a path
-- to a Desert zone (sand terrain, Golden Egg hatchery). Everything is
-- generated in code (no binary mesh/place assets) so it can live in a git
-- repo and sync entirely through Rojo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local MapBuilder = {}

local FARM_CENTER = Vector3.new(0, 0, 0)
local FARM_RADIUS = 150

local DESERT_CENTER = Vector3.new(0, 0, -450)
local DESERT_RADIUS = 100

local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	return p
end

local function addSign(parent, text, offsetY, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 180, 0, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard

	return billboard
end

-- A ring of posts around `center` with a gap left open facing `gapAngle` (radians)
-- so a connecting path isn't blocked.
local function buildFenceRing(mapFolder, center, radius, postCount, color, gapAngle)
	for i = 1, postCount do
		local angle = (i / postCount) * math.pi * 2
		if not gapAngle or math.abs(angle - gapAngle) > math.rad(20) then
			newPart({
				Name = "FencePost",
				Size = Vector3.new(2, 8, 2),
				Position = center + Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius),
				Material = Enum.Material.Wood,
				Color = color,
				Parent = mapFolder,
			})
		end
	end
end

-- Places hatchery stalls for a list of eggs along an arc in front of `center`,
-- facing back toward `facingCenter`. Returns { [eggId] = eggPart }.
local function buildEggStalls(mapFolder, eggs, center, facingCenter)
	local eggParts = {}
	local count = #eggs
	if count == 0 then
		return eggParts
	end

	local forward = (facingCenter - center)
	forward = if forward.Magnitude > 0 then forward.Unit else Vector3.new(0, 0, -1)
	local baseAngle = math.atan2(forward.X, forward.Z)

	for i, egg in ipairs(eggs) do
		local t = if count > 1 then (i - 1) / (count - 1) - 0.5 else 0
		local angle = baseAngle + t * (math.pi / 3)
		local radius = 45
		local offset = Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
		local position = center + offset

		local stallColor = if egg.RequiredRebirths > 0 then Color3.fromRGB(210, 170, 40) else Color3.fromRGB(120, 90, 60)

		newPart({
			Name = egg.Id .. "_Stand",
			Size = Vector3.new(9, 3, 9),
			Position = Vector3.new(position.X, 1.5, position.Z),
			Material = Enum.Material.Wood,
			Color = stallColor,
			Parent = mapFolder,
		})

		local eggPart = newPart({
			Name = egg.Id,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(5, 6, 5),
			Position = Vector3.new(position.X, 6.5, position.Z),
			Material = Enum.Material.SmoothPlastic,
			Color = stallColor,
			Parent = mapFolder,
		})
		addSign(eggPart, egg.Name .. "\n" .. tostring(egg.Cost) .. " coins", 5, Color3.fromRGB(255, 255, 255))

		eggParts[egg.Id] = eggPart
	end

	return eggParts
end

local function buildLighting()
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.Ambient = Color3.fromRGB(90, 90, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.FogEnd = 900

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(210, 220, 255)
	atmosphere.Decay = Color3.fromRGB(90, 100, 140)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
end

local function buildFarmZone(mapFolder, eggs)
	newPart({
		Name = "FarmGround",
		Size = Vector3.new(330, 4, 330),
		Position = FARM_CENTER + Vector3.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(90, 170, 90),
		Parent = mapFolder,
	})

	-- Central plaza
	newPart({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 44, 44),
		Orientation = Vector3.new(0, 0, 90),
		Position = FARM_CENTER + Vector3.new(0, 1, 0),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(150, 140, 130),
		Parent = mapFolder,
	})

	-- Spawn
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "MainSpawn"
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = FARM_CENTER + Vector3.new(0, 1.5, 25)
	spawnLocation.Anchored = true
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Color = Color3.fromRGB(255, 215, 60)
	spawnLocation.Duration = 0
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = mapFolder

	-- Click pedestal + orb (visual centerpiece; also clickable via ClickDetector)
	newPart({
		Name = "ClickPedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 7, 7),
		Orientation = Vector3.new(0, 0, 90),
		Position = FARM_CENTER + Vector3.new(0, 3, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(230, 220, 200),
		Parent = mapFolder,
	})

	local clickOrb = newPart({
		Name = "ClickOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Position = FARM_CENTER + Vector3.new(0, 9, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 40),
		Parent = mapFolder,
	})
	addSign(clickOrb, "CLICK ME!", 4.5, Color3.fromRGB(255, 215, 60))

	-- Rebirth altar
	local altar = newPart({
		Name = "RebirthAltar",
		Size = Vector3.new(10, 2, 10),
		Position = FARM_CENTER + Vector3.new(30, 1, -60),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(160, 60, 220),
		Parent = mapFolder,
	})
	addSign(altar, "REBIRTH ALTAR", 4, Color3.fromRGB(200, 120, 255))

	-- Basic Egg hatchery, arced toward the desert path (south side)
	local eggParts = buildEggStalls(mapFolder, eggs, FARM_CENTER + Vector3.new(-25, 0, -70), DESERT_CENTER)

	-- Border fence, gap facing south toward the Desert path
	buildFenceRing(mapFolder, FARM_CENTER, FARM_RADIUS, 24, Color3.fromRGB(90, 60, 40), math.rad(270))

	-- Scattered trees outside the plaza
	local rng = Random.new(42)
	for _ = 1, 24 do
		local x = (rng:NextNumber() - 0.5) * 290
		local z = (rng:NextNumber() - 0.5) * 290
		if Vector2.new(x, z).Magnitude > 60 then
			newPart({
				Name = "TreeTrunk",
				Size = Vector3.new(2, 8, 2),
				Position = FARM_CENTER + Vector3.new(x, 4, z),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(90, 60, 40),
				Parent = mapFolder,
			})
			newPart({
				Name = "TreeLeaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(10, 10, 10),
				Position = FARM_CENTER + Vector3.new(x, 10, z),
				Material = Enum.Material.Grass,
				Color = Color3.fromRGB(60, 140, 60),
				Parent = mapFolder,
			})
		end
	end

	return {
		ClickOrb = clickOrb,
		RebirthAltar = altar,
		EggParts = eggParts,
	}
end

local function buildDesertZone(mapFolder, eggs)
	newPart({
		Name = "DesertGround",
		Size = Vector3.new(260, 4, 260),
		Position = DESERT_CENTER + Vector3.new(0, -2, 0),
		Material = Enum.Material.Sand,
		Color = Color3.fromRGB(225, 195, 130),
		Parent = mapFolder,
	})

	-- Golden Egg hatchery, arced toward the farm path (north side)
	local eggParts = buildEggStalls(mapFolder, eggs, DESERT_CENTER + Vector3.new(0, 0, -35), FARM_CENTER)

	-- Border fence, gap facing north toward the Farm path
	buildFenceRing(mapFolder, DESERT_CENTER, DESERT_RADIUS, 18, Color3.fromRGB(180, 150, 100), math.rad(90))

	-- Rocks and cacti
	local rng = Random.new(7)
	for _ = 1, 10 do
		local x = (rng:NextNumber() - 0.5) * 190
		local z = (rng:NextNumber() - 0.5) * 190
		if Vector2.new(x, z).Magnitude > 45 then
			newPart({
				Name = "DesertRock",
				Size = Vector3.new(4 + rng:NextNumber() * 3, 3 + rng:NextNumber() * 2, 4 + rng:NextNumber() * 3),
				Position = DESERT_CENTER + Vector3.new(x, 2, z),
				Orientation = Vector3.new(0, rng:NextNumber() * 360, 0),
				Material = Enum.Material.Rock,
				Color = Color3.fromRGB(150, 130, 100),
				Parent = mapFolder,
			})
		end
	end

	for _ = 1, 8 do
		local x = (rng:NextNumber() - 0.5) * 190
		local z = (rng:NextNumber() - 0.5) * 190
		if Vector2.new(x, z).Magnitude > 45 then
			newPart({
				Name = "Cactus",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(7, 1.8, 1.8),
				Orientation = Vector3.new(0, 0, 90),
				Position = DESERT_CENTER + Vector3.new(x, 3.5, z),
				Material = Enum.Material.Grass,
				Color = Color3.fromRGB(60, 130, 70),
				Parent = mapFolder,
			})
		end
	end

	return {
		EggParts = eggParts,
	}
end

local function buildPath(mapFolder)
	local farmEdgeZ = FARM_CENTER.Z - FARM_RADIUS
	local desertEdgeZ = DESERT_CENTER.Z + DESERT_RADIUS
	local length = farmEdgeZ - desertEdgeZ
	local midZ = (farmEdgeZ + desertEdgeZ) / 2

	newPart({
		Name = "DesertPath",
		Size = Vector3.new(16, 1, length),
		Position = Vector3.new(0, 0.5, midZ),
		Material = Enum.Material.Sandstone,
		Color = Color3.fromRGB(195, 170, 130),
		Parent = mapFolder,
	})

	-- Gate marker at the Desert entrance
	local gate = newPart({
		Name = "DesertGate",
		Size = Vector3.new(16, 10, 2),
		Position = Vector3.new(0, 5, desertEdgeZ),
		Material = Enum.Material.Sandstone,
		Color = Color3.fromRGB(195, 170, 130),
		Parent = mapFolder,
	})
	addSign(gate, "DESERT ZONE\nGolden Egg - Requires 1 Rebirth", 6, Color3.fromRGB(255, 220, 150))
end

-- Returns references to the interactive parts so init.server.lua can wire up ClickDetectors.
function MapBuilder.Build()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = workspace

	local farmEggs, desertEggs = {}, {}
	for _, egg in ipairs(GameConfig.Eggs) do
		if egg.Zone == "Desert" then
			table.insert(desertEggs, egg)
		else
			table.insert(farmEggs, egg)
		end
	end

	local farmRefs = buildFarmZone(mapFolder, farmEggs)
	local desertRefs = buildDesertZone(mapFolder, desertEggs)
	buildPath(mapFolder)

	buildLighting()

	local eggParts = {}
	for id, part in pairs(farmRefs.EggParts) do
		eggParts[id] = part
	end
	for id, part in pairs(desertRefs.EggParts) do
		eggParts[id] = part
	end

	return {
		ClickOrb = farmRefs.ClickOrb,
		RebirthAltar = farmRefs.RebirthAltar,
		EggParts = eggParts,
	}
end

return MapBuilder
