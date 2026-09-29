-- Builds a pet model. Pets from the art package use their imported model from
-- ReplicatedStorage.ArtPets (see ASSETS.md) when it's there; every other pet, or an art pet whose model
-- hasn't been imported yet, is built as a cartoon cube pet: a big blocky head on a smaller body, stubby cube feet, a cute face
-- (big eyes with highlights, smile, blush), and species parts (ears, tail, wings, horns...) chosen
-- per pet. Each pet has its own colors; Legendary/Mythic accents glow and Golden pets turn gold.
-- Used for pet followers (server) and UI icons / hatch reveal (client). Pets face -Z.

local GameConfig = require(script.Parent.GameConfig)
local ArtLook = require(script.Parent.ArtLook)

-- Tiers whose pets sparkle (as do Golden and Shiny pets).
local SPARKLY = { Mythic = true }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetModelFactory = {}

local GOLD = Color3.fromRGB(255, 205, 60)
local GOLD_LIGHT = Color3.fromRGB(255, 240, 170)
local INK = Color3.fromRGB(35, 30, 45)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLUSH = Color3.fromRGB(255, 130, 160)
local C = Color3.fromRGB

-- [pet name] = { species, main color, accent color, crown? }
local LOOKS = {
	Cat = { "cat", C(255, 170, 90), C(255, 235, 210) },
	Dog = { "dog", C(190, 130, 80), C(250, 225, 190) },
	Bunny = { "bunny", C(245, 245, 250), C(255, 175, 200) },
	Puppy = { "dog", C(235, 190, 120), C(255, 240, 215) },
	Kitten = { "cat", C(170, 170, 185), C(255, 200, 220) },
	Fox = { "fox", C(255, 130, 40), C(255, 250, 240) },
	Wolf = { "fox", C(120, 135, 160), C(225, 230, 240) },
	Dragon = { "dragon", C(90, 200, 110), C(255, 220, 90) },
	Phoenix = { "bird", C(255, 90, 50), C(255, 210, 60) },
	["Golden Retriever"] = { "dog", C(240, 190, 90), C(255, 235, 190) },
	Griffin = { "bird", C(200, 150, 80), C(250, 250, 250) },
	Unicorn = { "unicorn", C(250, 245, 255), C(255, 150, 220) },
	["Ancient Dragon"] = { "dragon", C(120, 70, 160), C(255, 200, 60) },
	["Celestial Phoenix"] = { "bird", C(120, 200, 255), C(255, 250, 190) },
	["Lava Pup"] = { "dog", C(70, 55, 60), C(255, 120, 30) },
	["Magma Golem"] = { "golem", C(90, 70, 70), C(255, 110, 30) },
	["Fire Serpent"] = { "serpent", C(255, 80, 40), C(255, 200, 60) },
	["Inferno Dragon"] = { "dragon", C(200, 40, 40), C(255, 170, 30) },
	["Volcano Titan"] = { "golem", C(50, 40, 45), C(255, 90, 20) },
	["Gummy Bear"] = { "bear", C(255, 110, 150), C(255, 200, 220) },
	["Lollipop Cat"] = { "cat", C(170, 120, 255), C(255, 230, 120) },
	["Cupcake Unicorn"] = { "unicorn", C(255, 190, 220), C(140, 210, 255) },
	["Candy Dragon"] = { "dragon", C(120, 220, 255), C(255, 130, 190) },
	["Sugar Queen"] = { "cat", C(255, 150, 200), C(255, 230, 120), true },
	Alien = { "alien", C(130, 230, 120), C(220, 255, 200) },
	["Astro Dog"] = { "dog", C(230, 230, 240), C(80, 140, 255) },
	["Nebula Fox"] = { "fox", C(120, 80, 220), C(255, 140, 230) },
	["Galaxy Dragon"] = { "dragon", C(60, 40, 140), C(130, 220, 255) },
	["Cosmic Overlord"] = { "alien", C(40, 30, 80), C(255, 220, 90), true },
}

-- Cube-pet fallback for art-package pets not imported yet: a species guessed from the name and the
-- biome's colors.
local BIOME_COLORS = {
	Grasslands = { C(120, 200, 90), C(250, 240, 200) },
	Desert = { C(230, 180, 110), C(255, 235, 190) },
	Ice = { C(200, 230, 255), C(90, 160, 230) },
	Enchanted = { C(90, 200, 190), C(200, 120, 255) },
	Volcano = { C(70, 55, 60), C(255, 110, 30) },
	Candy = { C(255, 160, 200), C(255, 240, 200) },
	Celestial = { C(240, 240, 255), C(255, 210, 80) },
}
local SPECIES_WORDS = {
	{ "dragon", "dragon" }, { "bunny", "bunny" }, { "fox", "fox" }, { "fennec", "fox" }, { "wolf", "fox" },
	{ "cat", "cat" }, { "pup", "dog" }, { "dog", "dog" }, { "camel", "dog" }, { "sphinx", "cat" },
	{ "bear", "bear" }, { "cub", "bear" }, { "deer", "unicorn" }, { "stag", "unicorn" },
	{ "owl", "bird" }, { "bird", "bird" }, { "phoenix", "bird" }, { "bat", "bird" }, { "chicken", "bird" },
	{ "angel", "bird" }, { "penguin", "bird" }, { "bee", "bird" }, { "sprite", "bird" },
	{ "cobra", "serpent" }, { "lizard", "serpent" }, { "scorpion", "serpent" }, { "scarab", "serpent" },
	{ "golem", "golem" }, { "colossus", "golem" }, { "guardian", "golem" }, { "chest", "golem" }, { "tv", "golem" },
	{ "demon", "dragon" }, { "mask", "alien" }, { "ray", "alien" },
}
local function fallbackLook(name)
	local art = GameConfig.PetArt[name]
	if not art then
		return nil
	end
	local lower = string.lower(name)
	local species = "bear"
	for _, pair in ipairs(SPECIES_WORDS) do
		if string.find(lower, pair[1], 1, true) then
			species = pair[2]
			break
		end
	end
	local colors = BIOME_COLORS[art.Biome] or { C(200, 200, 210), WHITE }
	return { species, colors[1], colors[2] }
end

-- Imported art pet: clone, make it a non-colliding decoration, size it like a cube pet, and turn it
-- to face -Z (the art faces +Z after import). Golden pets are tinted gold.
local ART_HEIGHT = 2.4
-- Secret pets are built this much bigger than other pets.
local SECRET_SCALE = 2.8
local ART_YAW = math.pi
-- Divine aura for endgame pets (PetArt entry `Aura = true`): a white rim-light outline, a pink glow on
-- the surroundings, star sparkles, slow rising motes, and flare flashes on the gem.
local AURA_PINK = Color3.fromRGB(255, 120, 200)
local AURA_PALE = Color3.fromRGB(255, 220, 240)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local function addAura(model)
	local cf, size = model:GetBoundingBox()
	local holder = Instance.new("Part")
	holder.Name = "Aura"
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Size = size * 0.8
	holder.CFrame = cf
	holder.Parent = model

	local rim = Instance.new("Highlight")
	rim.FillTransparency = 1
	rim.OutlineColor = Color3.new(1, 1, 1)
	rim.OutlineTransparency = 0.15
	rim.DepthMode = Enum.HighlightDepthMode.Occluded
	rim.Parent = model

	local glow = Instance.new("PointLight")
	glow.Color = AURA_PINK
	glow.Brightness = 1
	glow.Range = size.Y * 0.6 -- just around the pet: an equipped one follows close enough to tint its owner
	glow.Parent = holder

	local stars = Instance.new("ParticleEmitter")
	stars.Name = "Stars"
	stars.Texture = SPARKLE
	stars.Color = ColorSequence.new(Color3.new(1, 1, 1), AURA_PINK)
	stars.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, size.Y * 0.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	stars.Lifetime = NumberRange.new(0.6, 1.2)
	stars.Rate = 14
	stars.Speed = NumberRange.new(0.5, 1.5)
	stars.SpreadAngle = Vector2.new(180, 180)
	stars.Rotation = NumberRange.new(0, 360)
	stars.RotSpeed = NumberRange.new(-90, 90)
	stars.LightEmission = 1
	stars.Parent = holder

	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Texture = SPARKLE
	motes.Color = ColorSequence.new(AURA_PALE)
	motes.Size = NumberSequence.new(size.Y * 0.035)
	motes.Transparency = NumberSequence.new(0.2, 1)
	motes.Lifetime = NumberRange.new(2, 3)
	motes.Rate = 10
	motes.Speed = NumberRange.new(0)
	motes.Acceleration = Vector3.new(0, size.Y * 0.25, 0)
	motes.LightEmission = 1
	motes.Parent = holder

	-- Flare flashes centred on the gem.
	local gem
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:find("^GemMid") then -- "GemMid" or Blender's "GemMid.001"
			gem = d
			break
		end
	end
	local flarePoint = Instance.new("Attachment")
	flarePoint.Parent = holder
	flarePoint.WorldPosition = if gem then gem.Position else cf.Position
	local flare = Instance.new("ParticleEmitter")
	flare.Name = "Flare"
	flare.Texture = SPARKLE
	flare.Color = ColorSequence.new(Color3.new(1, 1, 1))
	flare.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, size.Y * 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	flare.Lifetime = NumberRange.new(0.5)
	flare.Rate = 1.5
	flare.Speed = NumberRange.new(0)
	flare.Rotation = NumberRange.new(0, 90)
	flare.LockedToPart = true
	flare.LightEmission = 1
	flare.Parent = flarePoint
end

local function buildArtPet(template, petData, withEffects, art)
	local model = template:Clone()
	if not model:IsA("Model") then
		local wrapper = Instance.new("Model")
		model.Parent = wrapper
		model = wrapper
	end
	model.Name = petData.Name
	ArtLook.Apply(model, template.Name)
	-- Imported parts carry the FBX axis turn in their PivotOffset (and imports may set a PrimaryPart),
	-- which would make the model's pivot tilted: measuring and turning around it tips the pet over.
	-- Start from an upright pivot instead.
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new()
	local biggest
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.PivotOffset = CFrame.identity
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if petData.Golden and not d.Name:find("Eye") then -- gold all over, but keep the eyes
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
				d.Color = GOLD
			end
			-- Crystal pieces are named for how see-through they are (tools/art/build_crystal_seraph.py).
			if d.Name:find("Beam") then
				d.Transparency = 0.45
			elseif d.Name:find("Glass") then
				d.Transparency = 0.12
			end
			if not biggest or d.Size.Magnitude > biggest.Size.Magnitude then
				biggest = d
			end
		end
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * ART_HEIGHT * (if petData.Rarity == "Secret" then SECRET_SCALE else 1) / math.max(size.Y, 0.1))
	local center = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(center.Position)
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, ART_YAW, 0))
	model.PrimaryPart = biggest
	model.WorldPivot = CFrame.new(model:GetBoundingBox().Position) -- upright pivot at the center
	if withEffects and biggest and (petData.Golden or petData.Shiny or SPARKLY[petData.Rarity]) then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(if petData.Golden then GOLD else GameConfig.RarityColors.Mythic)
		sparkles.Size = NumberSequence.new(0.2, 0)
		sparkles.Lifetime = NumberRange.new(0.5, 1)
		sparkles.Rate = 10
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 0.8
		sparkles.Parent = biggest
	end
	if withEffects and art and art.Aura then
		addAura(model)
	end
	return model
end

-- options.WithEffects (default true) toggles sparkle emitters (ViewportFrames don't render them).
function PetModelFactory.Create(petData, options)
	options = options or {}
	local withEffects = if options.WithEffects == nil then true else options.WithEffects

	local art = GameConfig.PetArt[petData.Name]
	local artFolder = ReplicatedStorage:FindFirstChild("ArtPets")
	local template = art and artFolder and artFolder:FindFirstChild(art.Model)
	-- Some pets have their own Shiny colorway model (<Model>_Shiny).
	local shinyTemplate = template and petData.Shiny and artFolder:FindFirstChild(art.Model .. "_Shiny")
	if shinyTemplate then
		template = shinyTemplate
	end
	if template then
		return buildArtPet(template, petData, withEffects, art)
	end

	local look = LOOKS[petData.Name] or fallbackLook(petData.Name)
	local species = look and look[1] or "dog"
	local main = look and look[2] or (GameConfig.RarityColors[petData.Rarity] or C(200, 200, 210))
	local accent = look and look[3] or WHITE
	local crown = look and look[4]
	if petData.Golden then
		main, accent = GOLD, GOLD_LIGHT
	end
	local glowAccent = petData.Golden or petData.Rarity == "Legendary" or petData.Rarity == "Secret" or SPARKLY[petData.Rarity] == true

	local model = Instance.new("Model")
	model.Name = petData.Name

	-- Every piece is an anchored, non-colliding cube.
	local function cube(name, size, pos, color, rot, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(pos) * (rot or CFrame.identity)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local V = Vector3.new
	local function rz(deg) return CFrame.Angles(0, 0, math.rad(deg)) end
	local function rx(deg) return CFrame.Angles(math.rad(deg), 0, 0) end
	local accentMaterial = if glowAccent then Enum.Material.Neon else nil
	local function accentCube(name, size, pos, rot)
		return cube(name, size, pos, accent, rot, accentMaterial)
	end

	-- Body, belly patch and feet.
	local bodySize = if species == "golem" then V(1.5, 1.15, 1.3) else V(1.2, 1.0, 1.1)
	local body = cube("Body", bodySize, V(0, 0, 0), main)
	cube("Belly", V(0.75, 0.55, 0.06), V(0, -0.05, -bodySize.Z / 2 - 0.02), accent)
	if species ~= "serpent" then
		for _, x in ipairs({ -0.35, 0.35 }) do
			for _, z in ipairs({ -0.3, 0.3 }) do
				cube("Foot", V(0.36, 0.3, 0.36), V(x * bodySize.X / 1.2, -0.58, z), main:Lerp(INK, 0.25))
			end
		end
	end

	-- Head with face on the -Z side.
	local headSize = if species == "golem" then V(1.6, 1.25, 1.3) else V(1.5, 1.3, 1.3)
	local headY = 0.5 + headSize.Y / 2 - 0.05
	local faceZ = -0.1 - headSize.Z / 2
	cube("Head", headSize, V(0, headY, -0.1), main)
	local eyeY = headY + 0.08
	local eyeH = if species == "alien" then 0.46 else 0.32
	for _, side in ipairs({ -1, 1 }) do
		local eyeColor = if species == "golem" then accent else INK
		cube("Eye", V(0.24, eyeH, 0.06), V(side * 0.33, eyeY, faceZ - 0.02), eyeColor,
			nil, if species == "golem" then Enum.Material.Neon else nil)
		if species ~= "golem" then
			cube("EyeShine", V(0.09, 0.09, 0.04), V(side * 0.33 + 0.05, eyeY + eyeH / 2 - 0.08, faceZ - 0.05), WHITE)
		end
		cube("Blush", V(0.24, 0.1, 0.04), V(side * 0.56, eyeY - 0.24, faceZ - 0.02), BLUSH).Transparency = 0.15
	end

	-- Snout / beak and mouth.
	if species == "dog" or species == "fox" or species == "bear" then
		cube("Snout", V(0.56, 0.34, 0.18), V(0, headY - 0.24, faceZ - 0.08), accent)
		cube("Nose", V(0.2, 0.13, 0.06), V(0, headY - 0.14, faceZ - 0.19), INK)
		cube("Mouth", V(0.18, 0.05, 0.04), V(0, headY - 0.3, faceZ - 0.19), INK)
	elseif species == "bird" then
		cube("Beak", V(0.36, 0.24, 0.32), V(0, headY - 0.2, faceZ - 0.15), C(255, 170, 40))
	elseif species == "dragon" or species == "serpent" then
		cube("Snout", V(0.7, 0.36, 0.22), V(0, headY - 0.26, faceZ - 0.09), main:Lerp(WHITE, 0.2))
		for _, side in ipairs({ -1, 1 }) do
			cube("Nostril", V(0.08, 0.08, 0.04), V(side * 0.14, headY - 0.18, faceZ - 0.21), INK)
		end
	else
		if species == "cat" or species == "bunny" then
			cube("Nose", V(0.12, 0.09, 0.04), V(0, headY - 0.12, faceZ - 0.03), BLUSH)
		end
		cube("Mouth", V(0.22, 0.06, 0.04), V(0, headY - 0.24, faceZ - 0.02), INK)
	end

	-- Species parts: ears, horns, wings, tail.
	local top = headY + headSize.Y / 2
	if species == "cat" or species == "fox" then
		for _, side in ipairs({ -1, 1 }) do
			cube("Ear", V(0.42, 0.42, 0.2), V(side * 0.46, top + 0.04, -0.1), main, rz(45))
			cube("InnerEar", V(0.24, 0.24, 0.06), V(side * 0.46, top + 0.04, -0.21), accent, rz(45))
		end
	elseif species == "dog" then
		for _, side in ipairs({ -1, 1 }) do
			cube("Ear", V(0.28, 0.7, 0.5), V(side * 0.86, headY + 0.1, -0.1), main:Lerp(INK, 0.2), rz(side * 12))
		end
	elseif species == "bunny" or species == "unicorn" then
		local earH = if species == "bunny" then 0.9 else 0.4
		for _, side in ipairs({ -1, 1 }) do
			cube("Ear", V(0.28, earH, 0.2), V(side * 0.36, top + earH / 2 - 0.05, 0), main, rz(side * -8))
			cube("InnerEar", V(0.14, earH - 0.2, 0.05), V(side * 0.36, top + earH / 2 - 0.05, -0.11), accent, rz(side * -8))
		end
	elseif species == "bear" then
		for _, side in ipairs({ -1, 1 }) do
			cube("Ear", V(0.42, 0.38, 0.26), V(side * 0.56, top + 0.1, -0.05), main)
			cube("InnerEar", V(0.22, 0.2, 0.05), V(side * 0.56, top + 0.1, -0.2), accent)
		end
	elseif species == "dragon" or species == "serpent" then
		for _, side in ipairs({ -1, 1 }) do
			accentCube("Horn", V(0.2, 0.5, 0.2), V(side * 0.46, top + 0.18, 0.05), rz(side * -20))
		end
	elseif species == "bird" then
		for i = -1, 1 do
			accentCube("Crest", V(0.18, 0.42 - math.abs(i) * 0.12, 0.18), V(0, top + 0.16, 0.05 + i * 0.22), rx(i * 25))
		end
	elseif species == "alien" then
		cube("Antenna", V(0.08, 0.5, 0.08), V(0, top + 0.25, -0.1), main:Lerp(INK, 0.3))
		cube("AntennaTip", V(0.24, 0.24, 0.24), V(0, top + 0.56, -0.1), accent, nil, Enum.Material.Neon)
	elseif species == "golem" then
		for i = -1, 1 do -- glowing cracks
			cube("Crack", V(0.08, 0.5, 0.04), V(i * 0.4, 0.05, -bodySize.Z / 2 - 0.03), accent, rz(i * 25), Enum.Material.Neon)
		end
		for _, side in ipairs({ -1, 1 }) do
			cube("Shoulder", V(0.45, 0.45, 0.6), V(side * 0.85, 0.3, 0), main:Lerp(INK, 0.15))
		end
	end

	if species == "unicorn" then
		for i = 0, 2 do -- stacked horn, getting thinner
			local s = 0.26 - i * 0.07
			cube("Horn", V(s, 0.24, s), V(0, top + 0.1 + i * 0.2, -0.45 - i * 0.05), GOLD, nil, Enum.Material.Neon)
		end
		for i = 0, 2 do
			accentCube("Mane", V(0.24, 0.3, 0.3), V(0, top - 0.15 - i * 0.28, 0.6))
		end
	end

	if species == "dragon" or species == "bird" then
		for _, side in ipairs({ -1, 1 }) do
			local wingColor = if species == "bird" then accent else main:Lerp(accent, 0.35)
			cube("Wing", V(0.8, 0.55, 0.1), V(side * 0.95, 0.35, 0.25), wingColor,
				CFrame.Angles(0, math.rad(side * 25), math.rad(side * 20)), accentMaterial)
		end
	end

	-- Tails.
	if species == "cat" then
		cube("Tail", V(0.16, 0.16, 0.7), V(0, 0.25, 0.8), main, rx(-35))
	elseif species == "dog" then
		cube("Tail", V(0.2, 0.2, 0.5), V(0, 0.25, 0.7), main, rx(-45))
	elseif species == "fox" then
		cube("Tail", V(0.46, 0.46, 0.8), V(0, 0.15, 0.85), main, rx(-25))
		cube("TailTip", V(0.48, 0.48, 0.28), V(0, 0.36, 1.2), accent, rx(-25))
	elseif species == "bunny" or species == "bear" then
		cube("Tail", V(0.34, 0.34, 0.2), V(0, -0.05, 0.62), accent)
	elseif species == "dragon" or species == "serpent" then
		local len = if species == "serpent" then 3 else 2
		for i = 1, len do
			local s = 0.4 - i * 0.07
			cube("Tail", V(s, s, 0.45), V(0, -0.1 + i * 0.05, 0.4 + i * 0.4), main)
		end
		accentCube("TailSpike", V(0.18, 0.3, 0.18), V(0, 0.15 + len * 0.05, 0.45 + len * 0.4), rx(-20))
	elseif species == "bird" then
		accentCube("TailFeathers", V(0.55, 0.12, 0.5), V(0, 0.2, 0.75), rx(-30))
	end

	if crown then
		for i = 0, 3 do -- ring of four gold points
			local a = math.rad(i * 90 + 45)
			cube("Crown", V(0.22, 0.34, 0.22), V(math.cos(a) * 0.32, top + 0.12, -0.1 + math.sin(a) * 0.32), GOLD, nil, Enum.Material.Neon)
		end
		cube("CrownBand", V(0.8, 0.12, 0.8), V(0, top + 0.02, -0.1), GOLD)
	end

	model.PrimaryPart = body
	model:ScaleTo(0.8 * (if petData.Rarity == "Secret" then SECRET_SCALE else 1)) -- about as tall as the old critters (Secrets bigger)

	-- Golden, Shiny and Mythic pets sparkle (in the world; icons skip effects).
	if withEffects and (petData.Golden or petData.Shiny or SPARKLY[petData.Rarity]) then
		local attachment = Instance.new("Attachment")
		attachment.Position = V(0, 0.8, 0)
		attachment.Parent = body
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(if petData.Golden then GOLD else accent)
		sparkles.Size = NumberSequence.new(0.2, 0)
		sparkles.Lifetime = NumberRange.new(0.5, 1)
		sparkles.Rate = 10
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 0.8
		sparkles.Parent = attachment
	end

	return model
end

return PetModelFactory
