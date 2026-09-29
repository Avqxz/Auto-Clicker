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

		local frame, scroll = deps.createPanel("StoreFrame", "Store")
		deps.registerPanel(frame)
		deps.bindTab(cart, frame)

		local order = 0
		local function section(title)
			order += 1
			text(scroll, { Size = UDim2.new(1, 0, 0, 28), TextScaled = true, LayoutOrder = order, Text = title,
				TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(0, 150, 190) })
		end
		local function row(item, isPass)
			if item.Id == 0 and not isStudio then return end
			order += 1
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 70)
			card.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
			card.LayoutOrder = order
			card.Parent = scroll
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
			text(card, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -170, 0, 26), TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left, Text = item.Name })
			text(card, { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -170, 0, 28), TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = MUTED,
				Text = item.Description or ("Double " .. (item.Boost or "") .. " for " .. (item.Minutes or 0) .. " minutes") })
			local buy = Instance.new("TextButton")
			buy.AnchorPoint = Vector2.new(1, 0.5)
			buy.Position = UDim2.new(1, -10, 0.5, 0)
			buy.Size = UDim2.fromOffset(148, 48)
			buy.Font = Enum.Font.FredokaOne
			buy.TextScaled = true
			buy.TextColor3 = Color3.new(1, 1, 1)
			buy.BackgroundColor3 = if item.Id == 0 then GREY else GREEN
			buy.Text = if item.Id == 0 then "ID not set" else "BUY"
			buy.Parent = card
			Instance.new("UICorner", buy).CornerRadius = UDim.new(0, 10)
			deps.styleButton(buy)
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

		section("GAMEPASSES")
		for _, pass in ipairs(GameConfig.GamePasses) do row(pass, true) end
		section("BOOSTS & PACKS")
		for _, product in ipairs(GameConfig.DevProducts) do row(product, false) end
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
