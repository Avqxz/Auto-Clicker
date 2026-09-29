-- STORE panel (gamepasses + developer products) opened from a round shopping-cart button under the
-- right-hand button column, the AUTO click toggle for Auto Click owners, and the [VIP] chat tag. Items with Id 0 are hidden from players; in Studio they show as "ID not set"
-- so the layout can be checked before the real IDs are pasted into GameConfig.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local StoreUI = {}

local DARK = Color3.fromRGB(37, 65, 78)
local MUTED = Color3.fromRGB(77, 116, 130)
local GREY = Color3.fromRGB(152, 174, 184)
local GREEN = Color3.fromRGB(88, 219, 132)

-- deps: { screenGui, createPanel, bindTab, registerPanel, styleButton, dataRemote, clickRemote }
function StoreUI.Build(deps)
	local player = Players.LocalPlayer
	local isStudio = RunService:IsStudio()
	local data

	local function text(parent, props)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = DARK
		l.TextWrapped = true
		for k, v in pairs(props) do l[k] = v end
		l.Parent = parent
		return l
	end

	-- ===== STORE panel =====
	local visibleItems = 0
	for _, list in ipairs({ GameConfig.GamePasses, GameConfig.DevProducts }) do
		for _, item in ipairs(list) do
			if item.Id ~= 0 or isStudio then visibleItems += 1 end
		end
	end

	local rows = {}
	if visibleItems > 0 then
		-- Round cart button: big 🛒 with a small STORE tag, wiggling now and then to catch the eye.
		local cart = Instance.new("TextButton")
		cart.Name = "CartButton"
		-- Sits centered just under the right-hand button column (which ends at y=290), so it never
		-- overlaps it however short the screen is.
		cart.AnchorPoint = Vector2.new(0.5, 0)
		cart.Position = UDim2.new(1, -63, 0, 294)
		cart.Size = UDim2.fromOffset(74, 74)
		cart.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
		cart.Text = ""
		cart.Parent = deps.screenGui
		Instance.new("UICorner", cart).CornerRadius = UDim.new(1, 0)
		deps.styleButton(cart)
		text(cart, { Size = UDim2.fromScale(1, 0.78), Position = UDim2.fromScale(0, 0.04), TextScaled = true,
			Text = "🛒", TextColor3 = Color3.new(1, 1, 1) })
		local tag = text(cart, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 6),
			Size = UDim2.fromOffset(78, 24), TextScaled = true, Text = "STORE", TextColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(230, 70, 110) })
		Instance.new("UICorner", tag).CornerRadius = UDim.new(1, 0)
		task.spawn(function()
			while cart.Parent do
				task.wait(5)
				for _, angle in ipairs({ -10, 9, -6, 4, 0 }) do
					TweenService:Create(cart, TweenInfo.new(0.08), { Rotation = angle }):Play()
					task.wait(0.08)
				end
			end
		end)

		local frame, scroll = deps.createPanel("StoreFrame", "Shop")
		deps.registerPanel(frame)
		deps.bindTab(cart, frame)

		-- Tabs (Gamepasses / Boosts) over a grid of pastel cards: name, big icon, green price pill.
		local INK = Color3.fromRGB(22, 32, 58)
		local ICONS = { AutoClick = "👆", TripleHatch = "🥚", AutoHatch = "🤖", PetSlots = "🐾", Lucky = "🍀",
			FastHatch = "⏱️", VIP = "👑", PowerBoost15 = "⚡", LuckBoost15 = "🍀", BossRetry = "⚔️", TokenPack = "🎟️" }
		local CARD_COLORS = { Color3.fromRGB(255, 232, 120), Color3.fromRGB(255, 170, 200), Color3.fromRGB(170, 225, 255),
			Color3.fromRGB(170, 240, 150), Color3.fromRGB(200, 180, 255), Color3.fromRGB(255, 200, 150) }
		local function outline(object, thickness)
			local stroke = Instance.new("UIStroke", object)
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = INK
			stroke.Thickness = thickness or 2.5
		end
		local function inkText(parent, props)
			local l = text(parent, props)
			l.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
			local stroke = Instance.new("UIStroke", l)
			stroke.Color = INK
			stroke.Thickness = 2
			return l
		end

		local tabs = Instance.new("Frame")
		tabs.Size = UDim2.new(1, 0, 0, 38)
		tabs.BackgroundTransparency = 1
		tabs.LayoutOrder = 1
		tabs.Parent = scroll
		local tabLayout = Instance.new("UIListLayout", tabs)
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		tabLayout.Padding = UDim.new(0, 8)
		local grids, tabButtons = {}, {}
		local function showTab(name)
			for n, g in pairs(grids) do g.Visible = n == name end
			for n, b in pairs(tabButtons) do
				b.BackgroundColor3 = if n == name then Color3.fromRGB(40, 130, 240) else Color3.fromRGB(120, 170, 235)
			end
		end
		local function tab(name, order)
			local b = Instance.new("TextButton")
			b.LayoutOrder = order
			b.Size = UDim2.fromOffset(150, 34)
			b.AutoButtonColor = false
			b.Font = Enum.Font.FredokaOne
			b.TextScaled = true
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = name
			b.Parent = tabs
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
			outline(b, 2.5)
			local pad = Instance.new("UIPadding", b)
			pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
			local stroke = Instance.new("UIStroke", b)
			stroke.Color = INK
			stroke.Thickness = 1.8
			tabButtons[name] = b
			local grid = Instance.new("Frame")
			grid.Size = UDim2.new(1, 0, 0, 0)
			grid.AutomaticSize = Enum.AutomaticSize.Y
			grid.BackgroundTransparency = 1
			grid.LayoutOrder = 2
			grid.Parent = scroll
			local layout = Instance.new("UIGridLayout", grid)
			layout.CellSize = UDim2.new(1 / 3, -8, 0, 150)
			layout.CellPadding = UDim2.fromOffset(10, 12)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			grids[name] = grid
			b.Activated:Connect(function() showTab(name) end)
			return grid
		end

		local cardIndex = 0
		local function card(grid, item, isPass)
			if item.Id == 0 and not isStudio then return end
			cardIndex += 1
			local c = Instance.new("Frame")
			c.LayoutOrder = cardIndex
			c.BackgroundColor3 = CARD_COLORS[(cardIndex - 1) % #CARD_COLORS + 1]
			c.Parent = grid
			Instance.new("UICorner", c).CornerRadius = UDim.new(0, 16)
			outline(c, 3)
			local g = Instance.new("UIGradient", c)
			g.Rotation = 90
			g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 225))
			inkText(c, { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 24), TextScaled = true, Text = item.Name })
			text(c, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(62, 62),
				TextScaled = true, Text = ICONS[item.Key] or "⭐" })
			local buy = Instance.new("TextButton")
			buy.AnchorPoint = Vector2.new(0.5, 1)
			buy.Position = UDim2.new(0.5, 0, 1, -8)
			buy.Size = UDim2.new(0.78, 0, 0, 32)
			buy.AutoButtonColor = false
			buy.Font = Enum.Font.FredokaOne
			buy.TextScaled = true
			buy.TextColor3 = Color3.new(1, 1, 1)
			buy.BackgroundColor3 = if item.Id == 0 then GREY else Color3.fromRGB(60, 200, 90)
			buy.Text = if item.Id == 0 then "ID not set" else "BUY"
			buy.Parent = c
			Instance.new("UICorner", buy).CornerRadius = UDim.new(1, 0)
			outline(buy, 2.5)
			local buyText = Instance.new("UIStroke", buy)
			buyText.Color = INK
			buyText.Thickness = 1.8
			local buyPad = Instance.new("UIPadding", buy)
			buyPad.PaddingTop, buyPad.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
			buy.MouseButton1Click:Connect(function()
				if item.Id == 0 then return end
				if isPass then
					if not GameConfig.HasPass(data, item.Key) then
						MarketplaceService:PromptGamePassPurchase(player, item.Id)
					end
				else
					MarketplaceService:PromptProductPurchase(player, item.Id)
				end
			end)
			-- Show the Robux price once Roblox returns it.
			if item.Id ~= 0 then
				task.spawn(function()
					local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.Id,
						if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
					if ok and info and info.PriceInRobux then
						item.PriceText = "R$ " .. info.PriceInRobux
						if not (isPass and GameConfig.HasPass(data, item.Key)) then buy.Text = item.PriceText end
					end
				end)
			end
			table.insert(rows, { Item = item, IsPass = isPass, Buy = buy })
		end

		local passGrid = tab("Gamepasses", 1)
		local boostGrid = tab("Boosts", 2)
		for _, pass in ipairs(GameConfig.GamePasses) do card(passGrid, pass, true) end
		for _, product in ipairs(GameConfig.DevProducts) do card(boostGrid, product, false) end
		showTab("Gamepasses")
	end

	-- ===== AUTO click toggle (Auto Click pass) =====
	local autoButton = Instance.new("TextButton")
	autoButton.Name = "AutoClickToggle"
	autoButton.AnchorPoint = Vector2.new(0, 1)
	autoButton.Position = UDim2.new(0.5, 130, 1, -22)
	autoButton.Size = UDim2.fromOffset(96, 56)
	autoButton.Font = Enum.Font.FredokaOne
	autoButton.TextScaled = true
	autoButton.TextColor3 = Color3.new(1, 1, 1)
	autoButton.BackgroundColor3 = GREY
	autoButton.Text = "AUTO\nOFF"
	autoButton.Visible = false
	autoButton.Parent = deps.screenGui
	Instance.new("UICorner", autoButton).CornerRadius = UDim.new(0, 14)
	deps.styleButton(autoButton)
	local autoOn = false
	autoButton.MouseButton1Click:Connect(function()
		autoOn = not autoOn
		autoButton.Text = if autoOn then "AUTO\nON" else "AUTO\nOFF"
		autoButton.BackgroundColor3 = if autoOn then GREEN else GREY
	end)
	task.spawn(function()
		while true do
			task.wait(1 / GameConfig.AutoClickPerSecond)
			if autoOn and GameConfig.HasPass(data, "AutoClick") then
				deps.clickRemote:FireServer()
			end
		end
	end)

	local function refresh()
		if not data then return end
		autoButton.Visible = GameConfig.HasPass(data, "AutoClick")
		for _, r in ipairs(rows) do
			if r.IsPass and GameConfig.HasPass(data, r.Item.Key) then
				r.Buy.Text = "OWNED"
				r.Buy.BackgroundColor3 = GREY
			end
		end
	end
	deps.dataRemote.OnClientEvent:Connect(function(newData)
		data = newData
		refresh()
	end)

	-- ===== [VIP] chat tag (the server sets Pass_VIP on VIP owners) =====
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("Pass_VIP") then
			props.PrefixText = '<font color="#FFD24A">[VIP]</font> ' .. message.PrefixText
		end
		return props
	end
end

return StoreUI
