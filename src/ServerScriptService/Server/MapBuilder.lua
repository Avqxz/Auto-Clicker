-- Procedurally builds the game's map on server start: a Farm zone (ground,
-- spawn, click plaza, rebirth altar, Basic Egg hatchery) connected by a path
-- to a Desert zone (sand terrain, Golden Egg hatchery). Styled after
-- low-poly fantasy pet-sim aesthetics: layered pyramid-canopy trees, small
-- peaked-roof buildings, glowing glass egg pods, magic-circle glow pads, and
-- a distant mountain backdrop. Everything is generated in code (no binary
-- mesh/place assets) so it can live in a git repo and sync entirely through
-- Rojo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local MapBuilder = {}

local FARM_CENTER = Vector3.new(0, 0, 0)
local FARM_RADIUS = 150

local DESERT_CENTER = Vector3.new(0, 0, -450)
local DESERT_RADIUS = 100

local MOUNTAIN_COLORS_FARM = {
	Color3.fromRGB(230, 90, 170),
	Color3.fromRGB(190, 80, 210),
	Color3.fromRGB(160, 70, 200),
}

local MOUNTAIN_COLORS_DESERT = {
	Color3.fromRGB(220, 100, 150),
	Color3.fromRGB(190, 90, 160),
	Color3.fromRGB(170, 80, 140),
}

local DECOR_EGG_COLORS = {
	Color3.fromRGB(190, 90, 220),
	Color3.fromRGB(255, 90, 180),
	Color3.fromRGB(90, 220, 140),
	Color3.fromRGB(255, 210, 60),
}

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

-- Three stacked pyramid tiers on a trunk, for a faceted low-poly pine tree look.
local function buildPineTree(mapFolder, position)
	local trunkHeight = 6
	newPart({
		Name = "TreeTrunk",
		Size = Vector3.new(1.6, trunkHeight, 1.6),
		Position = position + Vector3.new(0, trunkHeight / 2, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(120, 35, 45),
		Parent = mapFolder,
	})

	local tierSizes = { 11, 8.5, 6 }
	local tierHeights = { 6, 5, 4 }
	local y = trunkHeight * 0.5
	for i, size in ipairs(tierSizes) do
		local height = tierHeights[i]
		local canopy = newPart({
			Name = "TreeCanopy",
			Size = Vector3.new(size, height, size),
			Position = position + Vector3.new(0, y + height / 2, 0),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(20, 110, 55),
			CanCollide = false,
			Parent = mapFolder,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Pyramid
		mesh.Parent = canopy
		y += height * 0.55
	end
end

-- Small decorative building: block walls, a pyramid roof, and a glowing window.
local function buildHatcheryBuilding(mapFolder, position, yRotation, roofColor, wallColor, windowColor)
	local baseCFrame = CFrame.new(position) * CFrame.Angles(0, yRotation, 0)
	local width, depth, wallHeight = 10, 8, 9

	local wallsPart = newPart({
		Name = "BuildingWalls",
		Size = Vector3.new(width, wallHeight, depth),
		CFrame = baseCFrame * CFrame.new(0, wallHeight / 2, 0),
		Material = Enum.Material.WoodPlanks,
		Color = wallColor,
		Parent = mapFolder,
	})

	local roofPart = newPart({
		Name = "BuildingRoof",
		Size = Vector3.new(width + 2, 5, depth + 2),
		CFrame = baseCFrame * CFrame.new(0, wallHeight + 2.5, 0),
		Material = Enum.Material.Wood,
		Color = roofColor,
		CanCollide = false,
		Parent = mapFolder,
	})
	local roofMesh = Instance.new("SpecialMesh")
	roofMesh.MeshType = Enum.MeshType.Pyramid
	roofMesh.Parent = roofPart

	newPart({
		Name = "Window",
		Size = Vector3.new(1.6, 2, 0.4),
		CFrame = baseCFrame * CFrame.new(0, wallHeight * 0.55, depth / 2 + 0.05),
		Material = Enum.Material.Neon,
		Color = windowColor,
		CanCollide = false,
		Parent = mapFolder,
	})

	return wallsPart
end

-- A translucent "glass" egg on a pedestal with a glowing pad underneath. Returns the egg part.
local function buildGlowingEggPod(mapFolder, name, position, podColor)
	newPart({
		Name = name .. "_Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 5, 5),
		Orientation = Vector3.new(0, 0, 90),
		Position = position,
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(235, 235, 240),
		Parent = mapFolder,
	})

	newPart({
		Name = name .. "_GlowPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 6.4, 6.4),
		Orientation = Vector3.new(0, 0, 90),
		Position = position + Vector3.new(0, 1.2, 0),
		Material = Enum.Material.Neon,
		Color = podColor,
		Transparency = 0.35,
		CanCollide = false,
		Parent = mapFolder,
	})

	local pod = newPart({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 6, 5),
		Position = position + Vector3.new(0, 6, 0),
		Material = Enum.Material.Glass,
		Color = podColor,
		Transparency = 0.35,
		Parent = mapFolder,
	})

	return pod
end

-- A small purely-decorative glass egg (no gameplay function) used to fill out a
-- colorful row next to the real hatchery pod, echoing multi-colored egg displays.
local function buildDecorEggPod(mapFolder, position, color, scale)
	newPart({
		Name = "DecorEggPedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 2.4 * scale, 2.4 * scale),
		Orientation = Vector3.new(0, 0, 90),
		Position = position,
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(90, 65, 45),
		CanCollide = false,
		Parent = mapFolder,
	})

	newPart({
		Name = "DecorEgg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6 * scale, 3.4 * scale, 2.6 * scale),
		Position = position + Vector3.new(0, 2.2 * scale, 0),
		Material = Enum.Material.Glass,
		Color = color,
		Transparency = 0.3,
		CanCollide = false,
		Parent = mapFolder,
	})
end

-- Small glowing teal spike accents scattered on the ground for extra color detail.
local function scatterGrassTufts(mapFolder, center, count, spreadRadius, rng)
	for _ = 1, count do
		local x = (rng:NextNumber() - 0.5) * spreadRadius * 2
		local z = (rng:NextNumber() - 0.5) * spreadRadius * 2
		if Vector2.new(x, z).Magnitude < spreadRadius then
			local tuft = newPart({
				Name = "GrassTuft",
				Size = Vector3.new(1, 2 + rng:NextNumber(), 1),
				Position = center + Vector3.new(x, 1, z),
				Orientation = Vector3.new(0, rng:NextNumber() * 360, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(60, 200, 190),
				CanCollide = false,
				CanQuery = false,
				Parent = mapFolder,
			})
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Pyramid
			mesh.Parent = tuft
		end
	end
end

-- A thin pole with a glowing top, for path lighting accents.
local function buildLampPost(mapFolder, position)
	newPart({
		Name = "LampPost",
		Size = Vector3.new(0.8, 10, 0.8),
		Position = position + Vector3.new(0, 5, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(70, 70, 90),
		CanCollide = false,
		Parent = mapFolder,
	})

	newPart({
		Name = "LampGlow",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = position + Vector3.new(0, 10, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 200, 255),
		CanCollide = false,
		Parent = mapFolder,
	})
end

-- A larger, bolder neon BillboardGui sign (vs. addSign's compact info labels).
local function addBigNeonSign(parent, text, offsetY, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 260, 0, 90)
	billboard.StudsOffset = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(10, 10, 30)
	label.Text = text
	label.Parent = billboard
end

-- Small toadstool prop: white stem + a colored cap.
local function buildMushroom(mapFolder, position, capColor, scale)
	scale = scale or 1
	newPart({
		Name = "MushroomStem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6 * scale, 0.7 * scale, 0.7 * scale),
		Orientation = Vector3.new(0, 0, 90),
		Position = position + Vector3.new(0, 0.8 * scale, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(240, 235, 220),
		CanCollide = false,
		Parent = mapFolder,
	})

	local cap = newPart({
		Name = "MushroomCap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.2 * scale, 1.3 * scale, 2.2 * scale),
		Position = position + Vector3.new(0, 1.5 * scale, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = capColor,
		CanCollide = false,
		Parent = mapFolder,
	})
	return cap
end

-- Small rounded shrub prop made of two overlapping spheres.
local function buildBush(mapFolder, position, scale)
	scale = scale or 1
	for _, yOffset in ipairs({ 0, 1.1 * scale }) do
		newPart({
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.2 * scale, 2.6 * scale, 3.2 * scale),
			Position = position + Vector3.new(0, 1.3 * scale + yOffset * 0.4, 0),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(50, 150, 70),
			CanCollide = false,
			Parent = mapFolder,
		})
	end
end

-- A small central-hub landmark: a round basin with a glowing "water" column.
local function buildFountain(mapFolder, position)
	newPart({
		Name = "FountainBasin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 14, 14),
		Orientation = Vector3.new(0, 0, 90),
		Position = position + Vector3.new(0, 1, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(230, 220, 235),
		Parent = mapFolder,
	})

	newPart({
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 11, 11),
		Orientation = Vector3.new(0, 0, 90),
		Position = position + Vector3.new(0, 1.6, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(90, 190, 255),
		Transparency = 0.25,
		CanCollide = false,
		Parent = mapFolder,
	})

	newPart({
		Name = "FountainSpout",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 2, 2),
		Orientation = Vector3.new(0, 0, 90),
		Position = position + Vector3.new(0, 6, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(140, 210, 255),
		Transparency = 0.2,
		CanCollide = false,
		Parent = mapFolder,
	})
end

-- A glowing portal-style gate: two pillars with a translucent energy field between them.
local function buildPortalGate(mapFolder, position, width, height, fieldColor, pillarColor)
	for _, side in ipairs({ -1, 1 }) do
		newPart({
			Name = "GatePillar",
			Size = Vector3.new(3, height, 3),
			Position = position + Vector3.new(side * width / 2, height / 2, 0),
			Material = Enum.Material.Sandstone,
			Color = pillarColor,
			Parent = mapFolder,
		})
	end

	local field = newPart({
		Name = "GateField",
		Size = Vector3.new(width - 2, height - 2, 0.6),
		Position = position + Vector3.new(0, height / 2, 0),
		Material = Enum.Material.Neon,
		Color = fieldColor,
		Transparency = 0.45,
		CanCollide = false,
		Parent = mapFolder,
	})

	return field
end

-- A flat glowing disc, for magic-circle-style ground accents.
local function addGlowPad(mapFolder, position, radius, color)
	newPart({
		Name = "GlowPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		Orientation = Vector3.new(0, 0, 90),
		Position = position,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.5,
		CanCollide = false,
		Parent = mapFolder,
	})
end

-- Scattered distant low-poly mountains (pyramid meshes) as a non-collidable backdrop.
local function buildMountainBackdrop(mapFolder, center, innerRadius, rng, colorPalette)
	for _ = 1, 10 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRadius + rng:NextNumber() * 80
		local x = center.X + math.cos(angle) * radius
		local z = center.Z + math.sin(angle) * radius
		local height = 60 + rng:NextNumber() * 60
		local width = 40 + rng:NextNumber() * 30

		local mountain = newPart({
			Name = "Mountain",
			Size = Vector3.new(width, height, width),
			Position = Vector3.new(x, height / 2 - 10, z),
			Orientation = Vector3.new(0, rng:NextNumber() * 360, 0),
			Material = Enum.Material.Slate,
			Color = colorPalette[rng:NextInteger(1, #colorPalette)],
			CanCollide = false,
			CanQuery = false,
			Parent = mapFolder,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Pyramid
		mesh.Parent = mountain
	end
end

-- A ring of posts (with connecting rails) around `center`, with a gap left open
-- facing `gapAngle` (radians) so a connecting path isn't blocked.
local function buildFenceRing(mapFolder, center, radius, postCount, color, gapAngle)
	local postPositions = {}
	for i = 1, postCount do
		local angle = (i / postCount) * math.pi * 2
		if not gapAngle or math.abs(angle - gapAngle) > math.rad(20) then
			local pos = center + Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)
			newPart({
				Name = "FencePost",
				Size = Vector3.new(2, 8, 2),
				Position = pos,
				Material = Enum.Material.Wood,
				Color = color,
				Parent = mapFolder,
			})
			postPositions[i] = pos
		end
	end

	for i = 1, postCount do
		local a, b = postPositions[i], postPositions[i + 1]
		if a and b and (a - b).Magnitude < radius then
			local mid = (a + b) / 2 + Vector3.new(0, 1, 0)
			local rail = newPart({
				Name = "FenceRail",
				Size = Vector3.new(1, 1, (a - b).Magnitude),
				Material = Enum.Material.Wood,
				Color = color,
				CanCollide = false,
				Parent = mapFolder,
			})
			rail.CFrame = CFrame.new(mid, b + Vector3.new(0, 1, 0))
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

		local podColor = if egg.RequiredRebirths > 0 then Color3.fromRGB(255, 200, 90) else Color3.fromRGB(130, 220, 255)

		newPart({
			Name = egg.Id .. "_Stand",
			Size = Vector3.new(11, 2, 11),
			Position = Vector3.new(position.X, 1, position.Z),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(110, 80, 55),
			Parent = mapFolder,
		})

		local pod = buildGlowingEggPod(mapFolder, egg.Id, Vector3.new(position.X, 2, position.Z), podColor)
		addSign(pod, egg.Name .. "\n" .. tostring(egg.Cost) .. " coins", 5, Color3.fromRGB(255, 255, 255))

		-- Row of small decorative multi-colored eggs beside the real hatchery pod.
		local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local sideDir = Vector3.new(math.cos(angle), 0, -math.sin(angle))
		local rowCenter = position + dir * 9
		for j = 1, #DECOR_EGG_COLORS do
			local decorOffset = sideDir * ((j - (#DECOR_EGG_COLORS + 1) / 2) * 4)
			local decorPos = rowCenter + decorOffset
			buildDecorEggPod(mapFolder, Vector3.new(decorPos.X, 1, decorPos.Z), DECOR_EGG_COLORS[j], 0.6)
		end

		if i == 1 then
			addBigNeonSign(pod, "EGGS", 9, Color3.fromRGB(80, 220, 255))
		end

		eggParts[egg.Id] = pod
	end

	return eggParts
end

local function buildLighting()
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 13
	Lighting.Ambient = Color3.fromRGB(100, 95, 115)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 160, 180)
	Lighting.FogEnd = 950

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(220, 215, 255)
	atmosphere.Decay = Color3.fromRGB(120, 110, 170)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Saturation = 0.25
	colorCorrection.Contrast = 0.08
	colorCorrection.Brightness = 0.02
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

	addGlowPad(mapFolder, FARM_CENTER + Vector3.new(0, 6.6, 0), 5.5, Color3.fromRGB(255, 210, 90))

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
	addGlowPad(mapFolder, FARM_CENTER + Vector3.new(30, 2.1, -60), 7, Color3.fromRGB(180, 100, 255))

	-- Basic Egg hatchery, arced toward the desert path (south side)
	local eggParts = buildEggStalls(mapFolder, eggs, FARM_CENTER + Vector3.new(-25, 0, -70), DESERT_CENTER)

	-- Fountain landmark near spawn
	buildFountain(mapFolder, FARM_CENTER + Vector3.new(22, 0, 25))

	-- Decorative village buildings flanking the spawn path; the left one doubles as the Shop landmark
	local shopWalls = buildHatcheryBuilding(
		mapFolder,
		FARM_CENTER + Vector3.new(-45, 0, 15),
		math.rad(200),
		Color3.fromRGB(200, 60, 60),
		Color3.fromRGB(60, 55, 70),
		Color3.fromRGB(255, 200, 80)
	)
	addBigNeonSign(shopWalls, "SHOP", 9, Color3.fromRGB(255, 200, 80))

	buildHatcheryBuilding(
		mapFolder,
		FARM_CENTER + Vector3.new(45, 0, 15),
		math.rad(160),
		Color3.fromRGB(70, 130, 200),
		Color3.fromRGB(55, 60, 75),
		Color3.fromRGB(120, 220, 255)
	)

	-- Border fence, gap facing south toward the Desert path
	buildFenceRing(mapFolder, FARM_CENTER, FARM_RADIUS, 24, Color3.fromRGB(90, 60, 40), math.rad(270))

	-- Scattered pine trees outside the plaza
	local rng = Random.new(42)
	for _ = 1, 24 do
		local x = (rng:NextNumber() - 0.5) * 290
		local z = (rng:NextNumber() - 0.5) * 290
		if Vector2.new(x, z).Magnitude > 60 then
			buildPineTree(mapFolder, FARM_CENTER + Vector3.new(x, 0, z))
		end
	end

	-- Scattered mushrooms and bushes for micro-prop variety
	local propRng = Random.new(77)
	local mushroomColors = { Color3.fromRGB(220, 60, 70), Color3.fromRGB(255, 150, 60), Color3.fromRGB(230, 90, 200) }
	for _ = 1, 18 do
		local x = (propRng:NextNumber() - 0.5) * 260
		local z = (propRng:NextNumber() - 0.5) * 260
		if Vector2.new(x, z).Magnitude > 55 then
			buildMushroom(
				mapFolder,
				FARM_CENTER + Vector3.new(x, 0, z),
				mushroomColors[propRng:NextInteger(1, #mushroomColors)],
				0.8 + propRng:NextNumber() * 0.6
			)
		end
	end
	for _ = 1, 14 do
		local x = (propRng:NextNumber() - 0.5) * 260
		local z = (propRng:NextNumber() - 0.5) * 260
		if Vector2.new(x, z).Magnitude > 55 then
			buildBush(mapFolder, FARM_CENTER + Vector3.new(x, 0, z), 0.8 + propRng:NextNumber() * 0.5)
		end
	end

	-- Small glowing teal accent tufts
	scatterGrassTufts(mapFolder, FARM_CENTER, 40, 140, Random.new(303))

	-- Distant mountain backdrop
	buildMountainBackdrop(mapFolder, FARM_CENTER, FARM_RADIUS + 40, Random.new(101), MOUNTAIN_COLORS_FARM)

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

	-- Glowing volcanic cracks, echoing the lava-zone reference art
	for _ = 1, 6 do
		local x = (rng:NextNumber() - 0.5) * 170
		local z = (rng:NextNumber() - 0.5) * 170
		if Vector2.new(x, z).Magnitude > 45 then
			newPart({
				Name = "LavaCrack",
				Size = Vector3.new(1 + rng:NextNumber() * 2, 0.15, 6 + rng:NextNumber() * 6),
				Orientation = Vector3.new(0, rng:NextNumber() * 360, 0),
				Position = DESERT_CENTER + Vector3.new(x, 0.1, z),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 130, 40),
				Transparency = 0.15,
				CanCollide = false,
				Parent = mapFolder,
			})
		end
	end

	-- Distant mountain backdrop
	buildMountainBackdrop(mapFolder, DESERT_CENTER, DESERT_RADIUS + 30, Random.new(202), MOUNTAIN_COLORS_DESERT)

	return {
		EggParts = eggParts,
	}
end

local function buildPath(mapFolder)
	local farmEdgeZ = FARM_CENTER.Z - FARM_RADIUS
	local desertEdgeZ = DESERT_CENTER.Z + DESERT_RADIUS
	local length = farmEdgeZ - desertEdgeZ
	local width = 16
	local tileSize = 8

	-- Checkered path tiles instead of one flat color
	local tilesZ = math.ceil(length / tileSize)
	local tilesX = math.ceil(width / tileSize)
	local colorA = Color3.fromRGB(235, 110, 130)
	local colorB = Color3.fromRGB(215, 90, 110)
	for row = 0, tilesZ - 1 do
		for col = 0, tilesX - 1 do
			local isAlt = (row + col) % 2 == 0
			newPart({
				Name = "PathTile",
				Size = Vector3.new(tileSize, 1, tileSize),
				Position = Vector3.new(
					-width / 2 + col * tileSize + tileSize / 2,
					0.5,
					desertEdgeZ + row * tileSize + tileSize / 2
				),
				Material = Enum.Material.SmoothPlastic,
				Color = if isAlt then colorA else colorB,
				Parent = mapFolder,
			})
		end
	end

	-- Lamp posts flanking the path
	for i = 1, math.floor(length / 40) do
		local z = farmEdgeZ - i * 40
		buildLampPost(mapFolder, Vector3.new(width / 2 + 2, 0, z))
		buildLampPost(mapFolder, Vector3.new(-width / 2 - 2, 0, z))
	end

	-- Portal-style gate marking the Desert entrance
	local gateField = buildPortalGate(
		mapFolder,
		Vector3.new(0, 0, desertEdgeZ),
		16,
		14,
		Color3.fromRGB(255, 170, 90),
		Color3.fromRGB(195, 170, 130)
	)
	addSign(gateField, "DESERT ZONE\nGolden Egg - Requires 1 Rebirth", 6, Color3.fromRGB(255, 220, 150))
end

-- Returns references to the interactive parts so init.server.lua can wire up ClickDetectors.
function MapBuilder.Build()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	-- Remove the default "Baseplate" template part if present, since it
	-- overlaps our own FarmGround at nearly the same height and causes
	-- z-fighting / lets the player spawn on the wrong surface.
	local defaultBaseplate = workspace:FindFirstChild("Baseplate")
	if defaultBaseplate and defaultBaseplate:IsA("BasePart") then
		defaultBaseplate:Destroy()
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
