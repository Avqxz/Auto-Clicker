-- GEAR tab: the four equipped slots, the total bonus, and the gear bag with Equip / Discard.
-- Gear drops from bosses; the server owns all changes (EquipGear / UnequipGear / DiscardGear).

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local GearUI = {}

local DARK = Color3.fromRGB(37, 65, 78)
local MUTED = Color3.fromRGB(77, 116, 130)
local GREY = Color3.fromRGB(152, 174, 184)

-- Rarity colors are tuned for dark backgrounds; darken them for text on the pale cards.
local function rarityText(rarity)
	local c = GameConfig.RarityColors[rarity] or DARK
	return Color3.new(c.R * 0.72, c.G * 0.72, c.B * 0.72)
end

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

-- deps: { createPanel, createTabButton, bindTab, panels, styleButton, equipRemote, unequipRemote, discardRemote }
function GearUI.Build(deps)
	local frame, scroll = deps.createPanel("GearFrame", "Gear")
	table.insert(deps.panels, frame)
	local toggle = deps.createTabButton("GearToggle", "GEAR", Color3.fromRGB(240, 90, 120))
	deps.bindTab(toggle, frame)

	local function button(parent, label, color, onClick)
		local b = Instance.new("TextButton")
		b.Font = Enum.Font.FredokaOne
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = color
		b.Text = label
		b.Parent = parent
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		deps.styleButton(b)
		b.MouseButton1Click:Connect(onClick)
		return b
	end

	-- Equipped slots row.
	local slotRow = Instance.new("Frame")
	slotRow.BackgroundTransparency = 1
	slotRow.Size = UDim2.new(1, 0, 0, 132)
	slotRow.LayoutOrder = 1
	slotRow.Parent = scroll
	local rowLayout = Instance.new("UIListLayout", slotRow)
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 6)
	local slotCards = {}
	for i, slot in ipairs(GameConfig.GearSlots) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0.25, -5, 1, 0)
		card.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
		card.LayoutOrder = i
		card.Parent = slotRow
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
		local edge = Instance.new("UIStroke", card)
		edge.Thickness = 2
		text(card, { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 18), TextScaled = true,
			Text = string.upper(slot), TextColor3 = MUTED })
		local name = text(card, { Position = UDim2.fromOffset(6, 24), Size = UDim2.new(1, -12, 0, 22), TextScaled = true })
		local stats = text(card, { Position = UDim2.fromOffset(6, 48), Size = UDim2.new(1, -12, 0, 42), TextSize = 12,
			TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = MUTED })
		local unequip = button(card, "Unequip", GREY, function()
			deps.unequipRemote:FireServer(slot)
		end)
		unequip.AnchorPoint = Vector2.new(0.5, 1)
		unequip.Position = UDim2.new(0.5, 0, 1, -6)
		unequip.Size = UDim2.new(1, -12, 0, 30)
		slotCards[slot] = { Edge = edge, Name = name, Stats = stats, Unequip = unequip }
	end

	local totalLabel = text(scroll, { Size = UDim2.new(1, 0, 0, 26), TextScaled = true, LayoutOrder = 2,
		TextColor3 = Color3.fromRGB(200, 60, 100) })
	local bagHeader = text(scroll, { Size = UDim2.new(1, 0, 0, 24), TextScaled = true, LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Left })

	local rows = {}
	local signature -- rows are rebuilt only when the gear actually changes
	local api = {}

	function api.Refresh(data)
		local gear = data.Gear or { Items = {}, Equipped = {} }
		local parts = {}
		for _, owned in ipairs(gear.Items) do table.insert(parts, owned.Uid .. owned.Id) end
		for _, slot in ipairs(GameConfig.GearSlots) do table.insert(parts, slot .. tostring(gear.Equipped[slot])) end
		local sig = table.concat(parts, ",")
		if sig == signature then
			return
		end
		signature = sig

		local byUid = {}
		for _, owned in ipairs(gear.Items) do byUid[owned.Uid] = owned end
		local equippedUids = {}
		for _, slot in ipairs(GameConfig.GearSlots) do
			local card = slotCards[slot]
			local owned = gear.Equipped[slot] and byUid[gear.Equipped[slot]]
			local item = owned and GameConfig.GetGear(owned.Id)
			if item then
				equippedUids[owned.Uid] = true
				local color = GameConfig.RarityColors[GameConfig.GetGearRarity(item)]
				card.Name.Text = item.Name
				card.Name.TextColor3 = rarityText(GameConfig.GetGearRarity(item))
				card.Edge.Color = color
				card.Stats.Text = GameConfig.DescribeGear(item)
				card.Unequip.Visible = true
			else
				card.Name.Text = "Empty"
				card.Name.TextColor3 = GREY
				card.Edge.Color = GREY
				card.Stats.Text = "Beat bosses for gear"
				card.Unequip.Visible = false
			end
		end

		local total = GameConfig.GetGearStats(data)
		local totalParts = {}
		if total.ClickPower > 0 then table.insert(totalParts, "+" .. math.floor(total.ClickPower * 100 + 0.5) .. "% click") end
		if total.CritChance > 0 then table.insert(totalParts, "+" .. math.floor(total.CritChance * 100 + 0.5) .. "% crit") end
		if total.CritDamage > 0 then table.insert(totalParts, "+" .. string.format("%.1f", total.CritDamage) .. "x crit dmg") end
		if total.AutoPower > 0 then table.insert(totalParts, "+" .. math.floor(total.AutoPower * 100 + 0.5) .. "% auto") end
		for _, burst in ipairs(total.Bursts) do table.insert(totalParts, burst.Name) end
		totalLabel.Text = if #totalParts > 0 then "Total: " .. table.concat(totalParts, " • ") else "No gear equipped"
		bagHeader.Text = "Bag (" .. #gear.Items .. "/" .. GameConfig.MaxGearItems .. ")"

		for _, row in ipairs(rows) do row:Destroy() end
		rows = {}
		for i, owned in ipairs(gear.Items) do
			local item = GameConfig.GetGear(owned.Id)
			if item then
				local rarity = GameConfig.GetGearRarity(item)
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 58)
				row.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
				row.LayoutOrder = 10 + i
				row.Parent = scroll
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
				text(row, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -200, 0, 24), TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left, Text = item.Name .. "  (" .. rarity .. " " .. item.Slot .. ")",
					TextColor3 = rarityText(rarity) })
				text(row, { Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -200, 0, 22), TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left, Text = GameConfig.DescribeGear(item), TextColor3 = MUTED })
				if equippedUids[owned.Uid] then
					local tag = text(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(176, 30), TextScaled = true, Text = "EQUIPPED", TextColor3 = Color3.fromRGB(60, 170, 90) })
					tag.TextXAlignment = Enum.TextXAlignment.Right
				else
					local equip = button(row, "Equip", Color3.fromRGB(88, 219, 132), function()
						deps.equipRemote:FireServer(owned.Uid)
					end)
					equip.AnchorPoint = Vector2.new(1, 0.5)
					equip.Position = UDim2.new(1, -96, 0.5, 0)
					equip.Size = UDim2.fromOffset(84, 36)
					local armed = false -- Discard needs a second tap to confirm
					local discard
					discard = button(row, "Discard", Color3.fromRGB(246, 88, 111), function()
						if armed then
							deps.discardRemote:FireServer(owned.Uid)
						else
							armed = true
							discard.Text = "Sure?"
							task.delay(2, function()
								armed = false
								if discard.Parent then discard.Text = "Discard" end
							end)
						end
					end)
					discard.AnchorPoint = Vector2.new(1, 0.5)
					discard.Position = UDim2.new(1, -8, 0.5, 0)
					discard.Size = UDim2.fromOffset(84, 36)
				end
				table.insert(rows, row)
			end
		end
	end

	return api
end

return GearUI
