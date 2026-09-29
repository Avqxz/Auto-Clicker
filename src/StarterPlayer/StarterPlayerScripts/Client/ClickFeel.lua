-- Click feedback driven by the server's ClickResult: floating "+N ⚡" numbers above the character
-- (bigger and orange on crits), a combo counter with a draining window bar, and OVERDRIVE
-- effects (glowing screen edge + sparks on the character) while the top combo tier is active.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local ClickFeel = {}

local OVERDRIVE = GameConfig.Combo.Tiers[1]

-- deps: { screenGui, resultRemote, formatNumber, getComboWindow(), isReducedMotion() }
function ClickFeel.Start(deps)
	local player = Players.LocalPlayer
	local screenGui = deps.screenGui

	-- Combo HUD, just above the CLICK button.
	local comboFrame = Instance.new("Frame")
	comboFrame.Name = "ComboMeter"
	comboFrame.AnchorPoint = Vector2.new(0.5, 1)
	comboFrame.Position = UDim2.new(0.5, 0, 1, -118)
	comboFrame.Size = UDim2.fromOffset(220, 58)
	comboFrame.BackgroundTransparency = 1
	comboFrame.Visible = false
	comboFrame.Parent = screenGui

	local comboLabel = Instance.new("TextLabel")
	comboLabel.BackgroundTransparency = 1
	comboLabel.Size = UDim2.new(1, 0, 0, 36)
	comboLabel.Font = Enum.Font.FredokaOne
	comboLabel.TextScaled = true
	comboLabel.TextColor3 = Color3.new(1, 1, 1)
	comboLabel.TextStrokeTransparency = 0.2
	comboLabel.Parent = comboFrame
	local comboScale = Instance.new("UIScale", comboLabel)

	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.new(0.1, 0, 0, 42)
	barBack.Size = UDim2.new(0.8, 0, 0, 8)
	barBack.BackgroundColor3 = Color3.fromRGB(25, 40, 55)
	barBack.BackgroundTransparency = 0.3
	barBack.Parent = comboFrame
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

	-- OVERDRIVE screen edge glow.
	local edge = Instance.new("Frame")
	edge.Name = "OverdriveEdge"
	edge.Position = UDim2.fromOffset(10, 10) -- inset so the whole outline stays on screen
	edge.Size = UDim2.new(1, -20, 1, -20)
	edge.BackgroundTransparency = 1
	edge.Visible = false
	edge.ZIndex = 0
	edge.Parent = screenGui
	Instance.new("UICorner", edge).CornerRadius = UDim.new(0, 24)
	local edgeStroke = Instance.new("UIStroke", edge)
	edgeStroke.Thickness = 14
	edgeStroke.Color = OVERDRIVE.Color

	local sparks -- ParticleEmitter on the character while in OVERDRIVE

	local comboCount, lastHit, currentTier = 0, 0, GameConfig.Combo.Tiers[#GameConfig.Combo.Tiers]

	local function setOverdrive(on)
		local fx = on and not deps.isReducedMotion()
		edge.Visible = fx
		if fx and not sparks then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				sparks = Instance.new("ParticleEmitter")
				sparks.Name = "OverdriveSparks"
				sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), OVERDRIVE.Color)
				sparks.Size = NumberSequence.new(0.6, 0)
				sparks.Lifetime = NumberRange.new(0.4, 0.8)
				sparks.Speed = NumberRange.new(6, 12)
				sparks.SpreadAngle = Vector2.new(180, 180)
				sparks.Rate = 45
				sparks.LightEmission = 1
				sparks.Parent = root
			end
		elseif not fx and sparks then
			sparks:Destroy()
			sparks = nil
		end
	end

	-- Click popups: a cursor icon and "+N" that pop in beside the character, arc outward to one side
	-- and fade (screen-space labels that track the character each frame; client-created
	-- BillboardGuis didn't render reliably). Crits and bursts are bigger and colored.
	local popups = {} -- { frame, scale, side, born, big }
	local POP_LIFE = 0.9
	local INK = Color3.fromRGB(22, 32, 58)
	-- mode "boss" = the click hit a boss; burstName = a gear/pet effect that fired on this click.
	local function popAbove(amount, crit, mode, burstName)
		local big = crit or burstName ~= nil
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = UDim2.fromOffset(big and 280 or 190, big and 50 or 38)
		frame.BackgroundTransparency = 1
		frame.ZIndex = 2 -- above the HUD (1), below open panels (3)
		frame.Position = UDim2.fromOffset(-500, -500) -- off-screen until the first frame positions it
		frame.Visible = false
		frame.Parent = screenGui
		local scale = Instance.new("UIScale", frame)
		scale.Scale = 0.3
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = "rbxassetid://79231008605619" -- cartoon cursor (tools/art/make_cursor_icon.py)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.fromScale(0, 0.5)
		icon.Size = UDim2.new(0, big and 50 or 38, 0, big and 50 or 38)
		icon.Rotation = math.random(-15, 5)
		icon.ZIndex = 2
		icon.Visible = mode ~= "boss"
		icon.Parent = frame
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.new(0, big and 46 or 34, 0.5, 0)
		label.Size = UDim2.new(1, big and -46 or -34, 1, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if burstName then Color3.fromRGB(205, 130, 255)
			elseif crit then Color3.fromRGB(255, 150, 60)
			elseif mode == "boss" then Color3.fromRGB(255, 100, 100)
			else Color3.new(1, 1, 1)
		local prefix = if burstName then burstName .. " " elseif crit then "CRIT " else ""
		label.Text = if mode == "boss"
			then prefix .. "-" .. deps.formatNumber(amount) .. " 💥"
			else prefix .. "+" .. deps.formatNumber(amount)
		label.ZIndex = 2
		label.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = big and 3 or 2.5
		stroke.Parent = label
		table.insert(popups, { frame = frame, scale = scale, icon = icon, label = label, stroke = stroke, big = big,
			side = (math.random() * 2 - 1), lift = 0.6 + math.random() * 0.8, born = os.clock() })
	end
	RunService.RenderStepped:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		for i = #popups, 1, -1 do
			local pop = popups[i]
			local t = (os.clock() - pop.born) / POP_LIFE
			if t >= 1 or not root then
				pop.frame:Destroy()
				table.remove(popups, i)
			else
				-- Arc: out to one side while rising, then easing down a little.
				local out = pop.side * 3.2 * (1 - (1 - t) ^ 2)
				local up = pop.lift + 3.4 * t - 1.4 * t * t
				local world = root.Position + camera.CFrame.RightVector * out + Vector3.new(0, up, 0)
				local screen, onScreen = camera:WorldToViewportPoint(world)
				pop.frame.Visible = onScreen
				local inset = if screenGui.IgnoreGuiInset then 0 else GuiService:GetGuiInset().Y
				pop.frame.Position = UDim2.fromOffset(screen.X, screen.Y - inset)
				-- Pop in (overshoot), then settle; fade over the last 40%.
				pop.scale.Scale = if t < 0.15 then 0.3 + (t / 0.15) * 0.95 elseif t < 0.25 then 1.25 - (t - 0.15) * 2.5 else 1
				local fade = math.clamp((t - 0.6) / 0.4, 0, 1)
				pop.label.TextTransparency = fade
				pop.stroke.Transparency = fade
				pop.icon.ImageTransparency = fade
			end
		end
	end)

	deps.resultRemote.OnClientEvent:Connect(function(amount, crit, count, mode, burstName)
		popAbove(amount, crit, mode, burstName)
		comboCount, lastHit = count, os.clock()
		local tier = GameConfig.GetComboTier(count)
		comboFrame.Visible = count >= 2
		comboLabel.Text = if tier == OVERDRIVE then count .. "x  OVERDRIVE!" else count .. "x COMBO  " .. tier.Name
		comboLabel.TextColor3 = tier.Color
		barFill.BackgroundColor3 = tier.Color
		if tier ~= currentTier and tier.MinCombo > currentTier.MinCombo and not deps.isReducedMotion() then
			comboScale.Scale = 1.35 -- punch when reaching a new tier
			TweenService:Create(comboScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		currentTier = tier
		setOverdrive(tier == OVERDRIVE)
	end)

	-- Drain the combo window locally; the server resets the combo on its own after the window.
	RunService.RenderStepped:Connect(function()
		if comboCount == 0 then
			return
		end
		local window = deps.getComboWindow()
		local left = 1 - (os.clock() - lastHit) / window
		if left <= 0 then
			comboCount = 0
			currentTier = GameConfig.Combo.Tiers[#GameConfig.Combo.Tiers]
			comboFrame.Visible = false
			setOverdrive(false)
			return
		end
		barFill.Size = UDim2.fromScale(left, 1)
		if edge.Visible then
			edgeStroke.Transparency = 0.35 + 0.3 * math.sin(os.clock() * 8)
		end
	end)

	player.CharacterAdded:Connect(function()
		sparks = nil -- the old emitter went away with the old character
	end)
end

return ClickFeel
