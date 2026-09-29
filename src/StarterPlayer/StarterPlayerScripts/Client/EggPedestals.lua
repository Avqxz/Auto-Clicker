-- Floats the eggs on their pedestals: a gentle bob and a slow turn, on this client only (the server
-- keeps them still). Eggs are parts that MapBuilder marks with a FloatingEgg attribute; far-away ones
-- are skipped to save work.
local RunService = game:GetService("RunService")

local EggPedestals = {}

local BOB_HEIGHT = 0.35
local BOB_SPEED = 1.8 -- radians per second
local TURN_SPEED = 0.5 -- radians per second
local ACTIVE_DISTANCE = 160

function EggPedestals.Start()
	local eggs = {} -- [part] = { Base = CFrame, Phase = number }

	local function track(part)
		if part:IsA("BasePart") and part:GetAttribute("FloatingEgg") and not eggs[part] then
			eggs[part] = { Base = part.CFrame, Phase = math.random() * math.pi * 2 }
		end
	end
	local function scan()
		local map = workspace:FindFirstChild("Map")
		if not map then return end
		for _, d in ipairs(map:GetDescendants()) do
			track(d)
		end
	end
	scan()
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			task.defer(track, d)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local now = os.clock()
		for part, info in pairs(eggs) do
			if not part.Parent then
				eggs[part] = nil
			elseif (camera.CFrame.Position - info.Base.Position).Magnitude < ACTIVE_DISTANCE then
				local t = now + info.Phase
				local lift = BOB_HEIGHT + math.sin(t * BOB_SPEED) * BOB_HEIGHT
				local rotation = info.Base - info.Base.Position
				part.CFrame = CFrame.new(info.Base.Position + Vector3.new(0, lift, 0))
					* CFrame.Angles(0, now * TURN_SPEED + info.Phase, 0) * rotation
			end
		end
	end)
	return {
		-- The model of an egg for UI previews: a copy of its pedestal egg, or nil.
		FindEggPart = function(modelName)
			local map = workspace:FindFirstChild("Map")
			local part = map and map:FindFirstChild(modelName, true)
			return if part and part:IsA("BasePart") then part else nil
		end,
	}
end

return EggPedestals
