-- Coins counter + SELL button (Power -> Coins), running-boost timers, and the Token Shop panel
-- (BOOSTS button in the right-hand column). The server owns every change (SellPower / BuyBoost).

local RunService = game:GetService("RunService")

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local EconomyUI = {}

local DARK = Color3.fromRGB(37, 65, 78)
local MUTED = Color3.fromRGB(77, 116, 130)
local GREY = Color3.fromRGB(152, 174, 184)
local GREEN = Color3.fromRGB(88, 219, 132)

local COIN = "💰"
local TOKEN = "🎫"

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- deps: { screenGui, controls, utility(text, y, color), createPanel, bindTab, registerPanel,
--         styleButton, formatNumber, dataRemote, getEquippedPets(data), requestData, sellRemote, buyBoostRemote }
function EconomyUI.Build(deps)
	local fmt = deps.formatNumber
	local data

	local function pill(name, position, size, color)
		local f = Instance.new("TextLabel")
		f.Name = name
		f.AnchorPoint = Vector2.new(1, 0)
		f.Position = position
		f.Size = size
		f.BackgroundColor3 = color
		f.Font = Enum.Font.FredokaOne
		f.TextScaled = true
		f.TextColor3 = Color3.new(1, 1, 1)
		f.TextStrokeTransparency = 0
		f.TextStrokeColor3 = Color3.fromRGB(60, 45, 10)
		f.Parent = deps.screenGui
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
		local stroke = Instance.new("UIStroke", f)
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(60, 45, 10)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local pad = Instance.new("UIPadding", f)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
		return f
	end

	-- Coins counter (left of the Power counter) with a SELL button under it.
	local coinPill = pill("CoinPill", UDim2.new(0.5, -138, 0, 12), UDim2.fromOffset(130, 56), Color3.fromRGB(240, 170, 30))
	coinPill.Text = COIN .. " 0"
	local sell = Instance.new("TextButton")
	sell.Name = "SellButton"
	sell.AnchorPoint = Vector2.new(1, 0)
	sell.Position = UDim2.new(0.5, -138, 0, 72)
	sell.Size = UDim2.fromOffset(130, 36)
	sell.BackgroundColor3 = GREEN
	sell.Font = Enum.Font.FredokaOne
	sell.TextScaled = true
	sell.TextColor3 = Color3.new(1, 1, 1)
	sell.Text = "SELL ⚡"
	sell.Parent = deps.screenGui
	Instance.new("UICorner", sell).CornerRadius = UDim.new(0, 10)
	deps.styleButton(sell)
	sell.MouseButton1Click:Connect(function()
		deps.sellRemote:FireServer()
	end)

	-- Running boosts (right of the Power counter, under the gem counter). Hidden when none run.
	local boostLabel = Instance.new("TextLabel")
	boostLabel.Name = "BoostTimers"
	boostLabel.AnchorPoint = Vector2.new(0, 0)
	boostLabel.Position = UDim2.new(0.5, 138, 0, 72)
	boostLabel.Size = UDim2.fromOffset(150, 36)
	boostLabel.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
	boostLabel.BackgroundTransparency = 0.15
	boostLabel.Font = Enum.Font.FredokaOne
	boostLabel.TextScaled = true
	boostLabel.TextColor3 = Color3.fromRGB(255, 225, 120)
	boostLabel.Visible = false
	boostLabel.Parent = deps.screenGui
	Instance.new("UICorner", boostLabel).CornerRadius = UDim.new(0, 10)

	-- ===== Token Shop =====
	deps.controls.Size = UDim2.fromOffset(106, 316)
	local shopButton = deps.utility("BOOSTS", 270, Color3.fromRGB(90, 120, 230))
	local frame, scroll = deps.createPanel("TokenShopFrame", "Token Shop")
	deps.registerPanel(frame)
	deps.bindTab(shopButton, frame)

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
	local tokensHeader = text(scroll, { Size = UDim2.new(1, 0, 0, 30), TextScaled = true, LayoutOrder = 0,
		TextColor3 = Color3.fromRGB(70, 90, 200) })
	local cards = {}
	for i, item in ipairs(GameConfig.TokenShop) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 84)
		card.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
		card.LayoutOrder = i
		card.Parent = scroll
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
		text(card, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -160, 0, 26), TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left, Text = item.Name .. "  •  " .. item.Minutes .. " min" })
		text(card, { Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -160, 0, 18), TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MUTED, Text = item.Description })
		local status = text(card, { Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -160, 0, 20), TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(40, 160, 90) })
		local buy = Instance.new("TextButton")
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -10, 0.5, 0)
		buy.Size = UDim2.fromOffset(136, 50)
		buy.Font = Enum.Font.FredokaOne
		buy.TextScaled = true
		buy.TextColor3 = Color3.new(1, 1, 1)
		buy.Text = TOKEN .. " " .. item.Cost
		buy.Parent = card
		Instance.new("UICorner", buy).CornerRadius = UDim.new(0, 10)
		deps.styleButton(buy)
		buy.MouseButton1Click:Connect(function()
			deps.buyBoostRemote:FireServer(item.Id)
		end)
		cards[item.Id] = { Item = item, Status = status, Buy = buy }
	end
	text(scroll, { Size = UDim2.new(1, 0, 0, 40), TextSize = 15, LayoutOrder = 99, TextColor3 = MUTED,
		Text = "Earn Tokens from quests and the Day 7 daily reward. Buying again extends a running boost (up to "
			.. GameConfig.BoostMaxMinutes .. " min)." })

	local function refresh()
		if not data then return end
		coinPill.Text = COIN .. " " .. fmt(data.Coins or 0)
		sell.Text = if (data.Power or 0) >= 1
			then "SELL → " .. COIN .. fmt(math.floor(math.floor(data.Power) * GameConfig.GetSellRate(data.RebirthCount)
				* (1 + GameConfig.GetPetAbilityStats(deps.getEquippedPets(data)).CoinBonus)))
			else "SELL ⚡"
		tokensHeader.Text = TOKEN .. " " .. fmt(data.Tokens or 0) .. " Tokens"
		for _, card in pairs(cards) do
			card.Buy.BackgroundColor3 = if (data.Tokens or 0) >= card.Item.Cost then GREEN else GREY
		end
	end

	deps.dataRemote.OnClientEvent:Connect(function(newData)
		data = newData
		refresh()
	end)

	-- Boost countdowns (server stores end times as os.time).
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 or not data then return end
		acc = 0
		local now = workspace:GetServerTimeNow()
		local parts = {}
		for _, card in pairs(cards) do
			local ends = data.Boosts and data.Boosts[card.Item.Boost]
			local left = ends and ends - now or 0
			if left > 0 then
				card.Status.Text = "Active • " .. clock(left) .. " left"
				table.insert(parts, card.Item.Name .. " " .. clock(left))
			else
				card.Status.Text = ""
			end
		end
		boostLabel.Visible = #parts > 0
		boostLabel.Text = table.concat(parts, "  ")
	end)

	deps.requestData()
end

return EconomyUI
