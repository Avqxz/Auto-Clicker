-- The egg UI (EggUI) and everything the player does with an egg: walking up to a pedestal opens a
-- panel with the egg, its price, the pets it can hatch with their odds (including your luck), and the
-- Hatch 1 / Hatch 3 / Auto buttons; walking away closes it. The panel is built once and refilled
-- for whichever egg is nearest. Hatches go to the server (RequestHatch), which decides the pets; the
-- result is played by HatchAnimationController.
--
-- Keys (EggConfig.Keys): E hatch 1, R hatch 3, T auto hatch. Touch screens get bigger buttons instead
-- of key hints.
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local EggConfig = require(Modules.EggConfig)
local PetConfig = require(Modules.PetConfig)
local HatchMath = require(Modules.HatchMath)
local HatchAnimationController = require(script.Parent.HatchAnimationController)

local EggInteractionController = {}

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(34, 48, 74)
local FONT = Enum.Font.FredokaOne
local PANEL_WIDTH = 420
local PANEL_HEIGHT = 540

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end
local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end
local function gradient(parent, top, bottom, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = WHITE
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end
local function tween(object, seconds, props, style, direction)
	local t = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function equippedPets(data)
	local set = {}
	for _, uid in ipairs(data.EquippedPetUids or {}) do set[uid] = true end
	local list = {}
	for _, pet in ipairs(data.Pets or {}) do
		if set[pet.Uid] then table.insert(list, pet) end
	end
	return list
end
local function playerLuck(data)
	return HatchMath.GetLuck(data, GameConfig.GetSkillLevel(data.Skills, "EggLuck"),
		GameConfig.GetPetAbilityStats(equippedPets(data)).EggLuck)
end
local function isUnlocked(data, unlock)
	if not unlock or (unlock.Pass == nil and unlock.Rebirths == nil) then return true end
	return (unlock.Pass ~= nil and GameConfig.HasPass(data, unlock.Pass))
		or (unlock.Rebirths ~= nil and (data.RebirthCount or 0) >= unlock.Rebirths)
end

-- deps: { getData(), dataChanged (RemoteEvent), remotes (Folder), playSound(kind), shake(strength, seconds),
--         isReducedMotion(), formatNumber(n) }
function EggInteractionController.Start(deps)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local requestHatch = deps.remotes:WaitForChild("RequestHatch")
	local setAutoDelete = deps.remotes:WaitForChild("SetAutoDelete")
	local animation = HatchAnimationController.new({
		playSound = deps.playSound,
		shake = deps.shake,
		isReducedMotion = deps.isReducedMotion,
	})
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local currentEgg -- egg whose panel is showing
	local dismissedEgg -- egg the player closed; stays closed until they walk away
	local autoOn = false
	local hatching = false

	-- ===== Panel =====
	local gui = Instance.new("ScreenGui")
	gui.Name = "EggUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local root = Instance.new("CanvasGroup")
	root.Name = "EggPanel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.52)
	root.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	root.Visible = false
	root.Parent = gui
	corner(root, 22)
	-- The colored rim is its own frame: a UIGradient directly on a CanvasGroup would tint everything in it.
	local rim = Instance.new("Frame")
	rim.Size = UDim2.fromScale(1, 1)
	rim.BackgroundColor3 = WHITE
	rim.ZIndex = 0
	rim.Parent = root
	corner(rim, 22)
	gradient(rim, Color3.fromRGB(80, 175, 255), Color3.fromRGB(175, 95, 255), 0) -- same as the other panels' headers
	local rootScale = Instance.new("UIScale")
	rootScale.Parent = root
	local fitScale = 1

	-- Soft drop shadow behind the panel (outside the CanvasGroup so it isn't clipped).
	local shadow = Instance.new("Frame")
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Size = UDim2.fromOffset(PANEL_WIDTH + 14, PANEL_HEIGHT + 14)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 1
	shadow.ZIndex = 0
	shadow.Visible = false
	shadow.Parent = gui
	corner(shadow, 28)
	local shadowScale = Instance.new("UIScale")
	shadowScale.Parent = shadow

	local inner = Instance.new("Frame")
	inner.Position = UDim2.fromOffset(8, 8)
	inner.Size = UDim2.new(1, -16, 1, -16)
	inner.BackgroundColor3 = Color3.fromRGB(248, 250, 255)
	inner.Parent = root
	corner(inner, 17)
	gradient(inner, Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 234, 250))

	local title = label(inner, {
		Position = UDim2.fromOffset(78, 8), Size = UDim2.new(1, -134, 0, 38), TextScaled = true,
		TextColor3 = WHITE, Text = "",
	})
	local titleStroke = Instance.new("UIStroke", title)
	titleStroke.Color = INK
	titleStroke.Thickness = 3
	local luckPill = label(inner, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(170, 22),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(80, 200, 120), TextSize = 15, Text = "",
	})
	corner(luckPill, 11)

	-- Close (hides until you walk away) and Auto Delete settings buttons in the header corners.
	local function iconButton(text, x, color, width)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Position = UDim2.new(x, if x == 0 then 8 else -8 - width, 0, 8)
		b.Size = UDim2.fromOffset(width, 40)
		b.BackgroundColor3 = color
		b.Font = FONT
		b.TextScaled = true
		b.TextColor3 = WHITE
		b.Text = text
		b.Parent = inner
		corner(b, 12)
		stroke(b, INK, 2, 0.6)
		return b
	end
	local deleteButton = iconButton("AUTO\nDELETE", 0, Color3.fromRGB(255, 140, 90), 64)
	local closeButton = iconButton("X", 1, Color3.fromRGB(240, 90, 110), 40)

	-- The egg: a turning model over a soft glow.
	local eggHolder = Instance.new("Frame")
	eggHolder.AnchorPoint = Vector2.new(0.5, 0)
	eggHolder.Position = UDim2.new(0.5, 0, 0, 70)
	eggHolder.Size = UDim2.fromOffset(120, 116)
	eggHolder.BackgroundTransparency = 1
	eggHolder.Parent = inner
	local eggGlow = Instance.new("ImageLabel")
	eggGlow.BackgroundTransparency = 1
	eggGlow.Image = "rbxasset://textures/glow.png"
	eggGlow.ImageTransparency = 0.35
	eggGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	eggGlow.Position = UDim2.fromScale(0.5, 0.5)
	eggGlow.Size = UDim2.fromScale(1.7, 1.7)
	eggGlow.Parent = eggHolder
	local eggView, eggModel

	local priceRow = label(inner, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 188), Size = UDim2.fromOffset(240, 30),
		TextScaled = true, TextColor3 = Color3.fromRGB(255, 196, 40), TextStrokeTransparency = 0, TextStrokeColor3 = INK, Text = "",
	})
	local lockNote = label(inner, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 218), Size = UDim2.fromOffset(300, 18),
		TextSize = 14, TextColor3 = Color3.fromRGB(100, 112, 140), Text = "",
	})

	-- Pet odds grid: up to 8 cells, four per row.
	local grid = Instance.new("Frame")
	grid.AnchorPoint = Vector2.new(0.5, 0)
	grid.Position = UDim2.new(0.5, 0, 0, 240)
	grid.Size = UDim2.new(1, -20, 0, 196)
	grid.BackgroundTransparency = 1
	grid.Parent = inner
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(88, 94)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local cells = {}
	for i = 1, 8 do
		local cell = Instance.new("Frame")
		cell.LayoutOrder = i
		cell.BackgroundColor3 = WHITE
		cell.Visible = false
		cell.Parent = grid
		corner(cell, 12)
		local cellStroke = stroke(cell, WHITE, 2.5)
		local cellGradient = gradient(cell, WHITE, WHITE)
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 3)
		icon.Size = UDim2.fromOffset(56, 56)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = cell
		local mystery = label(cell, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(40, 40),
			TextScaled = true, Text = "?", TextStrokeTransparency = 0.4, Visible = false,
		})
		local chance = label(cell, {
			Position = UDim2.fromOffset(2, 58), Size = UDim2.new(1, -4, 0, 18), TextScaled = true,
			TextColor3 = INK, Text = "",
		})
		local rarity = label(cell, {
			Position = UDim2.fromOffset(2, 76), Size = UDim2.new(1, -4, 0, 14), TextScaled = true, Text = "",
		})
		cells[i] = { Frame = cell, Stroke = cellStroke, Gradient = cellGradient, Icon = icon, Mystery = mystery,
			Chance = chance, Rarity = rarity }
	end

	-- Hatch buttons.
	local buttonHeight = if touchOnly then 62 else 54
	local buttonRow = Instance.new("Frame")
	buttonRow.AnchorPoint = Vector2.new(0.5, 1)
	buttonRow.Position = UDim2.new(0.5, 0, 1, -10)
	buttonRow.Size = UDim2.new(1, -20, 0, buttonHeight)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = inner
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = buttonRow

	local buttons = {}
	local function hatchButton(key, text, top, bottom, order)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.LayoutOrder = order
		b.Size = UDim2.new(1 / 3, -6, 1, 0)
		b.BackgroundColor3 = WHITE
		b.Text = ""
		b.Parent = buttonRow
		corner(b, 14)
		stroke(b, INK, 2.5, 0.35)
		local g = gradient(b, top, bottom)
		local caption = label(b, {
			Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0.62, -4), TextScaled = true,
			TextStrokeTransparency = 0.2, TextStrokeColor3 = INK, Text = text,
		})
		local sub = label(b, {
			Position = UDim2.new(0, 4, 0.62, 0), Size = UDim2.new(1, -8, 0.34, -2), TextScaled = true,
			TextColor3 = Color3.fromRGB(240, 246, 255), Text = "",
		})
		local keyHint = label(b, {
			AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(-6, -8), Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 0, BackgroundColor3 = INK, TextScaled = true, Text = EggConfig.Keys[key],
			Visible = not touchOnly, ZIndex = 3,
		})
		corner(keyHint, 7)
		local scale = Instance.new("UIScale")
		scale.Parent = b
		-- Scale feedback: grow on hover, squash on press.
		b.MouseEnter:Connect(function()
			tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
			deps.playSound("Hover")
		end)
		b.MouseLeave:Connect(function() tween(scale, 0.12, { Scale = 1 }) end)
		b.MouseButton1Down:Connect(function() tween(scale, 0.08, { Scale = 0.93 }) end)
		b.MouseButton1Up:Connect(function() tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back) end)
		buttons[key] = { Button = b, Gradient = g, Caption = caption, Sub = sub, Scale = scale, Top = top, Bottom = bottom }
		return b
	end
	hatchButton("Hatch1", "Hatch 1", Color3.fromRGB(90, 225, 255), Color3.fromRGB(30, 150, 235), 1)
	hatchButton("Hatch3", "Hatch 3", Color3.fromRGB(215, 130, 255), Color3.fromRGB(150, 70, 235), 2)
	hatchButton("Auto", "Auto", Color3.fromRGB(255, 205, 90), Color3.fromRGB(245, 140, 40), 3)

	for _, b in ipairs({ deleteButton, closeButton }) do
		local s = Instance.new("UIScale")
		s.Parent = b
		b.MouseEnter:Connect(function() tween(s, 0.12, { Scale = 1.1 }, Enum.EasingStyle.Back) deps.playSound("Hover") end)
		b.MouseLeave:Connect(function() tween(s, 0.12, { Scale = 1 }) end)
	end

	-- Warning banner inside the panel ("Pet Inventory Full!", "Not enough Coins!").
	local warning = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(360, 54),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(235, 70, 90), TextScaled = true,
		TextStrokeTransparency = 0.3, TextStrokeColor3 = INK, Text = "", Visible = false, ZIndex = 10,
	})
	corner(warning, 16)
	stroke(warning, WHITE, 3)
	local warningPad = Instance.new("UIPadding")
	warningPad.PaddingLeft = UDim.new(0, 14)
	warningPad.PaddingRight = UDim.new(0, 14)
	warningPad.PaddingTop = UDim.new(0, 8)
	warningPad.PaddingBottom = UDim.new(0, 8)
	warningPad.Parent = warning
	local warningScale = Instance.new("UIScale")
	warningScale.Parent = warning
	local warningToken = 0
	local function showWarning(text)
		if text == nil or text == "" then return end
		warningToken += 1
		local token = warningToken
		deps.playSound("Error")
		warning.Text = text
		warning.Visible = true
		warning.TextTransparency = 0
		warning.BackgroundTransparency = 0
		warningScale.Scale = 0.6
		tween(warningScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		for i = 1, 4 do
			task.delay(i * 0.05, function()
				warning.Rotation = if i % 2 == 0 then -2 else 2
				if i == 4 then warning.Rotation = 0 end
			end)
		end
		task.delay(1.8, function()
			if token ~= warningToken then return end
			tween(warning, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
			task.delay(0.3, function()
				if token == warningToken then warning.Visible = false end
			end)
		end)
	end

	-- Auto Hatch indicator at the top of the screen while it runs. Its own ScreenGui, marked to stay up
	-- while the hatch animation hides the rest of the UI.
	local indicatorGui = Instance.new("ScreenGui")
	indicatorGui.Name = "AutoHatchIndicator"
	indicatorGui.ResetOnSpawn = false
	indicatorGui.DisplayOrder = 60
	indicatorGui:SetAttribute("KeepDuringHatch", true)
	indicatorGui.Parent = playerGui
	local autoPill = label(indicatorGui, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(230, 34),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(70, 200, 110), TextScaled = true,
		TextStrokeTransparency = 0.4, TextStrokeColor3 = INK, Text = "AUTO HATCH ON", Visible = false,
	})
	corner(autoPill, 17)
	stroke(autoPill, WHITE, 2)
	local autoPillPad = Instance.new("UIPadding")
	autoPillPad.PaddingTop = UDim.new(0, 5)
	autoPillPad.PaddingBottom = UDim.new(0, 5)
	autoPillPad.Parent = autoPill

	-- Auto Delete settings popover.
	local deletePanel = Instance.new("Frame")
	deletePanel.Name = "AutoDeleteSettings"
	deletePanel.AnchorPoint = Vector2.new(0, 0)
	deletePanel.Position = UDim2.fromOffset(8, 54)
	deletePanel.Size = UDim2.fromOffset(200, 0)
	deletePanel.AutomaticSize = Enum.AutomaticSize.Y
	deletePanel.BackgroundColor3 = Color3.fromRGB(34, 44, 72)
	deletePanel.Visible = false
	deletePanel.ZIndex = 5
	deletePanel.Parent = inner
	corner(deletePanel, 14)
	stroke(deletePanel, WHITE, 2, 0.4)
	local deleteList = Instance.new("UIListLayout")
	deleteList.Padding = UDim.new(0, 6)
	deleteList.SortOrder = Enum.SortOrder.LayoutOrder
	deleteList.Parent = deletePanel
	local deletePad = Instance.new("UIPadding")
	deletePad.PaddingTop = UDim.new(0, 8)
	deletePad.PaddingBottom = UDim.new(0, 8)
	deletePad.PaddingLeft = UDim.new(0, 8)
	deletePad.PaddingRight = UDim.new(0, 8)
	deletePad.Parent = deletePanel
	label(deletePanel, { Size = UDim2.new(1, 0, 0, 22), TextScaled = true, Text = "Auto Delete", ZIndex = 5, LayoutOrder = 0 })
	label(deletePanel, { Size = UDim2.new(1, 0, 0, 30), TextSize = 12, TextWrapped = true, ZIndex = 5, LayoutOrder = 1,
		TextColor3 = Color3.fromRGB(190, 200, 225), Text = "Hatched pets of these rarities are deleted. Shiny and new pets are always kept." })
	local deleteToggles = {}
	for _, tier in ipairs(PetConfig.Rarities) do
		if PetConfig.CanAutoDelete(tier.Id) then
			local t = Instance.new("TextButton")
			t.AutoButtonColor = false
			t.LayoutOrder = tier.Rank + 1
			t.Size = UDim2.new(1, 0, 0, 34)
			t.BackgroundColor3 = Color3.fromRGB(60, 72, 104)
			t.Font = FONT
			t.TextScaled = true
			t.TextColor3 = tier.Color:Lerp(WHITE, 0.3)
			t.Text = tier.Id
			t.ZIndex = 5
			t.Parent = deletePanel
			corner(t, 10)
			local box = label(t, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, BackgroundColor3 = WHITE,
				TextColor3 = Color3.fromRGB(235, 70, 90), TextScaled = true, Text = "", ZIndex = 6 })
			corner(box, 6)
			t.Activated:Connect(function()
				local data = deps.getData()
				local on = not (data.Settings and data.Settings.AutoDelete and data.Settings.AutoDelete[tier.Id])
				deps.playSound("Click")
				box.Text = if on then "X" else ""
				setAutoDelete:FireServer(tier.Id, on)
			end)
			deleteToggles[tier.Id] = box
		end
	end
	deleteButton.Activated:Connect(function()
		deps.playSound("Click")
		deletePanel.Visible = not deletePanel.Visible
	end)

	-- ===== Filling the panel =====
	local function refreshAutoDelete(data)
		local settings = data.Settings and data.Settings.AutoDelete or {}
		for rarity, box in pairs(deleteToggles) do
			box.Text = if settings[rarity] then "X" else ""
		end
	end

	local function setButtonState(key, text, sub, enabled, lockedLook)
		local b = buttons[key]
		b.Caption.Text = text
		b.Sub.Text = sub
		b.Gradient.Color = if lockedLook
			then ColorSequence.new(Color3.fromRGB(170, 178, 196), Color3.fromRGB(120, 128, 150))
			else ColorSequence.new(b.Top, b.Bottom)
		b.Button.Active = enabled
	end

	local function refresh()
		local egg = currentEgg
		if not egg then return end
		local data = deps.getData()
		local luck = playerLuck(data)
		local chances = HatchMath.GetChances(egg, luck)
		local currency = EggConfig.Currencies[egg.Currency] or EggConfig.Currencies.Coins
		local balance = data[egg.Currency] or 0
		local zoneColor = PetConfig.Get(egg.Pets[#egg.Pets].Rarity).Color

		title.Text = egg.Name .. "!"
		luckPill.Visible = luck > 1.001
		luckPill.Text = string.format("LUCK x%.3g", luck)
		priceRow.Text = currency.Icon .. " " .. deps.formatNumber(egg.Cost)
		priceRow.TextColor3 = if balance >= egg.Cost then Color3.fromRGB(255, 196, 40) else Color3.fromRGB(240, 90, 100)
		local locked = (data.RebirthCount or 0) < egg.RequiredRebirths
		lockNote.Text = if locked then "LOCKED: needs " .. egg.RequiredRebirths .. " Ascensions"
			else "You have " .. currency.Icon .. " " .. deps.formatNumber(balance)
		eggGlow.ImageColor3 = zoneColor

		local discovered = data.Discovered or {}
		for i, cell in ipairs(cells) do
			local pet = egg.Pets[i]
			cell.Frame.Visible = pet ~= nil
			if pet then
				local tier = PetConfig.Get(pet.Rarity)
				local hidden = tier.Hidden and not discovered[pet.Name]
				local art = GameConfig.PetArt[pet.Name]
				cell.Icon.Image = art and art.Icon or ""
				cell.Icon.ImageColor3 = if hidden then Color3.new(0, 0, 0) else WHITE
				cell.Mystery.Visible = hidden or not (art and art.Icon)
				cell.Chance.Text = HatchMath.FormatChance(chances[i])
				cell.Rarity.Text = if hidden then "???" else string.upper(tier.Id)
				cell.Rarity.TextColor3 = if tier.Rainbow then Color3.fromRGB(150, 60, 220) else tier.Color:Lerp(INK, 0.25)
				cell.Stroke.Color = if tier.Rainbow then Color3.fromRGB(255, 120, 230) else tier.Color
				cell.Gradient.Color = if tier.Rainbow
					then ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 240)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 235, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 255, 225)) })
					else ColorSequence.new(WHITE, tier.Color:Lerp(WHITE, 0.72))
				cell.Mystery.TextColor3 = if hidden then Color3.fromRGB(80, 60, 120) else INK
				cell.Frame:SetAttribute("PetName", if hidden then "???" else pet.Name)
			end
		end

		local tripleUnlocked = isUnlocked(data, EggConfig.TripleHatchUnlock)
		local autoUnlocked = isUnlocked(data, EggConfig.AutoHatchUnlock)
		setButtonState("Hatch1", "Hatch 1", currency.Icon .. " " .. deps.formatNumber(egg.Cost), true, locked)
		setButtonState("Hatch3", "Hatch 3",
			if tripleUnlocked then currency.Icon .. " " .. deps.formatNumber(egg.Cost * 3) else "LOCKED", true, locked or not tripleUnlocked)
		setButtonState("Auto", if autoOn then "Auto: ON" else "Auto",
			if autoOn then "tap to stop" elseif autoUnlocked then "hatch nonstop" else "LOCKED", true, locked or not autoUnlocked)
		if autoOn then
			buttons.Auto.Gradient.Color = ColorSequence.new(Color3.fromRGB(120, 235, 140), Color3.fromRGB(40, 175, 90))
		end
		refreshAutoDelete(data)
	end

	local function setEggModel(egg)
		if eggView then eggView:Destroy() end
		eggView, eggModel = HatchAnimationController.MakeEggViewport(egg)
		eggView.Size = UDim2.fromScale(1, 1)
		eggView.ZIndex = 2
		eggView.Parent = eggHolder
	end

	-- Fit the panel on small screens.
	local function fit()
		local size = workspace.CurrentCamera.ViewportSize
		fitScale = math.min(1, (size.X - 24) / PANEL_WIDTH, (size.Y - 90) / PANEL_HEIGHT)
		shadow.Position = root.Position
		shadowScale.Scale = rootScale.Scale
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()

	-- Opening: scale 90% -> 100%, fade in, then the buttons bounce in one after another.
	local function open(egg)
		local switching = root.Visible and currentEgg ~= egg
		currentEgg = egg
		setEggModel(egg)
		refresh()
		ProximityPromptService.Enabled = false -- E is Hatch while the egg UI is open
		if root.Visible and not switching then return end
		deletePanel.Visible = false
		root.Visible = true
		shadow.Visible = true
		fit()
		rootScale.Scale = fitScale * 0.9
		root.GroupTransparency = 1
		shadow.BackgroundTransparency = 1
		tween(rootScale, 0.28, { Scale = fitScale }, Enum.EasingStyle.Back)
		tween(root, 0.22, { GroupTransparency = 0 })
		tween(shadow, 0.3, { BackgroundTransparency = 0.75 })
		for i, key in ipairs({ "Hatch1", "Hatch3", "Auto" }) do
			local s = buttons[key].Scale
			s.Scale = 0.5
			task.delay(0.08 + i * 0.06, function()
				tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
		deps.playSound("Hover")
	end

	local function stopAuto(message)
		if not autoOn then return end
		autoOn = false
		autoPill.Visible = false
		refresh()
		if message then showWarning(message) end
	end

	local function close()
		if not root.Visible then return end
		ProximityPromptService.Enabled = true
		deletePanel.Visible = false
		tween(rootScale, 0.18, { Scale = fitScale * 0.9 })
		tween(root, 0.18, { GroupTransparency = 1 })
		tween(shadow, 0.18, { BackgroundTransparency = 1 })
		task.delay(0.18, function()
			if root.GroupTransparency > 0.99 then
				root.Visible = false
				shadow.Visible = false
			end
		end)
		currentEgg = nil
	end
	closeButton.Activated:Connect(function()
		deps.playSound("Click")
		dismissedEgg = currentEgg
		stopAuto()
		close()
	end)

	-- ===== Hatching =====
	local reasonText = {
		InventoryFull = "Pet Inventory Full!",
		TooFar = "Get closer to the egg!",
		NeedTriple = "Triple Hatch is locked",
		NeedAuto = "Auto Hatch is locked",
	}

	-- Offers the unlock for a locked option: the gamepass prompt, or what's needed to earn it.
	local function promptUnlock(unlock, name)
		deps.playSound("Click")
		local pass = unlock.Pass and (function()
			for _, p in ipairs(GameConfig.GamePasses) do
				if p.Key == unlock.Pass then return p end
			end
		end)()
		if pass and pass.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		elseif unlock.Rebirths then
			showWarning(name .. " unlocks at " .. unlock.Rebirths .. " Ascension" .. (if unlock.Rebirths == 1 then "" else "s"))
		else
			showWarning(name .. " isn't for sale yet")
		end
	end

	-- Sends one hatch request and plays the result. Returns the result (or a failure table).
	local function request(egg, count, isAuto)
		if hatching or animation.IsPlaying() then
			return { Ok = false, Reason = "Busy" }
		end
		local data = deps.getData()
		local currency = EggConfig.Currencies[egg.Currency] or EggConfig.Currencies.Coins
		-- Quick client checks for instant feedback; the server checks all of these again.
		if (data.RebirthCount or 0) < egg.RequiredRebirths then
			return { Ok = false, Reason = "Locked", Message = "Ascend " .. egg.RequiredRebirths .. " times to hatch the " .. egg.Name }
		end
		if (data[egg.Currency] or 0) < egg.Cost * count then
			return { Ok = false, Reason = "Currency", Message = "Not enough " .. currency.Name .. "!" }
		end
		if #data.Pets + count > GameConfig.MaxPets then
			return { Ok = false, Reason = "InventoryFull", Message = reasonText.InventoryFull }
		end
		hatching = true
		local ok, result = pcall(requestHatch.InvokeServer, requestHatch, egg.Id, count, isAuto)
		hatching = false
		if not ok or type(result) ~= "table" then
			return { Ok = false, Reason = "Error", Message = "Couldn't reach the server" }
		end
		if not result.Ok then
			result.Message = result.Message or reasonText[result.Reason]
			return result
		end
		deps.playSound("Purchase")
		animation.Play(result, egg, { Fast = isAuto })
		refresh()
		return result
	end

	local function hatchOnce(count)
		local egg = currentEgg
		if not egg then return end
		local data = deps.getData()
		if count == 3 and not isUnlocked(data, EggConfig.TripleHatchUnlock) then
			promptUnlock(EggConfig.TripleHatchUnlock, "Triple Hatch")
			return
		end
		deps.playSound("Click")
		local result = request(egg, count, false)
		if not result.Ok and result.Reason ~= "Busy" and result.Reason ~= "Cooldown" then
			showWarning(result.Message)
		end
	end

	local function startAuto()
		local data = deps.getData()
		if not isUnlocked(data, EggConfig.AutoHatchUnlock) then
			promptUnlock(EggConfig.AutoHatchUnlock, "Auto Hatch")
			return
		end
		if autoOn then
			stopAuto()
			return
		end
		deps.playSound("Click")
		autoOn = true
		autoPill.Visible = true
		refresh()
		task.spawn(function()
			while autoOn do
				local egg = currentEgg
				if not egg then
					stopAuto("Auto Hatch stopped: you walked away")
					break
				end
				local d = deps.getData()
				local count = if isUnlocked(d, EggConfig.TripleHatchUnlock) and (d[egg.Currency] or 0) >= egg.Cost * 3
					and #d.Pets + 3 <= GameConfig.MaxPets then 3 else 1
				local result = request(egg, count, true)
				if not result.Ok then
					if result.Reason == "Busy" or result.Reason == "Cooldown" then
						task.wait(0.2)
					else
						stopAuto("Auto Hatch stopped: " .. (result.Message or "can't hatch"))
						break
					end
				else
					task.wait(EggConfig.AutoHatchDelay)
				end
			end
		end)
	end

	buttons.Hatch1.Button.Activated:Connect(function() hatchOnce(1) end)
	buttons.Hatch3.Button.Activated:Connect(function() hatchOnce(3) end)
	buttons.Auto.Button.Activated:Connect(startAuto)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not currentEgg or not root.Visible or animation.IsPlaying() then return end
		if input.KeyCode == Enum.KeyCode[EggConfig.Keys.Hatch1] then
			hatchOnce(1)
		elseif input.KeyCode == Enum.KeyCode[EggConfig.Keys.Hatch3] then
			hatchOnce(3)
		elseif input.KeyCode == Enum.KeyCode[EggConfig.Keys.Auto] then
			startAuto()
		end
	end)

	-- ===== Proximity =====
	local function nearestEgg()
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then return nil end
		local best, bestDistance
		for _, pedestal in ipairs(CollectionService:GetTagged("EggPedestal")) do
			local egg = EggConfig.ById[pedestal:GetAttribute("EggId")]
			if egg and pedestal:IsDescendantOf(workspace) then
				local distance = (pedestal.Position - hrp.Position).Magnitude
				if distance <= EggConfig.ProximityRange and (not bestDistance or distance < bestDistance) then
					best, bestDistance = egg, distance
				end
			end
		end
		return best
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		if eggModel and root.Visible then
			eggModel.CFrame = CFrame.Angles(0, os.clock() * 0.9, 0) * CFrame.new(0, math.sin(os.clock() * 2) * 0.12, 0)
		end
		elapsed += dt
		if elapsed < 0.15 then return end
		elapsed = 0
		if animation.IsPlaying() then return end
		-- The spawn is next to the Starter Egg: stay closed until the starter pet is picked.
		local egg = if deps.getData().HasPickedStarterPet then nearestEgg() else nil
		if egg ~= dismissedEgg then dismissedEgg = nil end
		if egg and egg ~= dismissedEgg then
			if egg ~= currentEgg or not root.Visible then open(egg) end
		elseif currentEgg then
			if autoOn then stopAuto("Auto Hatch stopped: you walked away") end
			close()
		end
	end)

	-- Clicking an egg in the world hatches one.
	local function hookClick(pedestal)
		local detector = pedestal:WaitForChild("ClickDetector", 10)
		if not detector then return end
		detector.MouseClick:Connect(function()
			local egg = EggConfig.ById[pedestal:GetAttribute("EggId")]
			if not egg then return end
			if currentEgg ~= egg and not egg.HatchAnywhere then
				showWarning("Get closer to the egg!")
				return
			end
			local result = request(egg, 1, false)
			if not result.Ok and result.Reason ~= "Busy" and result.Reason ~= "Cooldown" then
				showWarning(result.Message)
			end
		end)
	end
	for _, pedestal in ipairs(CollectionService:GetTagged("EggPedestal")) do task.spawn(hookClick, pedestal) end
	CollectionService:GetInstanceAddedSignal("EggPedestal"):Connect(function(p) task.spawn(hookClick, p) end)

	deps.dataChanged.OnClientEvent:Connect(function()
		if root.Visible then refresh() end
	end)

	-- For the Eggs menu: hatch an egg from anywhere it allows.
	local api = {}
	function api.Request(eggId, count)
		local egg = EggConfig.ById[eggId]
		if not egg then return end
		local data = deps.getData()
		if count == 3 and not isUnlocked(data, EggConfig.TripleHatchUnlock) then
			promptUnlock(EggConfig.TripleHatchUnlock, "Triple Hatch")
			return
		end
		local result = request(egg, count, false)
		if not result.Ok and result.Reason ~= "Busy" and result.Reason ~= "Cooldown" then
			showWarning(result.Message)
		end
	end
	api.ShowWarning = showWarning
	return api
end

return EggInteractionController
