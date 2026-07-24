-- Client bootstrap for the Clicking Simulator.
-- Builds the HUD/shop UI entirely in code and talks to the server via RemoteEvents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClickRemote = Remotes:WaitForChild("Click")
local PurchaseUpgradeRemote = Remotes:WaitForChild("PurchaseUpgrade")
local PurchaseAutoClickerRemote = Remotes:WaitForChild("PurchaseAutoClicker")
local RebirthRemote = Remotes:WaitForChild("Rebirth")
local DataUpdatedRemote = Remotes:WaitForChild("DataUpdated")

local currentData = {
	Coins = 0,
	ClickPower = GameConfig.StartingClickPower,
	UpgradeLevels = {},
	AutoClickerLevels = {},
	RebirthCount = 0,
}

-- ===== UI construction =====

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClickerSimulatorGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Coin counter
local coinFrame = Instance.new("Frame")
coinFrame.Name = "CoinFrame"
coinFrame.AnchorPoint = Vector2.new(0.5, 0)
coinFrame.Position = UDim2.new(0.5, 0, 0.02, 0)
coinFrame.Size = UDim2.new(0, 280, 0, 60)
coinFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
coinFrame.BorderSizePixel = 0
coinFrame.Parent = screenGui

Instance.new("UICorner", coinFrame).CornerRadius = UDim.new(0, 12)

local coinLabel = Instance.new("TextLabel")
coinLabel.Name = "CoinLabel"
coinLabel.BackgroundTransparency = 1
coinLabel.Size = UDim2.new(1, 0, 1, 0)
coinLabel.Font = Enum.Font.GothamBold
coinLabel.TextScaled = true
coinLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
coinLabel.Text = "0 Coins"
coinLabel.Parent = coinFrame

-- Click button
local clickButton = Instance.new("TextButton")
clickButton.Name = "ClickButton"
clickButton.AnchorPoint = Vector2.new(0.5, 0.5)
clickButton.Position = UDim2.new(0.5, 0, 0.55, 0)
clickButton.Size = UDim2.new(0, 260, 0, 260)
clickButton.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
clickButton.Text = "CLICK!"
clickButton.Font = Enum.Font.GothamBlack
clickButton.TextScaled = true
clickButton.TextColor3 = Color3.fromRGB(40, 30, 0)
clickButton.AutoButtonColor = true
clickButton.Parent = screenGui

Instance.new("UICorner", clickButton).CornerRadius = UDim.new(1, 0)

local clickStroke = Instance.new("UIStroke")
clickStroke.Thickness = 4
clickStroke.Color = Color3.fromRGB(180, 130, 0)
clickStroke.Parent = clickButton

-- Click power label
local powerLabel = Instance.new("TextLabel")
powerLabel.Name = "PowerLabel"
powerLabel.AnchorPoint = Vector2.new(0.5, 0)
powerLabel.Position = UDim2.new(0.5, 0, 0.55, 145)
powerLabel.Size = UDim2.new(0, 260, 0, 30)
powerLabel.BackgroundTransparency = 1
powerLabel.Font = Enum.Font.Gotham
powerLabel.TextScaled = true
powerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
powerLabel.Text = "+1 per click"
powerLabel.Parent = screenGui

-- Rebirth button
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.AnchorPoint = Vector2.new(1, 0)
rebirthButton.Position = UDim2.new(1, -20, 0.02, 0)
rebirthButton.Size = UDim2.new(0, 190, 0, 55)
rebirthButton.BackgroundColor3 = Color3.fromRGB(140, 50, 200)
rebirthButton.Font = Enum.Font.GothamBold
rebirthButton.TextScaled = true
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthButton.Text = "Rebirth (0)"
rebirthButton.Parent = screenGui

Instance.new("UICorner", rebirthButton).CornerRadius = UDim.new(0, 12)

-- Shop toggle
local shopToggle = Instance.new("TextButton")
shopToggle.Name = "ShopToggle"
shopToggle.AnchorPoint = Vector2.new(1, 1)
shopToggle.Position = UDim2.new(1, -20, 1, -20)
shopToggle.Size = UDim2.new(0, 140, 0, 50)
shopToggle.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
shopToggle.Font = Enum.Font.GothamBold
shopToggle.TextScaled = true
shopToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
shopToggle.Text = "Shop"
shopToggle.Parent = screenGui

Instance.new("UICorner", shopToggle).CornerRadius = UDim.new(0, 12)

-- Shop panel
local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.AnchorPoint = Vector2.new(1, 1)
shopFrame.Position = UDim2.new(1, -20, 1, -85)
shopFrame.Size = UDim2.new(0, 360, 0, 440)
shopFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
shopFrame.Visible = false
shopFrame.Parent = screenGui

Instance.new("UICorner", shopFrame).CornerRadius = UDim.new(0, 14)

local shopTitle = Instance.new("TextLabel")
shopTitle.BackgroundTransparency = 1
shopTitle.Size = UDim2.new(1, 0, 0, 40)
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextScaled = true
shopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
shopTitle.Text = "Upgrades"
shopTitle.Parent = shopFrame

local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Name = "ShopScroll"
shopScroll.Position = UDim2.new(0, 0, 0, 44)
shopScroll.Size = UDim2.new(1, 0, 1, -44)
shopScroll.BackgroundTransparency = 1
shopScroll.BorderSizePixel = 0
shopScroll.ScrollBarThickness = 6
shopScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
shopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopScroll.Parent = shopFrame

local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 8)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopScroll

local shopPadding = Instance.new("UIPadding")
shopPadding.PaddingTop = UDim.new(0, 8)
shopPadding.PaddingLeft = UDim.new(0, 8)
shopPadding.PaddingRight = UDim.new(0, 8)
shopPadding.PaddingBottom = UDim.new(0, 8)
shopPadding.Parent = shopScroll

shopToggle.MouseButton1Click:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
end)

-- ===== Helpers =====

local function formatNumber(n)
	n = math.floor(n)
	if n >= 1e12 then
		return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.2fK", n / 1e3)
	else
		return tostring(n)
	end
end

local shopEntries = {}

local function createShopEntry(item, kind, layoutOrder)
	local frame = Instance.new("Frame")
	frame.Name = item.Id
	frame.Size = UDim2.new(1, 0, 0, 80)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	frame.LayoutOrder = layoutOrder
	frame.Parent = shopScroll

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.Size = UDim2.new(1, -110, 0, 22)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Text = item.Name
	nameLabel.Parent = frame

	local descLabel = Instance.new("TextLabel")
	descLabel.BackgroundTransparency = 1
	descLabel.Position = UDim2.new(0, 10, 0, 27)
	descLabel.Size = UDim2.new(1, -110, 0, 18)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextScaled = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
	descLabel.Text = item.Description
	descLabel.Parent = frame

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.BackgroundTransparency = 1
	levelLabel.Position = UDim2.new(0, 10, 0, 46)
	levelLabel.Size = UDim2.new(1, -110, 0, 16)
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.TextScaled = true
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
	levelLabel.Text = "Level 0"
	levelLabel.Parent = frame

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.Position = UDim2.new(1, -10, 0.5, 0)
	buyButton.Size = UDim2.new(0, 90, 0, 40)
	buyButton.BackgroundColor3 = Color3.fromRGB(60, 170, 100)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextScaled = true
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.Text = "Buy"
	buyButton.Parent = frame

	Instance.new("UICorner", buyButton).CornerRadius = UDim.new(0, 8)

	buyButton.MouseButton1Click:Connect(function()
		if kind == "upgrade" then
			PurchaseUpgradeRemote:FireServer(item.Id)
		else
			PurchaseAutoClickerRemote:FireServer(item.Id)
		end
	end)

	shopEntries[item.Id] = {
		Item = item,
		Kind = kind,
		LevelLabel = levelLabel,
		BuyButton = buyButton,
	}
end

do
	local order = 0
	for _, upgrade in ipairs(GameConfig.Upgrades) do
		order += 1
		createShopEntry(upgrade, "upgrade", order)
	end
	for _, auto in ipairs(GameConfig.AutoClickers) do
		order += 1
		createShopEntry(auto, "auto", order)
	end
end

local function refreshShop()
	for id, entry in pairs(shopEntries) do
		local levels = if entry.Kind == "upgrade" then currentData.UpgradeLevels else currentData.AutoClickerLevels
		local level = levels[id] or 0
		local cost = GameConfig.GetCost(entry.Item, level)

		entry.LevelLabel.Text = "Level " .. level
		entry.BuyButton.Text = formatNumber(cost)
		entry.BuyButton.BackgroundColor3 = if currentData.Coins >= cost
			then Color3.fromRGB(60, 170, 100)
			else Color3.fromRGB(120, 60, 60)
	end
end

local function refreshUI()
	coinLabel.Text = formatNumber(currentData.Coins) .. " Coins"
	powerLabel.Text = "+" .. formatNumber(currentData.ClickPower) .. " per click"

	local requirement = GameConfig.GetRebirthRequirement(currentData.RebirthCount)
	rebirthButton.Text = ("Rebirth (%d)\n%s coins"):format(currentData.RebirthCount, formatNumber(requirement))
	rebirthButton.BackgroundColor3 = if currentData.Coins >= requirement
		then Color3.fromRGB(160, 60, 220)
		else Color3.fromRGB(90, 50, 110)

	refreshShop()
end

-- ===== Interactions =====

clickButton.MouseButton1Click:Connect(function()
	ClickRemote:FireServer()

	local shrink = TweenService:Create(
		clickButton,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 240, 0, 240) }
	)
	shrink:Play()
	shrink.Completed:Connect(function()
		TweenService:Create(
			clickButton,
			TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 260, 0, 260) }
		):Play()
	end)
end)

rebirthButton.MouseButton1Click:Connect(function()
	RebirthRemote:FireServer()
end)

DataUpdatedRemote.OnClientEvent:Connect(function(data)
	currentData = data
	refreshUI()
end)

refreshUI()
