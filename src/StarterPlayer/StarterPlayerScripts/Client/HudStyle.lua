-- The simulator HUD look: chunky counters across the top (big icon breaking out of each, label
-- underneath), a two-column grid of square icon tiles on the left, a big Rewards button with round
-- quick buttons on the right, a large square click button between SELL and AUTO at the bottom, and
-- multiplier chips in the bottom-left corner.
--
-- It restyles and re-lays-out the HUD pieces the other modules build (found by name), so their
-- click handlers, notification dots and text updates keep working: button text is hidden rather than
-- removed, and icons/captions are drawn on top.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local HatchMath = require(Modules.HatchMath)

local HudStyle = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(22, 32, 58)
local CURSOR_ICON = "rbxassetid://79231008605619"

local function corner(parent, radius)
	local c = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)
	c.Parent = parent
end
local function outline(parent, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = INK
	s.Thickness = thickness or 3
	s.Parent = parent
	return s
end
-- White text with a thick dark outline, the reference's caption style.
local function inkText(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = WHITE
	l.TextScaled = true
	for k, v in pairs(props) do
		if k ~= "StrokeThickness" then l[k] = v end
	end
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = props.StrokeThickness or 2.2
	s.Parent = l
	l.Parent = parent
	return l
end
local function glyph(parent, text, props)
	local l = Instance.new("TextLabel")
	l.Name = "Icon"
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.Text = text
	l.ZIndex = (parent.ZIndex or 1) + 1
	for k, v in pairs(props or {}) do l[k] = v end
	l.Parent = parent
	return l
end
local function cursorIcon(parent, props)
	local i = Instance.new("ImageLabel")
	i.Name = "Icon"
	i.BackgroundTransparency = 1
	i.Image = CURSOR_ICON
	i.ScaleType = Enum.ScaleType.Fit
	i.ZIndex = (parent.ZIndex or 1) + 1
	for k, v in pairs(props or {}) do i[k] = v end
	i.Parent = parent
	return i
end
-- Hover grow / press squash on a UIScale.
local function bounce(button)
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", button)
	local function to(s, t) TweenService:Create(scale, TweenInfo.new(t or 0.12, Enum.EasingStyle.Back), { Scale = s }):Play() end
	button.MouseEnter:Connect(function() to(1.07) end)
	button.MouseLeave:Connect(function() to(1) end)
	button.MouseButton1Down:Connect(function() to(0.92, 0.08) end)
	button.MouseButton1Up:Connect(function() to(1.07) end)
	return scale
end

-- Turns an existing text button into a chunky colored tile: its text goes invisible (other code may
-- keep updating it), strokes and padding meant for the text go, and an icon + caption go on top.
local function tile(button, icon, caption, color, size)
	button.TextTransparency = 1
	button.AutoButtonColor = false
	button.BackgroundColor3 = color
	button.Size = size or UDim2.fromOffset(84, 84)
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("UIPadding") or child:IsA("UITextSizeConstraint")
			or (child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual) then
			child:Destroy()
		elseif child:IsA("UIStroke") then
			child.Color = INK
			child.Thickness = 3
			child.Transparency = 0
		elseif child:IsA("UIGradient") then
			child.Color = ColorSequence.new(WHITE, Color3.fromRGB(205, 210, 225))
		end
	end
	if not button:FindFirstChildOfClass("UIStroke") then outline(button) end
	corner(button, 16)
	-- Glossy top highlight.
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = WHITE
	gloss.BackgroundTransparency = 0.72
	gloss.Position = UDim2.new(0, 5, 0, 4)
	gloss.Size = UDim2.new(1, -10, 0.38, 0)
	gloss.BorderSizePixel = 0
	gloss.Parent = button
	corner(gloss, 12)
	if icon == "cursor" then
		cursorIcon(button, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromScale(0.72, 0.72) })
	elseif icon then
		glyph(button, icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.62, 0.62) })
	end
	local cap
	if caption then
		cap = inkText(button, { Name = "Caption", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 6),
			Size = UDim2.new(1.08, 0, 0, 24), Text = caption, ZIndex = (button.ZIndex or 1) + 2 })
	end
	bounce(button)
	return cap
end

-- deps: { screenGui, getData(), dataChanged (RemoteEvent), formatNumber, getEquippedPets(data),
--         controls (utility column), objective, powerLabel }
function HudStyle.Apply(deps)
	local gui = deps.screenGui
	local fmt = deps.formatNumber
	local camera = workspace.CurrentCamera
	local function find(name) return gui:FindFirstChild(name, true) end
	local function utility(text)
		for _, b in ipairs(deps.controls:GetChildren()) do
			if b:IsA("TextButton") and (b.Text == text or b:GetAttribute("HudText") == text) then return b end
		end
	end
	local groups = {} -- containers scaled down on small screens: { frame, scale, compactScale }

	-- ===== Top counters =====
	for _, name in ipairs({ "CoinFrame", "CoinPill", "GemFrame", "BoostTimers", "Tip" }) do
		local old = find(name)
		if old then old.Visible = false end
	end
	local top = Instance.new("Frame")
	top.Name = "TopCounters"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 10, 0, 6)
	top.BackgroundTransparency = 1
	top.Parent = gui
	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.Padding = UDim.new(0, 30)
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.Parent = top
	local topScale = Instance.new("UIScale", top)
	local COUNTER = Vector2.new(170, 50)
	local counters = {}
	local function counter(order, icon, caption, color, key)
		local pill = Instance.new("Frame")
		pill.Name = caption .. "Counter"
		pill.LayoutOrder = order
		pill.Size = UDim2.fromOffset(COUNTER.X, COUNTER.Y)
		pill.BackgroundColor3 = WHITE
		pill.Parent = top
		corner(pill, 16)
		outline(pill, 3)
		local g = Instance.new("UIGradient", pill)
		g.Rotation = 90
		g.Color = ColorSequence.new(WHITE, color:Lerp(WHITE, 0.72))
		local number = inkText(pill, { Name = "Value", Position = UDim2.new(0, 34, 0, 5), Size = UDim2.new(1, -42, 1, -10),
			TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, StrokeThickness = 2.5 })
		local c = require(script.Parent.Counter).new(number, function(v) return fmt(v) end)
		glyph(pill, icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 6, 0.5, -2),
			Size = UDim2.fromOffset(64, 64), Rotation = -10, ZIndex = 3 })
		inkText(pill, { Name = "Caption", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 30, 1, 2),
			Size = UDim2.fromOffset(110, 20), TextXAlignment = Enum.TextXAlignment.Left, Text = caption, ZIndex = 3 })
		counters[key] = c
		return pill
	end
	counter(1, "🔄", "Ascensions", Color3.fromRGB(235, 70, 110), "RebirthCount")
	counter(2, "⚡", "Power", Color3.fromRGB(70, 170, 255), "Power")
	counter(3, "💰", "Coins", Color3.fromRGB(245, 165, 30), "Coins")
	counter(4, "💎", "Gems", Color3.fromRGB(165, 80, 255), "Gems")
	top.Size = UDim2.fromOffset(4 * COUNTER.X + 3 * 30, COUNTER.Y + 14)

	-- "+N per click" and the next-goal banner sit under the counters.
	if deps.powerLabel then
		deps.powerLabel.AnchorPoint = Vector2.new(0.5, 0)
		deps.powerLabel.Position = UDim2.new(0.5, 10, 0, 72)
		deps.powerLabel.Size = UDim2.fromOffset(260, 24)
		deps.powerLabel.TextStrokeTransparency = 1
		local s = Instance.new("UIStroke", deps.powerLabel)
		s.Color = INK
		s.Thickness = 2
	end
	if deps.objective then
		deps.objective.Position = UDim2.new(0.5, 10, 0, 100)
		deps.objective.BackgroundColor3 = INK
		deps.objective.BackgroundTransparency = 0.25
		corner(deps.objective, 14)
	end

	-- ===== Left grid of tiles =====
	local grid = Instance.new("Frame")
	grid.Name = "MenuGrid"
	grid.AnchorPoint = Vector2.new(0, 0.5)
	grid.Position = UDim2.new(0, 12, 0.5, 10)
	grid.Size = UDim2.fromOffset(84 * 2 + 12, 84 * 4 + 12 * 3 + 10)
	grid.BackgroundTransparency = 1
	grid.Parent = gui
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(84, 84)
	gridLayout.CellPadding = UDim2.fromOffset(12, 12)
	gridLayout.FillDirectionMaxCells = 2
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	local gridScale = Instance.new("UIScale", grid)
	table.insert(groups, { grid, gridScale, 0.72 })
	local order = 0
	local function place(button, icon, caption, color)
		if not button then return end
		order += 1
		button.LayoutOrder = order
		button.Visible = true
		button.Parent = grid
		return tile(button, icon, caption, color)
	end
	place(find("ShopToggle"), "⬆️", "Upgrades", Color3.fromRGB(80, 215, 120))
	place(find("EggsToggle"), "🥚", "Eggs", Color3.fromRGB(40, 200, 235))
	place(find("PetsToggle"), "🐶", "Pets", Color3.fromRGB(205, 115, 245))
	place(find("GearToggle"), "⚔️", "Gear", Color3.fromRGB(240, 90, 110))
	place(find("SkillsToggle"), "🌟", "Skills", Color3.fromRGB(255, 170, 60))
	place(find("RebirthButton"), "🔄", "Ascend", Color3.fromRGB(235, 70, 150))
	place(utility("QUESTS"), "📜", "Quests", Color3.fromRGB(245, 150, 45))
	place(utility("BOOSTS"), "🚀", "Boosts", Color3.fromRGB(90, 125, 235))
	local tabBar = find("TabBar")
	if tabBar then tabBar.Visible = false end

	-- ===== Right side: Store, Rewards, round quick buttons =====
	local right = Instance.new("Frame")
	right.Name = "RightHud"
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.new(1, -14, 0.5, 20)
	right.Size = UDim2.fromOffset(250, 250)
	right.BackgroundTransparency = 1
	right.Parent = gui
	local rightScale = Instance.new("UIScale", right)
	table.insert(groups, { right, rightScale, 0.72 })

	local cart = find("CartButton")
	if cart then
		cart.AnchorPoint = Vector2.new(1, 0)
		cart.Position = UDim2.new(1, 0, 0, 0)
		cart.Size = UDim2.fromOffset(78, 78)
		cart.Parent = right
		for _, s in ipairs(cart:GetChildren()) do
			if s:IsA("UIStroke") then s.Color = INK s.Thickness = 3 s.Transparency = 0 end
		end
	end

	local daily = utility("DAILY")
	if daily then
		daily.Parent = right
		daily.AnchorPoint = Vector2.new(1, 0)
		daily.Position = UDim2.new(1, 0, 0, 92)
		tile(daily, nil, nil, Color3.fromRGB(120, 225, 110), UDim2.fromOffset(220, 70))
		corner(daily, 20)
		glyph(daily, "🎁", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 22, 0.5, -4),
			Size = UDim2.fromOffset(82, 82), Rotation = -8, ZIndex = 4 })
		inkText(daily, { Name = "Caption", Position = UDim2.new(0, 64, 0, 10), Size = UDim2.new(1, -74, 1, -20),
			Text = "Rewards", StrokeThickness = 3, ZIndex = 4 })
	end

	local row = Instance.new("Frame")
	row.Name = "QuickButtons"
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.new(1, 0, 0, 178)
	row.Size = UDim2.fromOffset(250, 60)
	row.BackgroundTransparency = 1
	row.Parent = right
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row
	local function round(button, icon, color, n, mirror)
		if not button then return end
		button.LayoutOrder = n
		button.Parent = row
		tile(button, icon, nil, color, UDim2.fromOffset(54, 54))
		corner(button)
		if mirror then -- icon follows the button's (hidden) ON/OFF text
			local label = button:FindFirstChild("Icon")
			local function sync() label.Text = mirror(button.Text) end
			button:GetPropertyChangedSignal("Text"):Connect(sync)
			sync()
		end
	end
	round(utility("CODES"), "🏷️", Color3.fromRGB(45, 190, 210), 1)
	round(utility("SOUND ON") or utility("SOUND OFF"), "🔊", Color3.fromRGB(70, 150, 180), 2,
		function(t) return if t:find("OFF") then "🔇" else "🔊" end)
	round(utility("FX ON") or utility("FX LOW"), "✨", Color3.fromRGB(140, 100, 195), 3,
		function(t) return if t:find("LOW") then "💤" else "✨" end)
	local music = find("MusicToggle")
	if music then
		music.LayoutOrder = 4
		music.AnchorPoint = Vector2.new(0, 0)
		music.Size = UDim2.fromOffset(54, 54)
		music.Parent = row
		for _, s in ipairs(music:GetChildren()) do
			if s:IsA("UIStroke") then s.Color = INK s.Thickness = 3 s.Transparency = 0 end
		end
	end
	deps.controls.Visible = false

	-- ===== Bottom: big click button between SELL and AUTO =====
	local tap = find("TapButton")
	if tap then
		tap.AnchorPoint = Vector2.new(0.5, 1)
		tap.Position = UDim2.new(0.5, 0, 1, -12)
		tile(tap, "cursor", nil, Color3.fromRGB(110, 205, 255), UDim2.fromOffset(112, 112))
		corner(tap, 26)
	end
	local sell = find("SellButton")
	if sell then
		sell.AnchorPoint = Vector2.new(1, 1)
		sell.Position = UDim2.new(0.5, -70, 1, -12)
		tile(sell, "💰", "Sell", Color3.fromRGB(245, 185, 50), UDim2.fromOffset(78, 78))
	end
	local auto = find("AutoClickToggle")
	if auto then
		auto.AnchorPoint = Vector2.new(0, 1)
		auto.Position = UDim2.new(0.5, 70, 1, -12)
		local cap = tile(auto, "cursor", "Auto", Color3.fromRGB(150, 150, 170), UDim2.fromOffset(78, 78))
		local dot = Instance.new("Frame")
		dot.Name = "OnDot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(1, -6, 0, 6)
		dot.Size = UDim2.fromOffset(18, 18)
		dot.BackgroundColor3 = Color3.fromRGB(80, 230, 110)
		dot.ZIndex = 6
		dot.Parent = auto
		corner(dot)
		outline(dot, 2)
		local function sync()
			local on = auto.Text:find("ON") ~= nil
			dot.Visible = on
			auto.BackgroundColor3 = if on then Color3.fromRGB(90, 215, 130) else Color3.fromRGB(150, 150, 170)
			cap.Text = if on then "Auto On" else "Auto"
		end
		auto:GetPropertyChangedSignal("Text"):Connect(sync)
		sync()
	end
	local combo = find("ComboMeter")
	if combo then
		combo.Position = UDim2.new(0.5, 0, 1, -140)
		for _, l in ipairs(combo:GetDescendants()) do
			if l:IsA("TextLabel") then
				l.TextStrokeTransparency = 1
				local s = Instance.new("UIStroke", l)
				s.Color = INK
				s.Thickness = 2.5
			end
		end
	end

	-- ===== Bottom-left multiplier chips =====
	local chips = Instance.new("Frame")
	chips.Name = "BoostChips"
	chips.AnchorPoint = Vector2.new(0, 1)
	chips.Position = UDim2.new(0, 12, 1, -10)
	chips.Size = UDim2.fromOffset(330, 66)
	chips.BackgroundTransparency = 1
	chips.Parent = gui
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	chipLayout.Padding = UDim.new(0, 6)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chips
	local chipScale = Instance.new("UIScale", chips)
	table.insert(groups, { chips, chipScale, 0.8 })
	local function chip(n, icon)
		local f = Instance.new("Frame")
		f.LayoutOrder = n
		f.Size = UDim2.fromOffset(58, 62)
		f.BackgroundTransparency = 1
		f.Parent = chips
		glyph(f, icon, { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(6, 0) })
		local value = inkText(f, { Name = "Value", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(64, 22), Text = "" })
		return f, value
	end
	local _, ascValue = chip(1, "🔄")
	local _, petValue = chip(2, "🐾")
	local _, luckValue = chip(3, "🍀")
	local powerChip, powerValue = chip(4, "⚡")
	local function clock(seconds)
		seconds = math.max(0, math.floor(seconds))
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	local function multiplier(x)
		return "x" .. (string.format("%.2f", x):gsub("%.?0+$", ""))
	end

	local function refresh()
		local data = deps.getData()
		if not data then return end
		counters.RebirthCount:Set(data.RebirthCount or 0)
		counters.Power:Set(data.Power or 0)
		counters.Coins:Set(data.Coins or 0)
		counters.Gems:Set(data.Gems or 0)
		local equipped = deps.getEquippedPets(data)
		ascValue.Text = multiplier(GameConfig.GetRebirthMultiplier(data.RebirthCount or 0))
		petValue.Text = multiplier(GameConfig.GetPetMultiplierTotal(equipped))
		local luck = HatchMath.GetLuck(data, GameConfig.GetSkillLevel(data.Skills, "EggLuck"),
			GameConfig.GetPetAbilityStats(equipped).EggLuck)
		luckValue.Text = "+" .. math.floor((luck - 1) * 100 + 0.5) .. "%"
		local powerEnds = data.Boosts and data.Boosts.Power
		local left = if powerEnds then powerEnds - os.time() else 0
		powerChip.Visible = left > 0
		powerValue.Text = "2x " .. clock(left)
	end
	deps.dataChanged.OnClientEvent:Connect(function() task.defer(refresh) end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(1)
		end
	end)

	-- ===== Fit to the screen =====
	local function fit()
		local size = camera.ViewportSize
		local compact = size.X < 900 or size.Y < 560
		topScale.Scale = math.min(1, (size.X - 120) / top.Size.X.Offset)
		for _, g in ipairs(groups) do
			g[2].Scale = if compact then g[3] else 1
		end
		if deps.powerLabel then deps.powerLabel.Visible = size.X >= 600 end
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
end

return HudStyle
