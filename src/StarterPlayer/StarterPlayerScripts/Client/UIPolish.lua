-- Menu polish: blurs the world while any panel is open, pops panels in with a quick scale-up, and
-- shakes the camera for rare moments (skipped when FX is set to low).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIPolish = {}

local BLUR_SIZE = 14

-- deps: { panels (list, may grow), panelScales = { [panel] = UIScale }, isReducedMotion() }
function UIPolish.Start(deps)
	local blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 0
	blur.Parent = Lighting -- created on the client, so only this player sees it

	local function anyOpen()
		for _, panel in ipairs(deps.panels) do
			if panel.Visible then
				return true
			end
		end
		return false
	end
	local function updateBlur()
		TweenService:Create(blur, TweenInfo.new(0.2), { Size = if anyOpen() then BLUR_SIZE else 0 }):Play()
	end

	local hooked = {}
	local function hook(panel)
		if hooked[panel] then return end
		hooked[panel] = true
		panel:GetPropertyChangedSignal("Visible"):Connect(function()
			if panel.Visible and not deps.isReducedMotion() then
				local scale = deps.panelScales[panel]
				if scale then
					scale.Scale = 0.9
					TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			end
			updateBlur()
		end)
	end
	for _, panel in ipairs(deps.panels) do hook(panel) end
	-- Panels registered later (Quests, Daily, Token Shop, ...) get hooked as they appear.
	RunService.Heartbeat:Connect(function()
		for _, panel in ipairs(deps.panels) do
			if not hooked[panel] then hook(panel) end
		end
	end)

	-- Short camera shake via the humanoid's CameraOffset.
	local api = {}
	function api.Shake(strength, duration)
		if deps.isReducedMotion() then return end
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		local ends = os.clock() + (duration or 0.35)
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local left = ends - os.clock()
			if left <= 0 or not humanoid.Parent then
				humanoid.CameraOffset = Vector3.zero
				connection:Disconnect()
				return
			end
			local s = (strength or 0.6) * left / (duration or 0.35)
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
		end)
	end
	return api
end

return UIPolish
