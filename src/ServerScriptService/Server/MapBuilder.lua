-- Procedurally builds the game's map on server start: ground, spawn, a central
-- click plaza, egg hatchery stalls, a rebirth altar, and light decoration.
-- Everything is generated in code (no binary mesh/place assets) so it can live
-- in a git repo and sync entirely through Rojo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local MapBuilder = {}

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

local function buildLighting()
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.Ambient = Color3.fromRGB(90, 90, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.FogEnd = 700

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

-- Returns references to the interactive parts so init.server.lua can wire up ClickDetectors.
function MapBuilder.Build()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = workspace

	-- Ground
	newPart({
		Name = "Ground",
		Size = Vector3.new(320, 4, 320),
		Position = Vector3.new(0, -2, 0),
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
		Position = Vector3.new(0, 1, 0),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(150, 140, 130),
		Parent = mapFolder,
	})

	-- Spawn
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "MainSpawn"
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = Vector3.new(0, 1.5, 25)
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
		Position = Vector3.new(0, 3, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(230, 220, 200),
		Parent = mapFolder,
	})

	local clickOrb = newPart({
		Name = "ClickOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Position = Vector3.new(0, 9, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 40),
		Parent = mapFolder,
	})
	addSign(clickOrb, "CLICK ME!", 4.5, Color3.fromRGB(255, 215, 60))

	-- Egg hatchery stalls, arranged in an arc behind the plaza
	local eggParts = {}
	local eggCount = #GameConfig.Eggs
	for i, egg in ipairs(GameConfig.Eggs) do
		local t = if eggCount > 1 then (i - 1) / (eggCount - 1) else 0.5
		local angle = (t - 0.5) * math.pi -- spread across a semicircle
		local radius = 48
		local x = math.sin(angle) * radius
		local z = -math.cos(angle) * radius - 15

		local stallColor = if egg.RequiredRebirths > 0 then Color3.fromRGB(210, 170, 40) else Color3.fromRGB(120, 90, 60)

		newPart({
			Name = egg.Id .. "_Stand",
			Size = Vector3.new(9, 3, 9),
			Position = Vector3.new(x, 1.5, z),
			Material = Enum.Material.Wood,
			Color = stallColor,
			Parent = mapFolder,
		})

		local eggPart = newPart({
			Name = egg.Id,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(5, 6, 5),
			Position = Vector3.new(x, 6.5, z),
			Material = Enum.Material.SmoothPlastic,
			Color = stallColor,
			Parent = mapFolder,
		})
		addSign(eggPart, egg.Name .. "\n" .. tostring(egg.Cost) .. " coins", 5, Color3.fromRGB(255, 255, 255))

		eggParts[egg.Id] = eggPart
	end

	-- Rebirth altar
	local altar = newPart({
		Name = "RebirthAltar",
		Size = Vector3.new(10, 2, 10),
		Position = Vector3.new(0, 1, -75),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(160, 60, 220),
		Parent = mapFolder,
	})
	addSign(altar, "REBIRTH ALTAR", 4, Color3.fromRGB(200, 120, 255))

	-- Border fence
	local postCount = 24
	local fenceRadius = 150
	for i = 1, postCount do
		local angle = (i / postCount) * math.pi * 2
		newPart({
			Name = "FencePost",
			Size = Vector3.new(2, 8, 2),
			Position = Vector3.new(math.cos(angle) * fenceRadius, 3, math.sin(angle) * fenceRadius),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(90, 60, 40),
			Parent = mapFolder,
		})
	end

	-- Scattered trees outside the plaza
	local rng = Random.new(42)
	for _ = 1, 24 do
		local x = (rng:NextNumber() - 0.5) * 280
		local z = (rng:NextNumber() - 0.5) * 280
		if Vector2.new(x, z).Magnitude > 60 then
			newPart({
				Name = "TreeTrunk",
				Size = Vector3.new(2, 8, 2),
				Position = Vector3.new(x, 4, z),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(90, 60, 40),
				Parent = mapFolder,
			})
			newPart({
				Name = "TreeLeaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(10, 10, 10),
				Position = Vector3.new(x, 10, z),
				Material = Enum.Material.Grass,
				Color = Color3.fromRGB(60, 140, 60),
				Parent = mapFolder,
			})
		end
	end

	buildLighting()

	return {
		ClickOrb = clickOrb,
		RebirthAltar = altar,
		EggParts = eggParts,
	}
end

return MapBuilder
