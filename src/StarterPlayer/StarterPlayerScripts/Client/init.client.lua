-- Client bootstrap for the Clicking Simulator.
-- Builds the HUD/shop/eggs/pets UI entirely in code and talks to the server via RemoteEvents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PetModelFactory = require(ReplicatedStorage.Modules.PetModelFactory)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClickRemote = Remotes:WaitForChild("Click")
local PurchaseUpgradeRemote = Remotes:WaitForChild("PurchaseUpgrade")
local PurchaseAutoClickerRemote = Remotes:WaitForChild("PurchaseAutoClicker")
local AscendRemote = Remotes:WaitForChild("Ascend")
local UnlockSkillRemote = Remotes:WaitForChild("UnlockSkill")
local DataUpdatedRemote = Remotes:WaitForChild("DataUpdated")
local HatchEggRemote = Remotes:WaitForChild("HatchEgg")
local EquipPetRemote = Remotes:WaitForChild("EquipPet")
local UnequipPetRemote = Remotes:WaitForChild("UnequipPet")
local FusePetsRemote = Remotes:WaitForChild("FusePets")
local EggResultRemote = Remotes:WaitForChild("EggResult")
local EggLockedRemote = Remotes:WaitForChild("EggLocked")
local ZoneLockedRemote = Remotes:WaitForChild("ZoneLocked")
local PickStarterPetRemote = Remotes:WaitForChild("PickStarterPet")
local comboWindow = GameConfig.Combo.BaseWindow -- cached on each data update (upgrades + gear + pet abilities)

local currentData = {
	Power = 0, -- click currency (upgrades, Ascension)
	Coins = 0, -- egg currency (bosses, quests, selling Power)
	Tokens = 0,
	Essence = 0,
	Boosts = {},
	ClickPower = GameConfig.StartingClickPower,
	UpgradeLevels = {},
	AutoClickerLevels = {},
	RebirthCount = 0, -- shown as Ascensions
	Gems = 0,
	Skills = {},
	Gear = { Items = {}, Equipped = {} },
	Pets = {},
	EquippedPetUids = {},
	HasPickedStarterPet = true, -- assume true until the server says otherwise, so the modal doesn't flash on load
}

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

local function formatMultiplier(m)
	return string.format("x%.2f", m)
end

local function getEquippedPets(data)
	local equippedSet = {}
	for _, uid in ipairs(data.EquippedPetUids) do
		equippedSet[uid] = true
	end
	local equipped = {}
	for _, pet in ipairs(data.Pets) do
		if equippedSet[pet.Uid] then
			table.insert(equipped, pet)
		end
	end
	return equipped
end

local function getClickPower(data)
	return GameConfig.GetClickPower(data, getEquippedPets(data))
end

-- Builds a small 3D preview of a pet model inside a ViewportFrame.
local function createPetViewport(petData)
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.BackgroundTransparency = 1
	viewportFrame.Ambient = Color3.fromRGB(150, 150, 150)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightDirection = Vector3.new(-0.5, -1, -0.5)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewportFrame

	local model = PetModelFactory.Create(petData, { WithEffects = false })
	model.Parent = worldModel

	-- Pets face -Z, so frame them from the front (a little to the side and above), at a distance
	-- that fits the model in view.
	local center, size = model:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) * 1.3 + 0.4
	local camera = Instance.new("Camera")
	camera.FieldOfView = 50
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(distance * 0.35, distance * 0.25, -distance), center.Position)
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	return viewportFrame, model
end

-- ===== UI construction =====

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClickerSimulatorGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Clean mobile style: a thin, soft outline and a subtle top-to-bottom gradient.
local CARD_GRADIENT = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(222,236,242))
local HOVER_GRADIENT = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
local PRESS_GRADIENT = ColorSequence.new(Color3.fromRGB(215,215,215), Color3.fromRGB(185,196,202))
local function styleCard(object, color)
 object.BackgroundColor3 = color
 object.BorderSizePixel = 0
 local stroke = Instance.new("UIStroke")
 stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 stroke.Color = Color3.fromRGB(30, 54, 65)
 stroke.Transparency = 0.55
 stroke.Thickness = 1.5
 stroke.Parent = object
 local gradient = Instance.new("UIGradient")
 gradient.Color = CARD_GRADIENT
 gradient.Rotation = 90
 gradient.Parent = object
 return gradient
end
-- Buttons: one soft text outline, and hover/press feedback by brightening/darkening the gradient
-- (not by scaling; some HUD buttons already carry a UIScale for small screens).
local function styleButton(button)
 local gradient = styleCard(button, button.BackgroundColor3)
 button.Font = Enum.Font.FredokaOne
 button.AutoButtonColor = false
 local textOutline=Instance.new("UIStroke") textOutline.Color=Color3.fromRGB(26,43,51)
 textOutline.Thickness=1.2 textOutline.Transparency=0.25 textOutline.Parent=button
 button.TextStrokeTransparency = 1
 local pad = Instance.new("UIPadding")
 pad.PaddingLeft = UDim.new(0,8) pad.PaddingRight = UDim.new(0,8)
 pad.PaddingTop = UDim.new(0,6) pad.PaddingBottom = UDim.new(0,6) pad.Parent = button
 local limit = Instance.new("UITextSizeConstraint") limit.MaxTextSize=25 limit.Parent=button
 local hovered = false
 button.MouseEnter:Connect(function() hovered = true gradient.Color = HOVER_GRADIENT end)
 button.MouseLeave:Connect(function() hovered = false gradient.Color = CARD_GRADIENT end)
 button.MouseButton1Down:Connect(function() gradient.Color = PRESS_GRADIENT end)
 button.MouseButton1Up:Connect(function() gradient.Color = if hovered then HOVER_GRADIENT else CARD_GRADIENT end)
end

-- Coin counter
local coinFrame = Instance.new("Frame")
coinFrame.Name = "CoinFrame"
coinFrame.AnchorPoint = Vector2.new(0.5, 0)
coinFrame.Position = UDim2.new(0.5, 0, 0, 12)
coinFrame.Size = UDim2.new(0, 260, 0, 56)
coinFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
coinFrame.BorderSizePixel = 0
coinFrame.Parent = screenGui
styleCard(coinFrame, Color3.fromRGB(245, 253, 255))

Instance.new("UICorner", coinFrame).CornerRadius = UDim.new(0, 12)

local coinLabel = Instance.new("TextLabel")
coinLabel.Name = "CoinLabel"
coinLabel.BackgroundTransparency = 1
coinLabel.Size = UDim2.new(1, 0, 1, 0)
coinLabel.Font = Enum.Font.FredokaOne
coinLabel.TextStrokeTransparency = 0
coinLabel.TextStrokeColor3 = Color3.fromRGB(35,70,105)
coinLabel.TextScaled = true
coinLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
coinLabel.Parent = coinFrame
local powerCounter = require(script.Counter).new(coinLabel, function(v) return "⚡ " .. formatNumber(v) end)

-- Click power label (clicking is now a full-screen tap, not a dedicated button)
local powerLabel = Instance.new("TextLabel")
powerLabel.Name = "PowerLabel"
powerLabel.AnchorPoint = Vector2.new(0.5, 0)
powerLabel.Position = UDim2.new(0.5, 0, 0.02, 66)
powerLabel.Size = UDim2.new(0, 280, 0, 26)
powerLabel.BackgroundTransparency = 1
powerLabel.Font = Enum.Font.FredokaOne
powerLabel.TextScaled = true
powerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
powerLabel.TextStrokeTransparency = 0.5
powerLabel.Text = "+1 per click"
powerLabel.Parent = screenGui

-- Ascend button (opens the Ascend panel)
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.AnchorPoint = Vector2.new(0, 0.5)
rebirthButton.Position = UDim2.new(0, 16, 0.5, 130)
rebirthButton.Size = UDim2.new(0, 132, 0, 66)
rebirthButton.BackgroundColor3 = Color3.fromRGB(140, 50, 200)
rebirthButton.Font = Enum.Font.FredokaOne
rebirthButton.TextScaled = true
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthButton.Text = "Ascend (0)"
rebirthButton.Parent = screenGui

Instance.new("UICorner", rebirthButton).CornerRadius = UDim.new(0, 12)

-- Bottom tab bar (Shop / Eggs / Pets)
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.AnchorPoint = Vector2.new(0, 0.5)
tabBar.Position = UDim2.new(0, 16, 0.5, -20)
tabBar.Size = UDim2.new(0, 132, 0, 352)
tabBar.BackgroundTransparency = 1
tabBar.Parent = screenGui

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Vertical
tabLayout.Padding = UDim.new(0, 8)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = tabBar

local function createTabButton(name, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 64)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.Parent = tabBar
 styleButton(button)
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
	return button
end

local shopToggle = createTabButton("ShopToggle", "UPGRADES", Color3.fromRGB(92, 222, 142))
local eggsToggle = createTabButton("EggsToggle", "EGGS", Color3.fromRGB(0, 202, 237))
local petsToggle = createTabButton("PetsToggle", "PETS", Color3.fromRGB(209, 119, 245))

-- Generic panel factory used by Shop / Eggs / Pets
local function createPanel(name, title)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 35, 0.5, 10)
	frame.Size = UDim2.new(0, 570, 0, 440)
 frame.ZIndex=3
	styleCard(frame, Color3.fromRGB(252, 254, 255))
	frame.Visible = false
	frame.Parent = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 0
 titleLabel.BackgroundColor3 = Color3.fromRGB(0, 196, 237)
 titleLabel.TextStrokeColor3 = Color3.fromRGB(25,48,60)
 titleLabel.TextStrokeTransparency = 0.4
 local headingStroke=Instance.new("UIStroke",titleLabel) headingStroke.Thickness=1.5 headingStroke.Transparency=0.4 headingStroke.Color=Color3.fromRGB(29,50,60)
 local headingGradient=Instance.new("UIGradient",titleLabel) headingGradient.Rotation=90
 headingGradient.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(200,222,232))
 local titleCorner=Instance.new("UICorner",titleLabel) titleCorner.CornerRadius=UDim.new(0,12)
	titleLabel.Size = UDim2.new(1, 0, 0, 54)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Text = title
	titleLabel.Parent = frame
 local close = Instance.new("TextButton")
 close.Name="Close" close.Size=UDim2.fromOffset(38,34) close.Position=UDim2.new(1,-44,0,5)
 close.BackgroundColor3=Color3.fromRGB(246,88,111) close.Text="X" close.TextColor3=Color3.new(1,1,1) close.TextScaled=true
 close.Parent=frame Instance.new("UICorner",close).CornerRadius=UDim.new(0,9) styleButton(close)
 close.Activated:Connect(function() frame.Visible=false end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Position = UDim2.new(0, 0, 0, 58)
	scroll.Size = UDim2.new(1, 0, 1, -58)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = scroll

	return frame, scroll
end

local shopFrame, shopScroll = createPanel("ShopFrame", "Upgrades")
local eggsFrame, eggsScroll = createPanel("EggsFrame", "Hatch Eggs")
local petsFrame, petsScroll = createPanel("PetsFrame", "Pets")

local panels = { shopFrame, eggsFrame, petsFrame }

-- ViewportFrames built before their panel is first shown (e.g. pet icons made on join) can render
-- black; re-attaching the WorldModel when the panel opens makes Roblox draw them.
local function refreshViewports(root)
	for _, viewport in ipairs(root:GetDescendants()) do
		if viewport:IsA("ViewportFrame") then
			local world = viewport:FindFirstChildOfClass("WorldModel")
			if world then
				world.Parent = nil
				world.Parent = viewport
			end
		end
	end
end
local function refreshViewportsOnOpen(panel)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			task.defer(refreshViewports, panel)
		end
	end)
end
refreshViewportsOnOpen(petsFrame)

-- Toggling a tab shows its panel and hides the others; clicking the active tab again hides it.
local function bindTab(button, panel)
	button.MouseButton1Click:Connect(function()
		local wasVisible = panel.Visible
		for _, p in ipairs(panels) do
			p.Visible = false
		end
		panel.Visible = not wasVisible
	end)
end

bindTab(shopToggle, shopFrame)
bindTab(eggsToggle, eggsFrame)
bindTab(petsToggle, petsFrame)

-- Ascend panel, Skill Tree panel (+ SKILLS tab) and the HUD gem counter.
local ascensionUI = require(script.AscensionUI).Build({
	screenGui = screenGui,
	coinFrame = coinFrame,
	createPanel = createPanel,
	createTabButton = createTabButton,
	bindTab = bindTab,
	panels = panels,
	styleButton = styleButton,
	formatNumber = formatNumber,
	ascendRemote = AscendRemote,
	unlockSkillRemote = UnlockSkillRemote,
})
Remotes:WaitForChild("OpenPanel").OnClientEvent:Connect(function(name)
	ascensionUI.Open(name)
end)

-- GEAR tab: equipped slots and the gear bag (gear drops from bosses).
local gearUI = require(script.GearUI).Build({
	createPanel = createPanel,
	createTabButton = createTabButton,
	bindTab = bindTab,
	panels = panels,
	styleButton = styleButton,
	equipRemote = Remotes:WaitForChild("EquipGear"),
	unequipRemote = Remotes:WaitForChild("UnequipGear"),
	formatNumber = formatNumber,
	upgradeRemote = Remotes:WaitForChild("UpgradeGear"),
	salvageRemote = Remotes:WaitForChild("SalvageGear"),
})

-- ===== Shop (upgrades + auto-clickers) =====

local shopEntries = {}
local buyAmount = 1 -- 1, 10 or "max"; shared by every shop entry

-- x1 / x10 / MAX selector at the top of the shop.
local amountBar = Instance.new("Frame")
amountBar.Name = "BuyAmount"
amountBar.Size = UDim2.new(1, 0, 0, 40)
amountBar.BackgroundTransparency = 1
amountBar.LayoutOrder = -1
amountBar.Parent = shopScroll
local amountLayout = Instance.new("UIListLayout", amountBar)
amountLayout.FillDirection = Enum.FillDirection.Horizontal
amountLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
amountLayout.Padding = UDim.new(0, 10)
local amountButtons = {}
local refreshShop -- defined below; the selector refreshes the shop
for _, option in ipairs({ { 1, "x1" }, { 10, "x10" }, { "max", "MAX" } }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(96, 36)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = option[2]
	b.Parent = amountBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	styleButton(b)
	amountButtons[option[1]] = b
	b.MouseButton1Click:Connect(function()
		buyAmount = option[1]
		refreshShop()
	end)
end

local function createShopEntry(item, kind, layoutOrder)
	local frame = Instance.new("Frame")
	frame.Name = item.Id
	frame.Size = UDim2.new(1, 0, 0, 80)
	frame.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
	frame.LayoutOrder = layoutOrder
	frame.Parent = shopScroll

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.Size = UDim2.new(1, -110, 0, 22)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(37, 65, 78)
	nameLabel.Text = item.Name
	nameLabel.Parent = frame

	local descLabel = Instance.new("TextLabel")
	descLabel.BackgroundTransparency = 1
	descLabel.Position = UDim2.new(0, 10, 0, 27)
	descLabel.Size = UDim2.new(1, -110, 0, 18)
	descLabel.Font = Enum.Font.FredokaOne
	descLabel.TextScaled = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextColor3 = Color3.fromRGB(58, 90, 105)
	descLabel.Text = item.Description or ""
	descLabel.Parent = frame

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.BackgroundTransparency = 1
	levelLabel.Position = UDim2.new(0, 10, 0, 46)
	levelLabel.Size = UDim2.new(1, -110, 0, 16)
	levelLabel.Font = Enum.Font.FredokaOne
	levelLabel.TextScaled = true
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.TextColor3 = Color3.fromRGB(77, 116, 130)
	levelLabel.Text = "Level 0"
	levelLabel.Parent = frame

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.Position = UDim2.new(1, -10, 0.5, 0)
	buyButton.Size = UDim2.new(0, 96, 0, 48)
	buyButton.BackgroundColor3 = Color3.fromRGB(88, 219, 132)
	buyButton.Font = Enum.Font.FredokaOne
	buyButton.TextScaled = true
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.Text = "Buy"
	buyButton.Parent = frame
 styleButton(buyButton)

	Instance.new("UICorner", buyButton).CornerRadius = UDim.new(0, 8)

	buyButton.MouseButton1Click:Connect(function()
		if kind == "auto" then
			PurchaseAutoClickerRemote:FireServer(item.Id, buyAmount)
		else
			PurchaseUpgradeRemote:FireServer(item.Id, buyAmount)
		end
	end)

	shopEntries[item.Id] = {
		Item = item,
		Kind = kind,
		LevelLabel = levelLabel,
		DescLabel = descLabel,
		BuyButton = buyButton,
	}
end

do
	local order = 0
	for _, upgrade in ipairs(GameConfig.Upgrades) do
		order += 1
		createShopEntry(upgrade, "upgrade", order)
	end
	for _, boost in ipairs(GameConfig.ClickBoosts) do
		order += 1
		createShopEntry(boost, "boost", order)
	end
	for _, auto in ipairs(GameConfig.AutoClickers) do
		order += 1
		createShopEntry(auto, "auto", order)
	end
end

function refreshShop()
	for amount, b in pairs(amountButtons) do
		b.BackgroundColor3 = if amount == buyAmount then Color3.fromRGB(0, 196, 237) else Color3.fromRGB(152, 174, 184)
	end
	for id, entry in pairs(shopEntries) do
		local levels = if entry.Kind == "auto" then currentData.AutoClickerLevels else currentData.UpgradeLevels
		local level = levels[id] or 0
		local cap = math.max(0, (entry.Item.MaxLevel or GameConfig.MaxUpgradeLevel) - level)
		local count, cost
		if buyAmount == "max" then
			count, cost = GameConfig.GetMaxAffordable(entry.Item, level, currentData.Power, cap)
			if count == 0 then
				count, cost = math.min(1, cap), GameConfig.GetCost(entry.Item, level) -- show the next level's price
			end
		else
			count = math.min(buyAmount, cap)
			cost = GameConfig.GetBulkCost(entry.Item, level, count)
		end

		entry.LevelLabel.Text = "Level " .. level
		if entry.Kind == "boost" then
			entry.DescLabel.Text = GameConfig.DescribeBoost(entry.Item, level)
		end
		if cap == 0 then
			entry.BuyButton.Text = "MAX"
			entry.BuyButton.BackgroundColor3 = Color3.fromRGB(152, 174, 184)
		else
			entry.BuyButton.Text = (if count > 1 then "x" .. count .. " " else "") .. formatNumber(cost) .. " ⚡"
			entry.BuyButton.BackgroundColor3 = if currentData.Power >= cost
				then Color3.fromRGB(88, 219, 132)
				else Color3.fromRGB(152, 174, 184)
		end
	end
end

-- ===== Eggs =====

local eggEntries = {}

local function createEggEntry(egg, layoutOrder)
	local frame = Instance.new("Frame")
	frame.Name = egg.Id
	frame.Size = UDim2.new(1, 0, 0, 104)
	frame.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
	frame.LayoutOrder = layoutOrder
	frame.Parent = eggsScroll

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 10, 0, 6)
	nameLabel.Size = UDim2.new(1, -110, 0, 22)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(37, 65, 78)
	nameLabel.Text = egg.Name
	nameLabel.Parent = frame

	local oddsText = {}
	for _, pet in ipairs(egg.Pets) do
		local star = if GameConfig.PetAbilities[pet.Name] then " ★" else "" -- ★ = has an ability
		table.insert(oddsText, pet.Name .. " (" .. pet.Rarity .. star .. ")")
	end

	local oddsLabel = Instance.new("TextLabel")
	oddsLabel.BackgroundTransparency = 1
	oddsLabel.Position = UDim2.new(0, 10, 0, 28)
	oddsLabel.Size = UDim2.new(1, -120, 0, 48)
	oddsLabel.Font = Enum.Font.FredokaOne
	oddsLabel.TextScaled = false
	oddsLabel.TextSize = 12
	oddsLabel.TextWrapped = true
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
	oddsLabel.TextYAlignment = Enum.TextYAlignment.Top
	oddsLabel.TextColor3 = Color3.fromRGB(58, 90, 105)
	oddsLabel.Text = table.concat(oddsText, ", ")
	oddsLabel.Parent = frame

	local hatchButton = Instance.new("TextButton")
	hatchButton.Name = "HatchButton"
	hatchButton.AnchorPoint = Vector2.new(1, 0.5)
	hatchButton.Position = UDim2.new(1, -10, 0.5, 0)
	hatchButton.Size = UDim2.new(0, 96, 0, 48)
	hatchButton.BackgroundColor3 = Color3.fromRGB(0, 202, 237)
	hatchButton.Font = Enum.Font.FredokaOne
	hatchButton.TextScaled = true
	hatchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	hatchButton.Text = "Hatch"
	hatchButton.Parent = frame
 styleButton(hatchButton)

	Instance.new("UICorner", hatchButton).CornerRadius = UDim.new(0, 8)

	hatchButton.MouseButton1Click:Connect(function()
		HatchEggRemote:FireServer(egg.Id)
	end)

	-- Triple Hatch pass owners get an x3 button.
	local tripleButton = Instance.new("TextButton")
	tripleButton.Name = "TripleButton"
	tripleButton.AnchorPoint = Vector2.new(1, 0.5)
	tripleButton.Position = UDim2.new(1, -112, 0.5, 0)
	tripleButton.Size = UDim2.new(0, 64, 0, 48)
	tripleButton.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
	tripleButton.Font = Enum.Font.FredokaOne
	tripleButton.TextScaled = true
	tripleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	tripleButton.Text = "x3"
	tripleButton.Visible = false
	tripleButton.Parent = frame
	styleButton(tripleButton)
	Instance.new("UICorner", tripleButton).CornerRadius = UDim.new(0, 8)
	tripleButton.MouseButton1Click:Connect(function()
		HatchEggRemote:FireServer(egg.Id, 3)
	end)

	eggEntries[egg.Id] = { Egg = egg, Frame = frame, HatchButton = hatchButton, TripleButton = tripleButton }
end

do
	local order = 0
	for _, egg in ipairs(GameConfig.Eggs) do
		order += 1
		createEggEntry(egg, order)
	end
end

local function refreshEggs()
	for _, entry in pairs(eggEntries) do
		local egg = entry.Egg
		local locked = currentData.RebirthCount < egg.RequiredRebirths
		entry.TripleButton.Visible = not locked and GameConfig.HasPass(currentData, "TripleHatch")
		if locked then
			entry.HatchButton.Text = "Locked"
			entry.HatchButton.BackgroundColor3 = Color3.fromRGB(140, 159, 171)
		else
			entry.HatchButton.Text = "💰 " .. formatNumber(egg.Cost)
			entry.HatchButton.BackgroundColor3 = if currentData.Coins >= egg.Cost
				then Color3.fromRGB(0, 202, 237)
				else Color3.fromRGB(152, 174, 184)
		end
	end
end

-- ===== Pets inventory =====

local petGroupFrames = {}
local emptyPets=Instance.new("TextLabel")
emptyPets.Name="EmptyInventory" emptyPets.Size=UDim2.new(1,0,0,100)
emptyPets.BackgroundTransparency=1 emptyPets.TextColor3=Color3.fromRGB(44,76,89)
emptyPets.TextWrapped=true emptyPets.TextSize=22 emptyPets.Font=Enum.Font.FredokaOne
emptyPets.Text="Your pet adventure starts here!\nHatch your first egg for "..GameConfig.Eggs[1].Cost.." Coins."
emptyPets.Parent=petsScroll

local function petGroupKey(name, rarity, golden)
	return name .. "|" .. rarity .. "|" .. tostring(golden)
end

local function getOrCreatePetGroupFrame(key, layoutOrder)
	local existing = petGroupFrames[key]
	if existing then
		return existing
	end

	local frame = Instance.new("Frame")
	frame.Name = "PetGroup"
	frame.Size = UDim2.new(1, 0, 0, 104)
	frame.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
	frame.LayoutOrder = layoutOrder
	frame.Parent = petsScroll

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Position = UDim2.new(0, 8, 0, 8)
	iconContainer.Size = UDim2.new(0, 74, 0, 74)
	iconContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	iconContainer.Parent = frame
	Instance.new("UICorner", iconContainer).CornerRadius = UDim.new(0, 8)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 92, 0, 6)
	nameLabel.Size = UDim2.new(1, -242, 0, 22)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.BackgroundTransparency = 1
	infoLabel.Position = UDim2.new(0, 92, 0, 28)
	infoLabel.Size = UDim2.new(1, -242, 0, 18)
	infoLabel.Font = Enum.Font.FredokaOne
	infoLabel.TextScaled = true
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextColor3 = Color3.fromRGB(58, 90, 105)
	infoLabel.Parent = frame

	local equippedLabel = Instance.new("TextLabel")
	equippedLabel.Name = "EquippedLabel"
	equippedLabel.BackgroundTransparency = 1
	equippedLabel.Position = UDim2.new(0, 92, 0, 48)
	equippedLabel.Size = UDim2.new(1, -242, 0, 16)
	equippedLabel.Font = Enum.Font.FredokaOne
	equippedLabel.TextScaled = true
	equippedLabel.TextXAlignment = Enum.TextXAlignment.Left
	equippedLabel.TextColor3 = Color3.fromRGB(77, 116, 130)
	equippedLabel.Parent = frame

	local equipButton = Instance.new("TextButton")
	equipButton.Name = "EquipButton"
	equipButton.AnchorPoint = Vector2.new(1, 0)
	equipButton.Position = UDim2.new(1, -10, 0, 6)
	equipButton.Size = UDim2.new(0, 130, 0, 40)
	equipButton.BackgroundColor3 = Color3.fromRGB(88, 219, 132)
	equipButton.Font = Enum.Font.FredokaOne
	equipButton.TextScaled = true
	equipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	equipButton.Text = "Equip"
	equipButton.Parent = frame
 styleButton(equipButton)

	Instance.new("UICorner", equipButton).CornerRadius = UDim.new(0, 8)

	local fuseButton = Instance.new("TextButton")
	fuseButton.Name = "FuseButton"
	fuseButton.AnchorPoint = Vector2.new(1, 0)
	fuseButton.Position = UDim2.new(1, -10, 0, 48)
	fuseButton.Size = UDim2.new(0, 130, 0, 40)
	fuseButton.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
	fuseButton.Font = Enum.Font.FredokaOne
	fuseButton.TextScaled = true
	fuseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	fuseButton.Text = "Fuse x5"
	fuseButton.Visible = false
	fuseButton.Parent = frame
 styleButton(fuseButton)

	Instance.new("UICorner", fuseButton).CornerRadius = UDim.new(0, 8)

	local abilityLabel = Instance.new("TextLabel")
	abilityLabel.Name = "AbilityLabel"
	abilityLabel.BackgroundTransparency = 1
	abilityLabel.Position = UDim2.new(0, 92, 0, 66)
	abilityLabel.Size = UDim2.new(1, -242, 0, 32)
	abilityLabel.Font = Enum.Font.FredokaOne
	abilityLabel.TextSize = 13
	abilityLabel.TextWrapped = true
	abilityLabel.TextXAlignment = Enum.TextXAlignment.Left
	abilityLabel.TextYAlignment = Enum.TextYAlignment.Top
	abilityLabel.TextColor3 = Color3.fromRGB(150, 80, 220)
	abilityLabel.Parent = frame

	local group = {
		Frame = frame,
		IconContainer = iconContainer,
		IconBuilt = false,
		NameLabel = nameLabel,
		InfoLabel = infoLabel,
		EquippedLabel = equippedLabel,
		AbilityLabel = abilityLabel,
		EquipButton = equipButton,
		FuseButton = fuseButton,
		EquipConnection = nil,
		FuseConnection = nil,
	}
	petGroupFrames[key] = group
	return group
end

local function refreshPets()
 emptyPets.Visible = #currentData.Pets == 0
	local groups = {}
	local order = {}

	for _, pet in ipairs(currentData.Pets) do
		local key = petGroupKey(pet.Name, pet.Rarity, pet.Golden)
		if not groups[key] then
			groups[key] = { Pet = pet, Count = 0, EquippedCount = 0 }
			table.insert(order, key)
		end
		groups[key].Count += 1
	end

	local equippedSet = {}
	for _, uid in ipairs(currentData.EquippedPetUids) do
		equippedSet[uid] = true
	end
	for _, pet in ipairs(currentData.Pets) do
		if equippedSet[pet.Uid] then
			local key = petGroupKey(pet.Name, pet.Rarity, pet.Golden)
			groups[key].EquippedCount += 1
		end
	end

	-- Hide any stale group frames from a previous state, then rebuild visible ones.
	for _, existing in pairs(petGroupFrames) do
		existing.Frame.Visible = false
	end

	local layoutOrder = 0
	for _, key in ipairs(order) do
		layoutOrder += 1
		local info = groups[key]
		local pet = info.Pet
		local group = getOrCreatePetGroupFrame(key, layoutOrder)
		group.Frame.Visible = true
		group.Frame.LayoutOrder = layoutOrder

		if not group.IconBuilt then
			local viewport = createPetViewport(pet)
			viewport.Size = UDim2.new(1, 0, 1, 0)
			viewport.Parent = group.IconContainer
			group.IconBuilt = true
		end

		local displayName = if pet.Golden then "Golden " .. pet.Name else pet.Name
		local color = GameConfig.RarityColors[pet.Rarity] or Color3.fromRGB(255, 255, 255)

		group.NameLabel.Text = displayName
		group.NameLabel.TextColor3 = color:Lerp(Color3.fromRGB(29,49,67),0.35)
		group.InfoLabel.Text = pet.Rarity .. " - " .. formatMultiplier(pet.Multiplier) .. " - Owned " .. info.Count
		group.EquippedLabel.Text = "Equipped: " .. info.EquippedCount
		local ability = GameConfig.DescribePetAbility(pet.Name, pet.Golden)
		group.AbilityLabel.Text = if ability then "★ " .. ability else ""

		local maxEquipped = GameConfig.GetMaxEquippedPets(currentData.RebirthCount, currentData.Skills, currentData.Passes)
		if info.EquippedCount > 0 then
			group.EquipButton.Text = "Unequip"
			group.EquipButton.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
		else
			group.EquipButton.Text = "Equip"
			local canEquip = #currentData.EquippedPetUids < maxEquipped
			group.EquipButton.BackgroundColor3 = if canEquip
				then Color3.fromRGB(88, 219, 132)
				else Color3.fromRGB(90, 90, 100)
		end

		if group.EquipConnection then
			group.EquipConnection:Disconnect()
		end
		group.EquipConnection = group.EquipButton.MouseButton1Click:Connect(function()
			if info.EquippedCount > 0 then
				UnequipPetRemote:FireServer(pet.Name, pet.Rarity, pet.Golden)
			else
				EquipPetRemote:FireServer(pet.Name, pet.Rarity, pet.Golden)
			end
		end)

		if group.FuseConnection then
			group.FuseConnection:Disconnect()
			group.FuseConnection = nil
		end
		if not pet.Golden and info.Count >= GameConfig.FusionRequirement then
			group.FuseButton.Visible = true
			group.FuseConnection = group.FuseButton.MouseButton1Click:Connect(function()
				FusePetsRemote:FireServer(pet.Name, pet.Rarity)
			end)
		else
			group.FuseButton.Visible = false
		end
	end
end

-- ===== Egg hatch reveal popup =====

local revealFrame = Instance.new("Frame")
revealFrame.Name = "RevealFrame"
revealFrame.AnchorPoint = Vector2.new(0.5, 0.5)
revealFrame.Position = UDim2.new(0.5, 0, 0.3, 0)
revealFrame.Size = UDim2.new(0, 0, 0, 0)
revealFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
revealFrame.BackgroundTransparency = 1
revealFrame.ClipsDescendants = true
revealFrame.ZIndex = 8
revealFrame.Parent = screenGui

Instance.new("UICorner", revealFrame).CornerRadius = UDim.new(0, 14)

local revealStroke = Instance.new("UIStroke")
revealStroke.Thickness = 3
revealStroke.Transparency = 1
revealStroke.Parent = revealFrame

local revealViewport = Instance.new("ViewportFrame")
revealViewport.Name = "RevealViewport"
revealViewport.BackgroundTransparency = 1
revealViewport.Position = UDim2.new(0.5, 0, 0, 10)
revealViewport.AnchorPoint = Vector2.new(0.5, 0)
revealViewport.Size = UDim2.new(0, 120, 0, 120)
revealViewport.Ambient = Color3.fromRGB(150, 150, 150)
revealViewport.LightColor = Color3.fromRGB(255, 255, 255)
revealViewport.Parent = revealFrame

local revealWorldModel = Instance.new("WorldModel")
revealWorldModel.Parent = revealViewport

local revealCamera = Instance.new("Camera")
revealCamera.CFrame = CFrame.new(Vector3.new(0, 1.2, 5.2), Vector3.new(0, 0.7, 0)) -- fits the cube pets as they spin
revealCamera.Parent = revealViewport
revealViewport.CurrentCamera = revealCamera

local revealLabel = Instance.new("TextLabel")
revealLabel.AnchorPoint = Vector2.new(0.5, 0)
revealLabel.Position = UDim2.new(0.5, 0, 0, 134)
revealLabel.Size = UDim2.new(1, -20, 0, 56)
revealLabel.BackgroundTransparency = 1
revealLabel.Font = Enum.Font.FredokaOne
revealLabel.TextScaled = true
revealLabel.TextTransparency = 1
revealLabel.Text = ""
revealLabel.Parent = revealFrame

local revealToken = 0
local revealRotationConnection = nil

local function showPetReveal(pet)
	revealToken += 1
	local myToken = revealToken

	local color = GameConfig.RarityColors[pet.Rarity] or Color3.fromRGB(255, 255, 255)
	local displayName = if pet.Golden then "Golden " .. pet.Name else pet.Name

	revealWorldModel:ClearAllChildren()
	local model = PetModelFactory.Create(pet, { WithEffects = false })
	model.Parent = revealWorldModel
	local modelPivot = model:GetPivot()

	if revealRotationConnection then
		revealRotationConnection:Disconnect()
		revealRotationConnection = nil
	end
	revealRotationConnection = RunService.RenderStepped:Connect(function(dt)
		modelPivot = modelPivot * CFrame.Angles(0, dt * 2, 0)
		model:PivotTo(modelPivot)
	end)

	revealFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	revealStroke.Color = color
	revealLabel.TextColor3 = color
	local ability = GameConfig.PetAbilities[pet.Name]
	revealLabel.Text = string.format("%s\n%s  %s", displayName, pet.Rarity, formatMultiplier(pet.Multiplier))
		.. (if ability then "  ★ " .. ability.Name else "")

	TweenService:Create(
		revealFrame,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 260, 0, 200), BackgroundTransparency = 0.1 }
	):Play()
	TweenService:Create(revealStroke, TweenInfo.new(0.2), { Transparency = 0 }):Play()
	TweenService:Create(revealLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()

	task.delay(2.5, function()
		if myToken ~= revealToken then
			return
		end
		if revealRotationConnection then
			revealRotationConnection:Disconnect()
			revealRotationConnection = nil
		end
		TweenService:Create(
			revealFrame,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 }
		):Play()
		TweenService:Create(revealStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		TweenService:Create(revealLabel, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	end)
end

-- ===== Starter pet selection (first-join onboarding) =====

local starterPetFrame = Instance.new("Frame")
starterPetFrame.Name = "StarterPetFrame"
starterPetFrame.AnchorPoint = Vector2.new(0.5, 0.5)
starterPetFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
starterPetFrame.Size = UDim2.new(0, 460, 0, 320)
starterPetFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
starterPetFrame.Visible = false
starterPetFrame.ZIndex = 20 -- above the HUD (CLICK button, goal banner, combo meter) so Pick! stays clickable
starterPetFrame.Parent = screenGui
refreshViewportsOnOpen(starterPetFrame)

Instance.new("UICorner", starterPetFrame).CornerRadius = UDim.new(0, 16)

local starterTitle = Instance.new("TextLabel")
starterTitle.BackgroundTransparency = 1
starterTitle.Size = UDim2.new(1, 0, 0, 46)
starterTitle.Font = Enum.Font.GothamBlack
starterTitle.TextScaled = true
starterTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
starterTitle.Text = "Select a Pet!"
starterTitle.Parent = starterPetFrame

local starterSubtitle = Instance.new("TextLabel")
starterSubtitle.BackgroundTransparency = 1
starterSubtitle.Position = UDim2.new(0, 0, 0, 44)
starterSubtitle.Size = UDim2.new(1, 0, 0, 26)
starterSubtitle.Font = Enum.Font.Gotham
starterSubtitle.TextScaled = true
starterSubtitle.TextColor3 = Color3.fromRGB(190, 190, 200)
starterSubtitle.Text = "Choose a pet to begin with!"
starterSubtitle.Parent = starterPetFrame

local starterCardsHolder = Instance.new("Frame")
starterCardsHolder.BackgroundTransparency = 1
starterCardsHolder.Position = UDim2.new(0, 20, 0, 84)
starterCardsHolder.Size = UDim2.new(1, -40, 0, 160)
starterCardsHolder.Parent = starterPetFrame

local starterLayout = Instance.new("UIListLayout")
starterLayout.FillDirection = Enum.FillDirection.Horizontal
starterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
starterLayout.Padding = UDim.new(0, 12)
starterLayout.Parent = starterCardsHolder

local selectedStarterPet = nil
local starterCardStrokes = {}

local pickButton = Instance.new("TextButton")
pickButton.Name = "PickButton"
pickButton.AnchorPoint = Vector2.new(0.5, 1)
pickButton.Position = UDim2.new(0.5, 0, 1, -20)
pickButton.Size = UDim2.new(0, 160, 0, 46)
pickButton.BackgroundColor3 = Color3.fromRGB(60, 170, 100)
pickButton.Font = Enum.Font.GothamBold
pickButton.TextScaled = true
pickButton.TextColor3 = Color3.fromRGB(255, 255, 255)
pickButton.Text = "Pick!"
pickButton.Parent = starterPetFrame

Instance.new("UICorner", pickButton).CornerRadius = UDim.new(0, 10)

local starterCards = {} -- [name] = { Card, Scale, Check }

-- Highlights the chosen card (gold border, lighter background, pop, check badge) and names the pet
-- on the Pick button; every other card goes back to normal.
local function selectStarterPet(petName)
	selectedStarterPet = petName
	for name, stroke in pairs(starterCardStrokes) do
		local chosen = name == petName
		local card = starterCards[name]
		stroke.Transparency = if chosen then 0 else 1
		card.Card.BackgroundColor3 = if chosen then Color3.fromRGB(62, 58, 40) else Color3.fromRGB(35, 35, 48)
		card.Check.Visible = chosen
		TweenService:Create(card.Scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = if chosen then 1.05 else 1 }):Play()
	end
	pickButton.Text = "Pick " .. petName .. "!"
end

for _, starter in ipairs(GameConfig.StarterPets) do
	local card = Instance.new("TextButton")
	card.Name = starter.Name
	card.Size = UDim2.new(0, 130, 0, 160)
	card.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	card.Text = ""
	card.AutoButtonColor = false
	card.Parent = starterCardsHolder

	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	-- Border mode matters: on a text object a UIStroke outlines the text by default, and these cards
	-- have no text, so the highlight never showed.
	local cardStroke = Instance.new("UIStroke")
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Thickness = 5
	cardStroke.Color = Color3.fromRGB(255, 210, 60)
	cardStroke.Transparency = 1
	cardStroke.Parent = card
	starterCardStrokes[starter.Name] = cardStroke
	local cardScale = Instance.new("UIScale", card)

	local check = Instance.new("TextLabel") -- ✓ badge on the chosen card
	check.Name = "Check"
	check.AnchorPoint = Vector2.new(0.5, 0.5)
	check.Position = UDim2.new(1, -6, 0, 6)
	check.Size = UDim2.fromOffset(30, 30)
	check.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
	check.Font = Enum.Font.GothamBlack
	check.TextScaled = true
	check.TextColor3 = Color3.fromRGB(40, 30, 10)
	check.Text = "✓"
	check.Visible = false
	check.ZIndex = 3
	check.Parent = card
	Instance.new("UICorner", check).CornerRadius = UDim.new(1, 0)
	starterCards[starter.Name] = { Card = card, Scale = cardScale, Check = check }

	local viewport = createPetViewport({ Name = starter.Name, Rarity = starter.Rarity, Golden = false })
	viewport.Size = UDim2.new(1, -16, 0, 110)
	viewport.Position = UDim2.new(0, 8, 0, 8)
	viewport.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 0, 1, -36)
	nameLabel.Size = UDim2.new(1, 0, 0, 36)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Text = starter.Name
	nameLabel.Parent = card

	card.MouseButton1Click:Connect(function()
		selectStarterPet(starter.Name)
	end)
end

selectStarterPet(GameConfig.StarterPets[1].Name)

pickButton.MouseButton1Click:Connect(function()
	if selectedStarterPet then
		PickStarterPetRemote:FireServer(selectedStarterPet)
	end
end)

-- ===== Refresh loop =====

local function refreshUI()
	local totalClickPower = getClickPower(currentData)
	comboWindow = GameConfig.GetComboWindow(currentData.UpgradeLevels, GameConfig.GetBonusStats(currentData, getEquippedPets(currentData)))

	powerCounter:Set(currentData.Power)
	powerLabel.Text = "+" .. formatNumber(totalClickPower) .. " ⚡ per click"

	local requirement = GameConfig.GetRebirthRequirement(currentData.RebirthCount)
	rebirthButton.Text = ("Ascend (%d)\n%s ⚡"):format(currentData.RebirthCount, formatNumber(requirement))
	rebirthButton.BackgroundColor3 = if currentData.Power >= requirement
		then Color3.fromRGB(185, 96, 247)
		else Color3.fromRGB(127, 91, 189)

	refreshShop()
	refreshEggs()
	refreshPets()
	ascensionUI.Refresh(currentData)
	gearUI.Refresh(currentData)
end

-- ===== Interactions =====

-- Click anywhere on screen (not just a dedicated button). gameProcessedEvent
-- is true when the input already hit a GuiButton (Shop/Eggs/Pets/Ascend/etc),
-- so this only fires for clicks/taps on empty space.
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	ClickRemote:FireServer() -- the result (amount, crit, combo) comes back via ClickResult
end)

rebirthButton.MouseButton1Click:Connect(function()
	ascensionUI.Open("Ascend")
end)

DataUpdatedRemote.OnClientEvent:Connect(function(data)
	currentData = data
	starterPetFrame.Visible = not data.HasPickedStarterPet
	refreshUI()
end)

EggResultRemote.OnClientEvent:Connect(function(pet)
	showPetReveal(pet)
end)

-- Simple fading banner for brief status messages (e.g. a locked zone gate).
local toastFrame = Instance.new("Frame")
toastFrame.Name = "ToastFrame"
toastFrame.AnchorPoint = Vector2.new(0.5, 0)
toastFrame.Position = UDim2.new(0.5, 0, 0.14, 0)
toastFrame.Size = UDim2.new(0, 420, 0, 50)
toastFrame.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
toastFrame.BackgroundTransparency = 1
toastFrame.ZIndex = 12
toastFrame.Parent = screenGui

Instance.new("UICorner", toastFrame).CornerRadius = UDim.new(0, 10)

local toastLabel = Instance.new("TextLabel")
toastLabel.BackgroundTransparency = 1
toastLabel.Size = UDim2.new(1, -20, 1, 0)
toastLabel.Position = UDim2.new(0, 10, 0, 0)
toastLabel.Font = Enum.Font.FredokaOne
toastLabel.TextScaled = true
toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
toastLabel.TextTransparency = 1
toastLabel.Text = ""
toastLabel.Parent = toastFrame

local toastToken = 0
local function showToast(text)
	toastToken += 1
	local myToken = toastToken

	toastLabel.Text = text
	TweenService:Create(toastFrame, TweenInfo.new(0.15), { BackgroundTransparency = 0.15 }):Play()
	TweenService:Create(toastLabel, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()

	task.delay(2.2, function()
		if myToken ~= toastToken then
			return
		end
		TweenService:Create(toastFrame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toastLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end)
end

EggLockedRemote.OnClientEvent:Connect(function(eggName, requiredRebirths)
	showToast(("Locked! Need %d Ascension%s to hatch the %s"):format(
		requiredRebirths,
		requiredRebirths == 1 and "" or "s",
		eggName
	))
end)

ZoneLockedRemote.OnClientEvent:Connect(function(zoneName, requiredRebirths)
	showToast(("Locked! Need %d Ascension%s to enter %s"):format(
		requiredRebirths,
		requiredRebirths == 1 and "" or "s",
		zoneName
	))
end)

task.spawn(require(script.ZoneGates).Start)

refreshUI()

-- Responsive HUD: keep the world visible and the same controls on touch screens.
styleButton(rebirthButton)
local tapButton = Instance.new("TextButton")
tapButton.Name="TapButton" tapButton.AnchorPoint=Vector2.new(0.5,1)
tapButton.Position=UDim2.new(0.5,0,1,-18) tapButton.Size=UDim2.fromOffset(236,64)
tapButton.BackgroundColor3=Color3.fromRGB(0,216,243) tapButton.Text="CLICK!"
tapButton.TextColor3=Color3.new(1,1,1) tapButton.TextScaled=true tapButton.Parent=screenGui
Instance.new("UICorner",tapButton).CornerRadius=UDim.new(0,18) styleButton(tapButton)
tapButton.Activated:Connect(function()
 ClickRemote:FireServer()
end)
-- Hold-to-click: after a short delay, keep clicking at HoldClicksPerSecond while held.
local holding,holdToken=false,0
tapButton.MouseButton1Down:Connect(function()
 holding=true holdToken+=1
 local myHold=holdToken -- a quick re-press must not start a second loop
 task.delay(0.35,function()
  while holding and holdToken==myHold do ClickRemote:FireServer() task.wait(1/GameConfig.HoldClicksPerSecond) end
 end)
end)
UserInputService.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then holding=false end
end)
local tip=Instance.new("TextLabel") tip.Name="Tip" tip.BackgroundTransparency=1
 tip.AnchorPoint=Vector2.new(0.5,1) tip.Position=UDim2.new(0.5,0,1,-86)
 tip.Size=UDim2.fromOffset(280,23) tip.Text="TAP  •  HATCH  •  ASCEND" tip.Font=Enum.Font.FredokaOne
 tip.TextSize=16 tip.TextColor3=Color3.new(1,1,1) tip.TextStrokeTransparency=0.3 tip.Parent=screenGui
local panelScales={}
for _,panel in ipairs(panels) do panelScales[panel]=Instance.new("UIScale",panel) end
local hudScales={}
for _,item in ipairs({tabBar,rebirthButton,coinFrame,tapButton}) do hudScales[item]=Instance.new("UIScale",item) end
local function resizeHUD()
 local size=workspace.CurrentCamera.ViewportSize
 local compact=size.X<700 or size.Y<500
 for _,panel in ipairs(panels) do
  panelScales[panel].Scale=1
  panel.Size=UDim2.fromOffset(math.min(570,size.X-24),math.min(500,size.Y-110))
  panel.Position=UDim2.new(0.5,0,0.5,0)
 end
 for item,scale in pairs(hudScales) do scale.Scale=compact and 0.72 or 1 end
 rebirthButton.Position=UDim2.new(0,compact and 8 or 16,0.5,compact and 100 or 130)
 tabBar.Position=UDim2.new(0,compact and 8 or 16,0.5,compact and -65 or -96)
 powerLabel.Position=UDim2.new(0.5,0,0,compact and 55 or 74)
 toastFrame.Size=UDim2.new(0,math.min(420,size.X-24),0,50)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeHUD)
resizeHUD()

-- Retention HUD, codes and audiovisual feedback. Economy remains on the server.
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local soundEnabled=true
local reducedMotion=false
local function playSound(kind)
 if not soundEnabled then return end
 local sound=Instance.new("Sound") sound.SoundId=GameConfig.Sounds[kind] or GameConfig.Sounds.Click
 sound.Volume=kind=="Click" and 0.15 or 0.35 sound.Parent=SoundService
 sound:Play() Debris:AddItem(sound,8)
end
local lastSound=0
require(script.ClickFeel).Start({
 screenGui=screenGui,
 resultRemote=Remotes:WaitForChild("ClickResult"),
 formatNumber=formatNumber,
 getComboWindow=function() return comboWindow end,
 isReducedMotion=function() return reducedMotion end,
})
ClickRemote.OnClientEvent:Connect(function() end)
tapButton.Activated:Connect(function() playSound("Click") end)
UserInputService.InputBegan:Connect(function(input,processed)
 if not processed and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) and os.clock()-lastSound>0.08 then
  lastSound=os.clock() playSound("Click")
 end
end)
local controls=Instance.new("Frame") controls.Name="UtilityControls" controls.BackgroundTransparency=1
controls.AnchorPoint=Vector2.new(1,0) controls.Position=UDim2.new(1,-10,0,10) controls.Size=UDim2.fromOffset(106,154) controls.Parent=screenGui
-- Callers pass y on a 54px grid; buttons are laid out tighter (40px tall, 46px apart) so the full
-- column (up to 7 buttons) fits on short screens.
local function utility(text,y,color)
 local b=Instance.new("TextButton") b.Size=UDim2.fromOffset(106,40) b.Position=UDim2.fromOffset(0,math.floor(y*46/54))
 b.BackgroundColor3=color b.TextColor3=Color3.new(1,1,1) b.Text=text b.TextScaled=true b.Parent=controls
 Instance.new("UICorner",b).CornerRadius=UDim.new(0,10) styleButton(b) return b
end
local codesButton=utility("CODES",0,Color3.fromRGB(43,190,211))
local soundButton=utility("SOUND ON",54,Color3.fromRGB(69,147,173))
local motionButton=utility("FX ON",108,Color3.fromRGB(136,102,190))
soundButton.Activated:Connect(function() soundEnabled=not soundEnabled soundButton.Text=soundEnabled and "SOUND ON" or "SOUND OFF" end)
motionButton.Activated:Connect(function() reducedMotion=not reducedMotion motionButton.Text=reducedMotion and "FX LOW" or "FX ON" end)
local codesFrame,codesScroll=createPanel("CodesFrame","Creator Codes")
table.insert(panels,codesFrame) panelScales[codesFrame]=Instance.new("UIScale",codesFrame)
local codeInput=Instance.new("TextBox") codeInput.Name="CodeInput" codeInput.Size=UDim2.new(1,0,0,58)
codeInput.PlaceholderText="Enter a code" codeInput.Text="" codeInput.ClearTextOnFocus=false
codeInput.Font=Enum.Font.FredokaOne codeInput.TextSize=24 codeInput.TextColor3=Color3.fromRGB(34,66,81)
codeInput.BackgroundColor3=Color3.fromRGB(224,243,249) codeInput.LayoutOrder=1 codeInput.Parent=codesScroll
Instance.new("UICorner",codeInput).CornerRadius=UDim.new(0,10)
local redeem=Instance.new("TextButton") redeem.Name="Redeem" redeem.Size=UDim2.new(1,0,0,54)
redeem.Text="REDEEM" redeem.TextScaled=true redeem.TextColor3=Color3.new(1,1,1) redeem.BackgroundColor3=Color3.fromRGB(80,208,128)
redeem.LayoutOrder=2 redeem.Parent=codesScroll styleButton(redeem) Instance.new("UICorner",redeem).CornerRadius=UDim.new(0,10)
redeem.Activated:Connect(function() Remotes.RedeemCode:FireServer(codeInput.Text) end)
bindTab(codesButton,codesFrame)
local objective=Instance.new("TextLabel") objective.Name="NextGoal" objective.AnchorPoint=Vector2.new(0.5,0)
objective.Position=UDim2.new(0.5,0,0,101) objective.Size=UDim2.fromOffset(330,42)
objective.BackgroundColor3=Color3.fromRGB(25,53,74) objective.BackgroundTransparency=0.12
objective.Font=Enum.Font.FredokaOne objective.TextSize=17 objective.TextWrapped=true objective.TextColor3=Color3.new(1,1,1)
objective.Parent=screenGui Instance.new("UICorner",objective).CornerRadius=UDim.new(0,10)
local function nextGoal(data)
 if not next(data.UpgradeLevels) then objective.Text="FIRST GOAL • Buy Better Clicks for 10 Power"
 elseif #data.Pets==0 then objective.Text="NEXT • SELL Power for Coins, then hatch a Basic Egg ("..GameConfig.Eggs[1].Cost.." Coins)"
 elseif not next(data.AutoClickerLevels) then objective.Text="NEXT • Buy a Clicking Bot for 25 Power"
 else objective.Text="ASCEND • "..formatNumber(data.Power).." / "..formatNumber(GameConfig.GetRebirthRequirement(data.RebirthCount)).." Power" end
end
nextGoal(currentData)
DataUpdatedRemote.OnClientEvent:Connect(nextGoal)
local flash=Instance.new("Frame") flash.Name="CelebrationFlash" flash.Size=UDim2.fromScale(1,1)
flash.BackgroundColor3=Color3.new(1,1,1) flash.BackgroundTransparency=1 flash.ZIndex=20 flash.Parent=screenGui
-- Blur behind menus, panel pop-in, and camera shake for rare moments.
local polish=require(script.UIPolish).Start({
 panels=panels,
 panelScales=panelScales,
 isReducedMotion=function() return reducedMotion end,
})
local function celebrate(rarity)
 playSound("Rare")
 if reducedMotion then return end
 if rarity=="Legendary" or rarity=="Mythic" then polish.Shake(rarity=="Mythic" and 0.9 or 0.6, 0.45) end
 local color=GameConfig.RarityColors[rarity] or Color3.fromRGB(189,128,255)
 flash.BackgroundColor3=color flash.BackgroundTransparency=0.65
 TweenService:Create(flash,TweenInfo.new(0.45),{BackgroundTransparency=1}):Play()
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if root then
  local attachment=Instance.new("Attachment",root)
  local particles=Instance.new("ParticleEmitter") particles.Texture="rbxasset://textures/particles/sparkles_main.dds"
  particles.Color=ColorSequence.new(color,Color3.new(1,1,1)) particles.Lifetime=NumberRange.new(0.8,1.6)
  particles.Speed=NumberRange.new(7,15) particles.SpreadAngle=Vector2.new(180,180)
  particles.Rate=0 particles.LightEmission=0.8 particles.Parent=attachment particles:Emit(rarity=="Mythic" and 90 or 45)
  Debris:AddItem(attachment,3)
 end
 for i=1,24 do
  local confetti=Instance.new("Frame") confetti.Size=UDim2.fromOffset(7,13)
  confetti.Position=UDim2.fromScale(0.5,0.4) confetti.BackgroundColor3=i%2==0 and color or Color3.fromRGB(255,222,114)
  confetti.BorderSizePixel=0 confetti.ZIndex=21 confetti.Parent=screenGui
  TweenService:Create(confetti,TweenInfo.new(1.2),{Position=UDim2.fromScale(math.random(),1.1),Rotation=math.random(-360,360),BackgroundTransparency=1}):Play()
  Debris:AddItem(confetti,1.3)
 end
end
EggResultRemote.OnClientEvent:Connect(function(pet)
 if pet.Rarity=="Epic" or pet.Rarity=="Legendary" or pet.Rarity=="Mythic" then celebrate(pet.Rarity) else playSound("Purchase") end
end)
Remotes.Feedback.OnClientEvent:Connect(function(kind,message)
 showToast(message)
 if kind=="Ascend" then celebrate("Epic") elseif kind=="Purchase" then playSound("Purchase") end
end)
Remotes.Announcement.OnClientEvent:Connect(function(message,rarity)
 showToast(message) toastFrame.BackgroundColor3=GameConfig.RarityColors[rarity] or Color3.fromRGB(130,78,200)
end)
for _,panel in ipairs(panels) do
 panel:GetPropertyChangedSignal("Visible"):Connect(function()
  if panel.Visible then
   local target=panel.Position panel.Position=target+UDim2.fromOffset(0,14)
   TweenService:Create(panel,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{Position=target}):Play()
  end
 end)
end
local function layoutUtilities()
 local size=workspace.CurrentCamera.ViewportSize
 local narrow=size.X<600
 controls.Position=UDim2.new(1,-8,0,narrow and 104 or 10)
 objective.Size=UDim2.fromOffset(math.min(330,size.X-28),40)
 objective.Position=UDim2.new(0.5,0,0,narrow and 60 or 101)
 if narrow then coinFrame.Position=UDim2.new(0.5,0,0,8) powerLabel.Visible=false else powerLabel.Visible=true end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutUtilities)
resizeHUD() layoutUtilities()
Remotes.RequestData:FireServer()

-- Boss fight HUD (name, HP bar, timer) and victory / time's-up results.
require(script.BossUI).Start({
 screenGui=screenGui,
 bossRemote=Remotes:WaitForChild("BossState"),
 formatNumber=formatNumber,
 showToast=showToast,
 celebrate=celebrate,
 hideDuringFight={objective},
})

-- Quests, Daily rewards and the Welcome Back (offline earnings) panel, plus their buttons.
require(script.RetentionUI).Build({
 controls=controls,
 utility=utility,
 createPanel=createPanel,
 bindTab=bindTab,
 panels=panels,
 registerPanel=function(frame) table.insert(panels,frame) panelScales[frame]=Instance.new("UIScale",frame) end,
 styleButton=styleButton,
 formatNumber=formatNumber,
 dataRemote=DataUpdatedRemote,
 requestData=function() Remotes.RequestData:FireServer() end,
 claimQuestRemote=Remotes:WaitForChild("ClaimQuest"),
 claimDailyRemote=Remotes:WaitForChild("ClaimDaily"),
 offlineRemote=Remotes:WaitForChild("OfflineEarnings"),
})
-- Coins counter + SELL button, running boosts, and the Token Shop.
require(script.EconomyUI).Build({
 screenGui=screenGui,
 controls=controls,
 utility=utility,
 createPanel=createPanel,
 bindTab=bindTab,
 registerPanel=function(frame) table.insert(panels,frame) panelScales[frame]=Instance.new("UIScale",frame) end,
 styleButton=styleButton,
 formatNumber=formatNumber,
 dataRemote=DataUpdatedRemote,
 getEquippedPets=getEquippedPets,
 requestData=function() task.delay(1.1,function() Remotes.RequestData:FireServer() end) end, -- RequestData is rate-limited to 1/s
 sellRemote=Remotes:WaitForChild("SellPower"),
 buyBoostRemote=Remotes:WaitForChild("BuyBoost"),
})
-- STORE (gamepasses / products), the AUTO click toggle, and the [VIP] chat tag.
require(script.StoreUI).Build({
 screenGui=screenGui,
 createPanel=createPanel,
 bindTab=bindTab,
 registerPanel=function(frame) table.insert(panels,frame) panelScales[frame]=Instance.new("UIScale",frame) end,
 styleButton=styleButton,
 dataRemote=DataUpdatedRemote,
 clickRemote=ClickRemote,
})
-- Joyful, calm background music (shuffled, cross-faded) with a 🎵 mute button.
require(script.MusicPlayer).Start({ screenGui=screenGui, styleButton=styleButton })
resizeHUD() -- size the panels created above
