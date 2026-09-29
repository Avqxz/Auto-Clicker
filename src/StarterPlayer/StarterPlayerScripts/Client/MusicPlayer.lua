-- Background music: plays GameConfig.Music.Tracks in a shuffled loop (reshuffled each round, never
-- the same track twice in a row) with cross-fades, plus a round 🎵 button to mute/unmute it.
-- Runs on the client, so each player hears (and mutes) only their own music.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local MusicPlayer = {}

-- deps: { screenGui, styleButton }
function MusicPlayer.Start(deps)
	local config = GameConfig.Music
	local enabled = true
	local current -- the Sound playing now

	local function fade(sound, volume, onDone)
		local tween = TweenService:Create(sound, TweenInfo.new(config.FadeSeconds), { Volume = volume })
		tween:Play()
		if onDone then tween.Completed:Connect(onDone) end
	end

	-- Shuffled play order; a new round never starts with the track that just finished.
	local order, index = {}, 0
	local function nextTrack()
		index += 1
		if index > #order then
			local last = order[#order]
			order = table.clone(config.Tracks)
			for i = #order, 2, -1 do
				local j = math.random(i)
				order[i], order[j] = order[j], order[i]
			end
			if #order > 1 and order[1] == last then
				order[1], order[2] = order[2], order[1]
			end
			index = 1
		end
		return order[index]
	end

	local function playNext()
		local track = nextTrack()
		local sound = Instance.new("Sound")
		sound.Name = "Music_" .. track.Name
		sound.SoundId = "rbxassetid://" .. track.Id
		sound.Volume = 0
		sound.Parent = SoundService
		local previous = current
		current = sound
		sound:Play()
		fade(sound, if enabled then config.Volume else 0)
		if previous then
			fade(previous, 0, function() previous:Destroy() end)
		end
	end

	-- Start the next track when the current one is within a fade of its end (so they cross-fade),
	-- or if it stopped for any other reason. Checked from the actual playback position, so buffering
	-- or seeking can't leave a gap.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local sound = current
			if sound and sound.IsLoaded and sound.TimeLength > 0 then
				local left = sound.TimeLength - sound.TimePosition
				if left <= config.FadeSeconds or not sound.IsPlaying then
					playNext()
				end
			end
		end
	end)

	-- Round 🎵 button (left of the shopping cart, under the right-hand button column).
	local button = Instance.new("TextButton")
	button.Name = "MusicToggle"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(1, -128, 0, 308)
	button.Size = UDim2.fromOffset(46, 46)
	button.BackgroundColor3 = Color3.fromRGB(90, 200, 160)
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "🎵"
	button.Parent = deps.screenGui
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
	deps.styleButton(button)
	local slash = Instance.new("Frame") -- red slash shown while muted
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.fromScale(0.5, 0.5)
	slash.Size = UDim2.new(0.9, 0, 0, 5)
	slash.Rotation = -45
	slash.BackgroundColor3 = Color3.fromRGB(240, 70, 90)
	slash.BorderSizePixel = 0
	slash.Visible = false
	slash.Parent = button

	button.MouseButton1Click:Connect(function()
		enabled = not enabled
		slash.Visible = not enabled
		button.BackgroundColor3 = if enabled then Color3.fromRGB(90, 200, 160) else Color3.fromRGB(152, 174, 184)
		if current then fade(current, if enabled then config.Volume else 0) end
	end)

	if #config.Tracks > 0 then
		playNext()
	end
end

return MusicPlayer
