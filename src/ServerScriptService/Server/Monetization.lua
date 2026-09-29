-- Gamepasses and developer products (IDs in GameConfig.GamePasses / DevProducts; 0 = not set up).
--   * Pass ownership is checked with Roblox on join and after in-game purchases, stored as
--     data.Passes[Key] = true (refreshed every join) and as a player attribute for other clients
--     (VIP chat tag). VIP also gets a server-side aura everyone can see.
--   * ProcessReceipt grants products idempotently: each PurchaseId is recorded in the save and the
--     save is written before Roblox is told the purchase went through.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Modules.GameConfig)

local Monetization = {}

local MAX_RECEIPTS = 100

local function byId(list, id)
	for _, item in ipairs(list) do
		if item.Id ~= 0 and item.Id == id then
			return item
		end
	end
	return nil
end

-- deps: { PlayerData, pushData(player), feedback(player, kind, text), bossCooldowns = { [userId] = {...} } }
function Monetization.Start(deps)
	local api = {}

	local function applyVIPAura(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or root:FindFirstChild("VIPAura") then
			return
		end
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "VIPAura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(Color3.fromRGB(255, 210, 74), Color3.fromRGB(190, 110, 255))
		aura.Size = NumberSequence.new(0.4, 0)
		aura.Lifetime = NumberRange.new(0.8, 1.4)
		aura.Rate = 8
		aura.Speed = NumberRange.new(0.5, 1.5)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.LightEmission = 0.7
		aura.Parent = root
	end

	local function setPass(player, data, pass)
		data.Passes[pass.Key] = true
		player:SetAttribute("Pass_" .. pass.Key, true)
		if pass.Key == "VIP" then
			applyVIPAura(player)
		end
	end

	-- Called once the player's data has loaded.
	function api.RefreshPasses(player, data)
		data.Passes = {}
		for _, pass in ipairs(Config.GamePasses) do
			if pass.Id ~= 0 then
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
				if ok and owns then
					setPass(player, data, pass)
				end
			end
		end
		player.CharacterAdded:Connect(function()
			if data.Passes.VIP then
				task.wait(0.5)
				applyVIPAura(player)
			end
		end)
		if data.Passes.VIP then
			applyVIPAura(player)
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = purchased and byId(Config.GamePasses, passId)
		local data = pass and deps.PlayerData.Get(player)
		if data then
			setPass(player, data, pass)
			deps.feedback(player, "Ascend", "Thanks! " .. pass.Name .. " unlocked")
			deps.pushData(player)
		end
	end)

	local function grant(player, data, product)
		if product.Boost then
			local now = os.time()
			local current = math.max(now, data.Boosts[product.Boost] or 0)
			data.Boosts[product.Boost] = math.min(current + product.Minutes * 60, now + Config.PaidBoostMaxMinutes * 60)
		elseif product.Key == "BossRetry" then
			deps.bossCooldowns[player.UserId] = nil
		elseif product.Tokens then
			data.Tokens = (data.Tokens or 0) + product.Tokens
		end
	end

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local data = player and deps.PlayerData.Get(player)
		local product = byId(Config.DevProducts, receipt.ProductId)
		if not data or not product then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later (e.g. next join)
		end
		data.Receipts = data.Receipts or {}
		if table.find(data.Receipts, receipt.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted in this save
		end

		grant(player, data, product)
		table.insert(data.Receipts, receipt.PurchaseId)
		while #data.Receipts > MAX_RECEIPTS do
			table.remove(data.Receipts, 1)
		end
		deps.pushData(player)

		-- Studio saves are disposable (PlayerData skips them), so test purchases count as granted.
		if not RunService:IsStudio() and not deps.PlayerData.Save(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- the receipt id keeps a retry from double-granting
		end
		deps.feedback(player, "Ascend", "Thanks! " .. product.Name .. " received")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return api
end

return Monetization
