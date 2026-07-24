-- Builds a simple procedural "critter" model for a pet.
-- Used both for in-world pet followers (server) and 3D UI icons (client),
-- since the project has no hand-authored mesh assets to import.

local GameConfig = require(script.Parent.GameConfig)

local PetModelFactory = {}

local GOLDEN_COLOR = Color3.fromRGB(255, 215, 60)

-- options.WithEffects (default true) toggles the golden sparkle emitter.
-- ViewportFrames don't reliably render ParticleEmitters, so UI icons pass WithEffects = false.
function PetModelFactory.Create(petData, options)
	options = options or {}
	local withEffects = if options.WithEffects == nil then true else options.WithEffects

	local color = if petData.Golden then GOLDEN_COLOR else (GameConfig.RarityColors[petData.Rarity] or Color3.fromRGB(255, 255, 255))
	local material = if petData.Golden then Enum.Material.Neon else Enum.Material.SmoothPlastic

	local model = Instance.new("Model")
	model.Name = petData.Name

	local function newPart(name, size, cframe, overrideColor)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Ball
		p.Size = size
		p.CFrame = cframe
		p.Color = overrideColor or color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local body = newPart("Body", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 0, 0))
	local head = newPart("Head", Vector3.new(0.95, 0.95, 0.95), CFrame.new(0, 0.85, -0.55))

	newPart("LeftEar", Vector3.new(0.35, 0.55, 0.2), CFrame.new(-0.35, 1.35, -0.55))
	newPart("RightEar", Vector3.new(0.35, 0.55, 0.2), CFrame.new(0.35, 1.35, -0.55))

	newPart("LeftEye", Vector3.new(0.16, 0.16, 0.16), CFrame.new(-0.25, 0.9, -0.98), Color3.new(0, 0, 0))
	newPart("RightEye", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0.25, 0.9, -0.98), Color3.new(0, 0, 0))

	model.PrimaryPart = body

	if petData.Golden and withEffects then
		local attachment = Instance.new("Attachment")
		attachment.Parent = body

		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(GOLDEN_COLOR)
		sparkles.Size = NumberSequence.new(0.15)
		sparkles.Lifetime = NumberRange.new(0.5, 1)
		sparkles.Rate = 12
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = attachment
	end

	return model
end

return PetModelFactory
