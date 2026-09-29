-- Quests panel (3 daily + 3 weekly, with reset timers), the 7-day Daily reward calendar (opens
-- itself once per session when a reward is ready), the "Welcome back" offline-earnings panel, and
-- the QUESTS / DAILY buttons (with a red dot when something can be claimed).

local RunService = game:GetService("RunService")

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local RetentionUI = {}

local DARK = Color3.fromRGB(37, 65, 78)
local MUTED = Color3.fromRGB(77, 116, 130)
local GREY = Color3.fromRGB(152, 174, 184)
local GREEN = Color3.fromRGB(88, 219, 132)
local GOLD = Color3.fromRGB(255, 190, 40)

local function now()
	return workspace:GetServerTimeNow()
end

local function duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d, h, m = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if d > 0 then return d .. "d " .. h .. "h" end
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m " .. seconds % 60 .. "s"
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

-- deps: { controls (right-hand button column), utility(text, y, color), createPanel, bindTab, panels,
--         registerPanel(frame), styleButton, formatNumber, dataRemote, requestData, claimQuestRemote,
--         claimDailyRemote, offlineRemote }
function RetentionUI.Build(deps)
	local fmt = deps.formatNumber
	local data

	local function button(parent, label, onClick)
		local b = Instance.new("TextButton")
		b.Font = Enum.Font.FredokaOne
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = label
		b.Parent = parent
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		deps.styleButton(b)
		b.MouseButton1Click:Connect(onClick)
		return b
	end
	local function dot(parent)
		local d = Instance.new("Frame")
		d.Name = "Notify"
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = UDim2.new(1, -4, 0, 4)
		d.Size = UDim2.fromOffset(16, 16)
		d.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
		d.Visible = false
		d.ZIndex = 5
		d.Parent = parent
		Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
		local s = Instance.new("UIStroke", d)
		s.Thickness = 2
		s.Color = Color3.new(1, 1, 1)
		return d
	end

	-- Right-hand column gets two more buttons.
	deps.controls.Size = UDim2.fromOffset(106, 262)
	local questsButton = deps.utility("QUESTS", 162, Color3.fromRGB(240, 150, 40))
	local dailyButton = deps.utility("DAILY", 216, Color3.fromRGB(230, 80, 150))
	local questsDot, dailyDot = dot(questsButton), dot(dailyButton)

	-- ===== Quests panel =====
	local questsFrame, questsScroll = deps.createPanel("QuestsFrame", "Quests")
	deps.registerPanel(questsFrame)
	deps.bindTab(questsButton, questsFrame)

	local headers, rows = {}, { Daily = {}, Weekly = {} }
	for g, group in ipairs({ "Daily", "Weekly" }) do
		headers[group] = text(questsScroll, { Size = UDim2.new(1, 0, 0, 28), TextScaled = true, LayoutOrder = g * 10,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if group == "Daily" then Color3.fromRGB(0, 150, 190) else Color3.fromRGB(150, 80, 220) })
		for i = 1, GameConfig.QuestsPerPeriod do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 62)
			row.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
			row.LayoutOrder = g * 10 + i
			row.Parent = questsScroll
			Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
			local title = text(row, { Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -140, 0, 22), TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left })
			local barBack = Instance.new("Frame")
			barBack.Position = UDim2.fromOffset(10, 33)
			barBack.Size = UDim2.new(1, -140, 0, 20)
			barBack.BackgroundColor3 = Color3.fromRGB(205, 225, 232)
			barBack.Parent = row
			Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
			local barFill = Instance.new("Frame")
			barFill.BackgroundColor3 = GREEN
			barFill.BorderSizePixel = 0
			barFill.Parent = barBack
			Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
			local progress = text(barBack, { Size = UDim2.fromScale(1, 1), TextScaled = true, TextColor3 = DARK, ZIndex = 2 })
			local claim = button(row, "", function()
				deps.claimQuestRemote:FireServer(group, i)
			end)
			claim.AnchorPoint = Vector2.new(1, 0.5)
			claim.Position = UDim2.new(1, -8, 0.5, 0)
			claim.Size = UDim2.fromOffset(118, 44)
			rows[group][i] = { Title = title, Fill = barFill, Progress = progress, Claim = claim }
		end
	end

	-- ===== Daily reward panel =====
	local dailyFrame, dailyScroll = deps.createPanel("DailyFrame", "Daily Rewards")
	deps.registerPanel(dailyFrame)
	deps.bindTab(dailyButton, dailyFrame)
	local streakLabel = text(dailyScroll, { Size = UDim2.new(1, 0, 0, 30), TextScaled = true, LayoutOrder = 1 })
	local dayRow = Instance.new("Frame")
	dayRow.BackgroundTransparency = 1
	dayRow.Size = UDim2.new(1, 0, 0, 110)
	dayRow.LayoutOrder = 2
	dayRow.Parent = dailyScroll
	local dayLayout = Instance.new("UIListLayout", dayRow)
	dayLayout.FillDirection = Enum.FillDirection.Horizontal
	dayLayout.Padding = UDim.new(0, 5)
	local dayCards = {}
	for d = 1, #GameConfig.DailyRewards do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1 / #GameConfig.DailyRewards, -5, 1, 0)
		card.BackgroundColor3 = Color3.fromRGB(225, 246, 249)
		card.LayoutOrder = d
		card.Parent = dayRow
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
		local stroke = Instance.new("UIStroke", card)
		stroke.Thickness = 3
		text(card, { Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 22), TextScaled = true, Text = "Day " .. d })
		local reward = text(card, { Position = UDim2.fromOffset(4, 34), Size = UDim2.new(1, -8, 0, 44), TextScaled = true })
		local status = text(card, { Position = UDim2.fromOffset(4, 82), Size = UDim2.new(1, -8, 0, 20), TextScaled = true, TextColor3 = MUTED })
		dayCards[d] = { Card = card, Stroke = stroke, Reward = reward, Status = status }
	end
	local dailyClaim = button(dailyScroll, "CLAIM", function()
		deps.claimDailyRemote:FireServer()
	end)
	dailyClaim.Size = UDim2.new(1, 0, 0, 58)
	dailyClaim.LayoutOrder = 3
	text(dailyScroll, { Size = UDim2.new(1, 0, 0, 36), TextSize = 15, LayoutOrder = 4, TextColor3 = MUTED,
		Text = "Come back every day to build your streak. Missing a day starts it over at Day 1." })

	-- ===== Welcome back (offline earnings) panel =====
	local offlineFrame, offlineScroll = deps.createPanel("OfflineFrame", "Welcome Back!")
	deps.registerPanel(offlineFrame)
	local awayLabel = text(offlineScroll, { Size = UDim2.new(1, 0, 0, 30), TextScaled = true, LayoutOrder = 1, TextColor3 = MUTED })
	local earnedLabel = text(offlineScroll, { Size = UDim2.new(1, 0, 0, 56), TextScaled = true, LayoutOrder = 2, TextColor3 = Color3.fromRGB(40, 160, 90) })
	local rateLabel = text(offlineScroll, { Size = UDim2.new(1, 0, 0, 40), TextSize = 16, LayoutOrder = 3, TextColor3 = MUTED })
	local nice = button(offlineScroll, "NICE!", function()
		offlineFrame.Visible = false
	end)
	nice.BackgroundColor3 = GREEN
	nice.Size = UDim2.new(1, 0, 0, 56)
	nice.LayoutOrder = 4

	deps.offlineRemote.OnClientEvent:Connect(function(power, seconds, rate)
		awayLabel.Text = "You were away for " .. duration(seconds)
		earnedLabel.Text = "+" .. fmt(power) .. " ⚡ Power"
		rateLabel.Text = "Your auto-clickers kept working at " .. math.floor(rate * 100 + 0.5) .. "% while you were gone"
			.. (if seconds >= GameConfig.OfflineCapSeconds then " (8h max)." else ".")
			.. "\nUpgrade Offline Earnings in the Skill Tree to earn more."
		for _, p in ipairs(deps.panels) do p.Visible = false end
		offlineFrame.Visible = true
	end)

	-- ===== Refresh =====
	local shownDailyThisSession = false

	local function refresh()
		if not data then return end
		local quests = data.Quests or {}
		local questReady = false
		for _, group in ipairs({ "Daily", "Weekly" }) do
			local list = quests[group] or {}
			local current = (if group == "Daily" then GameConfig.GetDayIndex(now()) else GameConfig.GetWeekIndex(now()))
				== (if group == "Daily" then quests.Day else quests.Week)
			for i, row in ipairs(rows[group]) do
				local entry = current and list[i]
				local def = entry and GameConfig.GetQuestDef(group, entry.Id)
				row.Title.Parent.Visible = def ~= nil
				if def then
					local done = entry.Progress >= def.Target
					row.Title.Text = def.Text .. "   💎 " .. def.Gems .. (if def.Tokens then "  +" .. def.Tokens .. " token" .. (if def.Tokens == 1 then "" else "s") else "")
					row.Fill.Size = UDim2.fromScale(math.clamp(entry.Progress / def.Target, 0, 1), 1)
					row.Progress.Text = fmt(entry.Progress) .. " / " .. fmt(def.Target)
					if entry.Claimed then
						row.Claim.Text, row.Claim.BackgroundColor3 = "CLAIMED", GREY
					elseif done then
						row.Claim.Text, row.Claim.BackgroundColor3 = "CLAIM", GREEN
						questReady = true
					else
						row.Claim.Text, row.Claim.BackgroundColor3 = "In progress", GREY
					end
				end
			end
		end
		questsDot.Visible = questReady

		local nextDay, claimable = GameConfig.GetDailyRewardState(data.Daily, now())
		local requirement = GameConfig.GetRebirthRequirement(data.RebirthCount)
		for d, card in ipairs(dayCards) do
			local reward = GameConfig.DailyRewards[d]
			card.Reward.Text = if reward.Gems then "💎 " .. reward.Gems .. (if reward.Tokens then "\n+" .. reward.Tokens .. " tokens" else "")
				else fmt(math.floor(requirement * reward.CoinsPct)) .. "\nCoins"
			local claimed = if claimable then d < nextDay else d <= nextDay
			local isNext = claimable and d == nextDay
			card.Status.Text = if claimed then "✓" elseif isNext then "TODAY" else ""
			card.Stroke.Color = if isNext then GOLD elseif claimed then GREEN else GREY
			card.Card.BackgroundColor3 = if isNext then Color3.fromRGB(255, 244, 205) else Color3.fromRGB(225, 246, 249)
		end
		streakLabel.Text = if claimable then "Day " .. nextDay .. " reward is ready!" else "Streak: Day " .. nextDay .. "  •  claimed today"
		dailyClaim.BackgroundColor3 = if claimable then GREEN else GREY
		dailyDot.Visible = claimable

		-- Pop the daily calendar once per session, after the starter pet has been picked.
		if claimable and not shownDailyThisSession and data.HasPickedStarterPet then
			shownDailyThisSession = true
			task.delay(1.5, function()
				local anyOpen = false
				for _, p in ipairs(deps.panels) do anyOpen = anyOpen or p.Visible end
				if not anyOpen then dailyFrame.Visible = true end
			end)
		end
	end

	deps.dataRemote.OnClientEvent:Connect(function(newData)
		data = newData
		refresh()
	end)

	-- Reset timers (and day rollover while the game is open).
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 or not data then return end
		acc = 0
		local t = now()
		local dayLeft = 86400 - t % 86400
		local weekLeft = 604800 - (t - 4 * 86400) % 604800
		headers.Daily.Text = "DAILY QUESTS  •  new in " .. duration(dayLeft)
		headers.Weekly.Text = "WEEKLY QUESTS  •  new in " .. duration(weekLeft)
		local _, claimable = GameConfig.GetDailyRewardState(data.Daily, t)
		if not claimable then
			dailyClaim.Text = "Next reward in " .. duration(dayLeft)
		else
			dailyClaim.Text = "CLAIM"
		end
	end)

	deps.requestData()
end

return RetentionUI
