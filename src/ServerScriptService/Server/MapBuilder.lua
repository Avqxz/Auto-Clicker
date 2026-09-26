-- Minimal FUNCTIONAL map markers only, organized into the Zones / Spawns /
-- Interactives folder architecture common to Roblox simulator maps.
-- Deliberately not decorative: procedurally-generated primitive parts
-- (boxes/spheres/pyramids) have a hard visual ceiling and were never going
-- to look as good as a real asset pack placed by hand in Studio. This script
-- only creates what gameplay actually needs (spawn point, click point,
-- rebirth altar, one marker per egg, and the Desert zone gate), each labeled
-- with a floating text tag so they're easy to find and either dress up or
-- leave as-is. Everything else -- ground, trees, buildings, terrain -- is
-- meant to be built by hand with Toolbox assets.
--
-- IMPORTANT: this script destroys and rebuilds its own "Map" folder in
-- Workspace every time the server starts. Do NOT put hand-placed scenery
-- inside that folder, or it'll be wiped on the next Play/publish -- put your
-- own assets in a separate folder (or loose in Workspace) instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local MapBuilder = {}

local FARM_CENTER = Vector3.new(0, 0, 0)
local DESERT_CENTER = Vector3.new(0, 0, -450)
local DESERT_DOOR_Z = -150

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

local function addLabel(parent, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 160, 0, 34)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = billboard
end

-- Places one small marker per egg along an arc in front of `center`, facing
-- back toward `facingCenter`. Returns { [eggId] = eggPart }.
local function buildEggMarkers(parentFolder, eggs, center, facingCenter)
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

		local pod = newPart({
			Name = egg.Id,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			Position = Vector3.new(position.X, 3, position.Z),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 255, 255),
			Parent = parentFolder,
		})
		addLabel(pod, "Egg: " .. egg.Name)

		eggParts[egg.Id] = pod
	end

	return eggParts
end

-- Returns references to the interactive parts so init.server.lua can wire up
-- ClickDetectors and the Desert zone gate's Touched-based rebirth check.
function MapBuilder.Build()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	-- Remove the default "Baseplate" template part if present, since it
	-- overlaps our own ground at nearly the same height and causes
	-- z-fighting / lets the player spawn on the wrong surface.
	local defaultBaseplate = workspace:FindFirstChild("Baseplate")
	if defaultBaseplate and defaultBaseplate:IsA("BasePart") then
		defaultBaseplate:Destroy()
	end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = workspace

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = mapFolder

	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "Spawns"
	spawnsFolder.Parent = mapFolder

	local interactivesFolder = Instance.new("Folder")
	interactivesFolder.Name = "Interactives"
	interactivesFolder.Parent = mapFolder

	-- Plain flat placeholder ground spanning both zones, just so players
	-- don't fall through while you build real terrain/scenery. Replace or
	-- hide this once you've placed real assets.
	newPart({
		Name = "PlaceholderGround",
		Size = Vector3.new(500, 4, 750),
		Position = Vector3.new(0, -2, -225),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(160, 160, 165),
		Parent = zonesFolder,
	})

	-- Desert zone gate: a full-width barrier players must physically cross,
	-- gated by rebirths (see init.server.lua for the Touched-based check).
	local desertDoor = newPart({
		Name = "DesertDoor",
		Size = Vector3.new(500, 20, 2),
		Position = Vector3.new(0, 10, DESERT_DOOR_Z),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(220, 70, 70),
		Transparency = 0.5,
		Parent = zonesFolder,
	})
	addLabel(desertDoor, "Desert Zone Gate")

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "MainSpawn"
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = FARM_CENTER + Vector3.new(0, 1.5, 25)
	spawnLocation.Anchored = true
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Color = Color3.fromRGB(255, 215, 60)
	spawnLocation.Duration = 0
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = spawnsFolder
	addLabel(spawnLocation, "Spawn")

	local clickOrb = newPart({
		Name = "ClickOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		Position = FARM_CENTER + Vector3.new(0, 4, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 40),
		Parent = interactivesFolder,
	})
	addLabel(clickOrb, "Click Point")

	local altar = newPart({
		Name = "RebirthAltar",
		Size = Vector3.new(6, 2, 6),
		Position = FARM_CENTER + Vector3.new(30, 1, -60),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(160, 60, 220),
		Parent = interactivesFolder,
	})
	addLabel(altar, "Rebirth Altar")

	local farmEggs, desertEggs = {}, {}
	for _, egg in ipairs(GameConfig.Eggs) do
		if egg.Zone == "Desert" then
			table.insert(desertEggs, egg)
		else
			table.insert(farmEggs, egg)
		end
	end

	local eggParts = {}
	local farmEggMarkers =
		buildEggMarkers(interactivesFolder, farmEggs, FARM_CENTER + Vector3.new(-25, 0, -70), DESERT_CENTER)
	for id, part in pairs(farmEggMarkers) do
		eggParts[id] = part
	end
	local desertEggMarkers =
		buildEggMarkers(interactivesFolder, desertEggs, DESERT_CENTER + Vector3.new(0, 0, -35), FARM_CENTER)
	for id, part in pairs(desertEggMarkers) do
		eggParts[id] = part
	end

	return {
		ClickOrb = clickOrb,
		RebirthAltar = altar,
		EggParts = eggParts,
		DesertDoor = desertDoor,
	}
end

return MapBuilder
