-- Animated number label: :Set(value) rolls the shown number to the new value over a short ease-out
-- instead of jumping, and gives the label a quick pop when the value goes up.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Counter = {}
Counter.__index = Counter

local DURATION = 0.35

-- format(value) -> text shown in the label.
function Counter.new(label, format)
	local self = setmetatable({ Label = label, Format = format, Shown = 0, From = 0, To = 0, Started = 0 }, Counter)
	self.Scale = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", label)
	label.Text = format(0)
	RunService.RenderStepped:Connect(function()
		if self.Shown == self.To then
			return
		end
		local t = math.min(1, (os.clock() - self.Started) / DURATION)
		local eased = 1 - (1 - t) ^ 3
		self.Shown = if t >= 1 then self.To else self.From + (self.To - self.From) * eased
		label.Text = format(self.Shown)
	end)
	return self
end

function Counter:Set(value)
	if value == self.To then
		return
	end
	if value > self.To and self.To > 0 then
		self.Scale.Scale = 1.08
		TweenService:Create(self.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end
	self.From, self.To, self.Started = self.Shown, value, os.clock()
end

return Counter
