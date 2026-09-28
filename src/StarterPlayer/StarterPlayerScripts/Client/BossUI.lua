-- Boss fight HUD: boss name, HP bar and countdown while a fight is running, plus the victory /
-- time's-up result. Driven by the server's BossState remote ("start", "hp", "win", "lose").

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local BossUI = {}

-- deps: { screenGui, bossRemote, formatNumber, showToast(text), celebrate(rarity), hideDuringFight = {GuiObject} }
function BossUI.Start(deps)
	local fmt = deps.formatNumber

	local frame = Instance.new("Frame")
	frame.Name = "BossHUD"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 96)
	frame.Size = UDim2.fromOffset(380, 78)
	frame.BackgroundColor3 = Color3.fromRGB(30, 22, 40)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	frame.ZIndex = 8
	frame.Parent = deps.screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 80, 80)

	local function text(props)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.ZIndex = 9
		for k, v in pairs(props) do
			l[k] = v
		end
		l.Parent = frame
		return l
	end
	local nameLabel = text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
	local timerLabel = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(70, 26),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 210, 90) })

	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromOffset(12, 38)
	barBack.Size = UDim2.new(1, -24, 0, 28)
	barBack.BackgroundColor3 = Color3.fromRGB(70, 40, 50)
	barBack.ZIndex = 9
	barBack.Parent = frame
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(0, 8)
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 10
	barFill.Parent = barBack
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 8)
	local hpLabel = Instance.new("TextLabel")
	hpLabel.BackgroundTransparency = 1
	hpLabel.Size = UDim2.fromScale(1, 1)
	hpLabel.Font = Enum.Font.FredokaOne
	hpLabel.TextScaled = true
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextStrokeTransparency = 0.3
	hpLabel.ZIndex = 11
	hpLabel.Parent = barBack

	local fight -- { Name, Health, Max, Ends }

	local function setVisible(on)
		frame.Visible = on
		for _, gui in ipairs(deps.hideDuringFight or {}) do
			gui.Visible = not on
		end
	end

	local function showHealth(health)
		fight.Health = health
		local ratio = math.clamp(health / fight.Max, 0, 1)
		TweenService:Create(barFill, TweenInfo.new(0.12), { Size = UDim2.fromScale(ratio, 1) }):Play()
		hpLabel.Text = "❤ " .. fmt(math.ceil(health)) .. " / " .. fmt(fight.Max)
	end

	deps.bossRemote.OnClientEvent:Connect(function(kind, info)
		if kind == "start" then
			fight = { Name = info.Name, Max = info.Health, Health = info.Health, Ends = os.clock() + info.Seconds }
			nameLabel.Text = "⚔ " .. info.Name
			barFill.Size = UDim2.fromScale(1, 1)
			showHealth(info.Health)
			setVisible(true)
			deps.showToast("FIGHT! Click to hit " .. info.Name .. " before time runs out!")
		elseif kind == "hp" and fight then
			showHealth(info)
		elseif kind == "win" and fight then
			local name = fight.Name
			fight = nil
			setVisible(false)
			local drop = info.Gear and GameConfig.GetGear(info.Gear)
			local rarity = drop and GameConfig.GetGearRarity(drop) or "Epic"
			deps.showToast("DEFEATED " .. name .. "!  +" .. fmt(info.Coins) .. " Coins  +" .. info.Gems .. " 💎"
				.. (if (info.Essence or 0) > 0 then "  +" .. info.Essence .. " Essence" else "")
				.. (if drop then "  •  " .. drop.Name .. " (" .. rarity .. ")" else "  •  gear bag full"))
			deps.celebrate(rarity)
		elseif kind == "lose" and fight then
			local name = fight.Name
			fight = nil
			setVisible(false)
			deps.showToast("Time's up! " .. name .. " survived. Get stronger and try again.")
		end
	end)

	RunService.RenderStepped:Connect(function()
		if fight then
			timerLabel.Text = math.max(0, math.ceil(fight.Ends - os.clock())) .. "s"
		end
	end)
end

return BossUI
