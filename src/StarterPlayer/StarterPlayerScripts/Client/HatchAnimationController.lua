-- The hatch reveal (HatchResultsUI). Plays what the server already decided: eggs fly to the middle of the
-- screen, grow, shake harder and harder with sparkles and a glow, crack in a flash, and the pets pop
-- out with their name and rarity. Rarer pets get light rays, a colored flash, more sparkles, and for
-- Mythic/Secret a big flash, camera shake and their own sound. One or three eggs side by side.
-- A click, tap or Space after EggConfig.SkipMinDelay speeds the rest up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EggConfig = require(Modules.EggConfig)
local PetConfig = require(Modules.PetConfig)
local PetModelFactory = require(Modules.PetModelFactory)

local HatchAnimationController = {}

local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.FredokaOne
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GLOW = "rbxasset://textures/glow.png"
local SKIP_SPEED = 4

-- A ViewportFrame showing an egg: a copy of its pedestal egg from the map, or a plain colored egg.
function HatchAnimationController.MakeEggViewport(egg, fallbackColor)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(190, 190, 200)
	viewport.LightColor = WHITE
	viewport.LightDirection = Vector3.new(-0.35, -0.6, 1) -- from behind the camera
	local map = workspace:FindFirstChild("Map")
	local source = map and map:FindFirstChild(egg.Model or "", true)
	local model
	if source and source:IsA("BasePart") then
		model = source:Clone()
		for _, child in ipairs(model:GetChildren()) do
			if not child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
	else
		model = Instance.new("Part")
		model.Shape = Enum.PartType.Ball
		model.Size = Vector3.new(4, 4, 4)
		model.Color = fallbackColor or Color3.fromRGB(240, 240, 250)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.3, 1)
		mesh.Parent = model
	end
	model.Anchored = true
	model.CFrame = CFrame.new()
	model.Parent = viewport
	local size = if model:FindFirstChildOfClass("SpecialMesh") then Vector3.new(4, 5.2, 4) else model.Size
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = math.max(size.X, size.Y) * 1.75
	camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.08, -distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport, model
end

-- A ViewportFrame with the pet's model, turning slowly while `spin` is true.
local function makePetViewport(pet)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.LightColor = WHITE
	viewport.LightDirection = Vector3.new(-0.35, -0.6, 1) -- from behind the camera
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local model = PetModelFactory.Create({ Name = pet.Name, Rarity = pet.Rarity, Golden = false }, { WithEffects = false })
	if pet.Shiny then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Material ~= Enum.Material.Neon then
				part.Reflectance = 0.25
			end
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = world
	local _, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = math.max(size.X, size.Y, size.Z) * 2 + 0.5
	camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.15, -distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport, model
end

-- deps: { playSound(kind), shake(strength, seconds), isReducedMotion() }
function HatchAnimationController.new(deps)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HatchResultsUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(12, 14, 30)
	backdrop.BackgroundTransparency = 1
	backdrop.Parent = gui

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.47)
	stage.BackgroundTransparency = 1
	stage.Parent = gui

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.ZIndex = 20
	flash.Parent = gui

	local skipHint = Instance.new("TextLabel")
	skipHint.AnchorPoint = Vector2.new(0.5, 1)
	skipHint.Position = UDim2.new(0.5, 0, 1, -24)
	skipHint.Size = UDim2.fromOffset(320, 26)
	skipHint.BackgroundTransparency = 1
	skipHint.Font = FONT
	skipHint.TextSize = 18
	skipHint.TextColor3 = Color3.fromRGB(210, 220, 240)
	skipHint.TextTransparency = 1
	skipHint.ZIndex = 21
	skipHint.Parent = gui

	local playing = false
	local speed = 1
	local canSkip = false

	UserInputService.InputBegan:Connect(function(input)
		if not playing or not canSkip then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode[EggConfig.Keys.Skip] then
			speed = SKIP_SPEED
		end
	end)

	-- Time helpers that respect skipping.
	local function wait(seconds)
		local elapsed = 0
		while elapsed < seconds do
			elapsed += RunService.RenderStepped:Wait() * speed
		end
	end
	local function tween(object, seconds, props, style, direction)
		local t = TweenService:Create(object, TweenInfo.new(seconds / speed, style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out), props)
		t:Play()
		return t
	end

	local function hideOtherGuis()
		local hidden = {}
		for _, other in ipairs(playerGui:GetChildren()) do
			if other:IsA("ScreenGui") and other ~= gui and other.Enabled and not other:GetAttribute("KeepDuringHatch") then
				other.Enabled = false
				table.insert(hidden, other)
			end
		end
		return hidden
	end

	-- A burst of sparkle images flying out from the middle of `parent`.
	local function sparkleBurst(parent, color, count, reach)
		if deps.isReducedMotion() then count = math.ceil(count / 3) end
		for _ = 1, count do
			local s = Instance.new("ImageLabel")
			s.BackgroundTransparency = 1
			s.Image = SPARKLE
			s.ImageColor3 = if math.random() < 0.5 then color else WHITE
			local px = math.random(10, 24)
			s.Size = UDim2.fromOffset(px, px)
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.Position = UDim2.fromScale(0.5, 0.45)
			s.ZIndex = 6
			s.Parent = parent
			local angle = math.random() * math.pi * 2
			local distance = reach * (0.5 + math.random() * 0.6)
			tween(s, 0.6 + math.random() * 0.5, {
				Position = UDim2.new(0.5, math.cos(angle) * distance, 0.45, math.sin(angle) * distance),
				ImageTransparency = 1, Rotation = math.random(-180, 180),
			})
			task.delay(1.4, function() s:Destroy() end)
		end
	end

	-- Light rays spinning behind a revealed pet.
	local function makeRays(parent, color, size)
		local rays = Instance.new("Frame")
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = UDim2.fromScale(0.5, 0.42)
		rays.Size = UDim2.fromOffset(size, size)
		rays.BackgroundTransparency = 1
		rays.ZIndex = 1
		rays.Parent = parent
		for i = 0, 5 do
			local ray = Instance.new("Frame")
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.new(0, math.max(14, size * 0.09), 1, 0)
			ray.Rotation = i * 30
			ray.BackgroundColor3 = color
			ray.BorderSizePixel = 0
			ray.BackgroundTransparency = 1
			ray.ZIndex = 1
			ray.Parent = rays
			local fade = Instance.new("UIGradient")
			fade.Rotation = 90
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = ray
			tween(ray, 0.35, { BackgroundTransparency = 0 })
		end
		return rays
	end

	-- One egg slot: runs its whole egg -> pet sequence. `order` staggers the shakes a little.
	local function playSlot(slot, pet, egg, slotSize, order, fast, done)
		local tier = PetConfig.Get(pet.Rarity)
		local rank = tier.Rank
		local isRare = rank >= PetConfig.Rank("Rare")
		local isLegendary = rank >= PetConfig.Rank("Legendary")
		local isSecret = tier.Reveal == "Secret"
		local color = if tier.Rainbow then Color3.fromRGB(255, 120, 230) else tier.Color

		local glow = Instance.new("ImageLabel")
		glow.BackgroundTransparency = 1
		glow.Image = GLOW
		glow.ImageColor3 = color
		glow.ImageTransparency = 1
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.42)
		glow.Size = UDim2.fromOffset(slotSize * 1.3, slotSize * 1.3)
		glow.ZIndex = 2
		glow.Parent = slot

		-- The egg flies up from the bottom and grows.
		local eggView = HatchAnimationController.MakeEggViewport(egg)
		eggView.AnchorPoint = Vector2.new(0.5, 0.5)
		eggView.Size = UDim2.fromOffset(slotSize, slotSize)
		eggView.Position = UDim2.new(0.5, 0, 1.6, 0)
		eggView.ZIndex = 4
		eggView.Parent = slot
		local eggScale = Instance.new("UIScale")
		eggScale.Scale = 0.45
		eggScale.Parent = eggView

		local step = if fast then 0.7 else 1
		tween(eggView, 0.45 * step, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
		tween(eggScale, 0.55 * step, { Scale = 1 }, Enum.EasingStyle.Back)
		wait(0.5 * step + order * 0.06)

		-- Shakes, harder each time, with a building glow and sparkles.
		local shakes = if fast then 3 else (if isLegendary then 6 else 5)
		for i = 1, shakes do
			local strength = 7 + i * (if isLegendary then 3.2 else 2.2)
			deps.playSound("Shake")
			tween(glow, 0.12, { ImageTransparency = math.max(0.15, 0.9 - i * 0.14) })
			tween(eggView, 0.07, { Rotation = strength }, Enum.EasingStyle.Sine)
			wait(0.07)
			tween(eggView, 0.1, { Rotation = -strength }, Enum.EasingStyle.Sine)
			wait(0.1)
			tween(eggView, 0.07, { Rotation = 0 }, Enum.EasingStyle.Sine)
			wait(0.07)
			if i >= shakes - 1 then
				sparkleBurst(slot, color, if isRare then 6 else 3, slotSize * 0.45)
			end
			wait(math.max(0.05, 0.2 - i * 0.03) * step)
		end

		-- Crack: the egg swells and bursts in a flash.
		deps.playSound("Crack")
		tween(eggScale, 0.12, { Scale = 1.22 }, Enum.EasingStyle.Quad)
		wait(0.1)
		if order == 0 then
			flash.BackgroundColor3 = if isSecret then color else WHITE
			flash.BackgroundTransparency = if isSecret then 0.05 else 0.35
			tween(flash, if isSecret then 0.9 else 0.4, { BackgroundTransparency = 1 })
		end
		tween(eggView, 0.12, { ImageTransparency = 1 })
		tween(eggScale, 0.12, { Scale = 1.5 })
		sparkleBurst(slot, color, if isLegendary then 26 else (if isRare then 16 else 10), slotSize * 0.8)

		-- The pet pops out.
		if isRare then
			local rays = makeRays(slot, color, slotSize * 1.6)
			task.spawn(function()
				while rays.Parent do
					rays.Rotation += RunService.RenderStepped:Wait() * (if isLegendary then 45 else 25)
				end
			end)
		end
		local petView, petModel = makePetViewport(pet)
		petView.AnchorPoint = Vector2.new(0.5, 0.5)
		petView.Position = UDim2.fromScale(0.5, 0.42)
		petView.Size = UDim2.fromOffset(slotSize, slotSize)
		petView.ZIndex = 5
		if pet.Deleted then
			petView.ImageTransparency = 0.45
		end
		petView.Parent = slot
		local petScale = Instance.new("UIScale")
		petScale.Scale = 0
		petScale.Parent = petView
		tween(petScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		local pivot = petModel:GetPivot()
		local spinStart = os.clock()
		task.spawn(function()
			while petView.Parent do
				RunService.RenderStepped:Wait()
				petModel:PivotTo(pivot * CFrame.Angles(0, math.sin((os.clock() - spinStart) * 1.4) * 0.6, 0))
			end
		end)
		wait(0.12)
		eggView:Destroy()

		-- Name, rarity and tags.
		local nameLabel = Instance.new("TextLabel")
		nameLabel.AnchorPoint = Vector2.new(0.5, 0)
		nameLabel.Position = UDim2.new(0.5, 0, 0.42, slotSize * 0.46)
		nameLabel.Size = UDim2.new(1.2, 0, 0, math.clamp(slotSize * 0.17, 18, 34))
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = FONT
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = WHITE
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.Text = (if pet.Shiny then "★ Shiny " else "") .. pet.Name
		nameLabel.TextTransparency = 1
		nameLabel.ZIndex = 7
		nameLabel.Parent = slot

		local rarityLabel = nameLabel:Clone()
		rarityLabel.Position = UDim2.new(0.5, 0, 0.42, slotSize * 0.46 + nameLabel.Size.Y.Offset + 2)
		rarityLabel.Size = UDim2.new(1, 0, 0, math.clamp(slotSize * 0.13, 15, 26))
		rarityLabel.Text = string.upper(pet.Rarity)
		rarityLabel.TextColor3 = if tier.Rainbow then WHITE else color
		rarityLabel.Parent = slot
		if tier.Rainbow then
			local rainbow = Instance.new("UIGradient")
			rainbow.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 140)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255)),
			})
			rainbow.Parent = rarityLabel
			task.spawn(function()
				while rarityLabel.Parent do
					rainbow.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.4, 0)
					RunService.RenderStepped:Wait()
				end
			end)
		end
		tween(nameLabel, 0.25, { TextTransparency = 0 })
		tween(rarityLabel, 0.25, { TextTransparency = 0 })

		local tagText = if pet.Deleted then "AUTO-DELETED" elseif pet.New then "NEW!" else nil
		if tagText then
			local tag = Instance.new("TextLabel")
			tag.AnchorPoint = Vector2.new(0.5, 0.5)
			tag.Position = UDim2.new(0.5, slotSize * 0.32, 0.42, -slotSize * 0.38)
			tag.Size = UDim2.fromOffset(math.max(70, slotSize * 0.42), math.max(22, slotSize * 0.13))
			tag.BackgroundColor3 = if pet.Deleted then Color3.fromRGB(120, 125, 140) else Color3.fromRGB(255, 70, 110)
			tag.Font = FONT
			tag.TextScaled = true
			tag.TextColor3 = WHITE
			tag.Text = tagText
			tag.Rotation = 10
			tag.ZIndex = 8
			tag.Parent = slot
			Instance.new("UICorner", tag).CornerRadius = UDim.new(0, 8)
			local tagScale = Instance.new("UIScale")
			tagScale.Scale = 0
			tagScale.Parent = tag
			tween(tagScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		done(pet)
	end

	local api = {}

	function api.IsPlaying()
		return playing
	end

	-- result: the server's hatch result ({ Pets = { { Name, Rarity, Shiny, New, Deleted } } }).
	-- options.Fast: shorter version for Auto Hatch. Yields until the reveal has finished.
	function api.Play(result, egg, options)
		options = options or {}
		if playing then return end
		playing = true
		speed = 1
		canSkip = false
		local fast = options.Fast == true
		local hidden = hideOtherGuis()
		gui.Enabled = true
		for _, child in ipairs(stage:GetChildren()) do child:Destroy() end

		-- Lay out 1-3 slots, sized to fit the screen.
		local viewport = workspace.CurrentCamera.ViewportSize
		local count = #result.Pets
		local gap = 16
		local slotSize = math.floor(math.clamp((viewport.X - 40 - gap * (count - 1)) / count, 90,
			if count == 1 then math.min(300, viewport.Y * 0.45) else math.min(220, viewport.Y * 0.36)))
		stage.Size = UDim2.fromOffset(slotSize * count + gap * (count - 1), slotSize * 1.5)
		local slots = {}
		for i = 1, count do
			local slot = Instance.new("Frame")
			slot.BackgroundTransparency = 1
			slot.Size = UDim2.fromOffset(slotSize, slotSize * 1.5)
			slot.Position = UDim2.fromOffset((i - 1) * (slotSize + gap), 0)
			slot.Parent = stage
			slots[i] = slot
		end

		tween(backdrop, 0.3, { BackgroundTransparency = if fast then 0.6 else 0.35 })
		skipHint.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
			then "Tap to skip" else "Click or press Space to skip"
		task.delay(EggConfig.SkipMinDelay, function()
			if playing then
				canSkip = true
				tween(skipHint, 0.3, { TextTransparency = 0.2 })
			end
		end)

		-- All slots run together; wait for every one to reveal.
		local revealed = 0
		local rarest
		for i, pet in ipairs(result.Pets) do
			if not rarest or PetConfig.Rank(pet.Rarity) > PetConfig.Rank(rarest.Rarity) then
				rarest = pet
			end
			task.spawn(playSlot, slots[i], pet, egg, slotSize, i - 1, fast, function()
				revealed += 1
			end)
		end
		while revealed < count do
			RunService.RenderStepped:Wait()
		end

		-- One reveal sound and screen effect for the rarest pet.
		local tier = PetConfig.Get(rarest.Rarity)
		if tier.Reveal == "Secret" then
			deps.playSound("RevealSecret")
			deps.shake(1.1, 0.6)
		elseif tier.Reveal == "Legendary" then
			deps.playSound("RevealLegendary")
			deps.shake(0.6, 0.4)
		else
			deps.playSound("Reveal")
		end

		wait(if fast then 0.9 else (if tier.Reveal == "Secret" then 2.6 else 1.7))
		canSkip = false
		tween(skipHint, 0.2, { TextTransparency = 1 })
		tween(backdrop, 0.3, { BackgroundTransparency = 1 })
		for _, slot in ipairs(slots) do
			for _, d in ipairs(slot:GetDescendants()) do
				if d:IsA("TextLabel") then
					tween(d, 0.25, { TextTransparency = 1, BackgroundTransparency = 1 })
				elseif d:IsA("ImageLabel") or d:IsA("ViewportFrame") then
					tween(d, 0.25, { ImageTransparency = 1 })
				elseif d:IsA("Frame") then
					tween(d, 0.25, { BackgroundTransparency = 1 })
				end
			end
		end
		wait(0.3)
		for _, child in ipairs(stage:GetChildren()) do child:Destroy() end
		gui.Enabled = false
		for _, other in ipairs(hidden) do
			if other.Parent then other.Enabled = true end
		end
		playing = false
	end

	return api
end

return HatchAnimationController
