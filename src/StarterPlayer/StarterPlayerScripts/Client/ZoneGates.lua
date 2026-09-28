-- Per-player zone gates. Gates are solid on the server, so everyone is blocked by default; this
-- makes the gates the local player has unlocked non-solid on their own client. The character is
-- client-simulated, so local collision is what counts for it, while other players still see (and
-- bump into) the gates they haven't unlocked.

local Players = game:GetService("Players")

local ZoneGates = {}

function ZoneGates.Start()
	local player = Players.LocalPlayer
	local rebirths = player:WaitForChild("leaderstats"):WaitForChild("Ascensions") -- RebirthCount in the save
	local gates = workspace:WaitForChild("Map"):WaitForChild("Gates")

	local function refresh()
		for _, gate in ipairs(gates:GetChildren()) do
			local required = gate:GetAttribute("RequiredRebirths")
			if required then
				local unlocked = rebirths.Value >= required
				gate.CanCollide = not unlocked
				gate.Transparency = if unlocked then 0.85 else 0.3
			end
		end
	end

	refresh()
	rebirths.Changed:Connect(refresh)
	gates.ChildAdded:Connect(refresh)
end

return ZoneGates
