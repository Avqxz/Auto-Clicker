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

	-- Floating numbers are screen-space labels that track the character's position each frame
	-- (client-created BillboardGuis didn't render reliably), rising and fading over 0.8s.
	local popups = {} -- { label, offset (studs), born }
	local POP_LIFE = 0.8
	-- mode "boss" = the click hit a boss; burstName = a gear/pet effect that fired on this click.
	local function popAbove(amount, crit, mode, burstName)
		local big = crit or burstName ~= nil
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromOffset(big and 300 or 170, big and 52 or 36)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeTransparency = 0.2
		label.TextColor3 = if burstName then Color3.fromRGB(190, 110, 255)
			elseif crit then Color3.fromRGB(255, 120, 50)
			elseif mode == "boss" then Color3.fromRGB(255, 90, 90)
			else Color3.fromRGB(255, 225, 90)
		local prefix = if burstName then burstName .. " " elseif crit then "CRITICAL " else ""
		label.Text = if mode == "boss"
			then prefix .. "-" .. deps.formatNumber(amount) .. " 💥"
			else prefix .. "+" .. deps.formatNumber(amount) .. " ⚡"
		label.ZIndex = 2 -- above the HUD (1), below open panels (3)
		label.Position = UDim2.fromOffset(-500, -500) -- off-screen until the first frame positions it
		label.Visible = false
		label.Parent = screenGui
		-- Start at chest height, spread sideways, so numbers rise beside the character rather than
		-- behind the HUD banners at the top of the screen.
		table.insert(popups, { label = label, offset = Vector3.new(math.random(-25, 25) / 10, 1, 0), born = os.clock() })
	end
	RunService.RenderStepped:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		for i = #popups, 1, -1 do
			local pop = popups[i]
			local t = (os.clock() - pop.born) / POP_LIFE
			if t >= 1 or not root then
				pop.label:Destroy()
				table.remove(popups, i)
			else
				local rise = 2 * (1 - (1 - t) ^ 2) -- ease-out
				local world = root.Position + camera.CFrame.RightVector * pop.offset.X + Vector3.new(0, pop.offset.Y + rise, 0)
				local screen, onScreen = camera:WorldToViewportPoint(world)
				pop.label.Visible = onScreen
				local inset = if screenGui.IgnoreGuiInset then 0 else GuiService:GetGuiInset().Y
				pop.label.Position = UDim2.fromOffset(screen.X, screen.Y - inset)
				pop.label.TextTransparency = t ^ 2
				pop.label.TextStrokeTransparency = 0.2 + 0.8 * t ^ 2
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
