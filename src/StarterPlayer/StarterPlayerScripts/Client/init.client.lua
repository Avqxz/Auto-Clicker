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
local RebirthRemote = Remotes:WaitForChild("Rebirth")
local DataUpdatedRemote = Remotes:WaitForChild("DataUpdated")
local HatchEggRemote = Remotes:WaitForChild("HatchEgg")
local EquipPetRemote = Remotes:WaitForChild("EquipPet")
local UnequipPetRemote = Remotes:WaitForChild("UnequipPet")
local FusePetsRemote = Remotes:WaitForChild("FusePets")
local EggResultRemote = Remotes:WaitForChild("EggResult")
local ZoneLockedRemote = Remotes:WaitForChild("ZoneLocked")
local PickStarterPetRemote = Remotes:WaitForChild("PickStarterPet")

local currentData = {
	Coins = 0,
	ClickPower = GameConfig.StartingClickPower,
	UpgradeLevels = {},
	AutoClickerLevels = {},
	RebirthCount = 0,
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
	local petMultiplier = GameConfig.GetPetMultiplierTotal(getEquippedPets(data))
	return data.ClickPower * petMultiplier * GameConfig.GetRebirthMultiplier(data.RebirthCount)
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

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(Vector3.new(0, 0.9, 3.4), Vector3.new(0, 0.4, 0))
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	return viewportFrame, model
end

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

-- Click power label (clicking is now a full-screen tap, not a dedicated button)
local powerLabel = Instance.new("TextLabel")
powerLabel.Name = "PowerLabel"
powerLabel.AnchorPoint = Vector2.new(0.5, 0)
powerLabel.Position = UDim2.new(0.5, 0, 0.02, 66)
powerLabel.Size = UDim2.new(0, 280, 0, 26)
powerLabel.BackgroundTransparency = 1
powerLabel.Font = Enum.Font.Gotham
powerLabel.TextScaled = true
powerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
powerLabel.TextStrokeTransparency = 0.5
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

-- Bottom tab bar (Shop / Eggs / Pets)
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.AnchorPoint = Vector2.new(1, 1)
tabBar.Position = UDim2.new(1, -20, 1, -20)
tabBar.Size = UDim2.new(0, 360, 0, 50)
tabBar.BackgroundTransparency = 1
tabBar.Parent = screenGui

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = tabBar

local function createTabButton(name, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0, 112, 0, 50)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.Parent = tabBar
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
	return button
end

local shopToggle = createTabButton("ShopToggle", "Shop", Color3.fromRGB(40, 160, 90))
local eggsToggle = createTabButton("EggsToggle", "Eggs", Color3.fromRGB(210, 150, 30))
local petsToggle = createTabButton("PetsToggle", "Pets", Color3.fromRGB(70, 110, 220))

-- Generic panel factory used by Shop / Eggs / Pets
local function createPanel(name, title)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -20, 1, -80)
	frame.Size = UDim2.new(0, 380, 0, 440)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	frame.Visible = false
	frame.Parent = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Text = title
	titleLabel.Parent = frame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Position = UDim2.new(0, 0, 0, 44)
	scroll.Size = UDim2.new(1, 0, 1, -44)
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

-- ===== Shop (upgrades + auto-clickers) =====

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

-- ===== Eggs =====

local eggEntries = {}

local function createEggEntry(egg, layoutOrder)
	local frame = Instance.new("Frame")
	frame.Name = egg.Id
	frame.Size = UDim2.new(1, 0, 0, 90)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	frame.LayoutOrder = layoutOrder
	frame.Parent = eggsScroll

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 10, 0, 6)
	nameLabel.Size = UDim2.new(1, -110, 0, 22)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Text = egg.Name
	nameLabel.Parent = frame

	local oddsText = {}
	for _, pet in ipairs(egg.Pets) do
		table.insert(oddsText, pet.Name .. " (" .. pet.Rarity .. ")")
	end

	local oddsLabel = Instance.new("TextLabel")
	oddsLabel.BackgroundTransparency = 1
	oddsLabel.Position = UDim2.new(0, 10, 0, 28)
	oddsLabel.Size = UDim2.new(1, -20, 0, 40)
	oddsLabel.Font = Enum.Font.Gotham
	oddsLabel.TextScaled = false
	oddsLabel.TextSize = 12
	oddsLabel.TextWrapped = true
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
	oddsLabel.TextYAlignment = Enum.TextYAlignment.Top
	oddsLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
	oddsLabel.Text = table.concat(oddsText, ", ")
	oddsLabel.Parent = frame

	local hatchButton = Instance.new("TextButton")
	hatchButton.Name = "HatchButton"
	hatchButton.AnchorPoint = Vector2.new(1, 0.5)
	hatchButton.Position = UDim2.new(1, -10, 0.5, 0)
	hatchButton.Size = UDim2.new(0, 90, 0, 40)
	hatchButton.BackgroundColor3 = Color3.fromRGB(210, 150, 30)
	hatchButton.Font = Enum.Font.GothamBold
	hatchButton.TextScaled = true
	hatchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	hatchButton.Text = "Hatch"
	hatchButton.Parent = frame

	Instance.new("UICorner", hatchButton).CornerRadius = UDim.new(0, 8)

	hatchButton.MouseButton1Click:Connect(function()
		HatchEggRemote:FireServer(egg.Id)
	end)

	eggEntries[egg.Id] = { Egg = egg, Frame = frame, HatchButton = hatchButton }
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
		if locked then
			entry.HatchButton.Text = "Locked"
			entry.HatchButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
		else
			entry.HatchButton.Text = formatNumber(egg.Cost)
			entry.HatchButton.BackgroundColor3 = if currentData.Coins >= egg.Cost
				then Color3.fromRGB(210, 150, 30)
				else Color3.fromRGB(120, 60, 60)
		end
	end
end

-- ===== Pets inventory =====

local petGroupFrames = {}

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
	frame.Size = UDim2.new(1, 0, 0, 90)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
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
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.BackgroundTransparency = 1
	infoLabel.Position = UDim2.new(0, 92, 0, 28)
	infoLabel.Size = UDim2.new(1, -242, 0, 18)
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextScaled = true
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
	infoLabel.Parent = frame

	local equippedLabel = Instance.new("TextLabel")
	equippedLabel.Name = "EquippedLabel"
	equippedLabel.BackgroundTransparency = 1
	equippedLabel.Position = UDim2.new(0, 92, 0, 48)
	equippedLabel.Size = UDim2.new(1, -242, 0, 16)
	equippedLabel.Font = Enum.Font.Gotham
	equippedLabel.TextScaled = true
	equippedLabel.TextXAlignment = Enum.TextXAlignment.Left
	equippedLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
	equippedLabel.Parent = frame

	local equipButton = Instance.new("TextButton")
	equipButton.Name = "EquipButton"
	equipButton.AnchorPoint = Vector2.new(1, 0)
	equipButton.Position = UDim2.new(1, -10, 0, 6)
	equipButton.Size = UDim2.new(0, 130, 0, 32)
	equipButton.BackgroundColor3 = Color3.fromRGB(60, 170, 100)
	equipButton.Font = Enum.Font.GothamBold
	equipButton.TextScaled = true
	equipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	equipButton.Text = "Equip"
	equipButton.Parent = frame

	Instance.new("UICorner", equipButton).CornerRadius = UDim.new(0, 8)

	local fuseButton = Instance.new("TextButton")
	fuseButton.Name = "FuseButton"
	fuseButton.AnchorPoint = Vector2.new(1, 0)
	fuseButton.Position = UDim2.new(1, -10, 0, 42)
	fuseButton.Size = UDim2.new(0, 130, 0, 32)
	fuseButton.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
	fuseButton.Font = Enum.Font.GothamBold
	fuseButton.TextScaled = true
	fuseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	fuseButton.Text = "Fuse x5"
	fuseButton.Visible = false
	fuseButton.Parent = frame

	Instance.new("UICorner", fuseButton).CornerRadius = UDim.new(0, 8)

	local group = {
		Frame = frame,
		IconContainer = iconContainer,
		IconBuilt = false,
		NameLabel = nameLabel,
		InfoLabel = infoLabel,
		EquippedLabel = equippedLabel,
		EquipButton = equipButton,
		FuseButton = fuseButton,
		EquipConnection = nil,
		FuseConnection = nil,
	}
	petGroupFrames[key] = group
	return group
end

local function refreshPets()
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
		group.NameLabel.TextColor3 = color
		group.InfoLabel.Text = pet.Rarity .. " - " .. formatMultiplier(pet.Multiplier) .. " - Owned " .. info.Count
		group.EquippedLabel.Text = "Equipped: " .. info.EquippedCount

		local maxEquipped = GameConfig.GetMaxEquippedPets(currentData.RebirthCount)
		if info.EquippedCount > 0 then
			group.EquipButton.Text = "Unequip"
			group.EquipButton.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
		else
			group.EquipButton.Text = "Equip"
			local canEquip = #currentData.EquippedPetUids < maxEquipped
			group.EquipButton.BackgroundColor3 = if canEquip
				then Color3.fromRGB(60, 170, 100)
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
revealCamera.CFrame = CFrame.new(Vector3.new(0, 0.9, 3.4), Vector3.new(0, 0.4, 0))
revealCamera.Parent = revealViewport
revealViewport.CurrentCamera = revealCamera

local revealLabel = Instance.new("TextLabel")
revealLabel.AnchorPoint = Vector2.new(0.5, 0)
revealLabel.Position = UDim2.new(0.5, 0, 0, 134)
revealLabel.Size = UDim2.new(1, -20, 0, 56)
revealLabel.BackgroundTransparency = 1
revealLabel.Font = Enum.Font.GothamBlack
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
	revealLabel.Text = string.format("%s\n%s  %s", displayName, pet.Rarity, formatMultiplier(pet.Multiplier))

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
starterPetFrame.Parent = screenGui

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

local function selectStarterPet(petName)
	selectedStarterPet = petName
	for name, stroke in pairs(starterCardStrokes) do
		stroke.Transparency = if name == petName then 0 else 1
	end
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

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 3
	cardStroke.Color = Color3.fromRGB(60, 170, 100)
	cardStroke.Transparency = 1
	cardStroke.Parent = card
	starterCardStrokes[starter.Name] = cardStroke

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

	coinLabel.Text = formatNumber(currentData.Coins) .. " Coins"
	powerLabel.Text = "+" .. formatNumber(totalClickPower) .. " per click"

	local requirement = GameConfig.GetRebirthRequirement(currentData.RebirthCount)
	rebirthButton.Text = ("Rebirth (%d)\n%s coins"):format(currentData.RebirthCount, formatNumber(requirement))
	rebirthButton.BackgroundColor3 = if currentData.Coins >= requirement
		then Color3.fromRGB(160, 60, 220)
		else Color3.fromRGB(90, 50, 110)

	refreshShop()
	refreshEggs()
	refreshPets()
end

-- ===== Interactions =====

-- Floating "+N" popup that appears where the player clicked/tapped, since
-- there's no dedicated click button to animate anymore.
local function spawnClickFeedback(screenPosition, amount)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)
	label.Size = UDim2.fromOffset(140, 40)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 215, 60)
	label.TextStrokeTransparency = 0.4
	label.Text = "+" .. formatNumber(amount)
	label.ZIndex = 10
	label.Parent = screenGui

	local tween = TweenService:Create(
		label,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y - 60),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

-- Click anywhere on screen (not just a dedicated button). gameProcessedEvent
-- is true when the input already hit a GuiButton (Shop/Eggs/Pets/Rebirth/etc),
-- so this only fires for clicks/taps on empty space.
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	ClickRemote:FireServer()
	spawnClickFeedback(Vector2.new(input.Position.X, input.Position.Y), getClickPower(currentData))
end)

rebirthButton.MouseButton1Click:Connect(function()
	RebirthRemote:FireServer()
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
toastFrame.Parent = screenGui

Instance.new("UICorner", toastFrame).CornerRadius = UDim.new(0, 10)

local toastLabel = Instance.new("TextLabel")
toastLabel.BackgroundTransparency = 1
toastLabel.Size = UDim2.new(1, -20, 1, 0)
toastLabel.Position = UDim2.new(0, 10, 0, 0)
toastLabel.Font = Enum.Font.GothamBold
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

ZoneLockedRemote.OnClientEvent:Connect(function(requiredRebirths)
	showToast(("Locked! Need %d Rebirth%s to enter the Desert Zone"):format(
		requiredRebirths,
		requiredRebirths == 1 and "" or "s"
	))
end)

refreshUI()
