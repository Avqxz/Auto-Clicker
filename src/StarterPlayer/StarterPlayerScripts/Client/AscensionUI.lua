-- Ascend confirmation panel, the Gem-bought skill tree panel (three branches), and the HUD gem
-- counter. The server decides everything (Ascend / UnlockSkill remotes); this only displays data.

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local AscensionUI = {}

local BRANCH_COLORS = {
	Power = Color3.fromRGB(255, 120, 70),
	Automation = Color3.fromRGB(60, 190, 255),
	Luck = Color3.fromRGB(120, 210, 90),
}
local DARK = Color3.fromRGB(37, 65, 78)
local GREY = Color3.fromRGB(152, 174, 184)
local GREEN = Color3.fromRGB(88, 219, 132)

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = DARK
	l.TextWrapped = true
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- deps: { screenGui, coinFrame, createPanel, createTabButton, bindTab, panels, styleButton,
--         formatNumber, ascendRemote, unlockSkillRemote }
function AscensionUI.Build(deps)
	local fmt = deps.formatNumber
	local api = {}

	-- ===== HUD gem counter (right of the coin counter) =====
	local gemFrame = Instance.new("Frame")
	gemFrame.Name = "GemFrame"
	gemFrame.AnchorPoint = Vector2.new(0, 0)
	gemFrame.Position = UDim2.new(0.5, 138, 0, 12)
	gemFrame.Size = UDim2.fromOffset(120, 56)
	gemFrame.BackgroundColor3 = Color3.fromRGB(120, 70, 220)
	gemFrame.Parent = deps.screenGui
	Instance.new("UICorner", gemFrame).CornerRadius = UDim.new(0, 12)
	local gemStroke = Instance.new("UIStroke", gemFrame)
	gemStroke.Thickness = 2
	gemStroke.Color = Color3.fromRGB(40, 25, 80)
	local gemLabel = text(gemFrame, {
		Size = UDim2.fromScale(1, 1), TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(40, 25, 80), Text = "💎 0",
	})
	local gemPad = Instance.new("UIPadding", gemLabel)
	gemPad.PaddingLeft, gemPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	gemPad.PaddingTop, gemPad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)

	-- ===== Ascend panel =====
	local ascendFrame, ascendScroll = deps.createPanel("AscendFrame", "Ascend")
	table.insert(deps.panels, ascendFrame)

	local progressLabel = text(ascendScroll, { Size = UDim2.new(1, 0, 0, 30), TextScaled = true, LayoutOrder = 1 })
	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.new(1, 0, 0, 16)
	barBack.BackgroundColor3 = Color3.fromRGB(205, 225, 232)
	barBack.LayoutOrder = 2
	barBack.Parent = ascendScroll
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
	local barFill = Instance.new("Frame")
	barFill.BackgroundColor3 = Color3.fromRGB(185, 96, 247)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

	local rewardLabel = text(ascendScroll, {
		Size = UDim2.new(1, 0, 0, 52), TextScaled = true, LayoutOrder = 3,
		TextColor3 = Color3.fromRGB(120, 70, 220),
	})
	local bonusLabel = text(ascendScroll, { Size = UDim2.new(1, 0, 0, 30), TextScaled = true, LayoutOrder = 4 })
	local unlockLabel = text(ascendScroll, {
		Size = UDim2.new(1, 0, 0, 26), TextScaled = true, LayoutOrder = 5, TextColor3 = Color3.fromRGB(0, 150, 190),
	})
	text(ascendScroll, {
		Size = UDim2.new(1, 0, 0, 44), TextSize = 17, LayoutOrder = 8, TextColor3 = Color3.fromRGB(77, 116, 130),
		Text = "Resets: Coins, Upgrades, Auto-clickers\nKeeps: Pets, Gems, Skills",
	})
	local ascendButton = Instance.new("TextButton")
	ascendButton.Name = "AscendButton"
	ascendButton.Size = UDim2.new(1, 0, 0, 64)
	ascendButton.Font = Enum.Font.FredokaOne
	ascendButton.TextScaled = true
	ascendButton.TextColor3 = Color3.new(1, 1, 1)
	ascendButton.Text = "ASCEND"
	ascendButton.LayoutOrder = 6 -- above the resets/keeps note so it's visible without scrolling
	ascendButton.Parent = ascendScroll
	Instance.new("UICorner", ascendButton).CornerRadius = UDim.new(0, 12)
	deps.styleButton(ascendButton)
	local canAscend = false
	ascendButton.MouseButton1Click:Connect(function()
		if canAscend then
			deps.ascendRemote:FireServer()
			ascendFrame.Visible = false
		end
	end)

	-- ===== Skill tree panel =====
	local skillsFrame, skillsScroll = deps.createPanel("SkillsFrame", "Skill Tree")
	table.insert(deps.panels, skillsFrame)
	local skillsToggle = deps.createTabButton("SkillsToggle", "SKILLS", Color3.fromRGB(255, 170, 60))
	deps.bindTab(skillsToggle, skillsFrame)

	local gemsHeader = text(skillsScroll, {
		Size = UDim2.new(1, 0, 0, 30), TextScaled = true, LayoutOrder = 0, TextColor3 = Color3.fromRGB(120, 70, 220),
	})
	local columns = Instance.new("Frame")
	columns.Name = "Branches"
	columns.BackgroundTransparency = 1
	columns.Size = UDim2.new(1, 0, 0, 0)
	columns.AutomaticSize = Enum.AutomaticSize.Y
	columns.LayoutOrder = 1
	columns.Parent = skillsScroll
	local colLayout = Instance.new("UIListLayout", columns)
	colLayout.FillDirection = Enum.FillDirection.Horizontal
	colLayout.Padding = UDim.new(0, 6)
	colLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local cards = {}
	for b, branch in ipairs(GameConfig.SkillBranches) do
		local col = Instance.new("Frame")
		col.Name = branch
		col.BackgroundTransparency = 1
		col.Size = UDim2.new(1 / 3, -4, 0, 0)
		col.AutomaticSize = Enum.AutomaticSize.Y
		col.LayoutOrder = b
		col.Parent = columns
		local list = Instance.new("UIListLayout", col)
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		local header = text(col, {
			Size = UDim2.new(1, 0, 0, 30), TextScaled = true, Text = string.upper(branch),
			TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, BackgroundColor3 = BRANCH_COLORS[branch],
		})
		Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

		local order = 0
		for _, node in ipairs(GameConfig.Skills) do
			if node.Branch == branch then
				order += 1
				local card = Instance.new("Frame")
				card.Name = node.Id
				card.Size = UDim2.new(1, 0, 0, 128)
				card.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
				card.LayoutOrder = order
				card.Parent = col
				Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
				local edge = Instance.new("UIStroke", card)
				edge.Thickness = 2
				edge.Color = BRANCH_COLORS[branch]
				text(card, {
					Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 22), TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left, Text = node.Name,
				})
				local levelLabel = text(card, {
					Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 0, 16), TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(77, 116, 130),
				})
				local effectLabel = text(card, {
					Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -16, 0, 40), TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
					TextColor3 = Color3.fromRGB(58, 90, 105),
				})
				local buy = Instance.new("TextButton")
				buy.AnchorPoint = Vector2.new(0.5, 1)
				buy.Position = UDim2.new(0.5, 0, 1, -6)
				buy.Size = UDim2.new(1, -16, 0, 34)
				buy.Font = Enum.Font.FredokaOne
				buy.TextScaled = true
				buy.TextColor3 = Color3.new(1, 1, 1)
				buy.Parent = card
				Instance.new("UICorner", buy).CornerRadius = UDim.new(0, 8)
				deps.styleButton(buy)
				buy.MouseButton1Click:Connect(function()
					deps.unlockSkillRemote:FireServer(node.Id)
				end)
				cards[node.Id] = { Node = node, Level = levelLabel, Effect = effectLabel, Buy = buy }
			end
		end
	end

	function api.Refresh(data)
		local gems = data.Gems or 0
		local skills = data.Skills or {}
		gemLabel.Text = "💎 " .. fmt(gems)

		-- Ascend panel
		local requirement = GameConfig.GetRebirthRequirement(data.RebirthCount)
		local ready = data.Coins >= requirement
		progressLabel.Text = fmt(data.Coins) .. " / " .. fmt(requirement) .. " coins"
		barFill.Size = UDim2.fromScale(math.clamp(data.Coins / requirement, 0, 1), 1)
		rewardLabel.Text = "💎 +" .. fmt(GameConfig.GetAscensionGems(math.max(data.Coins, requirement), data.RebirthCount)) .. " Gems"
			.. (if ready then "" else " (at requirement)")
		bonusLabel.Text = "Permanent power: x" .. GameConfig.GetRebirthMultiplier(data.RebirthCount)
			.. "  →  x" .. GameConfig.GetRebirthMultiplier(data.RebirthCount + 1)
		unlockLabel.Text = ""
		for _, zone in ipairs(GameConfig.Zones) do
			if zone.RequiredRebirths == data.RebirthCount + 1 then
				unlockLabel.Text = "Unlocks " .. zone.Name .. "!"
			end
		end
		ascendButton.Text = if ready then "ASCEND" else "Need " .. fmt(requirement - data.Coins) .. " more coins"
		canAscend = ready
		ascendButton.AutoButtonColor = ready
		ascendButton.BackgroundColor3 = if ready then Color3.fromRGB(185, 96, 247) else GREY

		-- Skill tree
		gemsHeader.Text = "💎 " .. fmt(gems) .. " Gems  •  earn more by Ascending"
		for id, card in pairs(cards) do
			local node, level = card.Node, skills[id] or 0
			card.Level.Text = "Level " .. level .. " / " .. node.MaxLevel
			if level >= node.MaxLevel then
				card.Effect.Text = node.Effect(level)
				card.Buy.Text = "MAXED"
				card.Buy.BackgroundColor3 = GREY
			elseif node.Requires and (skills[node.Requires] or 0) < 1 then
				card.Effect.Text = "Next: " .. node.Effect(level + 1)
				card.Buy.Text = "🔒 " .. GameConfig.GetSkill(node.Requires).Name
				card.Buy.BackgroundColor3 = GREY
			else
				card.Effect.Text = (if level > 0 then "Now: " .. node.Effect(level) .. "\n" else "") .. "Next: " .. node.Effect(level + 1)
				local cost = GameConfig.GetSkillCost(node, level)
				card.Buy.Text = "💎 " .. fmt(cost)
				card.Buy.BackgroundColor3 = if gems >= cost then GREEN else GREY
			end
		end
	end

	-- Shows one panel (hiding the others), e.g. from the HUD Ascend button or the in-world altar.
	function api.Open(name)
		local target = if name == "Skills" then skillsFrame else ascendFrame
		for _, p in ipairs(deps.panels) do
			p.Visible = false
		end
		target.Visible = true
	end

	return api
end

return AscensionUI
